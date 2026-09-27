# Environments

Each subdirectory is one environment (`dev`, `staging`, `prod`). They are
deliberately **thin**: they only wire the reusable modules together and supply
environment-specific values via `terraform.tfvars`. All reusable logic lives in
`../modules`.

```
dev/  staging/  prod/
  main.tf          # calls modules/kind-cluster + modules/addons
  providers.tf     # provider + backend config
  variables.tf     # variable declarations (same across envs)
  terraform.tfvars # the ONLY thing that really differs per env
```

Run an environment:

```bash
cd dev            # or staging / prod
terraform init
terraform apply
```

## State backend

State is **local** here to keep the exercise self-contained. In a real setup each
environment gets an isolated remote backend with locking, for example:

Each env ships a `backend.tf.example` — rename it to `backend.tf` to enable it:

```hcl
terraform {
  backend "s3" {
    bucket       = "acme-tfstate"
    key          = "web/dev/terraform.tfstate" # per-env key
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true # native S3 state locking (Terraform >= 1.10)
  }
}
```

**State locking** prevents two people (or a person and CI) running `apply` at once
and corrupting state: the first holds a lock, the second waits. `use_lockfile`
does this natively on S3; older setups used a DynamoDB table. Separate state per
env also means a `terraform apply` in dev can never plan or destroy prod — the
same blast-radius principle as separate clusters.

Provider versions are already locked via the committed `.terraform.lock.hcl`.

## Swapping kind for a cloud

`modules/kind-cluster` is the seam. Replacing it with an `eks-cluster` /
`aks-cluster` / `gke-cluster` module that exposes the same outputs
(`kubeconfig_path`, endpoint, credentials) would let these environment files and
everything downstream (app manifests, CI/CD) stay unchanged.
