# Runbook

This runbook describes the steps required to deploy, verify, demonstrate, and clean up the **HPA Under Load** project. Following these instructions recreates the same environment and demonstration used during project development.

---

# 1. Purpose

The purpose of this runbook is to provide a repeatable procedure for deploying and demonstrating the project from a clean environment.

By following the documented steps, a user can:

- create a local Kubernetes cluster using kind;
- deploy the Go CPU burn application;
- install and verify Metrics Server;
- configure Horizontal Pod Autoscaler (HPA);
- apply namespace ResourceQuota limits;
- generate CPU load;
- observe autoscaling behavior; and
- verify how ResourceQuota affects ReplicaSet pod creation.

---

# 2. Scope

This runbook covers the complete lifecycle of the project, including:

- environment preparation;
- Kubernetes cluster creation;
- application deployment;
- project verification;
- Horizontal Pod Autoscaler demonstration;
- ResourceQuota verification;
- cleanup; and
- troubleshooting.

---

# 3. Environment

The project was developed and tested using the following environment.

| Component | Version |
|-----------|---------|
| Operating System | Windows 11 |
| Docker Desktop | 29.x |
| kind | v0.32.0 |
| Kubernetes | v1.36.x |
| kubectl | v1.34.x |
| Go | 1.23+ |
| Git | 2.52.x |

Equivalent or newer versions should also work.

The commands shown in this runbook were tested using Git Bash on Windows 11. Equivalent Linux or macOS shells may produce slightly different command output.

---

# 4. Clone the Repository

Clone the project repository:

```bash
git clone https://github.com/indahcs/hpaunderload.git
```

Move into the repository root:

```bash
cd hpaunderload
```

All remaining commands in this runbook should be executed from this directory unless otherwise specified.

---

# 5. Repository Layout

The repository should have the following structure.

```text
hpaunderload/
│
├── app/
├── manifests/
├── evidence/
├── bootstrap.sh
├── apply-quota.sh
├── kind-config.yaml
├── README.md
└── runbook.md
```

The commands shown throughout this runbook should be executed from the repository root unless otherwise specified.

---

# 6. Prerequisites

Before beginning, verify that the required software is installed.

```bash
docker --version
kind version
kubectl version --client
git --version
go version
```

Confirm that Docker Desktop is running.

```bash
docker info
```

If Docker is not running, start Docker Desktop before continuing.

---

# 7. Bootstrap the Environment

## Purpose

Create a clean Kubernetes environment and deploy all project resources using the provided automation script.

The bootstrap script removes any previous cluster with the same name before creating a new one. This ensures that every demonstration starts from a known and reproducible state.

## Command

From the repository root, execute:

```bash
time ./bootstrap.sh
```

## Expected Result

The bootstrap script automatically performs the following actions:

1. Deletes any existing kind cluster.
2. Creates a new three-node Kubernetes cluster.
3. Waits until all nodes are in the `Ready` state.
4. Installs Metrics Server.
5. Creates the project namespace.
6. Deploys the Go application.
7. Creates the ClusterIP Service.
8. Creates the Horizontal Pod Autoscaler.
9. Applies the default ResourceQuota.
10. Waits until Metrics Server begins reporting Pod metrics.
11. Displays the final cluster status.

At the end of execution, the following message should be displayed:

```text
HPA under load project bootstrapped successfully

The load Job was not started

Start load with:
kubectl apply -f manifests/load-job.yaml
```

## Verification

Confirm that the bootstrap script completed without errors before continuing. If the script terminates early, review the displayed error message before proceeding.

---

# 8. Verify Cluster Health

## Purpose

Verify that the Kubernetes cluster has been created successfully and that all nodes are in the **Ready** state.

## Command

```bash
kubectl get nodes -o wide
```

## Expected Result

The cluster should contain three nodes.

- One control-plane node
- Two worker nodes

All three nodes should report a `Ready` status.

Example (output abbreviated):

```text
NAME                          STATUS   ROLES           VERSION
115029258-hpa-control-plane   Ready    control-plane   v1.36.1
115029258-hpa-worker          Ready    <none>          v1.36.1
115029258-hpa-worker2         Ready    <none>          v1.36.1
```

## Verification

If all nodes are in the `Ready` state, the cluster is ready for application deployment.

---

# 9. Verify Metrics Server

