# Demo Script - HPA Under Load

> **Important**
The Kubernetes cluster has already been created before the demonstration by running `bootstrap.sh`. Do **not** run `bootstrap.sh` during the 10-minute demo.

The purpose of the demo is to verify that the deployed environment works correctly and to demonstrate HPA behavior under different ResourceQuota values.

---

# Step 1. Verify the Submitted Commit and Metrics Server

> Before starting the demonstration, I will first verify that I am using the same commit that I submitted. After that, I will verify that Metrics Server is working because the Horizontal Pod Autoscaler depends on CPU metrics. If Metrics Server is unavailable, the HPA cannot calculate CPU utilization and will not scale the application.

## Command 1. Verify the submitted commit

```bash
git log -1
```

## Expected Output
```text
commit c95b385...
Author: ...
Date: ...

Improve bootstrap script readability and deployment workflow
```

## What to Point Out

Point to the commit hash.

> This commit hash matches the hash that I submitted before the demonstration. All commands I execute during the demo are based on this exact version of the project.

# Command 2 — Verify node metrics

```bash
kubectl top nodes
```

## Narration (Before Typing)

> Next, I will verify that Metrics Server is collecting CPU and memory metrics from all Kubernetes nodes.

> I expect CPU and memory values to be displayed for all three nodes.

## Expected Output

Example:

```text
NAME                          CPU(cores)   MEMORY(bytes)

115029258-hpa-control-plane

115029258-hpa-worker

115029258-hpa-worker2
```

(The exact CPU and memory values will change.)

## What to Point Out

Point to:
- control-plane
- worker
- worker2

> All three nodes are reporting CPU and memory metrics. This confirms that Metrics Server is functioning correctly.

## Explain

> The Horizontal Pod Autoscaler does not monitor Pods directly.

> Instead, it requests CPU metrics from Metrics Server.

> Metrics Server collects CPU usage from each kubelet and exposes the metrics through the Kubernetes Metrics API.

> The HPA periodically queries those metrics and compares the current CPU utilization against the configured target utilization to determine whether additional replicas are needed.

# Transition
> Now that I have confirmed the submitted commit and verified that Metrics Server is working, I will verify that the application itself is healthy before generating CPU load.

---

# Step 2 — Verify the Application

## Narration (Before Typing)
> Before making any changes to the cluster, I want to verify that the application is already running correctly.
>
> I expect to see one Deployment, one ReplicaSet, one running application Pod, one ClusterIP Service, and one Horizontal Pod Autoscaler.
>
> After confirming the resources, I will verify that the application is reachable through the ClusterIP Service.

# Command 1 — Display all project resources

```bash
kubectl get all -n 115029258-hpa
```

## Expected Output

Example:

```text
NAME                                 READY   STATUS

pod/115029258-burn-xxxxx             1/1     Running

NAME

service/115029258-burn-svc

NAME

deployment.apps/115029258-burn

NAME

replicaset.apps/115029258-burn-xxxxx

NAME

job.batch/115029258-load
```

(If the load Job has not been started yet, it will not appear.)

## What to Point Out

> The **Deployment** manages the desired number of application replicas.

> The **ReplicaSet** is responsible for creating and maintaining the Pods requested by the Deployment.

> The **application** Pod is currently running successfully.

> The **ClusterIP** Service provides an internal stable endpoint for accessing the application.

> The **Horizontal Pod Autoscaler** is configured but has not started scaling because no CPU load has been generated yet.

---

## Explain

> At this stage, only one application Pod is running because the Deployment specifies one replica initially.
>
> The HPA will only increase the replica count after CPU utilization exceeds the configured target.

# Command 2 — Verify Service Connectivity

## Narration (Before Typing)

> Because the Service type is ClusterIP, it is only accessible from inside the Kubernetes cluster.
>
> I will create a temporary BusyBox Pod to send a request to the Service.

## Command

(Create the temporary BusyBox Pod exactly as documented in the runbook.)

