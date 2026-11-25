## Context

See proposal.md for motivation. The module already requires `>= 1.11.0` in `versions.tf`; The examples already declare `required_version = ">= 1.11.0"` and `scaleway ~> 2.89`, equal to the root. This module has no ephemeral input and no `*_wo` argument. Standards applied: `terraform-providers` (version constraints), `terraform-module-structure` (tooling), `terraform-repo-gitlab-ci` (Terraform validation job, Release depends on validation), `terraform-repo-mise` (toolchain pinned, hooks and CI use the pinned tools), `terraform-repo-precommit` (Terraform hooks run tofu), `terraform-versioning` (release level).

## Goals / Non-Goals

**Goals:**
- Prove at every merge request that Terraform and OpenTofu both validate the module and its examples.
- Make `mise.toml` the single source of the pinned versions used by hooks and CI.

**Non-Goals:**
- No change to `required_version`, to the provider constraint, to any resource, variable or output, and no use of provider arguments or resources.
- No catch-up of other drift from the store (hook repo revision, `terraform_validate`, `terraform_checkov`, `terraform_trivy`, `validate:examples`, `security:trivy`); that belongs to its own change.
- No new GitHub jobs. The `.github/workflows/` mirror only follows the pins (see decision 7).

## Decisions

1. **One `required_version = ">= 1.11.0"`, no `.tofu` file, no `language {}` block.** Both tools read the same constraint; 1.11.0 is the floor where both support ephemeral variables and write-only arguments. Alternative: a `.tofu` override file; rejected by `terraform-module-structure`.
2. **`mise.toml` pins `opentofu = '1.13.10'` and `terraform = '1.17.2'`, both exact** (`terraform-repo-mise`). The CI images use the same numbers (`ghcr.io/opentofu/opentofu:1.13.10`, `hashicorp/terraform:1.17.2`), so a bump touches both in one commit.
3. **`validate:terraform` placed right after `validate:opentofu`, same shape** (`terraform-repo-gitlab-ci`): `terraform init -backend=false`, `terraform validate`, then the same two commands in each `examples/*/` with a loop that stops at the first failure. It is added to `create:release` `needs:` right after `validate:opentofu`. The unit suite stays on `tofu test`.
4. **Hooks keep running tofu.** `.pre-commit-config.yaml` sets `args: [--hook-config=--tf-path=tofu]` on `terraform_fmt`, `terraform_docs` and `terraform_tflint` (hook repo stays at `v1.105.0`). Rationale: `terraform-repo-precommit` requires the hooks to run the same CLI as `tofu test` once both binaries exist in `mise.toml`; without the argument the hook default is `terraform`, which cannot read a tofu-initialised `.terraform/`. Alternative: environment variable `PCT_TFPATH`; rejected, the standard prescribes the hook argument.
5. **Terraform compatibility is checked in a scratch copy**, never in the repository: `terraform init` would write `registry.terraform.io` entries into `.terraform.lock.hcl`.
6. **Module spec delta**: `module-contract` states the floor, so it gets a MODIFIED requirement with a Terraform scenario. The floor and every existing scenario are unchanged.

7. **GitHub mirror workflows follow `mise.toml`** (`terraform-repo-mise`, "Hooks and CI use the pinned tools"): `tofu_version` in `.github/workflows/ci.yml` and `release.yml` moves from `1.11.6` to `1.13.10`. No Terraform step exists there and none is added.

## Risks / Trade-offs

- [Terraform 1.17.2 rejects something OpenTofu accepts] → the scratch-copy validation runs before the commit; the brief's expectation is that none is used. If it fails, stop and report instead of changing module code.
- [Scaleway provider cannot be downloaded by Terraform from `registry.terraform.io`] → `terraform init` is run in the scratch copy; a failure is reported as-is.
- [`validate:terraform` image tag drifts from the pin] → the scenario in `terraform-repo-gitlab-ci` applies: bump both in the same commit.
- [Upgrade] none for consumers; revert is a plain revert of the commit, no state involved.
