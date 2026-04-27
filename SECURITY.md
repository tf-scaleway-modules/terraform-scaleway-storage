# Security

Security guidance for operators of this module. Read this before deploying to a production project.

## Secrets

- Never commit credentials to `.tf` or `.tfvars` files. Pass `SCW_ACCESS_KEY` / `SCW_SECRET_KEY` via environment variables, CI/CD secret stores, or a vault.
- `*.tfvars` is gitignored except `example.tfvars` — keep it that way; if you need a real `terraform.tfvars` for a deployment, store it outside the repo.
- This module exposes no secret values today. If you add an output that wraps a credential, mark it `sensitive = true`.

## Terraform state

- State files contain your full resource graph (and any `sensitive = true` values in cleartext). Always use a remote backend with encryption at rest and access control.
- Do not commit `.tfstate` / `.tfstate.backup`. They are already in `.gitignore`.
- Restrict the IAM identity used by CI to only the Scaleway APIs this module calls (Object Storage, Block Storage, Account project read).

## Least privilege

- Issue separate Scaleway API keys for `plan` (read) and `apply` (read/write) where your team's workflow allows.
- For bucket policies, prefer named principals (`SCW: user_id:<USER_ID>` / `application_id:<APP_ID>`) over `Principal: "*"`. A policy that grants only `Principal: "*"` will lock the Terraform identity out of the bucket — always include your CI/operator principal with full S3 permissions in the same policy.
- Scaleway bucket policies use `Version = "2023-04-17"` (NOT AWS's `"2012-10-17"`); under this version, only explicitly-allowed actions are permitted (implicit deny).

## ACLs

- `private` is the default and the safe choice. Use bucket policies for fine-grained sharing.
- `public-read` exposes object listing and read to the public internet — use only for static-site assets and documents you have intentionally chosen to publish.
- `public-read-write` is **blocked** at variable validation (`var.buckets`) — it would let anonymous users overwrite or delete objects.

## Object Lock (WORM)

- `object_lock_enabled` cannot be turned off after bucket creation. Versioning is forced on whenever it is set.
- `mode = COMPLIANCE` is **irreversible**: no one (including the root account) can delete or overwrite a locked object until retention expires. Use it only when a regulator requires it, and test in `GOVERNANCE` mode first.
- Long retention (`days = 36500` / `years = 100`) under `COMPLIANCE` makes data permanently immutable for the practical lifetime of the bucket.

## Block storage

- `prevent_destroy` on the `lifecycle {}` block is currently `false` and Terraform requires it to be a literal — set it to `true` in `block-storage.tf` for production volumes you cannot afford to lose.
- The `prevent_destroy` variable on each volume is intent-only documentation; it does not enforce anything.
- Snapshots exported as QCOW2 to Object Storage inherit the destination bucket's ACL and policy — make sure the destination bucket is private.

## Production checklist

- [ ] `force_destroy = false` for every bucket
- [ ] `prevent_destroy = true` (literal) in `block-storage.tf` for critical volumes
- [ ] Versioning enabled for any bucket whose data must survive accidental deletion
- [ ] Bucket policies include the Terraform-running principal with `s3:*`
- [ ] `Principal: "*"` only on objects you intend to publish
- [ ] Remote, encrypted Terraform state with locking
- [ ] CI key scoped to this project, rotated regularly
- [ ] Static analysis (`tfsec` / `trivy config` / `checkov`) wired into CI
- [ ] `terraform plan` reviewed for unexpected destroys before every apply

## Static analysis

CI runs `pre-commit` (which executes `terraform_fmt`, `terraform_docs`, `terraform_tflint`) plus `validate:opentofu`, `validate:tflint`, and `osv-scanner` per `.gitlab/release.yml`. To extend with security-focused scanning:

```bash
# Misconfigurations
trivy config .
tfsec .

# Compliance policies
checkov -d .
```

## Reporting vulnerabilities

If you find a security issue in this module, open a confidential issue on the module's GitLab project rather than a public merge request.
