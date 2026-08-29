# OpenTelemetry DevOps Portfolio

Production-grade DevOps implementation demonstrating containerized microservices deployment on AWS EKS with Infrastructure as Code, automated CI/CD, and Kubernetes orchestration.

**Status**: Infrastructure provisioned and tested | Instance currently stopped (Free Tier budget constraint) | Can be redeployed in ~10 minutes via `terraform apply`

---

## Architecture Overview

```
GitHub Repo → CI/CD Pipeline → Docker Registry → EKS Cluster
    ↓              ↓                  ↓              ↓
  [Commit]    [Build/Test]      [Images]    [Services Running]
             [Lint/Quality]      [Push]      [Load Balanced]
             [Push to K8s]
```

- **Source**: Multi-language services (Go, Java, Python)
- **Build**: GitHub Actions (automated testing, linting, Docker builds)
- **Registry**: DockerHub (versioned images via run ID)
- **Target**: EKS with AWS ALB ingress and IRSA for secure pod-to-API access

---

## What's Implemented

### 1. Infrastructure as Code (Terraform)
**Location**: `Iaas-terraform/`

- **Modular Design**: Separate VPC and EKS modules for reusability
- **Networking**: 
  - Custom VPC with public/private subnets across 3 AZs
  - NAT Gateway for private subnet outbound traffic
  - Security groups with least-privilege rules
- **EKS Cluster**:
  - Auto-scaling node group (4x t3.micro, Free Tier optimized)
  - OIDC provider for IRSA (IAM Roles for Service Accounts)
  - Managed add-ons: VPC CNI, kube-proxy, CoreDNS
- **State Management**:
  - Remote S3 backend with DynamoDB locking (case-sensitive `LockID`)
  - Prevents concurrent modifications and state corruption
- **Key Artifacts**:
  - `modules/vpc/` — VPC, subnets, gateways, routing
  - `modules/eks/` — EKS cluster, node groups, add-ons
  - `notes/PROGRESS.md` — Detailed implementation guide with bug fixes

### 2. Containerization (Docker)
**Location**: `docker-images/`

**Go Service** (`golang/`)
- Product catalog microservice
- Multi-stage Dockerfile for minimal image size
- Exposes port 8088

**Java Service** (`java/`)
- Ad service microservice
- Includes JVM tuning and health checks
- Exposes port 9099

**Python Service** (`python/`)
- Recommendation engine
- Dependency management with requirements.txt
- Exposes port 1010

**Key Practices**:
- Non-root user execution (security)
- Health check endpoints defined
- Environment-driven configuration
- `.dockerignore` to exclude unnecessary files

### 3. Local Development (Docker Compose)
**Location**: `docker-compose/`

- Complete stack for local testing: services + MongoDB
- Named volume for persistent database
- Custom bridge network for inter-service communication
- Service discovery via DNS

**Services**:
- product-service (Go)
- ad-service (Java)
- recommendation-service (Python)
- mongo (official image)

### 4. CI/CD Pipeline
**Location**: `.demo-github/workflows/ci.yaml`

**Trigger**: Pull requests and pushes to `main`

**Jobs** (with dependency management):

1. **Build & Test** (runs first)
   - Checkout code (actions/checkout@v4)
   - Setup Go 1.22 (actions/setup-go@v4)
   - Compile: `go build -o product-catalog-service src/product-catalog/main.go`
   - Run unit tests: `go test ./src/product-catalog/... -v`
   - **Fail fast**: Stops pipeline if build fails

2. **Code Quality** (runs in parallel with build)
   - Static analysis: `golangci-lint run ./src/product-catalog/... --timeout 5m`
   - Catches linting issues, code style, potential bugs
   - **Fail point**: Pipeline stops if linting fails

3. **Docker Build & Push** (requires successful build)
   - Setup buildx for advanced Docker features (docker/setup-buildx-action@v1)
   - Authenticate with DockerHub (docker/login-action@v2)
   - Build and push image: tagged with `${{ github.run_id }}`
   - **Versioning**: Each run gets unique image tag for rollback capability
   - **Secrets**: Uses `DOCKER_USERNAME` and `DOCKER_TOKEN` from GitHub Secrets

4. **Kubernetes Deployment Update** (requires successful docker push)
   - Checkout with `GITHUB_TOKEN` for K8s manifest modifications
   - Update K8s deployment image tag
   - Command: `kubectl set image deployment/product-catalog-deployment product-catalog-service=${{ secrets.DOCKER_USERNAME }}/product-catalog-service:${{github.run_id}} -n product-catalog`
   - **Namespace**: `product-catalog` namespace
   - **In-place rolling update**: Zero-downtime deployment

**Pipeline Benefits**:
- ✅ Automated testing catches bugs early
- ✅ Code quality gates prevent bad code
- ✅ Immutable versioned images for every commit
- ✅ Automatic deployment on main branch
- ✅ Quick rollback via run ID tags

