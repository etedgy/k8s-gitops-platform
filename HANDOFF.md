# Handoff

Status of this DevOps take-home and how to pick it up. Deep detail lives in the
[README](README.md), [docs/architecture.md](docs/architecture.md),
[docs/troubleshooting.md](docs/troubleshooting.md),
[docs/governance.md](docs/governance.md), and the live evidence in
[docs/DEMO.md](docs/DEMO.md).

## TL;DR
A production-oriented deployment of a small containerized web app on Kubernetes,
reproducible locally on `kind` with **zero cloud cost**. IaC (Terraform) →
GitOps CD (Argo CD) → progressive delivery (Argo Rollouts canary) → default-deny
networking (Cilium) behind a real LoadBalancer (MetalLB). Brought up and verified
end-to-end on a real cluster (see DEMO.md).

## What's done (and verified live on a kind cluster)
- **Infra as Code** — Terraform split into reusable modules (`infra/modules/kind-cluster`,
  `infra/modules/addons`) and thin per-env configs (`infra/environments/{dev,staging,prod}`).
  `terraform apply` stands up cluster + Cilium + MetalLB + ingress-nginx + Argo CD +
  Argo Rollouts + Prometheus + metrics-server. ✅ verified
- **App deployment** — Flask app, non-root, health/ready/startup probes, HPA, PDB,
  topology spread, as an Argo Rollouts `Rollout`. ✅ running, healthy
- **Networking** — Cilium CNI enforcing **default-deny** NetworkPolicies; **MetalLB**
  LoadBalancer with a real external IP; explicit pod/service subnets. ✅ allow/deny proven
- **GitOps CD** — Argo CD app-of-apps (`argocd/`) reconciling the app from git;
  dev auto-syncs, staging/prod manual. ✅ Synced/Healthy
- **Progressive delivery** — canary 20% → Prometheus analysis gate → 50% → 100%,
  with automatic abort. ✅ both abort and full promotion demonstrated
- **CI** — GitHub Actions: test → build → Trivy scan → push by immutable SHA
  (`.github/workflows/ci.yaml`). Pinned base image + actions. ⚠️ not executed here
  (no paid Actions); pieces validated locally, runnable on a public repo.
- **Security** — no secrets in git; non-root numeric UID; read-only rootfs; dropped
  caps; seccomp; dedicated SA with no API token; default-deny netpol; pinned
  images/actions. Documented threat model in README.
- **Governance** — `.github/CODEOWNERS`, PR template, branch protection (PR-only,
  review, linear history/rebase) in `docs/governance.md`.

## Known gaps / not done (honest)
- **Cloud target not built** — kind only, by design (reproducible, free). The
  `infra/modules/kind-cluster` boundary is the seam to swap in EKS/AKS/GKE. Remote
  Terraform state is provided as `backend.tf.example` per env but not applied.
- **Only `dev` stood up live** — staging/prod overlays + Argo apps exist and build,
  but weren't provisioned.
- **CI not run** — see above; no image is actually published to GHCR yet.
- **Argo CD Image Updater** annotations are present but the controller isn't
  installed; promotion was demoed via git push. Not wired: cosign image signing +
  admission control, External Secrets (the demo app has no secrets), full
  observability stack (Grafana/tracing — Prometheus only), transitive-dep lockfile.

## Local demo scaffolding (not committed, local-only)
To run Argo CD without pushing to GitHub, a small in-cluster **git server** serves
the repo on an `argo-local` branch (dev image pinned to the locally-built
`assignment-web:local`). The committed `argocd/` manifests point at the real
GitHub URL; it's swapped to the git server only for the local run. On a pushed
repo, Argo points straight at GitHub and none of this scaffolding is needed.

## How to run
```bash
make all ENV=dev     # cluster + addons + build + deploy + smoke test
make down ENV=dev    # tear down
```
Prereqs: `docker`, `kind`, `kubectl`, `terraform` (≥1.5). Full flow (GitOps + canary)
in README "Deployment process"; captured evidence in docs/DEMO.md.

## Before submitting / next owner's checklist
1. Replace the `OWNER` placeholder (in `deploy/overlays/*/kustomization.yaml`,
   `.github/CODEOWNERS`, `argocd/*`) with the real GitHub org/user.
2. Push to GitHub; consider making it public so CI runs for free.
3. Apply branch protection (commands in `docs/governance.md`).
4. (Optional) Stand up a real cluster: swap the kind module for a cloud module and
   enable the remote backend (`backend.tf.example`).

## Suggested next steps (priority order)
1. Run CI on a public repo; publish the image; let Argo Image Updater bump dev.
2. Provision staging/prod (locally or a cloud module) and demo promotion via PR.
3. cosign signing + Kyverno/Gatekeeper admission policy.
4. kube-prometheus-stack + Grafana + OTel tracing + SLO burn-rate alerts as addons.
5. External Secrets + a secret-consuming path in the app.
