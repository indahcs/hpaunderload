# Section 1

### Q0.Why do we verify the commit?
It guarantees that the demonstration is performed using the same source code that was submitted for grading. This ensures reproducibility and prevents changes after submission.

### Q1. Why is Metrics Server required?
Metrics Server collects CPU and memory usage from the Kubernetes nodes and Pods.

The HPA uses those CPU metrics to calculate the desired number of replicas.

Without Metrics Server, CPU utilization would be unknown and the HPA would show `<unknown>` instead of scaling.

### Q2. What would happen if Metrics Server stopped working?
The application would continue running normally.

However, the HPA would no longer receive CPU metrics.

The TARGETS column would become `<unknown>` and the HPA would stop making scaling decisions based on CPU utilization.

### Q3. Why do we need the `--kubelet-insecure-tls` patch?
The kind cluster uses self-signed kubelet certificates.

By default, Metrics Server verifies kubelet certificates before collecting metrics.

Because those certificates are not signed by a trusted Certificate Authority, the verification fails.

The `--kubelet-insecure-tls` option tells Metrics Server to skip certificate verification so it can communicate with the kubelets in the local development cluster.

### Q4. Would you use `--kubelet-insecure-tls` in production?

> No.

Skipping certificate verification reduces security because the kubelet identity cannot be validated.

In production, kubelets should use certificates signed by a trusted Certificate Authority so Metrics Server can verify the certificates while still communicating securely.

### Q5. How often does the HPA check CPU utilization?
The HPA periodically requests CPU metrics from Metrics Server.

Metrics Server continuously refreshes the metrics, and the HPA uses the latest available values when calculating the desired number of replicas.

(If asked for exact timing, you can mention your Metrics Server configuration uses a 15-second metric resolution.)

---

# Section 2

### Q1. Why is the Service a ClusterIP instead of a NodePort?
This project only requires internal communication between Kubernetes resources.

The BusyBox load generator and the temporary test Pods communicate with the application inside the cluster.

Exposing the application externally is unnecessary for this demonstration.

### Q2. Why can't you use curl directly from the EC2 instance?
The Service type is ClusterIP.

ClusterIP Services only have an internal Kubernetes virtual IP and cannot be reached directly from the EC2 host.

A Pod inside the cluster shares the Kubernetes network and can access the Service.

### Q3. Why create a temporary Pod instead of using the application Pod itself?
I want to simulate how another workload inside the cluster communicates with the Service.

Using a separate Pod also avoids modifying or interfering with the application container.

### Q4. Why do the temporary Pods specify a CPU request?
The namespace ResourceQuota limits CPU requests.

Kubernetes requires every new Pod to declare a CPU request before it can be admitted into the namespace.

Without the CPU request, Kubernetes rejects the Pod before it starts.

### Q5. Why do you delete the temporary Pods?
They are only used to verify connectivity.

Removing them keeps the namespace clean and prevents them from affecting later calculations involving Pod quotas and CPU-request quotas.

---

# Section 3

### Q1. Why do you subtract three Pods?
The BusyBox Job always creates three load Pods. Those Pods consume namespace resources and therefore count toward the namespace Pod quota.

### Q2. Why do you subtract 150m CPU?
Each load Pod requests 50 millicores. Three load Pods consume a total of 150 millicores. That CPU request is unavailable to the application Pods.

### Q3. Why do you divide by 200m?
Each application Pod requests 200 millicores.

Dividing the remaining CPU-request quota by 200m gives the maximum number of application Pods that Kubernetes can admit.

### Q4. Why don't you use CPU limits instead of CPU requests?
ResourceQuota is configured to limit **CPU requests**, not CPU limits.

Kubernetes checks the requested resources during Pod admission.

The HPA also calculates utilization as a percentage of the CPU request.

### Q5. Why doesn't the HPA know the quota?
The HPA only calculates the desired number of replicas based on CPU utilization. It does not consider ResourceQuota.

The ReplicaSet attempts to create the requested Pods, and Kubernetes admission control rejects any Pods that would exceed the namespace quota.

---

# Section 4

### Q1. Why doesn't changing the quota immediately create or delete Pods?
ResourceQuota does not create Pods. It only limits whether Kubernetes is allowed to admit new Pods. Scaling decisions are still made by the HPA.

### Q2. Does ResourceQuota restart existing Pods?
> No.

Existing Pods continue running normally. Only newly created Pods are checked against the updated quota.

### Q3. Why do you verify the quota after applying it?
Because my prediction is based on the applied quota. I need to confirm that Kubernetes accepted the correct values before starting the load test.

---

# Section 5

### Q1. Why doesn't the HPA increase replicas immediately?
The HPA waits for Metrics Server to collect updated CPU metrics. It periodically evaluates those metrics before making a scaling decision.