## Purpose

Confirm that Metrics Server is running correctly and that the Kubernetes Metrics API is available.

Metrics Server is required because the Horizontal Pod Autoscaler uses CPU metrics to calculate the desired number of replicas.

## Step 1. Verify the Metrics API

Run:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

Expected result:

```text
AVAILABLE=True
```

## Step 2. Verify node metrics

Run:

```bash
kubectl top nodes
```

CPU and memory usage should be displayed for all three nodes.

Example (output abbreviated):

```text
NAME                          CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
115029258-hpa-control-plane   283m         1%       591Mi           3%
115029258-hpa-worker          57m          0%       167Mi           1%
115029258-hpa-worker2         49m          0%       145Mi           0%
```

## Step 3. Verify Pod metrics

Run:

```bash
kubectl top pods -n 115029258-hpa
```

Expected result:

One application Pod should appear together with its current CPU and memory usage.

Example:

```text
NAME                             CPU(cores)   MEMORY(bytes)
115029258-burn-xxxxx   1m           2Mi
```

## Verification

Metrics Server is functioning correctly when:

- the APIService reports `AVAILABLE=True`;
- `kubectl top nodes` returns resource usage; and
- `kubectl top pods` returns metrics for the application Pod.

If CPU usage appears as `<unknown>`, wait a few moments and run the commands again.

---

# 10. Verify the Application Deployment

## Purpose

Confirm that the application has been deployed successfully before generating CPU load.

## Verify all project resources

Run:

```bash
kubectl get all -n 115029258-hpa
```

## Expected Result

The namespace should contain:

- one running Pod;
- one Deployment;
- one ReplicaSet;
- one ClusterIP Service; and
- one Horizontal Pod Autoscaler.

Example (output abbreviated):

```text
NAME                                 READY   STATUS    RESTARTS   AGE
pod/115029258-burn-756969954-hnmpm   1/1     Running   0          2m

NAME                                TYPE        CLUSTER-IP      PORT(S)
service/115029258-burn-svc          ClusterIP   10.96.243.121   80/TCP

NAME                                READY   UP-TO-DATE   AVAILABLE
deployment.apps/115029258-burn      1/1     1            1

NAME                                       DESIRED   CURRENT   READY
replicaset.apps/115029258-burn-756969954   1         1         1

NAME                                                     TARGETS
horizontalpodautoscaler.autoscaling/115029258-burn-hpa   cpu: 6%/50%
```

## Verification

Confirm that:

- the Pod status is `Running`;
- the Deployment is `Available`;
- the ReplicaSet has one ready replica; and
- the Service has been created successfully.

If any resource is missing or reports an error state, resolve the issue before continuing.

---

# 11. Verify Service Connectivity

## Purpose

Verify that the application can be reached through the ClusterIP Service.

This confirms that Kubernetes networking is functioning correctly before the load test begins.

> **ResourceQuota note:** The bootstrap script applies a namespace `requests.cpu` quota before this test. Kubernetes therefore requires every new container in the namespace to declare a CPU request. Each temporary BusyBox Pod requests `10m` CPU so that it can pass quota admission. The Pod is deleted immediately after the test and does not affect the later autoscaling calculation.

## Step 1. Test the application endpoint

Create a temporary BusyBox Pod with a CPU request.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: curl-test
  namespace: 115029258-hpa
spec:
  restartPolicy: Never
  containers:
    - name: curl-test
      image: busybox:1.36
      command:
        - wget
        - -qO-
        - http://115029258-burn-svc
      resources:
        requests:
          cpu: 10m
EOF
```

Wait until the Pod completes.

```bash
kubectl wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/curl-test \
  -n 115029258-hpa \
  --timeout=60s
```

Verify the response.

```bash
kubectl logs curl-test -n 115029258-hpa
```

Expected result:

```text
OK burn 115029258 result=...
```

Delete the temporary Pod.

```bash
kubectl delete pod curl-test -n 115029258-hpa
```

## Step 2. Verify the health endpoint

Create a temporary BusyBox Pod with a CPU request.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: health-test
  namespace: 115029258-hpa
spec:
  restartPolicy: Never
  containers:
    - name: health-test
      image: busybox:1.36
      command:
        - wget
        - -qO-
        - http://115029258-burn-svc/health
      resources:
        requests:
          cpu: 10m
EOF
```

