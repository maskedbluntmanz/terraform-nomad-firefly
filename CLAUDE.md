# CLAUDE.md

This file provides guidance for AI assistants working with this repository.

## Project Overview

This is a **Terraform module** that provisions and manages [HashiCorp Nomad](https://www.nomadproject.io/) workloads. It automates the creation of Nomad namespaces, ACL policies, ACL tokens, and jobs from a parameterized HCL job spec template.

The module is designed to deploy multiple Nomad jobs across multiple prefixes (e.g., regions or environments) by combining configurable prefix/suffix values with a shared job template.

## Repository Structure

```
terraform-nomad-firefly/
├── main.tf              # Core Terraform resources: provider, namespace, ACL, jobs
├── variables.tf         # All input variable declarations with defaults
├── jobspec.nomad        # Nomad HCL2 job spec template (rendered via templatefile)
├── sample.tfvars        # Example variable overrides (e.g., image version)
├── go.mod               # Go module definition (module name only, no Go source)
├── .terraform.lock.hcl  # Provider dependency lock file (do not edit manually)
├── terraform.tfstate    # Local Terraform state (not committed in production)
├── .gitignore           # Ignores .terraform/ directory and .idea/
└── .github/
    └── workflows/
        └── tfsec.yml    # GitHub Actions: tfsec security scanning on push/PR to main
```

## Key Concepts

### Job Naming Convention

Jobs are named using a `prefix-appname-suffix` pattern, controlled by three variables:

- `job_name_prefix`: list of prefixes (e.g., `["region1", "region2"]`)
- `job_gen_spec.app_name`: the application name segment (e.g., `"broker"`)
- `job_gen_spec.suffix`: list of suffixes (e.g., `["grp1", "grp2"]`)

The `for_each` on `nomad_job.app` iterates over `job_name_prefix`, generating one job per prefix. Only `suffix[0]` is used in the current name format — extending to use all suffixes via `setproduct` is noted as a TODO in `main.tf:42`.

### Job Template Rendering

`jobspec.nomad` is a Nomad HCL2 template. It is:
1. Read as a raw file via `data "local_file" "template_job_spec"`
2. Rendered using Terraform's `templatefile()` to inject `job_name`
3. Passed to `nomad_job.app` with HCL2 mode enabled (`hcl2.enabled = true`)

Variables passed into the jobspec at runtime via `hcl2.vars`:
- `image` — Docker image to run
- `group_specs` — JSON-encoded list of group objects (label + port)
- `driver` — Nomad task driver (default: `"docker"`)
- `namespace` — Nomad namespace to deploy into

The jobspec uses Nomad's `dynamic "group"` block to generate task groups from `group_specs`. The Docker image is stored in group metadata and referenced inside the task as `${NOMAD_META_image}` (escaped as `$${NOMAD_META_image}` in the template to prevent Terraform interpolation).

### ACL and Namespace Setup

- `nomad_namespace.dev`: creates a Nomad namespace named from `var.namespace`
- `nomad_acl_policy.dev`: grants `write` access to the `"dev"` namespace (hardcoded)
- `nomad_acl_token.dev`: a client token bound to the `"dev"` policy
- The token `secret_id` is exposed as a sensitive output named `token`

## Provider Configuration

| Provider | Version | Purpose |
|---|---|---|
| `hashicorp/nomad` | `1.4.17` | Manages Nomad resources |
| `hashicorp/local` | `2.2.3` | Reads local template files |

The Nomad provider connects to `http://localhost:4646` by default. Override via the `NOMAD_ADDR` environment variable or provider configuration if targeting a remote cluster.

## Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `image` | `string` | `"redis:3.1"` | Docker image for the Nomad task |
| `driver` | `string` | `"docker"` | Nomad task driver |
| `namespace` | `string` | `"default"` | Nomad namespace to deploy into |
| `template_name` | `string` | `"jobspec.nomad"` | Template file to use as the job spec |
| `job_name_prefix` | `list(string)` | `["region1", "region2"]` | Prefixes for job name generation |
| `job_name_suffixes` | `list(string)` | `["grp1", "grp2"]` | Suffixes for job name generation (declared but unused — see note) |
| `job_name_base` | `string` | `"app"` | Base name segment (declared but unused — see note) |
| `job_gen_spec` | `object` | see below | Combined spec for job name generation |
| `group_specs` | `list(object)` | see below | Defines task groups within each job |

**`job_gen_spec` default:**
```hcl
{
  prefix   = ["pod01", "pod02"]
  suffix   = ["grp1", "grp2"]
  app_name = "app"
}
```

**`group_specs` default:**
```hcl
[
  { group_label = "api",    tags = 80   },
  { group_label = "ui",     tags = 8080 },
  { group_label = "batman", tags = 8080 },
]
```

> Note: `job_name_suffixes`, `job_name_base`, and `job_gen_spec.prefix` are declared but not actively referenced in `main.tf`. Only `job_gen_spec.app_name` and `job_gen_spec.suffix[0]` are used in job name construction.

## Development Workflow

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.1.x
- A running [Nomad](https://developer.hashicorp.com/nomad/install) cluster (local dev: `nomad agent -dev`)
- (Optional) [tfsec](https://github.com/aquasecurity/tfsec) for local security scanning

### Common Commands

```bash
# Initialize providers
terraform init

# Preview changes
terraform plan -var-file=sample.tfvars

# Apply changes
terraform apply -var-file=sample.tfvars

# Retrieve the ACL token (sensitive output)
terraform output -raw token

# Destroy all managed resources
terraform destroy -var-file=sample.tfvars
```

### Using a Different Job Template

Set `template_name` to point to an alternate `.nomad` file:

```bash
terraform apply -var="template_name=my-custom-job.nomad"
```

### Overriding Variables

Use a `.tfvars` file (see `sample.tfvars` for an example) or `-var` flags:

```bash
terraform apply \
  -var='image=redis:7.0' \
  -var='namespace=staging' \
  -var='job_name_prefix=["us-east", "us-west"]'
```

## CI/CD: GitHub Actions

The `.github/workflows/tfsec.yml` workflow runs [tfsec](https://github.com/aquasecurity/tfsec) security analysis:

- **Triggers:** push or PR to `main`; weekly scheduled scan (Tuesdays at 07:42 UTC)
- **Output:** SARIF report uploaded to GitHub Security tab via `github/codeql-action/upload-sarif`
- **Permissions required:** `actions: read`, `contents: read`, `security-events: write`

## Known Issues and TODOs

- **`for_each` + `setproduct`** (`main.tf:42`): The job creation currently iterates only over `job_name_prefix`. A TODO comment notes that `setproduct` should be used to generate the full cartesian product of prefix × suffix combinations.
- **Unused variables**: `job_name_suffixes`, `job_name_base`, and `job_gen_spec.prefix` are declared in `variables.tf` but not wired into `main.tf`. These likely represent work in progress.
- **Hardcoded ACL policy namespace**: The ACL policy in `main.tf` references `"dev"` literally rather than `var.namespace`, which means the policy won't match the namespace when deploying to non-dev environments.
- **Nomad provider address**: Defaults to `localhost:4646`. Remote deployments require explicit provider configuration or `NOMAD_ADDR`/`NOMAD_TOKEN` environment variables.
- **State files committed**: `terraform.tfstate` and `terraform.tfstate.backup` are present in the repository. For team use, migrate state to a remote backend (e.g., Terraform Cloud, S3+DynamoDB).

## File Conventions

- All Terraform configuration lives at the root level (no subdirectory modules)
- The job spec template (`jobspec.nomad`) uses Nomad HCL2 syntax and must declare all variables it receives via `hcl2.vars`
- Escape Nomad runtime variables with `$${}` in the template to prevent Terraform from interpolating them
- `lifecycle { ignore_changes = [] }` is explicitly set on jobs — adjust this if you want Terraform to detect and revert out-of-band changes