---

## Key Technical Decisions & Learnings

### 1. Terraform State Backend (DynamoDB Lock)
**Challenge**: Concurrent `terraform apply` could corrupt state in team environments

**Solution**: 
- S3 backend with DynamoDB locking table
- **Critical Detail**: DynamoDB partition key must be **exactly `LockID`** (case-sensitive)
- Prevents multiple users from applying simultaneously

**Interview Talking Point**: Shows understanding of state management and team DevOps workflows

### 2. EKS Node Capacity Optimization
**Challenge**: Free Tier t3.micro has only ~530Mi allocatable memory + 4 max pod slots

**Issue Found**: 
- CoreDNS running 2 replicas could land on same node (wasting pod slot)
- Many OpenTelemetry demo services couldn't fit

**Solution**:
- Scaled CoreDNS to 1 replica (still functional)
- Scaled non-essential services to 0 replicas
- Running 6-7 core services: frontend, adservice, currencyservice, emailservice, flagd, etc.
- Traced root cause via `kubectl describe pod` → `0/4 nodes are available: X Too many pods`

**Interview Talking Point**: Demonstrates troubleshooting mindset, resource constraint handling, and K8s internals knowledge

### 3. Terraform Syntax Gotcha
**Challenge**: `route = {}` vs `route {}` 

**Problem**: Empty block with `=` caused phantom provider dependencies on non-existent AWS resources

**Solution**: Changed to correct block syntax without assignment operator

**Learning**: Shows attention to detail and experience with infrastructure-as-code debugging

### 4. NAT Gateway Missing Link
**Challenge**: EC2 and EKS nodes in private subnets had no outbound internet access

**Symptoms**: 
- `NodeCreationFailure` errors
- Nodes couldn't pull images or reach package repositories

**Solution**: Added NAT Gateway in public subnet with route table pointing private subnets to NAT

**Architecture Understanding**: Shows knowledge of VPC networking, public/private subnet separation, and HA patterns

### 5. Terraform vs Kubernetes Resource Lifecycle
**Challenge**: `terraform destroy` hung indefinitely despite all resources allegedly deleted

**Root Cause**: K8s `LoadBalancer` Service auto-created a Classic ELB (outside Terraform state)
- ELB held ENIs across all 3 public subnets
- ELB's security group blocked deletion of VPC

**Solution**: Manual cleanup via AWS CLI after identifying the culprit

**Lesson Learned**: 
- K8s-provisioned cloud resources (LoadBalancer Services, PVCs backed by EBS)  live outside Terraform state
- **Always `kubectl delete` services/pvcs before `terraform destroy`**
- Added this to runbook for future deployments

**Interview Talking Point**: Real-world incident response, understanding of cloud resource layering, pragmatism in automation

### 6. IRSA (IAM Roles for Service Accounts)
**What**: Pods need AWS API access (e.g., S3, CloudWatch) without embedding credentials

**Implementation**:
- Created OIDC provider for EKS cluster: `https://oidc.eks.ap-south-1.amazonaws.com/id/BA1669B6F034D9B048B524E50BBCA795`
- Used `eksctl utils associate-iam-oidc-provider` for speed (vs Terraform-managed OIDC)
- Annotated ServiceAccount with role ARN: `serviceAccount.annotations.eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/POD_ROLE`
- Pods automatically assume role via webhook mutation

**Tradeoff**: OIDC provider now lives outside Terraform state → requires manual cleanup on future `destroy` cycles

**Why This Matters**: Pod-level IAM is the industry standard for AWS+K8s security (vs node-level IAM)

### 7. AWS Load Balancer Controller + ALB Ingress
**Old Way**: `LoadBalancer` Service type → auto-creates Classic ELB (legacy, expensive, lifecycle headaches)

**Better Way**: 
- Ingress resource with `ingressClassName: alb`
- AWS Load Balancer Controller (Helm chart in kube-system)
- Provisions ALB on-demand with proper Terraform state tracking
- Supports advanced features: path-based routing, host-based routing, SSL/TLS

**Status**: Controller installed and verified; Ingress manifest ready to apply

---

## Getting Started

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured with credentials
- kubectl connected to EKS cluster
- Docker (for local development)
- eksctl (already on devops-demo EC2)

### Deploy Infrastructure
```bash
cd Iaas-terraform
terraform init
terraform plan
terraform apply
```

### Deploy Services Locally
```bash
cd docker-compose
docker-compose up -d
```

**Verify**:
```bash
curl http://localhost:8088/products    # product-service
curl http://localhost:9099/ads         # ad-service
curl http://localhost:1010/recommend   # recommendation-service
mongo localhost:27017                  # MongoDB
```

### Trigger CI/CD
Simply push to `main` branch. GitHub Actions will:
1. Run tests and linting
2. Build Docker image with unique tag
3. Push to DockerHub
4. Update EKS deployment

