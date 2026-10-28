## Why

Verifying the issues noted while baselining the released contract shows real defects: an input that is accepted and silently ignored (`block_volumes.prevent_destroy`), export keys that collide with uppercase extensions, dependent keys that fail with an index error instead of a validation message, and bucket names that can pass validation and still be rejected by the S3 API. Others are documentation gaps. Each is fixed in the least disruptive way (`quality-security`: no control weakened silently; `terraform-versioning`).

## What Changes

| # | Issue | Verified | Decision | Breaking |
|---|-------|----------|----------|----------|
| 1 | `block_volumes.prevent_destroy` never read; `lifecycle.prevent_destroy` hard-coded `false` | Yes (`block-storage.tf`, `object-storage.tf`, `locals.tf`) | Cannot be enforced: the argument must be a literal. Keep the input (removing it is major), add a `check` that warns when a volume sets it to `true`, describe it as not enforced in the variable description, README and `SECURITY.md`, drop the dead passthrough in `locals.tf`, drop it from `examples/complete` and the README example | No |
| 2 | Export key regex accepts `.QCOW`/`.QCOW2`, count suffix only matches lowercase, so keys collide | Yes (`locals.tf`) | Code fix: make the suffix regex case-insensitive | No (only affected configs that overwrote each other's exports) |
| 3 | `bucket_policies`, `bucket_lock_configurations`, `objects` (and snapshot `volume_key`) only fail with an index error on an unknown key | Yes | Code fix: validations that `bucket_key` is an expanded key of `buckets`. Snapshot `volume_key` is left as is (not listed as a requirement of this change) | No (rejects only configs that already failed) |
| 4 | `zone` defaults to `fr-par-1` regardless of `region`, imported snapshots default to `<region>-1` | Yes | Left. Changing the default would move existing volumes outside `fr-par` (major). Documented in the variable description and README | No |
| 5 | Bucket name validation ignores the `-<n>` suffix | Yes | Code fix: with `count > 1`, base name + `-` + digits of `count` MUST fit in 63 characters | No (rejects only names the S3 API refuses) |
| 6 | Block `tags` are `list(string)` and not merged with `var.tags`; `region` output description says "all buckets" | Yes | Tags left: Scaleway block resources take a list of strings, a merge would invent a `key:value` encoding and change existing resources. Documented in the `tags` description. `region` output description fixed | No |

Semver: **patch** (fixes, one warning-only `check`, descriptions and documentation; no input or output removed, renamed or retyped, no default changed, no resource address changed).

Inputs whose meaning is clarified: `block_volumes` (`prevent_destroy` documented as not enforced, `zone` default documented), `tags` (buckets only), `region` output description. New validations on `buckets`, `bucket_policies`, `bucket_lock_configurations`, `objects`.

State: nothing new lands in state; no secret is involved. Resource attributes are unchanged for every config that planned and applied before.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `block-volumes`: `prevent_destroy` documented as not enforced, warned by a check; zone default stated as independent of `region`.
- `block-snapshots`: export suffix matches the extension case-insensitively.
- `bucket-access-and-lock`: `bucket_key` MUST be an expanded bucket key.
- `buckets`: final name with count suffix MUST fit in 63 characters.
- `objects`: `bucket_key` MUST be an expanded bucket key.
- `module-contract`: global `tags` apply to buckets only; `region` output description.

## Impact

`variables.tf`, `locals.tf`, `block-storage.tf`, `object-storage.tf` (comment), `outputs.tf` (description), `README.md`, `SECURITY.md`, `examples/complete/main.tf`, `tests/main.tftest.hcl`.
