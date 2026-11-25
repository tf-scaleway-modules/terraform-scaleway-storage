## 1. Standards reference

- [x] 1.1 `openspec/config.yaml`: change only the `terraform` reference `ref: v1.2.6` to `ref: v2.1.0`; `quality` (`v1.2.6`) and `repository` (`v4.1.0`) stay. Verify with `grep -n 'ref:' openspec/config.yaml` and `mise exec -- openspec doctor`.

## 2. Toolchain pins

- [x] 2.1 `mise.toml` `[tools]`: set `opentofu = '1.13.10'` and add `terraform = '1.17.2'`. Run `mise install`; verify with `mise exec -- tofu version` and `mise exec -- terraform version`.

## 3. CI

- [x] 3.1 `.gitlab/release.yml`: set the `validate:opentofu` image to `ghcr.io/opentofu/opentofu:1.13.10`. Verify with `grep -n 'opentofu:' .gitlab/release.yml`.
- [x] 3.2 `.gitlab/release.yml`: add `validate:terraform` right after `validate:opentofu` (image `hashicorp/terraform:1.17.2` with `entrypoint: [""]`, `rules: - when: always`, scripts `terraform init -backend=false`, `terraform validate`, and the loop over `examples/*/`), and add it to `create:release` `needs:` right after `validate:opentofu`. Verify by reading the file and with `mise exec -- yamlfmt -lint .gitlab/release.yml`.
- [x] 3.3 `.pre-commit-config.yaml`: add `args: [--hook-config=--tf-path=tofu]` to `terraform_fmt`, `terraform_docs` and `terraform_tflint`. Verify with `grep -c 'tf-path=tofu' .pre-commit-config.yaml` (3) and the pre-commit run in 6.7.

- [x] 3.4 `.github/workflows/ci.yml` and `release.yml`: set `tofu_version` to `"1.13.10"` (was `"1.11.6"`); add no job. Verify with `grep -rn 'tofu_version' .github/workflows`.

## 4. Docs and examples

- [x] 4.1 `AGENTS.md`: the opening line names OpenTofu >= 1.11.0 and Terraform >= 1.11.0, and the `Format / validate` command line gains `terraform init -backend=false && terraform validate`. Verify with `grep -n 'Terraform' AGENTS.md`.
- [x] `TESTING.md`: update the `Provides:` line to the `mise.toml` pins (opentofu 1.13.10, terraform 1.17.2, terraform-docs, tflint 0.62.0, pre-commit). Verify with `grep -n 'Provides' TESTING.md` against `mise.toml`.
- [x] `versions.tf`: change the comment to `OpenTofu/Terraform 1.11+`. Verify that `git diff versions.tf` shows the comment only.
- [x] README: the requirement line 58 and the compatibility matrix (lines 64-68) already name both tools at `>= 1.11.0`; keep them. The `verified on OpenTofu 1.11.6` note near line 83 is a dated verification fact, not a pin: keep it. Verify with `grep -n '1\.11\.6' README.md` that no other prose names the old pin.
- [x] 4.9 Stale references: `grep -rnE '1\.10\.0|1\.10\.7|1\.11\.6|v1\.2\.6|opentofu:1\.11\b' . --exclude-dir=.git --exclude-dir=.terraform --exclude=CHANGELOG.md --exclude-dir=archive` shows only the intentional hits (the `quality` store ref, historical notes). Never touch the text between `BEGIN_TF_DOCS` and `END_TF_DOCS`.

## 5. Spec

- [x] 5.1 After the apply, the `module-contract` delta in this change is the only spec change; confirm with `mise exec -- openspec validate --all --strict`.

## 6. Verification (run each through mise from the repo root; report each result as-is)

- [x] 6.1 `mise exec -- tofu fmt -recursive -check` passes.
- [x] 6.2 `mise exec -- tofu init -backend=false -upgrade && mise exec -- tofu validate` passes in the root and, separately initialised, in each `examples/*`.
- [x] 6.3 `mise exec -- tflint --init && mise exec -- tflint --recursive` passes.
- [x] 6.4 `mise exec -- tofu test` passes.
- [x] 6.5 Terraform compatibility in a scratch copy (never in the repo): `S=$(mktemp -d) && rsync -a --exclude .terraform --exclude .terraform.lock.hcl --exclude .git --exclude 'mise*.toml' ./ "$S/" && (cd "$S" && T=$(mise which terraform) && $T init -backend=false && $T validate && for d in examples/*/; do (cd "$d" && $T init -backend=false && $T validate) || exit 1; done)`, with `mise which terraform` run from the repo so 1.17.2 is used.
- [x] 6.6 `mise exec -- openspec validate --all --strict` passes.
- [x] 6.7 `mise exec -- pre-commit run -a` passes after moving every `.terraform.lock.hcl` to a backup folder outside the repo; restore them afterwards. The README stays unchanged between the terraform-docs markers.

## 7. Commit

- [x] 7.1 One signed commit (`git commit -S`), subject `Validate the module with Terraform and pin both toolchains`, no `feat:` prefix; `CHANGELOG.md` is not edited (git-cliff owns it).

## Workflow follow-up

- Push, merge request, tag (PATCH: next `v<major>.<minor>.<patch+1>`) and archive happen outside this change's apply.
