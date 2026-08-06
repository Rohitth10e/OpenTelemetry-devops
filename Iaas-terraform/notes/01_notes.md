# Terraform Notes

## 1. What is Terraform?
Terraform is an open-source Infrastructure as Code (IaC) tool that lets you define, provision, and manage cloud and on-prem resources using declarative configuration files (HCL - HashiCorp Configuration Language). Instead of clicking in a console, you write configuration describing the desired end state and Terraform figures out the actions required to reach that state.

Why use Terraform?
- Reproducibility: same config produces the same infrastructure.
- Versionable: store configs in Git, review diffs, track changes.
- Provider ecosystem: works with AWS, Azure, GCP, Kubernetes, and many more.

Example (minimal AWS EC2):

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
}
```

Save this as main.tf, then use the lifecycle commands below.

---

## 2. Terraform lifecycle (commands & flow)
Terraform uses a small set of commands forming a typical workflow:

1. terraform init
   - Initializes a working directory: downloads providers and sets up the backend.
   - Run once per project or after changing backend/providers.
   - Example: sets up S3 backend config or downloads the AWS provider plugin.

2. terraform validate
   - Validates configuration syntactically and finds simple errors.

3. terraform fmt
   - Formats HCL files consistently.

4. terraform plan
   - Produces an execution plan showing what will change to reach the desired state.
   - Crucial: review the plan before applying to avoid surprises.
   - Example output: "Plan: 1 to add, 0 to change, 0 to destroy"

5. terraform apply
   - Applies the changes to create/update/destroy resources to match the plan.
   - Can accept a plan file produced by `terraform plan -out=plan.tfplan` for safer runs.

6. terraform destroy
   - Removes all resources managed by the configuration.
   - Useful for cleaning up temporary environments.

Typical workflow scenario:
- Developer creates/edits *.tf files -> run `terraform init` (first time) -> `terraform plan` -> review -> `terraform apply`.

Automation: CI pipelines typically run `terraform init` and `terraform plan` and require human approval before `apply` (or run `apply` in CD with restricted credentials).

---

## 3. Terraform state: what it is and why it matters
Terraform state is a JSON file that records the mapping between configuration and real-world resources. It stores:
- Resource IDs (cloud provider identifiers)
- Metadata, attributes, and computed values
- Dependency graph information

Why state exists:
- To know which existing real-world resource corresponds to which resource block in config.
- To detect drift and compute minimal changes.

Local state example:
- `terraform apply` creates `terraform.tfstate` in the working directory. This file contains the created resource IDs.

Problems with local state:
- Not shareable — multiple users running `apply` with local state can diverge and overwrite each other's changes.
- Risk of data loss if the file is deleted.
- Secrets may be stored in state (sensitive attributes) — treat it carefully.

State sensitivity and security:
- State can contain secrets (passwords, ARNs, tokens). Use secure storage and limited access.
- Enable encryption at rest for remote backends (e.g., S3 + SSE, Azure Storage encryption).

State locking and concurrency:
- When multiple engineers or automation run Terraform simultaneously, race conditions can corrupt state.
- Locking ensures only one operation mutates state at a time.

---

## 4. Remote backend: purpose and common types
A backend tells Terraform where to store state and how to perform state operations (locking, encryption, consistency). Using a remote backend centralizes state for teams and enables collaboration.

Common backends:
- S3 (AWS) + DynamoDB for locking
- Azure Blob Storage (azurerm backend) — supports locking via blob leases
- Google Cloud Storage (GCS) — supports consistency and object versioning; Terraform supports locking via Google Cloud's native mechanisms when available
- HashiCorp Cloud (Terraform Cloud/Enterprise) — built-in state management, locking, private module registry, runs, and policy enforcement

Example: S3 backend with DynamoDB locking (recommended for AWS teams)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "projectX/infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "my-terraform-locks"
    encrypt        = true
  }
}
```

