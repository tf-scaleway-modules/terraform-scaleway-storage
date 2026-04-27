# Testing

This module ships with a hermetic test suite using Terraform's native `.tftest.hcl` framework plus end-to-end validation of the example modules.

## What is tested

| File                    | What it covers                                                                          |
| ----------------------- | --------------------------------------------------------------------------------------- |
| `tests/main.tftest.hcl` | Variable validations, count expansion in `locals.tf`, derived `s3_endpoint`             |
| `examples/minimal/`     | Smoke test: a single bucket configuration validates and plans cleanly                   |
| `examples/complete/`    | Integration target: every feature wired together (Object + Block storage)               |

The `tests/` suite uses `mock_provider` blocks so it runs without Scaleway credentials. The example modules require credentials only when run against a real account.

## Prerequisites

Tools are pinned in `mise.toml`:

```bash
mise install
```

Provides: `opentofu 1.11`, `terraform-docs 0.21`, `tflint 0.56`, `pre-commit 4.3`.

## Running the tests

### Native `terraform test`

```bash
# All test files in tests/
terraform init
terraform test

# Single file
terraform test -filter=tests/main.tftest.hcl

# Verbose output
terraform test -verbose
```

`tofu test` works identically.

### Examples — validate only (no credentials needed)

```bash
cd examples/minimal
terraform init -backend=false
terraform validate

cd ../complete
terraform init -backend=false
terraform validate
```

### Examples — full plan (requires credentials)

```bash
export SCW_ACCESS_KEY=...
export SCW_SECRET_KEY=...
export TF_VAR_organization_id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export TF_VAR_project_name=test-project

cd examples/complete
terraform init
terraform plan
```

## Pre-commit checks

`pre-commit` runs the formatting, docs, and lint hooks before every commit:

```bash
pre-commit install
pre-commit run -a
```

Hooks executed (configured in `.pre-commit-config.yaml`):

- `terraform_fmt` — canonical formatting
- `terraform_docs` — refresh README.md `BEGIN_TF_DOCS` block
- `terraform_tflint` — preset `recommended` plus the rules in `.tflint.hcl`

## CI

GitLab CI (`.gitlab-ci.yml` + `.gitlab/`) runs three validation jobs on every push:

1. **pre-commit** — full pre-commit run + `osv-scanner` for dependency vulns
2. **validate:opentofu** — `tofu init -backend=false`, `tofu validate`, `tofu fmt -check -recursive`
3. **validate:tflint** — `tflint --recursive` with `.tflint.hcl`

On semver tags (`v*.*.*`), `verify:changelog` checks that `CHANGELOG.md` is up to date with `git-cliff`, and `create:release` cuts a GitLab release. Tag a release with:

```bash
git tag v1.2.3
git push origin v1.2.3
```

GitHub Actions equivalents live in `.github/workflows/`.

## Adding a test

Tests should be plan-only and use mocks unless they're explicitly integration tests. Pattern:

```hcl
mock_provider "scaleway" {
  mock_data "scaleway_account_project" {
    defaults = { id = "11111111-1111-1111-1111-111111111111" }
  }
}

variables {
  organization_id = "11111111-1111-1111-1111-111111111111"
  project_name    = "test-project"
}

run "my_new_check" {
  command = plan

  variables {
    # ... module inputs ...
  }

  assert {
    condition     = local.expanded_buckets["data-1"].name == "expected"
    error_message = "explain what broke"
  }
}
```

For validation-rejection tests, use `expect_failures = [var.<name>]` instead of `assert`.
