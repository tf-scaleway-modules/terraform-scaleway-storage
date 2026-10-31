## Why

The module (v3.0.0) already pins `scaleway/scaleway ~> 2.89` (2.89.0, 2026-10-27, latest on the Terraform and OpenTofu registries; v2.90.0 is tagged but unpublished and brings nothing for this module). The archived change `update-provider-2-89` only added pass-through arguments. What remains is a design that predates the provider's current shape: a project looked up by name, a hard-coded region and zone, client-side string building for endpoints the provider already reports, a second map for the lock configuration that lives on the same bucket, an input that is accepted and ignored (`prevent_destroy`), `depends_on` that Terraform infers, and eleven outputs that repeat the four main ones. A major release is allowed, so this change aligns the module with the cross-module conventions and removes that weight in one breaking step.

Gap analysis against the 2.89.0 schema (`scaleway_object_bucket`, `_acl`, `_lock_configuration`, `_policy`, `_server_side_encryption_configuration`, `_website_configuration`, `scaleway_object`, `scaleway_block_volume`, `scaleway_block_snapshot`): the provider has **no write-only (`*_wo`) argument and no ephemeral resource in the Object or Block Storage products**, no separate CORS, versioning or lifecycle resource (all stay nested in `scaleway_object_bucket`), and `scaleway_object_bucket.acl` is deprecated (the module already uses `scaleway_object_bucket_acl`). Nothing else of the two products is unmanaged. The gaps are therefore mostly in the module's own design, not in missing provider arguments.

## What Changes

### Adopted features

| # | Item | Provider | Notes |
|---|------|----------|-------|
| 1 | `project_id` (string, `null` = provider default project) replaces `organization_id` + `project_name` and `data.scaleway_account_project` | n/a (convention) | Fixed decision 4 |
| 2 | `region` and a new `zone` (strings, `null` = provider default) | n/a (convention) | `zone` is the default for volumes and imported snapshots, per-item `zone` overrides |
| 3 | `buckets[*].object_lock` (`default_retention` with `mode`, `days`, `years`) replaces `object_lock_enabled` and the `bucket_lock_configurations` map | `scaleway_object_bucket.object_lock_enabled` and `scaleway_object_bucket_lock_configuration` (<= 2.86) | The lock belongs to the bucket; removes a cross-reference input and three `bucket_key` validations |
| 4 | `buckets[*].lifecycle_rules[*].tags` (tag filter) | `scaleway_object_bucket.lifecycle_rule.tags` (present in 2.89.0 schema, <= 2.86 per the archived analysis) | Deferred in `update-provider-2-89` as niche; a tag filter is the standard way to scope a rule without a prefix |
| 5 | `block_volumes[*].size_in_gb` optional when `snapshot_id` is set | `scaleway_block_volume.size_in_gb` is optional and computed in 2.89.0 | A restored volume takes the snapshot size; required otherwise |
| 6 | Global `tags` also applied to objects and, rendered as `key:value`, to volumes and snapshots (merged, distinct, with per-item tags) | `scaleway_object.tags` (map), `scaleway_block_*.tags` (list) | Convention: tags on every taggable resource |
| 7 | Snapshot `volume_key` validated as an expanded key of `block_volumes` | n/a | Deferred in `fix-validation-and-docs-gaps`; fails with a message instead of an index error |
| 8 | Outputs read provider-reported `endpoint`, `api_endpoint`, `website_endpoint` instead of building URLs from `region` | `scaleway_object_bucket.endpoint`/`api_endpoint`, `scaleway_object_bucket_website_configuration.website_endpoint` (<= 2.86) | Required once `region` can be `null` |

### Breaking changes

| # | Change | Consumer edit |
|---|--------|---------------|
| 1 | `organization_id` and `project_name` removed | Pass `project_id = <uuid>` (for example `data.scaleway_account_project.x.id`); omit it to use the provider default project |
| 2 | `region` default `"fr-par"` becomes `null` (provider default) | Set `region = "fr-par"` to keep buckets where they are; a different provider default region would replace every bucket |
| 3 | Block volume `zone` default `"fr-par-1"` and imported snapshot default `<region>-1` become `null` (provider default zone) | Set `zone` (module or per item) when the provider default zone differs; a different zone replaces volumes |
| 4 | `bucket_lock_configurations` removed; `buckets[*].object_lock_enabled` replaced by `buckets[*].object_lock` | `object_lock_enabled = true` becomes `object_lock = {}`; a lock configuration becomes `object_lock = { default_retention = { mode, days \| years } }` on the bucket; move the state address (see design.md) |
| 5 | `block_volumes[*].prevent_destroy` removed, with its `check` | Delete the attribute; protect volumes through plan review and credentials |
| 6 | `block_snapshots[*].volume_key` that names no expanded volume key is rejected by validation (it already failed with an index error) | Use an expanded key such as `db-1` |
| 7 | Outputs removed: `project_id`, `region`, `s3_endpoint`, `bucket_names`, `bucket_ids`, `bucket_endpoints`, `bucket_arns`, `website_endpoints`, `website_urls`, `lock_configurations`, `object_urls`, `aws_cli_config`, `environment_variables`, `block_volume_ids`, `block_volume_names`, `block_snapshot_ids`, `block_snapshot_exports` | Read the same data from `buckets`, `objects`, `block_volumes`, `block_snapshots` (field names in the spec delta) |
| 8 | `buckets` output gains `region` and `website_endpoint` and reads `endpoint`/`api_endpoint` from the provider; `block_snapshots[*].export` keeps `bucket` and `key` only (the export URL is gone with `block_snapshot_exports`) | Build an export URL from the bucket endpoint if needed |
| 9 | Global `tags` now also reach objects and block resources | Expect an in-place tag update on those resources on the first plan |

