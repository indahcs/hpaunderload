#!/bin/bash
# HPA Under Load bootstrap
# Creates a clean kind cluster, deploys the application and supporting
# resources, and waits until Metrics Server returns pod metrics.
# To run from the repository root: ./bootstrap.sh

set -euo pipefail

STUDENT_ID="115029258"
CLUSTER_NAME="${STUDENT_ID}-hpa"
NAMESPACE="${STUDENT_ID}-hpa"
APP_NAME="${STUDENT_ID}-burn"
HPA_NAME="${STUDENT_ID}-burn-hpa"

step() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

info() {
    echo "  $1"
}

success() {
    echo "✓ $1"
}

fail() {
    echo "✗ $1" >&2
    exit 1
}

# 1. Check required tools and files
step "1. Checking prerequisites"

for COMMAND in docker kind kubectl sed; do
    if command -v "$COMMAND" >/dev/null 2>&1; then
        success "$COMMAND is available"
    else
        fail "Required command not found: $COMMAND"
    fi
done

if docker info >/dev/null 2>&1; then
    success "Docker is running"
else
    fail "Docker is not running"
fi

REQUIRED_FILES=(
    "kind-config.yaml"
    "manifests/metrics-server.yaml"
    "manifests/00-namespace.yaml"
    "manifests/01-deployment.yaml"
    "manifests/02-service.yaml"
    "manifests/03-hpa.yaml"
    "manifests/quota.yaml"
    "manifests/load-job.yaml"
    "apply-quota.sh"
)

for FILE in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$FILE" ]]; then
        fail "Required file not found: $FILE"
    fi
done

success "All required project files are present"

# 2. Delete an existing cluster
step "2. Preparing a clean environment"

if kind get clusters 2>/dev/null | grep -Fxq "$CLUSTER_NAME"; then
    info "Deleting existing cluster: $CLUSTER_NAME"
    kind delete cluster --name "$CLUSTER_NAME"
    success "Existing cluster deleted"
else
    info "No existing cluster named $CLUSTER_NAME was found"
fi

# 3. Create the kind cluster
step "3. Creating the kind cluster"

kind create cluster \
    --name "$CLUSTER_NAME" \
    --config kind-config.yaml \
    --wait 180s

success "Control plane is ready"

# 4. Wait for all nodes
step "4. Waiting for all three nodes"

NODES_READY="false"

for ATTEMPT in $(seq 1 36); do
    READY_NODES=$(
        kubectl get nodes --no-headers 2>/dev/null |
            awk '$2 == "Ready" {count++} END {print count + 0}'
    )

    info "Node readiness: ${READY_NODES}/3"

    if [[ "$READY_NODES" -eq 3 ]]; then
        NODES_READY="true"
        break
    fi

    sleep 5
done

if [[ "$NODES_READY" != "true" ]]; then
    kubectl get nodes -o wide
    fail "All three nodes did not become Ready"
fi

success "All three nodes are Ready"

kubectl get nodes

# 5. Install Metrics Server
step "5. Installing Metrics Server"

kubectl apply -f manifests/metrics-server.yaml >/dev/null

info "Waiting for the Metrics Server Deployment"

kubectl rollout status \
    deployment/metrics-server \
    -n kube-system \
    --timeout=180s

success "Metrics Server Deployment is ready"

# 6. Deploy the application
step "6. Deploying the application"

kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-deployment.yaml
kubectl apply -f manifests/02-service.yaml

info "Waiting for the application Deployment"

kubectl rollout status \
    deployment/"$APP_NAME" \
    -n "$NAMESPACE" \
    --timeout=180s

success "Application Deployment is ready"

# 7. Create HPA and quota
step "7. Configuring autoscaling and quota"

kubectl apply -f manifests/03-hpa.yaml

./apply-quota.sh 6 1000m

success "HPA and default ResourceQuota are configured"

# 8. Wait for Pod metrics
step "8. Waiting for Pod metrics"

METRICS_READY="false"

for ATTEMPT in $(seq 1 60); do
    if kubectl top pods \
        -n "$NAMESPACE" \
        --no-headers >/dev/null 2>&1; then

        METRICS_READY="true"
        break
    fi

    info "Metrics not ready yet (${ATTEMPT}/60)"
    sleep 5
done

if [[ "$METRICS_READY" != "true" ]]; then
    kubectl get apiservice v1beta1.metrics.k8s.io || true
    kubectl logs deployment/metrics-server \
        -n kube-system \
        --tail=100 || true

    fail "Pod metrics did not become available"
fi

success "Pod metrics are available"

# 9. Wait for HPA metrics
step "9. Waiting for HPA metrics"

HPA_READY="false"

for ATTEMPT in $(seq 1 30); do
    HPA_TARGET=$(
        kubectl get hpa "$HPA_NAME" \
            -n "$NAMESPACE" \
            -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' \
            2>/dev/null || true
    )

    if [[ -n "$HPA_TARGET" ]]; then
        HPA_READY="true"
        break
    fi

    info "HPA metrics not ready yet (${ATTEMPT}/30)"
    sleep 5
done

if [[ "$HPA_READY" != "true" ]]; then
    kubectl describe hpa "$HPA_NAME" \
        -n "$NAMESPACE" || true

    fail "HPA metrics did not become available"
fi

success "HPA is receiving CPU metrics"

# 10. Display final state
step "10. Final cluster status"

echo
echo "Nodes"
echo "-----"
kubectl get nodes

echo
echo "Application resources"
echo "---------------------"
kubectl get all -n "$NAMESPACE"

echo
echo "ResourceQuota"
echo "-------------"
kubectl describe quota "${STUDENT_ID}-quota" \
    -n "$NAMESPACE"

echo
echo "Node metrics"
echo "------------"
kubectl top nodes

echo
echo "Pod metrics"
echo "-----------"
kubectl top pods -n "$NAMESPACE"

echo
echo "============================================================"
echo "✓ HPA Under Load project bootstrapped successfully"
echo "============================================================"
echo
echo "Cluster:   $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo
echo "The load Job was not started."
echo
echo "Start the load test with:"
echo "kubectl apply -f manifests/load-job.yaml"