Wait until the Pod completes.

```bash
kubectl wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/health-test \
  -n 115029258-hpa \
  --timeout=60s
```

Verify the response.

```bash
kubectl logs health-test -n 115029258-hpa
```

Expected result:

```text
health check OK
```

Delete the temporary Pod.

```bash
kubectl delete pod health-test -n 115029258-hpa
```

> Confirm that both temporary test Pods have been deleted before applying a custom quota or starting the load test.

```bash
kubectl get pods -n 115029258-hpa
```

Expected result:

- Only the Go burn application Pod remains.
- Neither `curl-test` nor `health-test` appears in the namespace.

## Verification

Service connectivity is verified when:

- the root endpoint returns the expected application response;
- the `/health` endpoint returns `health check OK`; and
- both temporary test Pods are deleted successfully.

The application and Service are now verified. Continue by applying the selected ResourceQuota and calculating the expected maximum number of application replicas.

---

# 12. Apply a Custom ResourceQuota

The quota helper accepts a Pod limit, a CPU-request limit, or both values.

Apply a Pod-count limit while keeping the default CPU-request limit:

```bash
./apply-quota.sh 6
```

Apply a CPU-request limit while keeping the default Pod limit:

```bash
./apply-quota.sh 900m
```

Apply both limits explicitly:

```bash
./apply-quota.sh 8 1200m
```

---

# 13. Verify the ResourceQuota

## Purpose

Review the namespace ResourceQuota before starting the load test.

Understanding the configured limits makes it possible to predict how many application Pods can be created during autoscaling.

## Command

```bash
kubectl describe quota 115029258-quota -n 115029258-hpa
```

## Expected Result

The default quota should limit the namespace to:

```text
Pods:          6
CPU Requests:  1000m
```

Example:

```text
Resource      Used   Hard
pods          1      6
requests.cpu  200m   1
requests.cpu  200m   1
```

Kubernetes may display the hard CPU-request limit as `1` instead of `1000m`; both values represent one CPU core.

At this stage only the application Pod is running, so only a small portion of the quota has been consumed.

## Verification

Confirm that:

- Pod limit is **6**
- CPU request limit is **1000m**

The ResourceQuota is now ready for the load test.

---

# 14. Predict the Maximum Number of Application Pods

## Purpose

Estimate how many application Pods can run before the ResourceQuota prevents additional Pods from being created. This prediction will later be compared with the actual Kubernetes behavior.

## Current Configuration

### Namespace ResourceQuota

| **Namespace ResourceQuota (Variable)** | Value |
| -------------------------------------- | ----: |
| Pods                                   |     6 |
| CPU Requests                           | 1000m |

| **Application Configuration (Fixed)** | Value |
| ------------------------------------- | ----: |
| CPU Request                           |  200m |
| CPU Limit                             |  500m |

| **Load Generator Configuration (Fixed)** | Value |
| ---------------------------------------- | ----: |
| Load Pods                                |     3 |
| CPU Request per Pod                      |   50m |

## Pod Calculation

Maximum namespace Pods:

```text
6
```

Load Job creates:

```text
3 Pods
```

Remaining Pod capacity:

```text
6 - 3 = 3 application Pods
```

## CPU Request Calculation

Namespace CPU Requests:

```text
1000m
```

Load Job CPU Requests:

```text
3 × 50m = 150m
```

Remaining CPU Requests:

```text
1000m - 150m = 850m
```

Each application Pod requests:

```text
200m
```

Maximum application Pods allowed by CPU:

```text
850m ÷ 200m = 4 Pods
```

## Final Prediction

Three different limits exist.

- Pod quota
- CPU request quota
- HPA maximum replicas

The final result is the smallest value.

```text
min(3, 4, 10) = 3 Pods
```

The expected outcome is:

- HPA requests additional replicas.
- Deployment updates its desired replica count.
- ReplicaSet attempts to create Pods.
- ResourceQuota allows only **three** application Pods to run.

---

# 15. Prepare the Monitoring Windows

## Purpose

Open monitoring commands before generating load.

This allows scaling events to be observed in real time.

### Terminal 1 – Monitor the HPA

```bash
kubectl get hpa -n 115029258-hpa -w
```

Observe:

- TARGETS
- REPLICAS

### Terminal 2 - Monitor the Pods.