### Q2. Why do you monitor three windows?
Each window shows a different part of the autoscaling process.

The CPU metrics show why scaling should happen.

The HPA window shows the desired replica count.

The Pods window shows whether Kubernetes successfully creates those Pods.

### Q3. What is the difference between the Deployment and the HPA?
The Deployment manages the application Pods. The HPA modifies the Deployment's replica count based on CPU utilization.

### Q4. What if CPU utilization falls below 50% immediately?
The HPA would no longer need additional replicas. Depending on the stabilization window, it would eventually begin scaling the Deployment back down.

---

# Section 6

### Q1. Why didn't Kubernetes create all ten Pods?
The HPA only requested ten replicas. Kubernetes admission control prevented additional Pods because creating them would exceed the namespace ResourceQuota.

### Q2. Did the HPA fail?
> No.

The HPA successfully calculated the desired replica count. The ReplicaSet attempted to create those Pods.

Kubernetes admission control rejected the additional Pods because of the namespace quota.

### Q3. Who actually creates Pods?
The Deployment specifies the desired replica count.

The ReplicaSet creates and maintains the Pods.

The HPA only updates the Deployment's replica count.

Kubernetes admission control decides whether new Pods are allowed to be created.

### Q4. What is Kubernetes admission control?
Admission control checks every request before Kubernetes accepts it.

In this project, ResourceQuota is one admission controller.

It rejects Pods that would exceed the configured namespace resource limits.


### Q5. Why do the FailedCreate events appear in the ReplicaSet instead of the HPA?
The ReplicaSet is responsible for creating Pods.

Since it is the object attempting to create the Pods, it receives the FailedCreate events when Kubernetes rejects those requests.

---

# Section 7

### Q1. Why didn't the HPA immediately remove Pods?
The HPA uses a downscale stabilization window.

Instead of immediately reducing replicas, it waits for a short period to ensure that CPU utilization remains consistently below the target.

This prevents unnecessary scaling fluctuations.

### Q2. Why did you configure a 15-second stabilization window?
The Kubernetes default is approximately 300 seconds.

Waiting five minutes would make the scale-down difficult to observe during a 10-minute demonstration.

I reduced the window to 15 seconds so the complete autoscaling lifecycle could be demonstrated within the allotted time.

### Q3. What would happen with a 0-second stabilization window?
The HPA would begin removing replicas immediately after CPU utilization fell below the target.

That could cause rapid scaling up and down if the workload fluctuated frequently.

### Q4. What would happen with the default 300-second window?
The HPA would wait approximately five minutes before reducing replicas.

This provides greater stability in production environments but would make the scale-down difficult to observe during a short demonstration.

### Q5. Why doesn't Kubernetes keep all the Pods running?
Extra Pods consume CPU and memory resources. Once CPU utilization returns below the target, the additional replicas are no longer needed, so the HPA reduces the Deployment back to the minimum replica count.

---

# Section 8

### Q1. Why do you sort the events?
Sorting by timestamp makes it easier to follow the order in which Kubernetes processed the scaling operations.

### Q2. Which component actually rejected the Pods?
Kubernetes admission control rejected the Pods because creating them would violate the namespace ResourceQuota.

### Q3. Which event best proves that ResourceQuota worked?
The `FailedCreate` event containing `exceeded quota`.

### Q4. Which event proves that the HPA worked?
The `SuccessfulRescale` events.

### Q5. If you had unlimited quota, what would happen?
The ReplicaSet would be able to create all of the replicas requested by the HPA, up to the configured `maxReplicas` value of 10.

---

# Oral Questions 

### Question 1
> Your Pods have CPU limits of **500m** but requests of **200m**. Which number does the HPA's 50% target apply to, and what would change if you deleted the requests entirely?

The HPA calculates CPU utilization as a percentage of the **CPU request**, not the CPU limit.

In my project:

- CPU request = **200m**
- CPU limit = **500m**
- HPA target = **50%**

That means the HPA tries to keep each Pod around **100m CPU usage**, because:

```
50% × 200m = 100m
```

The CPU limit is different. It is the maximum CPU the container is allowed to use before Linux throttles it. The HPA does not use the limit when calculating utilization.

If I removed the CPU requests entirely, the HPA would no longer be able to calculate CPU utilization because the utilization percentage is based on the request value. The HPA would report something like:

```
TARGETS

<unknown>/50%
```

and it would stop making scaling decisions based on CPU utilization.

### If the professor asks "Why?"

Because utilization is defined as:

```
Current CPU Usage
-----------------
Requested CPU
```

Without a CPU request, there is no denominator for the calculation.

### Question 2

