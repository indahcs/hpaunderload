# EC2 Setup Guide

This guide prepares a fresh Amazon Linux 2023 EC2 instance to run the HPA Under Load project.

### EC2 Instance Configuration

Launch a new Amazon EC2 instance with the following configuration.

| Setting | Value |
|---------|-------|
| Name | `hpaunderload-demo` (or any preferred name) |
| AMI | Amazon Linux 2023 AMI (64-bit x86) |
| Instance Type | **m5.large** |
| vCPUs | 2 |
| Memory | 8 GiB |
| Key Pair | Your existing AWS Academy key pair |
| Network | Default VPC |
| Auto-assign Public IP | Enabled |
| Security Group | Allow SSH (TCP Port 22) from **My IP** |
| Root Volume | 30 GiB gp3 (recommended) |

> **Note:** The `m5.large` instance provides sufficient CPU and memory to run Docker, a three-node kind cluster, Metrics Server, the Go application, and the HPA demonstration.

## 1. Connect to the EC2 instance

From your local computer:

```bash
chmod 400 your-key.pem

ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

## 2. Update the operating system

```bash
sudo dnf update -y
```

## 3. Install Docker

```bash
sudo dnf install docker -y
```

Start Docker:

```bash
sudo systemctl enable docker
```

```bash
sudo systemctl start docker
```

Allow the current user to run Docker commands:

```bash
sudo usermod -aG docker ec2-user
```

Log out of the EC2 instance:

```bash
exit
```

Reconnect:

```bash
ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
```

Verify Docker:

```bash
docker info
```

## 4. Install Git

```bash
sudo dnf install git -y
```

Verify:

```bash
git --version
```

## 5. Install curl

```bash
sudo dnf install curl -y
```

Verify:

```bash
curl --version
```

## 6. Install watch

The `watch` command is used during the HPA demonstration.

```bash
sudo dnf install procps-ng -y
```

Verify:

```bash
watch --version
```

## 7. Install kind v0.31.0

```bash
curl -sLo kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
```

```bash
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
```

```bash
rm kind
```

Verify:

```bash
kind version
```

Expected output:

```text
kind version 0.31.0
```

## 8. Install kubectl v1.35.0

```bash
curl -LO "https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl"
```

```bash
chmod +x kubectl
```

```bash
sudo mv kubectl /usr/local/bin/
```

Verify:

```bash
kubectl version --client
```

## 9. Verify the installation

```bash
docker --version
```

```bash
docker info
```

```bash
kind version
```

```bash
kubectl version --client
```

```bash
git --version
```

## 10. Clone the repository

```bash
git clone https://github.com/indahcs/hpaunderload.git
```

Enter the repository:

```bash
cd hpaunderload
```

Switch to the latest main branch:

```bash
git checkout main
```

```bash
git pull origin main
```

## 11. Prepare the project

```bash
chmod +x bootstrap.sh
```

```bash
chmod +x apply-quota.sh
```

Verify the scripts:

```bash
ls -l bootstrap.sh apply-quota.sh
```

## 12. Create the Kubernetes environment

```bash
time ./bootstrap.sh
```

If the bootstrap completes successfully, continue with the project runbook.