```bash
kubectl get pods -n 115029258-hpa -w
```

Observe:

- New Pods
- Pod status
- Pod termination

### Terminal 3 — Monitor Pod CPU Usage

`kubectl top` does not support continuous watch mode. On Linux, the `watch` utility can repeatedly execute the command.

```bash
watch kubectl top pods -n 115029258-hpa
```

On Windows Git Bash, the `watch` utility is typically unavailable. Use the following loop instead:

```bash
while true
do
    clear
    date
    kubectl top pods -n 115029258-hpa
    sleep 2
done
```

Press **Ctrl+C** to stop monitoring.

Observe:

- CPU usage
- Memory usage

## Verification

Before continuing:

- Terminal 1 is watching the HPA.
- Terminal 2 is watching Pods.
- Terminal 3 is displaying CPU metrics.

---

# 16. Start the Load Test

## Purpose

Generate CPU load so the Horizontal Pod Autoscaler can begin scaling the Deployment.

## Command

```bash
kubectl apply -f manifests/load-job.yaml
```

## Verify the Job

```bash
kubectl get jobs -n 115029258-hpa
```

Example while the load is running:

```text
NAME             STATUS    COMPLETIONS   DURATION   AGE
115029258-load   Running   0/3           30s        30s
```

Verify that the load Pods have started successfully:
Depending on the Kubernetes version, the output may omit the `STATUS` column. The important result is that the Job has not completed and its three Pods remain active.

```bash
kubectl get pods -n 115029258-hpa -l app=115029258-load
```

### Expected Result

- Three BusyBox load Pods
- All load Pods in the `Running` state


Example output:

```text
NAME                      READY   STATUS    RESTARTS   AGE
115029258-load-7zfq7      1/1     Running   0          30s
115029258-load-c7gqw      1/1     Running   0          30s
115029258-load-xfj7q      1/1     Running   0          30s
```

Verify the complete namespace state:

```bash
kubectl get pods -n 115029258-hpa
```

Example after the default quota limit is reached:

```text
NAME                             READY   STATUS    RESTARTS   AGE
115029258-burn-xxxx              1/1     Running   0          2m
115029258-burn-yyyy              1/1     Running   0          45s
115029258-burn-zzzz              1/1     Running   0          45s
115029258-load-7zfq7             1/1     Running   0          30s
115029258-load-c7gqw             1/1     Running   0          30s
115029258-load-xfj7q             1/1     Running   0          30s
```

The exact Pod names and ages will vary between runs.

## Observe HPA Scaling

Terminal 1 should begin displaying changes similar to:

Example:

```text
NAME                 REFERENCE                   TARGETS     MINPODS   MAXPODS   REPLICAS
115029258-burn-hpa   Deployment/115029258-burn   189%/50%    1         10        1

↓

NAME                 REFERENCE                   TARGETS     MINPODS   MAXPODS   REPLICAS
115029258-burn-hpa   Deployment/115029258-burn   189%/50%    1         10        5

↓

NAME                 REFERENCE                   TARGETS     MINPODS   MAXPODS   REPLICAS
115029258-burn-hpa   Deployment/115029258-burn   199%/50%    1         10        10
```

The HPA increases the desired number of replicas because average CPU utilization exceeds the configured 50% target.

## Observe Resource Usage

Terminal 2 should display new application Pods entering the Running state.

Example:

```text
115029258-burn-xxxxx    Running
```

The number of Running Pods will stop increasing after three application Pods have been created.

## Observe CPU Usage

Terminal 3 should display increased CPU utilization while the load generator is running.

Higher CPU utilization confirms that the BusyBox Job is successfully generating workload for the application.

## Verification

The load test is successful when:

- CPU utilization increases.
- The HPA increases its desired replica count.
- Additional application Pods are created.

---

# 17. Verify Horizontal Pod Autoscaler Behavior

## Purpose

Verify that the Horizontal Pod Autoscaler responds correctly to increased CPU utilization by increasing the Deployment's desired replica count.

## Verify HPA Details

Run:

```bash
kubectl describe hpa 115029258-burn-hpa -n 115029258-hpa
```

## Expected Result

During the load test, CPU utilization should exceed the configured target.

Example:

```text
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  ... / 50%
```

The HPA should increase the desired number of replicas.

Example:

```text
Deployment pods:       10 current / 10 desired
```

