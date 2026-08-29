# OpenTelemetry DevOps Project

This repository is a **resume/profile project** demonstrating practical DevOps and cloud infrastructure skills through deploying the OpenTelemetry demo application on AWS EKS (Elastic Kubernetes Service).

## Current Status

- **Active Deployment**: OpenTelemetry demo running on AWS EKS (ap-south-1 region)
- **Infrastructure**: VPC + EKS cluster with 4x t3.micro nodes (Free Tier optimized)
- **Load Balancing**: AWS Load Balancer Controller installed, migrating to ALB-based Ingress
- **Services**: ~6-7 core services deployed (frontend, adservice, currencyservice, etc.)

## What this repo contains

- `docker-images/` — service-level Docker image examples and implementation notes
- `docker-compose/` — local demo stack for multi-container development
- `Iaas-terraform/` — Terraform IaC for AWS infrastructure + detailed learning notes
  - `Iaas-terraform/notes/PROGRESS.md` — detailed progress log with bug fixes and lessons learned

## Project intent

Demonstrate real-world DevOps skills through infrastructure-as-code, containerization, and cloud-native deployment:

- **Infrastructure as Code (Terraform)**: VPC, EKS, networking, and state management
- **Container Orchestration (Kubernetes)**: Service deployment, scaling, networking, and load balancing
- **Cloud Services (AWS)**: EC2, EKS, VPC, ALB, S3, DynamoDB, IAM roles
- **DevOps Practices**: Free Tier optimization, troubleshooting, and incident response
- **Local Development**: Docker and Docker Compose for multi-service development

## Topics to explore
CI/CD(in progress)

### AWS Infrastructure

- **VPC & Networking**: Custom VPC with public/private subnets, Internet Gateway, NAT Gateway, route tables
- **EKS (Elastic Kubernetes Service)**: Managed Kubernetes cluster with auto-scaling node groups
- **IAM & IRSA**: Identity and Access Management, Roles for Service Accounts for pod-level AWS API access
- **Load Balancing**: AWS Load Balancer Controller for Ingress-based ALB provisioning
- **State Management**: S3 backend with DynamoDB locking for Terraform state

### Terraform Infrastructure as Code

Defined in `Iaas-terraform/`:

- **Modules**: Reusable VPC and EKS configurations
- **Backend**: S3 + DynamoDB for remote state and concurrent access safety
- **Notes & Learning**:
  - `01_notes.md` — Terraform fundamentals, workflow, and state basics
  - `02_cheatsheet_and_backends.md` — quick command reference and backend examples
  - `01_basic_networks.md` — beginner networking concepts (VPC, IGW, NAT, routes, SSH/TLS)
  - `02_advanced_networks.md` — advanced cloud/devops networking design and operations
  - `PROGRESS.md` — detailed bug fixes, lessons learned, and deployment status

### Docker & Containerization

Building and managing container images for all OpenTelemetry demo services.

### Kubernetes Deployment

- **Services**: Deploying multi-tier applications on EKS
- **Resource Management**: Optimizing for Free Tier constraints (t3.micro nodes with ~530Mi allocatable memory)
- **Service Types**: ClusterIP, NodePort, LoadBalancer, ExternalName
- **Networking**: Service discovery, Ingress, and ALB integration

### CI/CD & Automation

Building deployment pipelines and automated workflows (planned).

## Key Accomplishments

- **Terraform VPC + EKS Infrastructure**: Built reusable modules for VPC and EKS clusters with state backend security
- **Free Tier Optimization**: Debugged and resolved capacity issues (node count, pod limits, CoreDNS replica scaling)
- **Critical Bug Fixes**: 
  - Fixed Terraform syntax typo (`route = {}` → `route {}`)
  - Resolved missing NAT Gateway causing `NodeCreationFailure`
  - Handled orphaned LoadBalancer cleanup after `terraform destroy` (K8s-provisioned resources lifecycle)
- **IRSA Setup**: Configured IAM Roles for Service Accounts for secure pod-to-AWS-API authentication
- **AWS Load Balancer Controller**: Installed via Helm, configured for ALB-based Ingress provisioning
- **OpenTelemetry Core Services**: Running adservice, currencyservice, emailservice, frontend, and supporting services

## Lessons Learned

- Terraform state backend must use `LockID` key (case-sensitive) for DynamoDB locks
- EKS node upgrades are limited to one minor version at a time
- K8s cloud-provisioned resources (LoadBalancer Services, PVCs) must be deleted before `terraform destroy`
- Free Tier constraints require careful resource planning: 2 usable pod slots per t3.micro node after daemonsets
- ServiceAccount IRSA annotations and OIDC provider setup are critical for pod IAM access