Wait for completion.

```bash
kubectl logs curl-test -n 115029258-hpa
```

## Expected Output

Example:

```text
OK burn 115029258 result=922875 duration=...
```

## What to Point Out

Point to:

```text
115029258
```

> The response contains my student ID, confirming that the request reached my application successfully through the ClusterIP Service.

## Command 3 — Verify the Health Endpoint

(Create the temporary health-test Pod.)

Wait until it completes.

```bash
kubectl logs health-test -n 115029258-hpa
```

## Expected Output

Example:

```text
health check OK
```

## What to Point Out
> The health endpoint returned "health check OK", confirming that the application is healthy.

## Cleanup

Delete both temporary Pods.

```bash
kubectl delete pod curl-test -n 115029258-hpa
```

```bash
kubectl delete pod health-test -n 115029258-hpa
```

Confirm that only the application Pod remains.

```bash
kubectl get pods -n 115029258-hpa
```

## Explain

> The temporary Pods were only used to test Service connectivity.
>
> I delete them before continuing because they are no longer needed and I want the namespace to accurately reflect the application resources before the quota demonstration begins.

# Transition
> The application has now been verified.
>
> Next, I will apply the ResourceQuota selected by the instructor.
>
> Before applying it, I will calculate the maximum number of replicas that I expect the HPA to reach based on the quota values.

---

# Step 3 — Predict the Maximum Number of Replicas

## Narration (Before Typing)
> Before I apply the new ResourceQuota, I will first predict the maximum number of application replicas that the HPA can create.
>
> The HPA itself only decides the desired number of replicas. The actual number of running Pods is limited by Kubernetes resource constraints.
>
> To make the prediction, I compare three independent limits:
>
> 1. Pod quota
> 2. CPU-request quota
> 3. HPA maximum replicas
>
> The smallest value becomes my prediction.

# Wait for the Instructor

At this point, wait for the instructor to provide the new quota values.

Examples:

```text
pods: 4

requests.cpu: 1200m

pods: 8
requests.cpu: 900m
```

Do **not** run any commands yet.

# Write the Prediction

Open a comment in the terminal (or write it on the whiteboard if requested).

Example only:

```text
Pod quota: 6 Pods total
    3 Load Pods (default)
    6 − 3 = **3** application Pods

CPU-request quota: 1000m total
    3 Load Pods × 50m (default cpu req) = 150m
    1000m − 150m = 850m
    850m ÷ 200m (default cpu limit) = **4** application Pods

HPA maxReplicas: **10** application Pods

Prediction: *min*(3,4,10) = **3**
```

## Explain the Calculation
> First, I calculate the maximum number of Pods allowed by the namespace Pod quota.
>
> The load generator always creates three BusyBox Pods, so those Pods also count toward the namespace Pod limit.
>
> Next, I calculate the CPU-request quota.
>
> Every application Pod requests 200 millicores.
>
> Every load Pod requests 50 millicores.
>
> Finally, I compare those values with the HPA maximum replica limit.
>
> The smallest value determines the actual maximum number of application Pods that Kubernetes can run.

#### Example 1
```text
pods: 4
```

Write:

```text
Pod quota: 4 total Pods
    3 load Pods
    4 − 3 = **1** application Pod

CPU-request quota: Not limiting

HPA: **10** application Pod

Prediction: *min*(1,10)= **1**
```

Narrate:

> The Pod quota is now the limiting factor.
>
> Only one application Pod can exist because the remaining three Pods are used by the load generator.

### Example 2
```text
requests.cpu: 1200m
```

Write:

```text
Pod quota: 6 Pods total (default)
    3 Load Pods (default)
    6 − 3 = **3** application Pods

CPU-request quota: 1200m
Load: 3 Load Pods × 50m (default cpu req) = 150m 
Remaining: 1200m - 150m = 1050m
    1050 ÷ 200m (default cpu limit) = **5** application Pods

Prediction: *min*(3,5,10)=**3**
```