The **Events** section should contain entries similar to the following:

```text
Events:
  Type    Reason             Age    From                       Message
  ----    ------             ----   ----                       -------
  Normal  SuccessfulRescale  ...    horizontal-pod-autoscaler  New size: 5; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  ...    horizontal-pod-autoscaler  New size: 10; reason: cpu resource utilization (percentage of request) above target
```

The exact timestamps and replica counts may differ depending on the ResourceQuota values used during the demonstration.

## Review HPA Conditions

The **Conditions** section shows the current state of the Horizontal Pod Autoscaler and confirms whether it is functioning correctly.

Example:

```text
Conditions:
  Type            Status  Reason            Message
  ----            ------  ------            -------
  AbleToScale     True    ReadyForNewScale  recommended size matches current size
  ScalingActive   True    ValidMetricFound  the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  True    TooManyReplicas   the desired replica count is more than the maximum replica count

```

Typical meanings:

- **AbleToScale = True** indicates that the HPA can communicate with and update the target Deployment.
- **ScalingActive = True** indicates that valid CPU metrics are available for calculating the desired replica count.
- **ScalingLimited = True** with the reason `TooManyReplicas` indicates that the calculated replica count exceeded the configured `maxReplicas` value.

> **Note:** `ScalingLimited=True` indicates that the HPA cannot increase the desired replica count any further because it has reached the configured `maxReplicas` value. Separately, the namespace `ResourceQuota` may still prevent the ReplicaSet from creating all requested Pods. These are two different mechanisms that can occur at the same time during this demonstration.

## Verification

Confirm that:

- CPU utilization is greater than the 50% target.
- The HPA has increased the Deployment's desired replica count.
- Scaling events appear in the Events section.

The HPA is now functioning as expected.

---

# 18. Verify ReplicaSet Behavior

## Purpose

Verify that the ReplicaSet attempts to create the Pods requested by the Horizontal Pod Autoscaler.

## Verify ReplicaSets

```bash
kubectl get rs -n 115029258-hpa
```

Expected Result:

```text
NAME                       DESIRED   CURRENT   READY   AGE
115029258-burn-xxxxx       10        3         3       108m
```

## Describe the ReplicaSet

```bash
kubectl describe rs -n 115029258-hpa
```

## Expected Result

The ReplicaSet should report:

```text
Replicas:   3 current / 10 desired
```

Condition:

```text
  Type             Status  Reason
  ----             ------  ------
  ReplicaFailure   True    FailedCreate
```

Events similar to:

```text
FailedCreate
pods "... " is forbidden:
exceeded quota
```

## Verification

Confirm that:

- the ReplicaSet received the updated replica count from the Deployment;
- it attempted to create additional Pods; and
- Pod creation failed because of the namespace ResourceQuota.

This confirms that the ReplicaSet—not the HPA—is responsible for creating Pods.

---

# 19. Verify ResourceQuota Enforcement

## Purpose

Confirm that the namespace ResourceQuota is preventing additional Pods from being created.

## Command

```bash
kubectl describe quota 115029258-quota -n 115029258-hpa
```

## Expected Result

Example:

```text
Resource      Used   Hard
--------      ----   ----
pods          6      6
requests.cpu  750m   1
```

The namespace has reached the configured Pod limit.

Although additional CPU requests are still available, Kubernetes cannot create more Pods because the Pod quota has already been exhausted.

## Verification

Confirm that:

- Pod usage equals the configured limit.
- CPU request usage remains below the configured maximum.
- Pod quota is the limiting factor.

The observed behavior should match the prediction made before the load test.

---

# 20. Review the Namespace Event Timeline

Display namespace events in chronological order:

```bash
kubectl get events -n 115029258-hpa --sort-by=.lastTimestamp
```

The event timeline should show the main lifecycle of the load test:

1. The HPA detects CPU utilization above the target.
2. The HPA updates the desired replica count.
3. The ReplicaSet creates the Pods allowed by the quota.
4. Additional Pod creation fails with `FailedCreate`.
5. The events report `exceeded quota`.
6. After the load Job is removed, the HPA begins scaling down.

The exact timestamps, repeated events, and number of `FailedCreate` messages may differ between executions because Kubernetes continuously retries Pod creation while the Deployment remains above the namespace quota.

---

# 21. Verify Scaling Prediction

