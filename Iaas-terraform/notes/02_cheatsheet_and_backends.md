# Terraform Quick Reference & Backend Examples

## Quick CLI cheat-sheet
- terraform init
  - Initialize working directory, download providers, configure backend.
  - Example: terraform init

- terraform fmt
  - Formats HCL files.
  - Example: terraform fmt -recursive

- terraform validate
  - Checks syntax and simple errors.

- terraform plan
  - Shows proposed changes. Use -out to save a plan.
  - Example: terraform plan -out=out.plan

- terraform apply
  - Applies changes. Prefer applying a saved plan: terraform apply out.plan

- terraform destroy
  - Removes managed resources. Use with caution.
  - Example: terraform destroy

- terraform import
  - Import existing resources into state.
  - Example: terraform import aws_instance.web i-0123456789abcdef0

- terraform state (subcommands)
  - state list, show, rm, mv — manipulate or inspect state if required.

- workspaces
  - Create isolated state sets (terraform workspace new dev).
  - Useful for simple env separation but prefer separate state for prod/team clarity.

- automation pattern
  - CI: terraform init -> terraform plan -out=plan -> save plan artifact -> human review -> terraform apply plan

---

## Azure backend (azurerm) example
- Backend stores state in Azure Blob Storage; locking uses blob leases.

Example backend block:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "projectX/terraform.tfstate"
  }
}
```

Setup notes:
- Enable RBAC on the storage container and grant CI/service principal least-privilege access.
- Terraform obtains a blob lease for locking; ensure the storage account supports lease operations.

---

## Google Cloud backend (GCS) example
- Store state in a GCS bucket; use bucket object versioning and IAM for security. GCS locking is supported when using Google Storage with proper APIs.

```hcl
terraform {
  backend "gcs" {
    bucket  = "my-gcs-tfstate"
    prefix  = "projectX/terraform"
  }
}
```

Setup notes:
- Enable object versioning for state recovery.
- Use a service account with restricted permissions (storage.objects.get, storage.objects.create, storage.objects.delete).

---

## Terraform Cloud / Enterprise backend example
- Terraform Cloud offers managed state, locking, runs, VCS integration, and policy enforcement.

Example backend block (using CLI-driven remote operations):

```hcl
terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "my-org"
    workspaces { name = "projectX-prod" }
  }
}
```

Notes:
- State is stored and locked by Terraform Cloud; runs can be executed remotely.
- Use VCS-driven runs to ensure reproducibility and remove secrets from local machines.
- Policies (Sentinel or OPA) can enforce guardrails.

---

## Locking comparison and recommendations
- S3 + DynamoDB (AWS): explicit lock table via dynamodb_table; widely adopted for AWS.
- Azure Blob (azurerm): uses blob lease behavior for locks.
- GCS: supports locking with proper backend support and APIs.
- Terraform Cloud: built-in locking and run serialization.

Recommendation: use a remote backend with locking for any team project. For AWS, prefer S3 + DynamoDB. For Azure/GCP, use their native storage backends and enable backend-specific locking.

---

## Security & operational tips
- Never commit backend secrets (access keys) to VCS. Provide via environment variables or CI secrets.
- Enable server-side encryption and object versioning where available.
- Limit IAM/service principal permissions to least privilege.
- Periodically audit who can read/write state; state contains sensitive runtime values.

---