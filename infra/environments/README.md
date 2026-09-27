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

```hcl
terraform {
  backend "s3" {
    bucket         = "acme-tfstate"
    key            = "web/dev/terraform.tfstate"   # per-env key
    region         = "eu-west-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
```

Separate state per environment means a `terraform apply` in dev can never plan or
destroy prod resources — the same blast-radius principle as separate clusters.

## Swapping kind for a cloud

`modules/kind-cluster` is the seam. Replacing it with an `eks-cluster` /
`aks-cluster` / `gke-cluster` module that exposes the same outputs
(`kubeconfig_path`, endpoint, credentials) would let these environment files and
everything downstream (app manifests, CI/CD) stay unchanged.
