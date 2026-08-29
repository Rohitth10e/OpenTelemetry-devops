# OpenTelemetry Demo on EKS — Progress Log

## Infrastructure (Terraform)
- VPC + EKS cluster (`my-eks-cluster`, region `ap-south-1`) via Terraform modules (`./modules/vpc`, `./modules/eks`)
- Node group: 4x `t3.micro` (Free Tier constraint — on-demand `t3.medium`/`t3.small` blocked)
- State backend: S3 + DynamoDB lock table (`tf-state-lock`, key must be exactly `LockID` — case-sensitive)
- `devops-demo` EC2 (Ubuntu) hosts the full app codebase + K8s manifests, `kubectl`-connected to the cluster

## Key bugs fixed (interview stories)
- `route = {}` vs `route {}` typo → phantom `hashicorp/internet`/`hashicorp/route` provider errors
- EKS only allows one minor-version upgrade at a time (1.30→1.31→1.32→1.33)
- Missing NAT Gateway → private-subnet nodes had no internet route → `NodeCreationFailure`
- Messy teardown: deleted backend bucket/lock table mid-`destroy`, then hit a stuck `terraform destroy` caused by an orphaned classic ELB (auto-created by a K8s `LoadBalancer` Service, invisible to Terraform) holding ENIs + its security group across all 3 public subnets — manually deleted via AWS CLI
- **Lesson**: K8s-provisioned cloud resources (LoadBalancer Services, PVC-backed volumes) live outside Terraform's state — always `kubectl delete` those before `terraform destroy`

## Free Tier capacity limits (OpenTelemetry Demo, ~18 services)
- `t3.micro` gives ~530Mi allocatable memory and only 2 usable pod slots per node (4 max, minus 2 for mandatory daemonsets: `aws-node` + `kube-proxy`)
- Discovered CoreDNS's 2 replicas can land on the same node, silently eating a 3rd "app" slot on that node — scaled to 1 replica to free capacity
- Scaled non-essential services to 0 replicas to fit remaining ~6-7 core services (`adservice`, `currencyservice`, `emailservice`, `flagd`, `frontend`, `frontendproxy`, `productcatalogservice`)
- Root cause of `Pending` pods traced via `kubectl describe pod` → `0/4 nodes are available: X Too many pods` (pod-count ceiling, not memory)

## Kubernetes Service types (learned)
- `ClusterIP` (default) — internal-only, used by all backend services
- `NodePort` — opens a port on every node; rarely used directly
- `LoadBalancer` — provisions a real cloud ELB (this is what caused the orphaned-ELB teardown issue); built on NodePort underneath
- `ExternalName` — DNS alias only, no proxying

## IRSA (IAM Roles for Service Accounts) setup
- Confirmed cluster OIDC issuer: `https://oidc.eks.ap-south-1.amazonaws.com/id/BA1669B6F034D9B048B524E50BBCA795`
- Chose `eksctl` for OIDC provider association (`eksctl utils associate-iam-oidc-provider`) over Terraform-managed OIDC, for speed — tradeoff: this resource now lives outside Terraform state and needs manual tracking/cleanup on future `destroy` cycles (added to running manual-cleanup checklist alongside the ELB lesson)
- Installed `eksctl` on `devops-demo` (Ubuntu) via GitHub release tarball

## AWS Load Balancer Controller
- Installed via Helm (`eks/aws-load-balancer-controller` chart) into `kube-system`, with `serviceAccount.create=false` (ServiceAccount + IRSA role-arn annotation set up separately)
- Helm reported `STATUS: deployed` — pod health/IRSA auth still to be verified via `kubectl logs`
- Moving from `frontendproxy`'s `LoadBalancer`-type Service to a proper `Ingress` (`ingressClassName: alb`) for ALB provisioning with correct lifecycle tracking, instead of the legacy classic-ELB path
- Ingress config uses `scheme: internet-facing`, `target-type: ip`; removed the placeholder `host: example.com` rule since no real domain is owned yet — routes on path only

## Next up
- Verify AWS Load Balancer Controller pod is authenticating correctly (ServiceAccount IRSA annotation check, `kubectl logs`)
- Apply the `Ingress` manifest, confirm ALB creation via `kubectl get ingress`
- Deeper K8s manifest concepts: Deployments, Services, ConfigMaps/Secrets, resource requests/limits, probes — hands-on authoring of own manifests vs. the pre-built demo