Narrate:

> Even though the CPU quota now allows five application Pods, the namespace Pod quota still limits the Deployment to three application Pods.

### Example 3
```text
pods: 10
requests.cpu: 500m
```

Write:

```text
Pod quota: 10 Pods total
    3 Load Pods (default)
    10 − 3 = **7** application Pods

CPU-request quota: 500m total
    3 Load Pods × 50m (default cpu req) = 150m
    500m − 150m = 350m
    350m ÷ 200m (default cpu limit) = **1** application Pods

Prediction: min(7,1,10) = **1**
```

Narrate:

> In this case, the CPU-request quota becomes the limiting factor because there is only enough CPU request remaining for one application Pod.

# Common Mistakes

Do **not** forget:

- Load Pods count toward the Pod quota.
- Load Pods consume CPU requests.
- The Deployment replica count includes only the application Pods.
- The HPA recommendation can never exceed `maxReplicas`.

# Transition
> I have now predicted the maximum number of replicas based on the ResourceQuota provided by the instructor.
>
> Next, I will apply the new quota and verify that Kubernetes has accepted it before starting the load test.

---

# Step 4 — Apply the Instructor's ResourceQuota

## Narration (Before Typing)

> I have calculated my expected maximum number of application replicas.
>
> Next, I will apply the ResourceQuota provided by the instructor and verify that Kubernetes accepted the new quota.
>
> I expect the quota values shown by Kubernetes to exactly match the values used in my prediction.

## Command

Example only.
```text
pods: 4
```

Run:
```bash
./apply-quota.sh 4
```

```text
requests.cpu: 1200m
```

Run:
```bash
./apply-quota.sh 1200m
```

```text
pods: 8
requests.cpu: 900m
```

Run:
```bash
./apply-quota.sh 8 900m
```

## Verify the quota

```bash
kubectl describe quota 115029258-quota -n 115029258-hpa
```

## What to Point Out

Point to:

```text
pods
requests.cpu
```

> Kubernetes has successfully updated the namespace ResourceQuota.
>
> These are the values I used when calculating my prediction.
>
> The application has not been affected yet because no additional Pods have been created.

## Explain

> ResourceQuota is enforced during Pod admission.
>
> Existing Pods continue running.
>
> The new limits only affect future Pods that Kubernetes attempts to create.

# Transition
> The new ResourceQuota has now been applied successfully.
>
> Next, I will generate CPU load and observe how the Horizontal Pod Autoscaler reacts.

# Step 5 — Start the Load Test

## Narration (Before Typing)

> Before starting the load, I expect only one application Pod because the Deployment initially starts with one replica.
>
> Once the BusyBox Job begins generating CPU load, I expect CPU utilization to increase.
>
> The HPA should detect the increased CPU utilization and begin increasing the desired replica count.
>
> Depending on the ResourceQuota, Kubernetes may or may not be able to create all of those replicas.

# Open Monitoring Terminal 1

```bash
kubectl get hpa -n 115029258-hpa -w
```

## Narration

> This window allows me to observe the HPA changing the desired number of replicas in real time.

# Open Monitoring Terminal 2

```bash
kubectl get pods -n 115029258-hpa -w
```

## Narration

> This window shows Pods being created as the Deployment scales.

# Open Monitoring Terminal 3

```bash
watch kubectl top pods -n 115029258-hpa
```

If `watch` is unavailable:

```bash
while true
do
    clear
    date
    kubectl top pods -n 115029258-hpa
    sleep 2
done
```

## Narration

> This window allows me to monitor CPU utilization while the load test is running.

# Terminal 4

Start the load.

```bash
kubectl apply -f manifests/load-job.yaml
```

## What to Point Out

Immediately after applying the Job:

```bash
kubectl get jobs -n 115029258-hpa
```

Point out:
- Job created.
- Three BusyBox Pods begin running.

## Explain

