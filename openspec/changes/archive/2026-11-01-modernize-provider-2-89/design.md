## Context

See proposal.md for motivation, the tables of adopted, breaking and rejected items, and the semver call. State today: v3.0.0, `scaleway/scaleway ~> 2.89`, `required_version >= 1.11.0`, tests with `mock_provider "scaleway"`, no credentials. The caller configures the provider; no secret input exists.

## Goals / Non-Goals

**Goals:** align the contract with the cross-module conventions (`project_id`, `region`/`zone`, `tags`), remove dead and duplicate surface, keep every existing resource address except the lock configuration, and keep a second plan empty.

**Non-Goals:** dropping `count` expansion, merging the two snapshot resources, any new resource type (the provider has none left unmanaged in these two products), real-account apply (a separate task group).

## Resources and arguments

| Resource | Argument / attribute | Provider | Use |
|----------|----------------------|----------|-----|
| `scaleway_object_bucket` | `project_id`, `region` (optional, computed) | <= 2.86 | `var.project_id`, `var.region`, both `null` allowed |
| `scaleway_object_bucket` | `object_lock_enabled`, `versioning { enabled }` | <= 2.86 | `object_lock != null`; versioning `versioning \|\| object_lock != null` |
| `scaleway_object_bucket` | `lifecycle_rule.tags` (map) | present in 2.89.0 schema | tag filter; `null` when the map is empty |
| `scaleway_object_bucket` | `endpoint`, `api_endpoint` (computed) | <= 2.86 | `buckets` output instead of `https://<name>.s3.<region>.scw.cloud` |
| `scaleway_object_bucket_website_configuration` | `website_endpoint` (computed) | <= 2.86 | `buckets[*].website_endpoint` |
| `scaleway_object_bucket_lock_configuration` | `rule.default_retention` | <= 2.86 | one per bucket with `object_lock.default_retention`, keyed by expanded bucket key |
| `scaleway_object` | `tags` (map) | <= 2.86 | `merge(var.tags, each.value.tags)` |
| `scaleway_block_volume` | `size_in_gb` (optional, computed), `zone`, `project_id`, `tags` (list) | <= 2.86 | optional size with `snapshot_id`; zone `each.value.zone` then `var.zone` then `null` |
| `scaleway_block_snapshot` | `zone`, `project_id`, `tags`, `timeouts` | `timeouts` 2.88.0 | unchanged shape; zone and tags as above |

Provider constraint stays `~> 2.89`. No `*_wo` argument and no ephemeral resource exists for Object or Block Storage in 2.89.0 (checked in the schema), so the secrets convention has nothing to apply. `required_version` stays `>= 1.11.0`: nothing needs it (no write-only or ephemeral feature), but lowering it would claim support CI (OpenTofu 1.11.6) never exercises.

Removed: `data "scaleway_account_project"`, `local.s3_endpoint`, `lifecycle { prevent_destroy = false }` on buckets and volumes (the default), the `check "block_volume_prevent_destroy_not_enforced"`, and every `depends_on` that restates a reference (ACL, SSE, website, lock, policy and object on `scaleway_object_bucket.this`; snapshot on its volume). The `depends_on = [scaleway_object_bucket.this]` of `scaleway_block_snapshot.imported` stays: it names buckets by string only (`import.bucket`), so no reference orders them.

## Decisions

- **Project, region, zone**: `project_id`, `region`, `zone` are `optional string = null`; validation runs only when set (`can(regex(...))` guarded by `== null ||`). Resources receive the variable directly. Alternative: keep defaults `fr-par` / `fr-par-1`; rejected, the fixed decision makes the provider default the single source and removes the module/provider disagreement. Risk and mitigation below.
- **Outputs from provider attributes**: `endpoint`/`api_endpoint`/`website_endpoint` are read from the resources, so no output depends on `region` being known at plan time. `bucket_arns` is dropped: Scaleway policies use bare bucket names, an `arn:scw:s3:::` string is not accepted in them (the `bucket_policies` description says so). Alternative: keep thin `bucket_ids` / `bucket_names` maps; rejected as derivable with one `for` expression (`quality-simplicity`), recorded as open question 2.
- **Lock folded into the bucket**: `object_lock = optional(object({ default_retention = optional(object({ mode = string, days = optional(number), years = optional(number) })) }))`. `object_lock_enabled` on the resource and the forced versioning derive from `object_lock != null`. The lock configuration resource is `for_each` over buckets whose `object_lock.default_retention != null`. The validations (mode, exactly one unit, ranges) move to `buckets` and iterate `v.object_lock.default_retention`. Alternative: keep a bool `object_lock_enabled` next to a `default_retention` object; rejected, two inputs for one state.
- **Policies stay separate**: the JSON embeds the bucket name; with `count > 1` one document cannot be right for every expanded bucket. The policy's `bucket_key` keeps its expanded-key validation.
- **Global tags**: `tags` stays `map(string)`. **Exception to the convention `tags = list(string)`**, because the provider types bucket and object tags as maps (`scaleway_object_bucket.tags`, `scaleway_object.tags`: `map(string)`) while volume and snapshot tags are lists. A list input would lose keys on buckets. Block resources receive `distinct(concat(each.value.tags, [for k, v in var.tags : "${k}:${v}"]))`; `key:value` follows the style the previous input description already recommended. Alternative: two inputs; rejected, a second global input for the same idea.
- **Volume size**: `size_in_gb = optional(number)`; one validation `size_in_gb != null || snapshot_id != null`; the size minimum validation applies when set. The planned volume passes `null` and the provider computes the snapshot size.
- **`volume_key` existence**: validated with the same `flatten([for k, b in var.block_volumes : [for i in range(1, b.count + 1) : "${k}-${i}"]])` expression the bucket validations use.
- **Snapshot zone**: from-volume snapshots keep `zone != null ? zone : volume.zone`; imported snapshots use `zone`, then `var.zone`, else `null`.
- **Outputs**: four maps (`buckets`, `objects`, `block_volumes`, `block_snapshots`). `block_snapshots[*].export` is the effective `{bucket, key}` (after the `-<n>` insertion), replacing `block_snapshot_exports`; a URL is dropped because the target bucket's region is not known to the module.
- **Kept on purpose**: `count` expansion and its keys (see proposal rejected table), the two snapshot resources, `policy`/`objects` maps.

