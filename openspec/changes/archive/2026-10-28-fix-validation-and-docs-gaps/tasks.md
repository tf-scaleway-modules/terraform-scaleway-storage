## 1. Code
- [x] 1.1 `locals.tf`: case-insensitive export suffix; drop the unused `prevent_destroy` passthrough
- [x] 1.2 `variables.tf`: `bucket_key` existence validations (policies, lock configurations, objects); final bucket name length validation; description updates (`prevent_destroy`, `zone`, `tags`)
- [x] 1.3 `block-storage.tf`: `check` warning for `prevent_destroy = true`; fix comments
- [x] 1.4 `outputs.tf`: `region` description

## 2. Tests (`tests/main.tftest.hcl`)
- [x] 2.1 Rejected-input runs: unknown `bucket_key` in policies, lock configurations and objects; bucket name over 63 characters with suffix
- [x] 2.2 Happy-path runs: uppercase export extension with count 2; valid expanded `bucket_key`; name exactly 63 characters
- [x] 2.3 Check run: `prevent_destroy = true` warns, default does not

## 3. Docs and examples
- [x] 3.1 `README.md` (outside terraform-docs block) and `SECURITY.md`: `prevent_destroy` not enforced, zone default, block tags
- [x] 3.2 `examples/complete/main.tf`: remove `prevent_destroy`

## 4. Verify
- [x] 4.1 `tofu fmt -recursive`, `tofu validate`, `tflint --recursive`, `tofu test`, `pre-commit run -a`, `openspec validate --all --strict`
- [x] 4.2 Commit subject: `Fix key validation, export suffix case and prevent_destroy documentation` (patch; no upgrade notes)