> The BusyBox Job continuously sends requests to the Go application.
>
> This increases CPU utilization.
>
> Metrics Server reports the increased CPU usage.
>
> The HPA compares CPU utilization against the configured target of 50%.
>
> As long as CPU utilization remains above the target, the HPA increases the desired replica count.

## Observe the HPA

Point to:

```text
TARGETS
REPLICAS
```

> CPU utilization is now above the target. The HPA is increasing the desired replica count.

---

## Observe the Pods

Point to:

```text
Running     ContainerCreating
```

> Kubernetes is creating additional application Pods requested by the HPA.

## Observe CPU

Point to:

```text
CPU(cores)
```

> CPU utilization has increased significantly compared with the idle state.
>
> This confirms that the BusyBox Job is successfully generating load.

# Transition
> The HPA has now increased the desired replica count.
>
> Next, I will verify whether Kubernetes was actually able to create all of those Pods or whether the ResourceQuota prevented additional Pods from being admitted.

# Step 6 — Explain Why Scaling Stopped

## Narration (Before Typing)

> At this point, the HPA has already increased the desired replica count.
>
> Now I want to determine whether Kubernetes was able to create all of those Pods.
>
> I expect one of three possible limits to stop further scaling:
> - the namespace Pod quota;
> - the namespace CPU-request quota; or
> - the HPA maximum replica limit.
>
> I will first examine the HPA, then the ReplicaSet, and finally compare the actual result with my prediction.

# Command 1 — Describe the HPA

```bash
kubectl describe hpa 115029258-burn-hpa -n 115029258-hpa
```

## What to Point Out

Point to:

```text
Metrics
Current Replicas
Desired Replicas
```

Then point to the Conditions section.

Example:

```text
AbleToScale      True
ScalingActive    True
ScalingLimited   True
```

## Explain

> The HPA successfully calculated the desired number of replicas using CPU utilization.
>
> It is functioning correctly.
>
> The HPA only recommends the desired replica count.
>
> It does not create Pods itself.

## If ScalingLimited=True

Point to:

```text
Reason:     TooManyReplicas
```

> The HPA recommendation exceeded the configured maximum replica count.
>
> The HPA will never recommend more than the configured maxReplicas value.

## If ScalingLimited=False
> The HPA itself is not limiting scaling.
>
> I now need to verify whether Kubernetes prevented additional Pods from being created.

# Command 2 — Describe the ReplicaSet

```bash
kubectl describe rs -n 115029258-hpa
```

## Narration (Before Typing)

> The ReplicaSet receives the desired replica count from the Deployment.
>
> If Kubernetes rejects new Pods, the ReplicaSet records the reason in its Events section.

## What to Point Out

Point to:

```text
Desired
Current
Ready
```

For example:

```text
Desired: 10
Current: 3
Ready: 3
```

> The HPA requested ten replicas.However, only three application Pods were successfully created.

## Scroll to Events

Point to:

```text
FailedCreate    exceeded quota
```

## Explain

> Kubernetes attempted to create additional Pods.
>
> During Pod admission, ResourceQuota detected that creating another Pod would exceed the namespace quota.
>
> Kubernetes rejected the new Pod.
>
> The ReplicaSet recorded that rejection as a FailedCreate event.

## Important Explanation

> The HPA did not fail.
>
> The ReplicaSet did not fail.
>
> Kubernetes admission control prevented additional Pods from being created because the namespace quota had already been reached.

# Compare with Prediction

Point to your prediction.

> My prediction was: ___ application Pods.
>
> The ReplicaSet successfully created: ___ application Pods.
>
> The prediction matches the observed result.

## If Your Prediction Was Wrong

> My arithmetic was incorrect. The limiting factor was actually _______. I originally assumed _______.
>
> After examining the ReplicaSet events, I can see that Kubernetes was limited by _______ instead.

# Transition

> The scaling behavior matches my prediction.
> Next, I will remove the load generator and observe how the HPA gradually scales the application back down.