### Simplifications

| # | Change |
|---|--------|
| 1 | Remove `data.tf` and the project lookup; drop `local.s3_endpoint` |
| 2 | Remove the `check` and the dead `lifecycle { prevent_destroy = false }` blocks on buckets and volumes |
| 3 | Remove `depends_on` that restates a reference (ACL, SSE, website, lock, policy, object on the bucket; snapshot on its volume) |
| 4 | Collapse seventeen outputs to `buckets`, `objects`, `block_volumes`, `block_snapshots` |
| 5 | Fold the lock map into `buckets`, deleting its cross-reference validation |

### Deferred / rejected

| Candidate | Provider | Reason |
|-----------|----------|--------|
| Fold `bucket_policies` into `buckets` | n/a | A policy document embeds the bucket name; one string cannot serve an entry with `count > 1`. It stays a separate map keyed by expanded key |
| Drop `count` expansion (keys `data-1`) | n/a | Renames every instance address; `moved` blocks cannot carry dynamic keys, so every consumer would hand-write moves. Out of proportion |
| Merge `scaleway_block_snapshot.imported` into `this` | n/a | Moves every imported snapshot address for a saving of one resource block |
| `objects.sse_customer_key` (SSE-C) | <= 2.86 | Secret with no write-only variant in 2.89.0; would land in state (`terraform-security`) |
| `objects.content_base64` | <= 2.86 | `source` covers binary; widens the source xor content contract |
| `lifecycle_rule` `expiration.date` / `transition.date` | <= 2.86 | Absolute dates make a plan stale once the date passes |
| `scaleway_object_bucket_acl.access_control_policy` grants | <= 2.86 | Conflicts with policies-over-ACLs; `public-read-write` is blocked on purpose |
| `scaleway_object_bucket.timeouts`, `scaleway_object.timeouts`, `scaleway_block_volume.timeouts` | <= 2.86 | No observed need; snapshot timeouts exist because exports are long |
| `scaleway_block_volume.instance_volume_id` | <= 2.86 | Legacy Instance volume migration, one-off |
| Check: website on a `private` bucket | n/a | False positives when a policy grants public read |
| `data.scaleway_block_snapshots` (2.84.0), `data.scaleway_object_bucket`, other data sources | 2.84.0 | The module has no lookup need |
| `srn` on `scaleway_account_project` (2.87.0), `srn` on ephemeral `scaleway_iam_api_key` (2.90.0) | 2.87.0 / 2.90.0 | Not consumed; the module has no IAM or secrets |
| Secrets: write-only / ephemeral inputs | n/a | No secret-bearing input exists, none added |
| Global resource-name prefix `name` | n/a | The module takes full names per item and derives none globally |
| Raise `required_version` | n/a | No write-only or ephemeral feature used; `>= 1.11.0` stays (CI pins 1.11.6, a lower floor would be untested) |

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `module-contract`: `project_id`, `region`, `zone` inputs; global tags; slimmed outputs; project lookup removed.
- `buckets`: `object_lock`, lifecycle `tags`; bucket outputs from provider attributes.
- `bucket-access-and-lock`: lock configuration folded into `buckets`; policies unchanged.
- `objects`: global tags merged.
- `block-volumes`: optional size with snapshot, `zone` default, tags, `prevent_destroy` removed.
- `block-snapshots`: zone default, tags, `volume_key` existence, export reported in `block_snapshots`.

## Semver: MAJOR

Per `terraform-versioning`: removed inputs (`organization_id`, `project_name`, `bucket_lock_configurations`, `object_lock_enabled`, `prevent_destroy`), removed outputs (list above), changed defaults. Released as v4.0.0.

Inputs whose type, default or meaning changes: `region` (default `fr-par` to `null`); `block_volumes` (`zone` default `fr-par-1` to `null`, `size_in_gb` optional, `prevent_destroy` removed); `block_snapshots` (`zone` default to `null`, `volume_key` validated); `buckets` (`object_lock_enabled` to `object_lock`, `lifecycle_rules[*].tags` added); `tags` (now reaches objects and block resources); new `project_id`, `zone`. Outputs changing: `buckets`, `block_snapshots`, `objects` (fields), plus the removals.

## State

Buckets, objects, volumes, snapshots, ACL, SSE, website and policy addresses are unchanged. `scaleway_object_bucket_lock_configuration.this` changes key from the old lock map key to the expanded bucket key (`data-1`): the consumer adds a `moved` block (design.md). Nothing secret lands in state; `policy` is a JSON document, not a secret. No secret-bearing input is added (`terraform-security`).

## Impact

`variables.tf`, `locals.tf`, `object-storage.tf`, `block-storage.tf`, `outputs.tf`, `main.tf` header, `data.tf` (deleted), `README.md` outside the terraform-docs block (compatibility table, "Upgrading from v3 to v4"), `SECURITY.md` (state table), `TESTING.md` (mock sample), `examples/minimal`, `examples/complete`, `tests/main.tftest.hcl`, `tests/examples.tftest.hcl`.

Standards applied: `terraform-versioning`, `terraform-providers`, `terraform-variables`, `terraform-outputs`, `terraform-state`, `terraform-testing`, `terraform-security`, `quality-simplicity`, `quality-security`, `quality-production-readiness`.