What each setting does:
- bucket/key: where the state file lives
- dynamodb_table: used for state locking (Terraform will create a lock item in DynamoDB)
- encrypt: server-side encryption for S3 objects

Scenario: Two engineers run apply simultaneously
- Without locks: both may read old state, produce different plans, and then overwrite state causing resource drift or duplication.
- With DynamoDB locking: the first apply acquires a lock; the second waits or fails until lock released, preventing corruption.

Benefits of remote backends:
- Centralized state for team collaboration
- Integrated locking (depending on backend) prevents concurrent changes
- Encryption at rest
- Optional versioning and history (e.g., S3 object versioning)
- Ability to run remote operations (Terraform Cloud) so sensitive credentials never stored on developers' machines

---

## 5. State locking: how it works and examples
Locking prevents concurrent write operations to state. Implementation differs by backend.

S3 + DynamoDB pattern (AWS)
- Terraform writes a lock record into the DynamoDB table before writing state to S3.
- The lock record uses a consistent lock key derived from the S3 key.
- If another run finds the lock present, it waits or errors, depending on configuration.

Steps to add locking (DynamoDB setup):
1. Create DynamoDB table with a primary key (LockID as string).
2. Configure backend with dynamodb_table argument (as shown above).

Azure Blob Storage (azurerm backend)
- Uses blob leases for locking. When using the azurerm backend, Terraform obtains a lease on the state blob before writing it.

Terraform Cloud / Enterprise
- Provides state locking and runs management out of the box. It serializes operations and provides run history, policy checks, and team access control.

Example scenario showing race condition avoided by locking:
- Two CI jobs triggered by a PR merge both run `terraform apply` to provision the same environment.
- With locking: job A obtains lock, completes changes, releases lock. Job B waits until lock released and then re-plans against the updated state (or fails if configured), preventing conflicts.

---

## 6. Best practices and patterns
- Use a remote backend for team projects — avoid local state for collaborative work.
- Enable state locking (DynamoDB for S3 backend) and encryption at rest.
- Store backend config in a secure place; avoid committing secrets into repository. Use partial backend config in files and pass sensitive values (bucket names, keys) via environment variables or CI secrets.
- Use `terraform plan -out=plan.tfplan` and `terraform apply "plan.tfplan"` for reproducible applies.
- Keep state minimal: prefer data sources over storing unnecessary computed attributes in outputs.
- Use workspaces or separate state files per environment (e.g., dev/prod) — do not reuse a single state for multiple environments.
- Enable S3 versioning (or backend equivalent) to recover from accidental state corruption.
- Lock provider versions using `required_providers` and `required_version` in `terraform` block.

---

## 7. Example: full backend + workflow (AWS)
1. Create S3 bucket `my-tf-state` with versioning enabled.
2. Create DynamoDB table `my-tf-locks` with primary key `LockID`.
3. Add backend block to `main.tf` or `backend.tf`:

```hcl
terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    bucket         = "my-tf-state"
    key            = "teams/myteam/projectX/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "my-tf-locks"
    encrypt        = true
  }
}
```

4. Initialize and apply safely in CI:
- `terraform init`
- `terraform plan -out=out.plan`
- Human reviews plan
- `terraform apply out.plan`

5. If a second operator runs `apply` concurrently, they will block until the first finishes (due to DynamoDB lock) and then re-run planning against the latest state.

---

## 8. Troubleshooting tips
- "State file missing" — ensure backend correctly configured and you ran `terraform init`.
- "Failed to acquire lock" — check DynamoDB permissions, or an orphaned lock; locks can expire, or you may need to manually remove a stale lock item (careful!).
- "Resources in state but not in cloud" — may indicate manual deletion outside Terraform; import resources (`terraform import`) or update config to reflect reality.
- "Secrets in state" — rotate credentials and restrict access to backend storage.

---

## 9. Additional resources
- Terraform docs: https://www.terraform.io/docs
- Best practices: https://www.terraform.io/docs/cloud/guides/recommended-practices.html


---