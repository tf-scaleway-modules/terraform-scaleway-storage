## Why

Scaleway provider 2.89.0 (2026-10-27) is out and the module pins `~> 2.86`. A gap analysis of every resource the module manages (`scaleway_block_volume`, `scaleway_block_snapshot`, `scaleway_object`, `scaleway_object_bucket` and its `_acl`, `_lock_configuration`, `_policy`, `_server_side_encryption_configuration`, `_website_configuration`, data `scaleway_account_project`) between the 2.86.0 and 2.89.0 docs and sources shows one new capability, plus gaps that already existed in 2.86 and a validation that disagrees with the provider.

Snapshot exports and imports of large volumes can outlast the provider's 5 minute default wait; `timeouts` (2.88.0) is the only lever. Separately, `scaleway_object.hash` is the only way to re-upload a changed local `source` file (the provider reacts to `file` or `hash` changes only when `hash` changes, see the provider's object update), and the module cannot set it.

## What Changes

| # | Item | Introduced in | Decision | Breaking |
|---|------|---------------|----------|----------|
| 1 | `block_snapshots.timeouts` (`create`, `read`, `update`, `delete`) passed to both `scaleway_block_snapshot` resources | provider 2.88.0 | Adopt. New optional input, default `null` (provider default 5m) | Floor raise only |
| 2 | `objects.hash`, `objects.storage_class`, `objects.metadata` passed to `scaleway_object` | provider <= 2.86 (identical in the 2.86.0 and 2.89.0 docs) | Adopt. Optional, default `null`; `hash` makes a changed local `source` re-upload, `storage_class` and `metadata` as in the provider | No |
| 3 | Lifecycle transition storage class validation accepts `STANDARD_IA`, which the provider rejects (it accepts `STANDARD`, `GLACIER`, `ONEZONE_IA`) | provider enum, unchanged | Fix: align the validation with the provider so the error appears at variable validation with the right list | See below |
| 4 | `srn` added to the `block_volumes` and `block_snapshots` output objects | provider <= 2.86 (`srn` documented on both resources) | Adopt: usable in IAM policies and resource references; new map key only | No |

### Semver: MAJOR

`versions.tf` goes from `~> 2.86` to `~> 2.89` because item 1 needs `scaleway_block_snapshot.timeouts`, absent before 2.88.0 (`terraform-versioning`, `terraform-providers`: a raised provider floor is major, whatever else changes). 2.89.0 rather than the technical minimum 2.88.0 is chosen so every consumer also gets the 2.89.0 fix that computes the region first on object resources (empty S3 URL), relevant to `objects`. Consumers whose lock file or other modules hold the provider at 2.86 or 2.87 must upgrade it; `~> 2.86` already resolved to 2.89, so a consumer on a fresh `init -upgrade` sees no difference.

If the maintainers prefer a minor release, drop item 1 and keep `~> 2.86`: items 2 and 4 are minor and item 3 is a patch-level fix.

Item 3 changes behaviour in one direction only: a transition with `STANDARD_IA` is now rejected by the module's validation. Provider 2.86 to 2.89 already reject it at plan (`StringInSlice` on `STANDARD`, `GLACIER`, `ONEZONE_IA`), so no configuration that applied before is affected. The README upgrade note lists it.

Inputs whose type changes: `block_snapshots` (new optional `timeouts` attribute), `objects` (new optional `hash`, `storage_class`, `metadata`). Input whose validation changes: `buckets` (lifecycle storage class list). Outputs changing: `block_volumes` and `block_snapshots` (new `srn` key). No default changes, no removal, no rename.

State: `timeouts` is stored in state as an attribute of the snapshot (non-secret); `hash`, `storage_class` and `metadata` are stored on the object (non-secret metadata, the content hash is a digest the caller chooses); `srn` is computed. No secret-bearing input is added (`terraform-security`).

### Considered and deferred

| Candidate | Provider | Reason |
|-----------|----------|--------|
| `objects.sse_customer_key` (SSE-C) | <= 2.86 | Secret with no write-only (`*_wo`) variant in 2.89.0 docs; would land in state (`terraform-security`, `quality-security`) |
| `objects.content_base64` | <= 2.86 | Third content source widens the source xor content contract for a rare case; `content` and `source` cover the module's uses |
| `lifecycle_rule.tags`, `expiration.date`, `transition.date` | <= 2.86 | Tag filters and absolute dates are niche; absolute dates also make a plan stale after the date passes. Re-evaluate on demand |
| `scaleway_object_bucket_acl` `access_control_policy` grants | <= 2.86 | Per-grantee ACLs conflict with the module's "policies instead of ACLs" stance; canned ACLs already cover it and `public-read-write` is blocked on purpose |
| `data.scaleway_account_project.srn` (2.87.0) | 2.87.0 | Not consumed anywhere; exposing it adds an output without a use |
| `data.scaleway_block_snapshots` (2.84.0), custom S3 endpoint (2.84.0) | 2.84.0 | Data source: the module has no lookup need. Endpoint: provider-level setting, the caller configures the provider |
| Provider fixes 2.83.0 (lifecycle expiration unset when empty), 2.85.0 (`expired_object_delete_marker` ignored when false), 2.86.0 (auto-populated s3 endpoint), 2.89.0 (region first) | fixes | Taken for free by the floor; no module change. Task 4.2 checks the second plan stays empty |
| `block_volume` / `block_snapshot` framework migration (2.87.0) | 2.87.0 | Verified: `import` and `export` stay nested blocks (`ListNestedBlock`), `volume_id`, `tags`, `zone`, `project_id` unchanged; only `timeouts` is new, and it is an attribute (`timeouts = { create = "10m" }`) not a block |
| Per-volume `prevent_destroy`, volume `tags` merging | n/a | Settled in the archived `fix-validation-and-docs-gaps` change |

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `module-contract`: provider constraint `~> 2.89`; block storage outputs gain `srn`.
- `block-snapshots`: optional `timeouts` input passed to both snapshot resources, with duration validation.
- `objects`: optional `hash`, `storage_class`, `metadata` with validation.
- `buckets`: lifecycle storage class validation aligned with the provider (`STANDARD`, `GLACIER`, `ONEZONE_IA`).

## Impact

`versions.tf`, `variables.tf`, `block-storage.tf`, `object-storage.tf`, `outputs.tf`, `README.md` (outside the terraform-docs block: compatibility table and upgrade notes), `examples/complete/main.tf`, `tests/main.tftest.hcl`, `TESTING.md` only if its table changes.

Standards applied: `terraform-versioning`, `terraform-providers`, `terraform-variables`, `terraform-testing`, `terraform-security`, `quality-simplicity`, `quality-security`.