## Perpetual-diff avoidance

- `project_id`, `region`, `zone` are optional-computed provider arguments; passing `null` keeps the provider value and plans empty.
- `lifecycle_rule.tags` is sent as `null` when empty, never `{}`, so a rule without tags does not diff against a state that holds none. Test: empty second plan for `examples/complete`.
- Tags lists are built with `distinct(concat(...))` from a map iterated in key order, so the order is stable between plans. Object tags `merge(...)` of two empty maps is `{}`, which the provider reads back as unset; verify in the real-account group, fall back to `length(...) > 0 ? ... : null`.
- `size_in_gb` is `null` only with `snapshot_id`; the computed size is not diffed.
- Dropping `depends_on` changes ordering only where a reference already implies it.

## State migration

| Address | Change | Handling |
|---------|--------|----------|
| `scaleway_object_bucket.this[...]`, `_acl`, `_server_side_encryption_configuration`, `_website_configuration`, `_policy`, `scaleway_object.this`, `scaleway_block_volume.this`, `scaleway_block_snapshot.this/imported` | none | in-place tag updates for objects, volumes and snapshots when global `tags` is non-empty |
| `scaleway_object_bucket_lock_configuration.this["<lock key>"]` | key becomes the expanded bucket key (`data-1`) | no module-side `moved` (instance keys cannot be generated); the consumer adds `moved { from = module.<name>.scaleway_object_bucket_lock_configuration.this["<lock key>"] to = module.<name>.scaleway_object_bucket_lock_configuration.this["data-1"] }`, or `tofu state mv`. Without it the old lock configuration is destroyed and the new one created: default retention is removed for the instant between the two calls and objects written then are not locked. The root-level `moved` form into a git-sourced module's instance key was verified on OpenTofu 1.11.6 (task 1.4) |
| `data.scaleway_account_project.project` | removed | data source, no state impact |

If `region` or `zone` is left unset and the provider default differs from the old default (`fr-par`, `fr-par-1`), buckets and volumes are **forced to be replaced**: the README upgrade section opens with this warning and the one-line fix (`region = "fr-par"`).

## Risks / Trade-offs

- [Silent region/zone default change replaces data-bearing resources] -> Upgrade section first item; plan review; commit body states it. Alternative (keep defaults) rejected by the fixed decision.
- [Large output removal] -> One breaking release, field mapping in the README; open question 2 lets the maintainer keep thin maps.
- [Global tags rendered `key:value` on block resources] -> Open question 1; rendering is isolated in one local.
- [Mock provider returns random computed values for `endpoint`] -> Tests assert shape (contains `/index.html`, null `website_endpoint`) with `mock_resource` defaults for `endpoint`, `api_endpoint`, `website_endpoint`.
- [Lock configuration replaced if the consumer skips the move] -> Documented above; plan shows destroy and create.

## Migration plan

1. Consumer sets `project_id`, pins `region`/`zone` to current values, renames `object_lock_enabled`, removes `prevent_destroy`, `organization_id`, `project_name`, adds the lock `moved` blocks, updates output references.
2. `tofu init -upgrade`, plan: expect only in-place tag updates (when `tags` is set) and the lock move; apply; a second plan is empty.
3. Rollback: pin v3.0.0; the lock configuration key changes back (reverse `moved`).

## Open Questions

1. Render global `tags` on volumes and snapshots as `key:value` (proposed), as `key=value`, or leave block resources out of the global tags?
2. Keep the thin maps `bucket_ids`, `bucket_names`, `block_volume_ids` for consumers, or accept the pruned four-output contract (proposed)?
3. Keep `count` expansion (proposed, no state churn) or drop it for plain map keys with consumer-side moves?
