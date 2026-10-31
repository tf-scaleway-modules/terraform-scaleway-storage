## 1. Provider constraint
- [x] 1.1 `versions.tf`: provider `version = "~> 2.89"` (major: the floor is raised for `scaleway_block_snapshot.timeouts`, provider 2.88.0)

## 2. Code
- [x] 2.1 `variables.tf` `block_snapshots`: add `timeouts = optional(object({ create/read/update/delete = optional(string) }))`; validation with message "Snapshot timeouts must be durations such as 10m or 1h30m (units ns, us, ms, s, m, h)."; description (duration form, defaults to the provider's 5m, useful for large exports/imports)
- [x] 2.2 `block-storage.tf`: `timeouts = each.value.timeouts` on `scaleway_block_snapshot.this` and `.imported` (attribute assignment, not a block); keep `import {}` and `dynamic "export"` unchanged
- [x] 2.3 `variables.tf` `objects`: add `hash`, `storage_class`, `metadata` (all `optional(...)`, default null); validations "Object storage_class must be one of: STANDARD, GLACIER, ONEZONE_IA." and "Object metadata keys must be lowercase."; description entries (mention `hash = filemd5(path)` for `source`)
- [x] 2.4 `object-storage.tf`: pass `hash`, `storage_class`, `metadata` to `scaleway_object.this`
- [x] 2.5 `variables.tf` `buckets`: lifecycle storage class list `STANDARD`, `GLACIER`, `ONEZONE_IA`; message "Storage class must be one of: STANDARD, GLACIER, ONEZONE_IA."; fix the `transition` line of the description
- [x] 2.6 `outputs.tf`: add `srn` to the `block_volumes` and `block_snapshots` values (volume, volume snapshots, imported snapshots) and to their descriptions

## 3. Tests (`tests/main.tftest.hcl`, `mock_provider "scaleway"`)
- [x] 3.1 Rejected-input runs (`expect_failures`): malformed snapshot timeout (`"ten minutes"`), object `storage_class = "DEEP_ARCHIVE"`, object `metadata` with an uppercase key, lifecycle `storage_class = "STANDARD_IA"` (replace the existing assertion on the old list if there is one)
- [x] 3.2 Happy-path runs: snapshot with `timeouts = { create = "30m" }` and `count = 2` planned on both `this` and `imported` resources with the value; no `timeouts` leaves it null; object with `hash`, `storage_class = "GLACIER"`, `metadata` planned with those values
- [x] 3.3 Output run: `block_volumes[...].srn` and `block_snapshots[...].srn` exist (add `mock_resource` defaults for `scaleway_block_snapshot` if the mock needs them)
- [x] 3.4 `tests/examples.tftest.hcl`: keep passing with the updated `examples/complete`

## 4. Docs and examples
- [x] 4.1 `examples/complete/main.tf`: a snapshot with `export` and `timeouts = { create = "30m" }`; an object with `hash = filemd5(...)`/`storage_class`/`metadata` where a `source` file already exists in the example (otherwise `content` plus `metadata`); a `block_volumes`/`block_snapshots` `srn` output in `examples/complete/outputs.tf` if it fits the existing outputs; update `examples/complete/README.md` if it lists features
- [x] 4.2 `README.md` outside the terraform-docs block: compatibility table (provider `~> 2.89`, last applied versions), upgrade notes (major: provider floor 2.88.0 needed for snapshot `timeouts`; `STANDARD_IA` in lifecycle transitions is now rejected by validation, the provider already refused it; new `srn` output key). `SECURITY.md`: what-lands-in-state table gets nothing new, say so in the commit body only if the table is touched
- [x] 4.3 `TESTING.md` only if its coverage table changes

## 5. Verify
- [x] 5.1 Move `.terraform.lock.hcl` aside before `pre-commit run -a` and before pushing: a local lock file makes terraform-docs write the locked provider version into the README instead of the `~> 2.89` constraint; restore it afterwards if needed
- [x] 5.2 `tofu fmt -recursive`
- [x] 5.3 `tofu init -backend=false && tofu validate` (also in `examples/minimal` and `examples/complete`)
- [x] 5.4 `tflint --recursive`
- [x] 5.5 `tofu test`
- [x] 5.6 `pre-commit run -a` (regenerates the README block; check it shows `~> 2.89`, not a locked version)
- [x] 5.7 `openspec validate --all --strict` (`mise run spec-validate`)
- [ ] 5.8 If credentials are provided: apply `examples/complete`, confirm the second `plan` is empty (covers the provider fixes 2.83.0 to 2.89.0), then destroy; otherwise state that the apply was skipped (skipped: no credentials; not run)
- [x] 5.9 Commit subject (reads as the CHANGELOG line): `Raise provider floor to ~> 2.89 and add snapshot timeouts, object hash, storage class and metadata`; body: **BREAKING** provider floor raised from `~> 2.86` to `~> 2.89` (needs `scaleway_block_snapshot.timeouts`, provider 2.88.0), lifecycle `STANDARD_IA` now rejected by validation (the provider already refused it), new `srn` output key. Do not edit `CHANGELOG.md` by hand (git-cliff generates it)