## Purpose

Compare the observed results with the calculated prediction.

## Predicted Result

Before starting the load test, the expected maximum number of application Pods was calculated as:

```text
min(3, 4, 10) = 3 application Pods
```

## Observed Result

Verify the running Pods.

```bash
kubectl get pods -n 115029258-hpa
```

Expected Result:

- Three application Pods
- Three BusyBox load Pods

Total:

```text
6 Pods
```

## Verification

The observed result should match the earlier prediction.

This confirms that:

- the HPA correctly requested additional replicas;
- the Deployment updated its desired replica count;
- the ReplicaSet attempted to create additional Pods; and
- the ResourceQuota prevented further Pod creation.

---

# 22. Stop the Load Test

## Purpose

Remove the CPU workload and observe the Horizontal Pod Autoscaler returning the Deployment toward its minimum replica count.

## Delete the Load Job

```bash
kubectl delete job 115029258-load -n 115029258-hpa
```

## Verify Job Removal

```bash
kubectl get jobs -n 115029258-hpa
```

Expected Result:

```text
No resources found in 115029258-hpa namespace.
```

## Observe CPU Usage

Continue observing the following command:

```bash
kubectl top pods -n 115029258-hpa
```

CPU utilization should gradually decrease.

## Observe HPA Scale-down

Continue observing the following command:

```bash
kubectl get hpa -n 115029258-hpa -w
```

The HPA should gradually reduce the desired number of replicas. The exact intermediate replica counts may vary. The expected behavior is:

```text
multiple replicas → gradual scale-down → 1 replica
```

Example progression:

```text
10 → 5 → 4 → 1
```

The reduction may not happen immediately because the HPA respects the configured scale-down stabilization window. The final state should return to `minReplicas: 1`.

### Review HPA during Scale-Down

Display the HPA after the load Job has been deleted and CPU utilization has decreased.

```bash
kubectl describe hpa 115029258-burn-hpa -n 115029258-hpa
```

The `Conditions` section should contain entries similar to the following:

```text
Conditions:
  Type            Status  Reason               Message
  ----            ------  ------               -------
  AbleToScale     True    ScaleDownStabilized  recent recommendations were higher than current one, applying the highest recent recommendation
  ScalingActive   True    ValidMetricFound     the HPA successfully calculated the desired replica count from CPU utilization
  ScalingLimited  False   DesiredWithinRange   the desired replica count is within the acceptable range
```

During scale-down:

- **AbleToScale = True** confirms that the HPA is allowed to update the Deployment.
- **ScaleDownStabilized** indicates that the HPA temporarily keeps a higher replica recommendation before reducing the number of Pods. This stabilization window helps prevent rapid scaling fluctuations if CPU usage briefly increases again.
- **ScalingActive = True** confirms that Metrics Server is still providing valid CPU metrics.
- **ScalingLimited = False** indicates that the desired replica count is now within the configured range, so the HPA is no longer constrained by its scaling limits.

The exact timestamps and messages may differ between demonstrations, but the HPA should eventually reduce the Deployment back toward its minimum replica count after CPU utilization remains below the target.

## Verification

Wait until CPU utilization falls below the configured target.

The HPA should gradually reduce the Deployment toward its minimum replica count.

---

# 23. Verify Final Cluster State

## Purpose

Confirm that the cluster has returned to a stable state after the load test.

## Verify Project Resources

```bash
kubectl get all -n 115029258-hpa
```

Expected Result:

- One running application Pod
- One Deployment
- One ReplicaSet
- One ClusterIP Service
- One Horizontal Pod Autoscaler

No BusyBox load Pods should remain.

## Verify HPA

```bash
kubectl get hpa -n 115029258-hpa
```

Expected Result:

```text
NAME                 REFERENCE                   TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
115029258-burn-hpa   Deployment/115029258-burn   cpu: 0%/50%   1         10        1          ---
```

## Verification

The demonstration is complete when:

- CPU utilization has returned to normal.
- The HPA has reduced the Deployment to its minimum replica count.
- The namespace contains only the application resources.

---

# 24. Cleanup

## Purpose

Remove the project resources after the demonstration has been completed.

Cleaning up the environment ensures that the next deployment starts from a clean state and prevents leftover resources from affecting future demonstrations.

## Delete the Load Job

If the load generator is still running, remove it.