> During your demo the HPA showed `<unknown>/50%` for the first minute. What was happening, and what two things would you check if it never resolved?

### Answer

Immediately after creating the cluster or deploying the application, Metrics Server may not have collected CPU metrics yet.

The HPA depends on Metrics Server to provide CPU usage information.

While Metrics Server is still collecting its first metrics, the HPA displays:

```
<unknown>/50%
```

because CPU utilization is not available yet.

Normally, after Metrics Server finishes collecting metrics, the HPA automatically begins showing actual CPU utilization percentages.

### If it never resolved, I would check two things.

### First

I would verify that Metrics Server is running.

```bash
kubectl get pods -n kube-system
```

or

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

The Metrics API should report:

```
AVAILABLE=True
```

### Second

I would verify that Metrics Server can actually retrieve metrics.

```bash
kubectl top nodes
```

or

```bash
kubectl top pods -n 115029258-hpa
```

If those commands fail, the HPA cannot receive CPU metrics.

### Another possible cause

If Metrics Server is running but still cannot collect metrics in a kind cluster, I would check that it was started with:

```
--kubelet-insecure-tls
```

because kind uses self-signed kubelet certificates.

### Question 3
> The quota blocked the ReplicaSet, but `kubectl get hpa` still showed a desired replica count above the running count. Which controller actually got refused, and where did the refusal surface?

### Answer

The HPA was **not** refused.

The HPA successfully calculated the desired number of replicas and updated the Deployment.

The Deployment then instructed the ReplicaSet to create additional Pods.

The ReplicaSet attempted to create those Pods.

The request was rejected during Kubernetes admission control because creating another Pod would exceed the namespace ResourceQuota.

Therefore, the controller that encountered the failure was the **ReplicaSet**.

The refusal appeared in the ReplicaSet Events section.

For example:

```
FailedCreate

exceeded quota
```

### The scaling process is:

Metrics Server
↓
HPA calculates desired replicas
↓
Deployment updated
↓
ReplicaSet creates Pods
↓
Admission Controller checks ResourceQuota
↓
Pod rejected
↓
ReplicaSet records FailedCreate

### Question 4
> Your load Job Pods count against the same quota as the application Pods. How did you account for that in your prediction, and how could you restructure the project so they didn't?

### Answer

When calculating the prediction, I always included the load Pods because they consume namespace resources just like the application Pods.

For the Pod quota:

```
Available Pods = Namespace Pod quota − Load Pods
```

For example:

```
6 Pods − 3 Load Pods = 3 Application Pods
```

For the CPU-request quota:

Each load Pod requests:

```
50m
```

Three load Pods consume:

```
150m
```

So I subtract that from the namespace CPU-request quota before calculating how many application Pods can still be admitted.

### How could the project be restructured?

One option would be to place the load generator in a different namespace.

Each namespace has its own ResourceQuota.

If the BusyBox Job were deployed into another namespace, it would no longer consume Pod quota or CPU-request quota from the application's namespace.

That would allow the application quota to be calculated independently from the load generator.

### Question 5
> If the instructor set `requests.cpu` to **900m** instead of limiting Pods, walk through the arithmetic, and explain which event proves the limit was CPU rather than Pod count.

### Answer

First, I calculate how much CPU is already reserved by the load generator.

Each BusyBox Pod requests:

```
50m
```

There are three load Pods.

```
3 × 50m = 150m
```

The namespace CPU-request quota is:

```
900m
```

Remaining CPU requests:

```
900m−150m=750m
```

Each application Pod requests:

```
200m
```

Maximum application Pods:

```
750 ÷ 200 = 3
```

Only three complete Pods fit because Kubernetes cannot create a partial Pod.

If the Pod quota is larger than three and the HPA maximum is ten, then the CPU-request quota becomes the limiting factor.

### Which event proves it?

The ReplicaSet Events section.

```
FailedCreate
```

with a message indicating that creating another Pod would exceed the namespace `requests.cpu` quota.

That tells me the limiting resource was CPU requests rather than the Pod count.

The HPA itself would still continue recommending additional replicas, but Kubernetes admission control would reject any new Pods once the CPU-request quota had been exhausted.

### Folow Up Questions 
> Which event proves the cap was CPU, not pod count?

### Answer: 
I would look at the FailedCreate event message. The event type is the same for both Pod quota and CPU-request quota violations. The message tells me which quota was exceeded.

### Example - Poq Quota
FailedCreate
exceeded quota: 115029258-quota, requested: pods=1, used: pods=6, limited: pods=6

### Example - CPU-request Quota
FailedCreate
exceeded quota: 115029258-quota, requested: requests.cpu=200m, used: requests.cpu=900m, limited: requests.cpu=900m