**Monitor**:
```bash
kubectl rollout status deployment/product-catalog-deployment -n product-catalog
kubectl logs -f deployment/product-catalog-deployment -n product-catalog
```

---

## Blockers & Solutions

| Blocker | Root Cause | Solution | Status |
|---------|-----------|----------|--------|
| Terraform syntax error → phantom providers | `route = {}` empty block with assignment | Use correct `route {}` block syntax | ✅ Fixed |
| Nodes stuck in `NodeCreationFailure` | Private subnets had no NAT Gateway | Added NAT Gateway + route table entry | ✅ Fixed |
| Pod pending, `Too many pods` errors | CoreDNS 2 replicas on same node wasted slots | Scaled CoreDNS to 1 replica | ✅ Fixed |
| `terraform destroy` hung for 30min | Orphaned Classic ELB from K8s LoadBalancer Service | Manual AWS CLI deletion, added cleanup runbook | ✅ Fixed |
| IRSA annotations not working | OIDC provider not associated with cluster | Used `eksctl utils associate-iam-oidc-provider` | ✅ Fixed |
| Load Balancer type Service creates classic ELB | ELB auto-created outside Terraform state | Plan to migrate to ALB Ingress | ✅ In Progress |

---

## DevOps Guide for Peers

### 1. Infrastructure Patterns
- **Modularity**: VPC and EKS as separate modules → reusable across projects
- **State Safety**: Always use remote backend with locking
- **Secrets Management**: Use AWS Secrets Manager or GitHub Secrets, never hardcode
- **IaC Best Practice**: Version control your `terraform.tfstate.backup` and `tfplan` files (in `.gitignore`)

### 2. Kubernetes Resource Management
- **Free Tier Constraints**: t3.micro = 1 vCPU + 1GB RAM
  - Allocatable: ~530Mi (after kubelet reservation)
  - Pod slots: 2 per node (after daemonsets: aws-node, kube-proxy)
  - Always test locally before deploying
- **Pod Pending Troubleshooting**: 
  ```bash
  kubectl describe pod <POD_NAME>  # Check Events section for real cause
  kubectl top nodes                 # Check node utilization
  kubectl get pods -o wide          # See which node pods are on
  ```

### 3. CI/CD Best Practices
- **Docker Versioning**: Use commit SHA or run ID (immutable, traceable)
- **Test First**: Fail fast in pipeline (tests before build)
- **Secrets**: Never log secrets; use GitHub Secrets with least-privilege token scopes
- **Kubernetes Access**: Use `GITHUB_TOKEN` with `contents: read, packages: write` minimum

### 4. EKS-Specific Patterns
- **IAM at Pod Level**: Use IRSA for fine-grained permissions (vs node-level IAM)
- **Networking**: Always plan for private subnets with NAT for security
- **Ingress over LoadBalancer**: Use ALB Ingress for better lifecycle management
- **Multi-region**: S3 backend works across regions; tag resources for easy identification

### 5. Cleanup Checklist Before Destroying
```bash
# 1. Delete K8s-provisioned cloud resources FIRST
kubectl delete service <LOAD_BALANCER_SERVICES>
kubectl delete pvc <PERSISTENT_VOLUMES>
kubectl delete ingress <INGRESS_OBJECTS>

# 2. Delete OIDC provider manually (if not Terraform-managed)
aws iam list-open-id-connect-providers
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn arn:...

# 3. NOW run Terraform destroy
terraform destroy
```

---

## Key Learnings for Interview

1. **Problem Solving**: Traced pod capacity issue via `kubectl describe` and K8s documentation
2. **Infrastructure Knowledge**: Understand VPC layering, NAT, routing, security groups
3. **State Management**: Recognized Terraform state corruption risk; implemented S3 + DynamoDB locks
4. **Automation**: Built full CI/CD from commit to K8s deployment
5. **Cloud Economics**: Optimized for Free Tier (t3.micro) instead of over-provisioning
6. **Security**: Implemented pod-level IAM (IRSA) instead of node-level
7. **Pragmatism**: Manual cleanup when automation limits hit; documented for team

---

## Files Worth Reviewing

- **`Iaas-terraform/notes/PROGRESS.md`** — Detailed step-by-step implementation with all bugs and fixes
- **`Iaas-terraform/modules/vpc/main.tf`** — VPC, subnets, NAT Gateway, routing logic
- **`Iaas-terraform/modules/eks/main.tf`** — EKS cluster, OIDC, node groups
- **`.demo-github/workflows/ci.yaml`** — Full CI/CD pipeline with job dependencies
- **`docker-compose/docker-compose.yaml`** — Local multi-service setup with networking patterns

---

**Last Updated**: August 2026  
**Infrastructure Status**: Live (ap-south-1)  
**Questions?** See `Iaas-terraform/notes/PROGRESS.md` for detailed implementation guide.