```bash
kubectl delete job 115029258-load -n 115029258-hpa
```

If the Job has already been removed, Kubernetes may return:

```text
Error from server (NotFound)
```

This message is expected and can be ignored.

## Delete the kind Cluster

Delete the entire Kubernetes cluster.

```bash
kind delete cluster --name 115029258-hpa
```

## Verify Cleanup

Verify that the cluster has been removed.

```bash
kind get clusters
```

Expected result:

```text
No clusters found.
```

The local Kubernetes environment has now been removed successfully.

---

# 25. Troubleshooting

The following table lists common issues that may occur during deployment or demonstration.

| Problem | Possible Cause | Suggested Solution |
|----------|----------------|--------------------|
| Worker nodes remain `NotReady` | Nodes are still joining the cluster | Wait a few seconds and run `kubectl get nodes` again. |
| Metrics Server API reports `AVAILABLE=False` | Metrics Server is still starting | Wait for the deployment to finish and verify using `kubectl rollout status`. |
| `kubectl top` returns an error | Metrics Server is not yet providing metrics | Wait a few moments and try again. |
| HPA shows `<unknown>` CPU utilization | Metrics are not yet available | Verify Metrics Server and wait until metrics are collected. |
| Application Pod is not running | Image pull or container startup failure | Review Pod events using `kubectl describe pod` and container logs using `kubectl logs`. |
| BusyBox load Job finishes immediately | Incorrect Job configuration | Verify `load-job.yaml` and recreate the Job. |
| ReplicaSet reports `FailedCreate` | Namespace ResourceQuota has been exceeded | This behavior is expected during the demonstration. Verify the ResourceQuota using `kubectl describe quota`. |
| Bootstrap script stops unexpectedly | Missing tools or project files | Verify all prerequisites and rerun `bootstrap.sh`. |

### Run the bootstrap script in debug mode

If the bootstrap script stops unexpectedly and the normal output does not show enough detail, rerun it with Bash command tracing enabled:

```bash
bash -x bootstrap.sh
```

This prints each command before it runs and is useful for troubleshooting. The output is intentionally verbose and should not be used for the normal demonstration.

---

# 26. Demonstration Verification Checklist

The project demonstration is considered successful when all of the following conditions have been verified.

## Environment

- [ ] Bootstrap script completes successfully.
- [ ] Three Kubernetes nodes report `Ready`.
- [ ] Metrics Server reports `AVAILABLE=True`.

## Application

- [ ] Namespace created successfully.
- [ ] Deployment created successfully.
- [ ] ClusterIP Service created successfully.
- [ ] Application Pod reaches the `Running` state.
- [ ] Application responds through the Service.
- [ ] Health endpoint responds successfully.

## Horizontal Pod Autoscaler

- [ ] HPA created successfully.
- [ ] CPU utilization exceeds the configured target.
- [ ] HPA increases the desired replica count.
- [ ] Deployment reflects the updated replica count.

## ResourceQuota

- [ ] ResourceQuota applied successfully.
- [ ] ReplicaSet attempts to create additional Pods.
- [ ] ReplicaSet reports `FailedCreate` events.
- [ ] Pod creation stops after the namespace reaches its configured Pod limit.
- [ ] Observed behavior matches the predicted maximum number of application Pods.

## Scale-down

- [ ] Load Job removed successfully.
- [ ] CPU utilization decreases.
- [ ] HPA gradually reduces the Deployment replica count.
- [ ] Deployment returns to its minimum replica count.

---

# 27. Summary

This runbook provides the complete procedure required to deploy, verify, demonstrate, and remove the HPA Under Load project.

The project demonstrates how Kubernetes controllers work together during autoscaling by combining:

- a Go application deployed as a Kubernetes Deployment;
- a ClusterIP Service for internal communication;
- Metrics Server for resource collection;
- Horizontal Pod Autoscaler (HPA) for automatic scaling;
- ResourceQuota for namespace resource enforcement; and
- a BusyBox Job for generating CPU load.

Following this runbook recreates the same environment and demonstration in a repeatable and consistent manner.

## Additional Notes

The exact CPU utilization percentages, Pod names, ReplicaSet names, and timestamps shown throughout this runbook are examples.

Actual values may vary depending on the local environment and execution time, but the overall behavior of the Kubernetes controllers should remain the same.
