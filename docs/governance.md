# Repo governance & branch protection

`main` is protected and is the single source of truth Argo CD reconciles from, so
what merges to `main` is what runs in the cluster. Rules:

- **No direct pushes to `main`.** All changes land via pull request.
- **≥1 approving review**, from a Code Owner (see `.github/CODEOWNERS`); stale
  approvals are dismissed when new commits are pushed.
- **Required status checks must pass** (the `ci` workflow: tests, `kustomize
  build`, image build/scan) and the branch must be **up to date** before merge.
- **Linear history** — merge commits are disallowed; PRs merge by **rebase**.
  Conflicts are resolved by rebasing the branch onto `main`, not by merge commits.
- **No force-pushes or deletion** of `main`.

## Developer workflow

```bash
git checkout -b feature/x
# ... commit work ...
git fetch origin
git rebase origin/main        # resolve any conflicts here, then:
git push --force-with-lease    # update the PR branch
# open PR -> CI + review -> "Rebase and merge"
```

Locally, `git config pull.rebase true` keeps pulls rebase-based (already set in
this repo).

## Enforce it (once, per repo)

GitHub UI: *Settings → Branches → Add rule for `main`*, or via the CLI:

```bash
gh api -X PUT repos/etedgy/k8s-gitops-platform/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[checks][][context]=test' \
  -f 'required_status_checks[checks][][context]=validate-manifests' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'required_pull_request_reviews[require_code_owner_reviews]=true' \
  -F 'required_pull_request_reviews[dismiss_stale_reviews]=true' \
  -F 'required_linear_history=true' \
  -F 'allow_force_pushes=false' \
  -F 'allow_deletions=false' \
  -F 'restrictions=null'
```

In production this ruleset would itself be codified (Terraform `github` provider /
a repo ruleset) so protection is reviewable and can't be silently disabled.
