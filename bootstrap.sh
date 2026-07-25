#!/bin/bash 
# HPA under load bootstrap
# Creates a clean kind cluster, deploys the application and supporting
# resources, and waits until Metrics Server returns pod metrics.
# To run from the repository root: ./bootstrap.sh

set -euxo pipefail

STUDENT_ID="115029258"
CLUSTER_NAME="${STUDENT_ID}-hpa"
NAMESPACE="${STUDENT_ID}-hpa"

# 1. Check the required tools and project files
command -v docker >/dev/null 
command -v kind >/dev/null
command -v kubectl >/dev/null
command -v sed >/dev/null

docker info >/dev/null || (echo "Docker is not running" && exit 1)

test -f kind-config.yaml || (echo "kind-config.yaml not found" && exit 1)
test -f manifests/metrics-server.yaml || (echo "manifests/metrics-server.yaml not found" && exit 1)
test -f manifests/00-namespace.yaml || (echo "manifests/00-namespace.yaml not found" && exit 1)
test -f manifests/01-deployment.yaml || (echo "manifests/01-deployment.yaml not found" && exit 1)
test -f manifests/02-service.yaml || (echo "manifests/02-service.yaml not found" && exit 1)
test -f manifests/03-hpa.yaml || (echo "manifests/03-hpa.yaml not found" && exit 1)
test -f manifests/quota.yaml || (echo "manifests/quota.yaml not found" && exit 1)
test -f manifests/load-job.yaml || (echo "manifests/load-job.yaml not found" && exit 1)
test -f apply-quota.sh || (echo "apply-quota.sh not found" && exit 1)

# 2. Delete the existing cluster if it exists
if kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
    kind delete cluster --name "${CLUSTER_NAME}"
fi

# 3. Create the kind cluster: one control-plane and two worker nodes
kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml --wait 180s 

# Wait until all three kind nodes become Ready
NODES_READY=false

for ATTEMPT in $(seq 1 36); do
    READY_NODES=$(
        kubectl get nodes --no-headers |
            awk '$2 == "Ready" {count++} END {print count + 0}'
    )

    echo "Waiting for nodes: ${READY_NODES}/3 Ready, attempt ${ATTEMPT}/36"

    if [ "${READY_NODES}" -eq 3 ]; then
        NODES_READY=true
        break
    fi

    sleep 5
done

if [ "${NODES_READY}" = false ]; then
    echo "All three kind nodes did not become Ready within the expected time."
    kubectl get nodes -o wide
    kubectl get pods -n kube-system -o wide
    exit 1
fi

kubectl get nodes -o wide

# 4. Install the Metrics Server 
kubectl apply -f manifests/metrics-server.yaml

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

kubectl get apiservice v1beta1.metrics.k8s.io 

# 5. Create the namespace and deploy the CPU burn application 
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-deployment.yaml
kubectl apply -f manifests/02-service.yaml

kubectl rollout status deployment/${STUDENT_ID}-burn -n "${NAMESPACE}" --timeout=180s

# 6. Create the HPA and apply the default namespace quota 
kubectl apply -f manifests/03-hpa.yaml

./apply-quota.sh 6 1000m 

# 7. Wait until Metrics Server returns pod metrics
METRICS_READY=false 

for ATTEMPT in $(seq 1 60); do 
    echo "Waiting for pod metrics: attempt ${ATTEMPT}/60"

    if kubectl top pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -q .; then 
        METRICS_READY=true 
        break 
    fi

    sleep 5 
done 

if [ "${METRICS_READY}" != "true" ]; then 
    echo "Pod metrics did not become available within the expected time."
    
    kubectl get apiservice v1beta1.metrics.k8s.io -o wide || true
    kubectl logs deployment/metrics-server -n kube-system --tail=100 || true

    exit 1
fi

# 8. Wait until the HPA displays a valid CPU target
HPA_READY=false

for ATTEMPT in $(seq 1 30); do
    HPA_TARGETS=$(
        kubectl get hpa "${STUDENT_ID}-burn-hpa" \
            -n "${NAMESPACE}" \
            -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' \
            2>/dev/null || true
    )

    echo "Waiting for HPA metrics: attempt ${ATTEMPT}/30"

    if [ -n "${HPA_TARGETS}" ]; then
        HPA_READY=true
        break
    fi

    sleep 5
done

if [ "${HPA_READY}" != "true" ]; then
    echo "HPA did not display valid CPU utilization within the expected time."
    kubectl describe hpa "${STUDENT_ID}-burn-hpa" -n "${NAMESPACE}"
    exit 1
fi

# 9. Display the final state 
kubectl get nodes -o wide 
kubectl get all -n "${NAMESPACE}"
kubectl get hpa -n "${NAMESPACE}"
kubectl describe quota "${STUDENT_ID}-quota" -n "${NAMESPACE}"
kubectl top nodes 
kubectl top pods -n "${NAMESPACE}"

echo "HPA under load project bootstrapped successfully" 
echo "The load Job was not started" 
echo "Start load with: kubectl apply -f manifests/load-job.yaml"
