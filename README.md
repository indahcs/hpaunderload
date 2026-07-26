# HPA Under Load with Kubernetes

![Go](https://img.shields.io/badge/Go-1.23-blue) ![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36-blue) ![kind](https://img.shields.io/badge/kind-v0.32-green) ![Docker](https://img.shields.io/badge/Docker-29.x-blue)

A demonstration project showing how Kubernetes Horizontal Pod Autoscaler (HPA) responds to CPU load while operating under namespace ResourceQuota constraints.

**Course:** CLO835 – Portable Technologies in Cloud

**Project:** Final Project - Summer 2026

**Student:** Indah Cahyani Styoningrum (115029258)

## Table of Contents

- [Project Overview](#project-overview)
- [Project Objectives](#project-objectives)
- [System Architecture](#system-architecture)
- [Repository Structure](#repository-structure)
- [Technologies Used](#technologies-used)
- [Prerequisites](#prerequisites)
- [Project Components](#project-components)
- [Application Configuration](#application-configuration)
- [Default ResourceQuota](#default-resourcequota)
- [Quick Start](#quick-start)
- [Verify the Deployment](#verify-the-deployment)
- [Running the Load Test](#running-the-load-test)
- [Stopping the Load Test](#stopping-the-load-test)
- [Implementation Highlights](#implementation-highlights)
- [Design Decisions](#design-decisions)
- [Known Limitations](#known-limitations)
- [Project Demonstration](#project-demonstration)
- [References](#references)

---

## Project Overview

This project demonstrates how Kubernetes Horizontal Pod Autoscaler (HPA) automatically scales an application based on CPU utilization. The application is written in Go and deployed to a local Kubernetes cluster created with **kind (Kubernetes in Docker)**. Each request sent to the application performs CPU-intensive work, making it easy to observe how the HPA reacts when CPU usage increases.

The project intentionally applies a namespace **ResourceQuota**. As the application scales, the HPA requests additional replicas, but Kubernetes cannot always create them because the namespace eventually reaches its resource limits. This allows the project to demonstrate not only autoscaling, but also how different Kubernetes controllers interact when resources become constrained.

The repository also includes automation scripts to recreate the complete environment from scratch. Running the bootstrap script creates the Kubernetes cluster, installs Metrics Server, deploys the application, configures the HPA, and applies the default ResourceQuota, making the project easy to reproduce and verify.

---

## Project Objectives

This project was developed to demonstrate the following Kubernetes concepts:

- Deploy a containerized Go application.
- Expose the application using a ClusterIP Service.
- Install and configure Metrics Server.
- Configure Horizontal Pod Autoscaler (HPA) using CPU utilization.
- Apply a namespace ResourceQuota.
- Generate CPU load using Kubernetes Jobs.
- Observe how the HPA updates the Deployment during high CPU utilization.
- Demonstrate how ResourceQuota prevents the ReplicaSet from creating additional Pods.
- Observe the scale-down stabilization period after the load is removed.
- Automate the deployment process using shell scripts.

---

## System Architecture

The project consists of two independent workflows:

1. **Application traffic flow**, where the BusyBox load generator sends HTTP requests to the Go application through a ClusterIP Service.
2. **Autoscaling workflow**, where Kubernetes monitors CPU utilization and automatically adjusts the number of application Pods.

The following diagram illustrates how the major Kubernetes components interact during the demonstration.

```text
                    Application Traffic
────────────────────────────────────────────────────────────────────

                    +----------------------+
                    |   BusyBox Load Job   |
                    +----------+-----------+
                                |
                                | HTTP requests
                                v
                    +----------------------+
                    |   ClusterIP Service  |
                    +----------+-----------+
                                |
                                |
                                v
                    +----------------------+
                    | Go CPU Burn          |
                    | Application          |
                    | (Deployment → Pods)  |
                    +----------------------+

                    Autoscaling Workflow
────────────────────────────────────────────────────────────────────

                    +----------------------+
                    | Go CPU Burn Pods     |
                    +----------+-----------+
                                |
                                | CPU utilization
                                v
                    +----------------------+
                    |    Metrics Server    |
                    +----------+-----------+
                                |
                                | Resource metrics
                                v
                    +----------------------+
                    | Horizontal Pod       |
                    | Autoscaler (HPA)     |
                    +----------+-----------+
                                |
                                | Desired replicas
                                v
                    +----------------------+
                    |     Deployment       |
                    +----------+-----------+
                                |
                                | Creates / removes Pods
                                v
                    +----------------------+
                    |      ReplicaSet      |
                    +----------+-----------+
                                |
                                | Admission control
                                v
                    +----------------------+
                    |    ResourceQuota     |
                    +----------+-----------+
                                |
                                | Allowed Pods
                                v
                    +----------------------+
                    | Go CPU Burn Pods     |
                    +----------------------+
```

During the demonstration, the BusyBox Job continuously generates HTTP requests to the Go application. As CPU utilization increases, Metrics Server collects resource metrics and makes them available to the Horizontal Pod Autoscaler (HPA). The HPA calculates the required number of replicas and updates the Deployment. The Deployment instructs the ReplicaSet to create additional Pods, while the namespace ResourceQuota determines whether those Pods can actually be admitted. In this project, the HPA requests up to ten replicas, but the configured ResourceQuota limits the number of application Pods that can run simultaneously.

### Scaling Workflow

The Horizontal Pod Autoscaler (HPA) does not create Pods directly. Instead, Kubernetes follows the controller hierarchy shown below.

```text
                        CPU Load
                            │
                            ▼
                        Metrics Server
                            │
                            ▼
                Horizontal Pod Autoscaler
                            │
                            ▼
                        Deployment
                            │
                            ▼
                        ReplicaSet
                            │
                            ▼
                        Pod Creation
                            │
                            ▼
                    ResourceQuota Validation
```

When CPU utilization exceeds the configured threshold, the HPA updates the **Deployment's desired replica count**. The Deployment then updates its ReplicaSet, which attempts to create additional Pods. Before each Pod is admitted into the namespace, Kubernetes checks the configured ResourceQuota. If the namespace has reached its limits, Pod creation is rejected and the ReplicaSet reports `FailedCreate` events.

This behavior demonstrates that the HPA is functioning correctly even when the desired number of replicas cannot be achieved due to resource constraints.

---

## Repository Structure

```text
hpaunderload/
│
├── app/
│   ├── Dockerfile
│   ├── go.mod
│   └── main.go
│
├── manifests/
│   ├── 00-namespace.yaml
│   ├── 01-deployment.yaml
│   ├── 02-service.yaml
│   ├── 03-hpa.yaml
│   ├── load-job.yaml
│   ├── metrics-server.yaml
│   └── quota.yaml
│
├── evidence/
│
├── bootstrap.sh
├── apply-quota.sh
├── kind-config.yaml
├── README.md
├── runbook.md
└── .gitattributes
```

### Repository Contents

| File / Directory   | Description                                                                       |
| ------------------ | --------------------------------------------------------------------------------- |
| `app/`             | Contains the Go application source code and Dockerfile.                           |
| `manifests/`       | Kubernetes manifests used to deploy the project resources.                        |
| `bootstrap.sh`     | Creates a clean Kubernetes environment and deploys the application automatically. |
| `apply-quota.sh`   | Applies configurable namespace ResourceQuota values.                              |
| `kind-config.yaml` | Defines the local Kubernetes cluster topology.                                    |
| `runbook.md`       | Operational guide describing deployment, testing, and troubleshooting procedures. |
| `evidence/`        | Screenshots and command outputs collected during project verification.            |

---

## Technologies Used

The following tools and technologies were used to build and demonstrate this project.

| Technology                      | Purpose                                                                |
| ------------------------------- | ---------------------------------------------------------------------- |
| Go                              | Implements the CPU burn application.                                   |
| Docker                          | Builds and runs the application container.                             |
| kind                            | Creates a local multi-node Kubernetes cluster.                         |
| Kubernetes                      | Deploys and manages the application.                                   |
| Metrics Server                  | Provides CPU and memory metrics for the HPA.                           |
| Horizontal Pod Autoscaler (HPA) | Automatically adjusts the number of replicas based on CPU utilization. |
| ResourceQuota                   | Limits namespace resources to demonstrate quota enforcement.           |
| BusyBox                         | Generates HTTP requests during the load test.                          |
| Git                             | Version control.                                                       |

---

## Prerequisites

The following software must already be installed on the host machine.

| Software                | Version Used  |
| ----------------------- | ------------- |
| Docker Desktop          | 29.x or later |
| kind                    | v0.32.0       |
| kubectl                 | v1.34.x       |
| Git                     | 2.52.x        |
| Go _(development only)_ | 1.23 or later |

Verify the installation.

```bash
docker --version
kind version
kubectl version --client
git --version
go version
```

---

## Project Components

The project consists of several independent Kubernetes resources that work together.

| Component                 | Description                                                         |
| ------------------------- | ------------------------------------------------------------------- |
| Namespace                 | Isolates all project resources from other workloads.                |
| Deployment                | Runs the Go CPU burn application.                                   |
| ClusterIP Service         | Provides an internal stable endpoint for the application.           |
| Metrics Server            | Supplies CPU metrics to the HPA.                                    |
| Horizontal Pod Autoscaler | Monitors CPU utilization and adjusts the desired replica count.     |
| ResourceQuota             | Restricts the number of Pods and CPU requests within the namespace. |
| Load Job                  | Generates continuous HTTP requests to create CPU load.              |

---

## Application Configuration

The application is configured with the following resource settings.

| Property                 | Value      |
| ------------------------ | ---------- |
| Container Port           | 8080       |
| CPU Request              | 200m       |
| CPU Limit                | 500m       |
| HPA Target CPU           | 50%        |
| Minimum Replicas         | 1          |
| Maximum Replicas         | 10         |
| Scale-down Stabilization | 60 seconds |

The Go application exposes two HTTP endpoints.

| Endpoint  | Purpose                                                                 |
| --------- | ----------------------------------------------------------------------- |
| `/`       | Performs CPU-intensive work and returns the student ID.                 |
| `/health` | Returns a health response for Kubernetes readiness and liveness probes. |

---

## Default ResourceQuota

The default namespace ResourceQuota is intentionally restrictive.

| Resource     | Default Value |
| ------------ | ------------- |
| Pods         | 6             |
| CPU Requests | 1000m         |

The load generator creates three BusyBox Pods.

Each load Pod requests:

```text
50m CPU
```

Total load CPU requests:

```text
3 × 50m = 150m
```

Each application Pod requests:

```text
200m CPU
```

Under the default quota:

```text
Pod quota: 6 total Pods − 3 load Pods = 3 application Pods
```

CPU request quota:

```text
1000m − 150m = 850m
850m ÷ 200m = 4 application Pods
```

Since Kubernetes must satisfy **both** limits simultaneously, the expected maximum number of running application Pods is:

```text
min(3, 4, 10) = 3
```

This prediction is verified during the HPA demonstration.

---

## Quick Start

Clone the repository.

```bash
git clone https://github.com/indahcs/hpaunderload.git
```

Move into the project directory.

```bash
cd hpaunderload
```

Create the Kubernetes environment.

```bash
time ./bootstrap.sh
```

The bootstrap script automatically:

- removes any existing kind cluster;
- creates a new three-node cluster;
- installs Metrics Server;
- deploys the Go application;
- creates the ClusterIP Service;
- configures the Horizontal Pod Autoscaler;
- applies the default ResourceQuota; and
- waits until Metrics Server starts reporting Pod metrics.

The load generator is **not** started automatically, so the cluster begins in an idle state and is ready for the demonstration.

---

### Verify the Deployment

Verify that all nodes are healthy.

```bash
kubectl get nodes -o wide
```

Verify Metrics Server.

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

Expected:

```text
AVAILABLE=True
```

Display node metrics.

```bash
kubectl top nodes
```

Display Pod metrics.

```bash
kubectl top pods -n 115029258-hpa
```

Verify all project resources.

```bash
kubectl get all -n 115029258-hpa
```

At this point, the project should contain:

- One running application Pod.
- One ClusterIP Service.
- One Deployment.
- One ReplicaSet.
- One Horizontal Pod Autoscaler.
- One ResourceQuota.

The environment is now ready for load testing.

---

### Running the Load Test

Start the load generator.

```bash
kubectl apply -f manifests/load-job.yaml
```

Observe the Horizontal Pod Autoscaler.

```bash
kubectl get hpa -n 115029258-hpa -w
```

Observe Pod creation.

```bash
kubectl get pods -n 115029258-hpa -w
```

Monitor CPU utilization.

```bash
kubectl top pods -n 115029258-hpa
```

During the load test, the HPA increases the Deployment's desired replica count based on CPU utilization. However, the configured ResourceQuota prevents the ReplicaSet from creating all requested Pods once the namespace limits are reached.

This behavior demonstrates the interaction between Kubernetes autoscaling and namespace resource enforcement.

---

### Stopping the Load Test

Delete the load Job.

```bash
kubectl delete job 115029258-load -n 115029258-hpa
```

Continue observing the HPA.

```bash
kubectl get hpa -n 115029258-hpa -w
```

After CPU utilization decreases, the HPA gradually scales the Deployment back toward a single replica while respecting the configured 60-second scale-down stabilization window.

---

## Implementation Highlights

This project focuses on showing how multiple Kubernetes controllers work together during autoscaling. The project demonstrates how Metrics Server, Horizontal Pod Autoscaler, Deployment, ReplicaSet, and ResourceQuota interact while the application is under CPU load.

### Go CPU Burn Application

The application uses Go because it is lightweight, compiles into a single static binary, starts quickly inside containers, and consumes minimal runtime resources.

Unlike a traditional web application, every request to the root endpoint intentionally performs CPU-intensive calculations before returning a response. This predictable CPU consumption makes it suitable for demonstrating Horizontal Pod Autoscaler behavior.

The application also exposes a `/health` endpoint that is used by Kubernetes readiness and liveness probes to monitor container health.

### Kubernetes Deployment

The application runs as a Kubernetes Deployment. The Deployment ensures that the desired number of application replicas is maintained and automatically replaces Pods if they fail.

The Deployment does not create Pods directly. Instead, it manages a ReplicaSet, which is responsible for creating and deleting Pods. This distinction becomes important during the demonstration because the ResourceQuota prevents the ReplicaSet from creating all of the replicas requested by the HPA.

### ClusterIP Service

A ClusterIP Service provides a stable internal endpoint for the application.

Rather than communicating directly with individual Pod IP addresses, clients communicate with the Service.

Benefits include:

- Stable virtual IP address
- Automatic load balancing across healthy Pods
- No dependency on changing Pod IP addresses
- Internal-only communication inside the cluster

During the demonstration, the BusyBox load generator communicates only with the ClusterIP Service.

### Metrics Server

Metrics Server collects CPU and memory metrics from the Kubernetes nodes and Pods. These metrics are required by the Horizontal Pod Autoscaler to determine when additional replicas are needed.

Without Metrics Server:

- `kubectl top` cannot display resource usage.
- The HPA reports CPU usage as `<unknown>`.
- Automatic scaling cannot occur.

Because this project runs on a local kind cluster, the Metrics Server manifest includes the `--kubelet-insecure-tls` option to allow communication with kubelets that use self-signed certificates.

### Horizontal Pod Autoscaler

The HPA in this project uses CPU utilization as its scaling metric.

Configuration:

| Property                 | Value      |
| ------------------------ | ---------- |
| Minimum replicas         | 1          |
| Maximum replicas         | 10         |
| CPU target               | 50%        |
| Scale-down stabilization | 60 seconds |

The HPA continuously monitors CPU utilization reported by Metrics Server.

When average CPU utilization exceeds 50% of the configured CPU request, the HPA increases the Deployment's desired replica count.

When CPU utilization later decreases, the HPA gradually reduces the number of replicas after the stabilization period has elapsed.

### ResourceQuota

The namespace intentionally includes a ResourceQuota.

This component is central to the project because it demonstrates that Kubernetes autoscaling is limited by namespace resource policies.

Default quota:

| Resource     | Limit |
| ------------ | ----- |
| Pods         | 6     |
| requests.cpu | 1000m |

The ResourceQuota is intentionally configured so that the HPA requests more replicas than Kubernetes is permitted to create.

This creates ReplicaSet `FailedCreate` events that clearly demonstrate namespace quota enforcement.

### BusyBox Load Generator

The project uses a Kubernetes Job containing BusyBox containers to generate HTTP requests.

The load generator:

- Creates three concurrent Pods.
- Continuously sends requests to the application Service.
- Increases CPU utilization.
- Triggers Horizontal Pod Autoscaler decisions.

Separating the load generator from the application keeps the demonstration reproducible and allows CPU load to be started or stopped independently.

---

## Design Decisions

Several design choices were made to keep the project simple, reproducible, and easy to demonstrate.

### Go Language

Go produces a single compiled executable.

Advantages include:

- Faster container startup
- Smaller runtime image
- No interpreter required
- Consistent CPU performance

### kind instead of Minikube

kind was selected because it:

- Creates multi-node clusters quickly.
- Uses standard Kubernetes.
- Runs entirely inside Docker.
- Can be recreated automatically from scripts.
- Requires minimal host resources.

### ClusterIP instead of NodePort

The application is accessed only by other Pods.

Since external access is unnecessary, ClusterIP provides a simpler and more secure networking model.

### Bootstrap Automation

The project includes a bootstrap script that recreates the complete environment from scratch.

Running:

```bash
./bootstrap.sh
```

automatically:

- creates the Kubernetes cluster;
- installs Metrics Server;
- deploys the application;
- configures the HPA;
- applies the default ResourceQuota;
- waits until Pod metrics become available.

This ensures every demonstration begins from a consistent environment.

---

## Known Limitations

This project was built for learning and demonstration purposes rather than production use. Some implementation choices were intentionally simplified so the Kubernetes behaviors could be observed more easily.

Current limitations include:

- Uses a local kind cluster rather than a cloud-managed Kubernetes service.
- Metrics Server disables kubelet certificate validation for local development.
- CPU utilization is the only autoscaling metric.
- The load generator is manually started and stopped.
- Persistent storage is not required because the application is stateless.

These limitations simplify the environment while still demonstrating Kubernetes autoscaling behavior accurately.

---

## Project Demonstration

The `evidence/` directory contains screenshots and command outputs collected during project verification.

The evidence includes:

- Successful bootstrap execution
- Kubernetes cluster creation
- Metrics Server deployment
- Deployment and Service verification
- Horizontal Pod Autoscaler scaling events
- ResourceQuota enforcement
- ReplicaSet `FailedCreate` events
- CPU metrics collected by Metrics Server
- Scale-down stabilization after load removal

These screenshots demonstrate that the application and Kubernetes resources behave as expected throughout the complete lifecycle of the project.

---

## References

- Kubernetes Documentation  https://kubernetes.io/docs/
- Horizontal Pod Autoscaler  https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- Metrics Server  https://github.com/kubernetes-sigs/metrics-server
- kind (Kubernetes in Docker)  https://kind.sigs.k8s.io/
- Go Programming Language  https://go.dev/

---

## Acknowledgements

This project was completed as part of **CLO835 – Portable Technologies in Cloud** at Seneca Polytechnic.

The project combines concepts covered throughout the course, including containerization, Kubernetes deployments, Horizontal Pod Autoscaler, Metrics Server, and ResourceQuota. It was developed as a hands-on exercise to better understand how Kubernetes controllers interact during autoscaling.