---

# Step 7 — Remove the Load and Observe Scale-Down

## Narration (Before Typing)

> The application has now finished handling the CPU load.
>
> I will remove the BusyBox Job that generates the load.
>
> Even after removing the Job, I do **not** expect the application to immediately scale back down.
>
> The HPA uses a downscale stabilization window to prevent rapid scaling fluctuations when CPU utilization changes.
>
> I configured the stabilization window to **15 seconds** for this project so that the scale-down behavior is visible during the demonstration.

---

# Command 1 — Delete the Load Job

```bash
kubectl delete job 115029258-load -n 115029258-hpa
```

## What to Point Out

> The Job has been deleted.
> No additional requests will be sent to the application.

---

# Continue Monitoring

Keep the two monitoring windows open.

Terminal 1

```bash
kubectl get hpa -n 115029258-hpa -w
```

Terminal 2

```bash
kubectl get pods -n 115029258-hpa -w
```

## Narration

> I expect CPU utilization to decrease.
> However, I do not expect the HPA to immediately reduce the number of replicas because the stabilization window is still active.

---

## Observe the HPA

Watch until replicas begin decreasing.

Point to:

```text
REPLICAS
```

> CPU utilization has fallen below the target.
> After the stabilization window expires, the HPA begins reducing the desired number of replicas.

---

## Observe the Pods

Point to the Pods disappearing.

> Kubernetes is terminating the extra application Pods because they are no longer required.

---

# Command 2 — Describe the HPA

```bash
kubectl describe hpa 115029258-burn-hpa -n 115029258-hpa
```

## What to Point Out

If present, point to:

```text
ScaleDownStabilized
```

> This condition indicates that the HPA intentionally delayed scaling down even though CPU utilization had already fallen below the target.

## Explain

> The stabilization window allows the HPA to wait before removing replicas.
> This prevents rapid scaling up and down when CPU utilization fluctuates around the target.

## Continue Watching

Eventually the Deployment should return to one replica.

Verify:

```bash
kubectl get deployment -n 115029258-hpa
```

Verify Pods:

```bash
kubectl get pods -n 115029258-hpa
```

## What to Point Out

Point to:

```text
READY

1/1
```

> The Deployment has now returned to its original state with one application replica.

---

# Transition

> The application has now completed the full autoscaling lifecycle.
> Finally, I will review the Kubernetes event timeline to show the complete sequence of events that occurred during the demonstration.

---

# Step 8 — Review the Kubernetes Event Timeline

## Narration (Before Typing)

> Kubernetes records significant events during the lifecycle of the application.
> I will display the events in chronological order and explain what happened during the demonstration from beginning to end.

## Command

```bash
kubectl get events -n 115029258-hpa --sort-by=.lastTimestamp
```

## Narration While Reviewing

Walk through the events in order. Point to the important events as they appear.

### SuccessfulCreate
> Kubernetes successfully created the initial application Pod.

### SuccessfulRescale
> The HPA detected high CPU utilization and increased the desired replica count.

### FailedCreate
> The ReplicaSet attempted to create additional Pods.
> Kubernetes admission control rejected those Pods because the namespace ResourceQuota would have been exceeded.

### Killing / Deleted
> After the load generator was removed and CPU utilization returned below the target, Kubernetes terminated the unnecessary application Pods.

### Final State
> The application returned to one running replica.
> The HPA completed the full autoscaling lifecycle successfully.

---

# Closing Summary

> This demonstration showed the complete Horizontal Pod Autoscaler lifecycle.
>
> First, the application was verified.
>
> Next, I predicted the maximum number of replicas based on the ResourceQuota.
>
> After CPU load was generated, the HPA increased the desired replica count.
>
> ResourceQuota prevented Kubernetes from creating additional Pods beyond the calculated limit.
>
> Finally, after removing the load, the HPA gradually reduced the Deployment back to one replica using the configured stabilization window.
