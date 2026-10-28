## Context

See proposal.md for motivation and the deferred list. Constraints: the caller configures the provider; no secret input is added; OpenTofu >= 1.11; tests use `mock_provider "scaleway"` with no credentials.

## Resources and arguments used

| Resource | Argument / attribute | Introduced in | Notes |
|----------|----------------------|---------------|-------|
| `scaleway_block_snapshot` (`this`, `imported`) | `timeouts` (`create`, `read`, `update`, `delete`, default 5m each) | **2.88.0** | Drives the floor raise. Since 2.87.0 the resource uses the plugin framework, so `timeouts` is an **attribute** (`timeouts = { create = "10m" }`), not a `timeouts {}` block. `import` and `export` remain nested blocks (verified in `internal/services/block/snapshot.go` at v2.89.0: `ListNestedBlock`), so the existing `import {}` and `dynamic "export"` stay unchanged |
| `scaleway_block_snapshot`, `scaleway_block_volume` | `srn` (computed) | present in the 2.86.0 docs | Output only |
| `scaleway_object` | `hash`, `storage_class`, `metadata` | present in the 2.86.0 docs (docs are identical in 2.86.0 and 2.89.0) | `hash` is what makes the provider re-upload when `file` changes; `storage_class` is validated by the provider against `STANDARD`, `GLACIER`, `ONEZONE_IA`; `metadata` keys must be lowercase |
| `scaleway_object_bucket` | `lifecycle_rule.transition.storage_class`, `noncurrent_version_transition.storage_class` | unchanged | Same provider enum as above; only the module validation changes |

Provider constraint becomes `~> 2.89`. 2.88.0 is the technical minimum; 2.89.0 is taken so consumers also get the object region-first fix.

## Decisions

- **Timeouts shape**: `timeouts = optional(object({ create = optional(string), read = optional(string), update = optional(string), delete = optional(string) }))` on the `block_snapshots` entry, default `null`. The same value feeds both resources: `timeouts = each.value.timeouts`. A `null` attribute leaves the provider default; members left null mean the same. Alternative considered: a module-wide `block_snapshot_timeouts` input; rejected because export duration depends on the volume size, which is per entry (`quality-simplicity`: the smallest input that solves the case). Alternative: a `timeouts {}` block via `dynamic`; rejected, it would not validate against a framework attribute.
- **Validation**: one `validation` on `block_snapshots` with `can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", t))` for each non-null member (`terraform-variables`: validate the boundary, error message names the accepted form). The provider would otherwise fail at apply on a malformed duration.
- **Object pass-through**: `hash = each.value.hash`, `storage_class = each.value.storage_class`, `metadata = each.value.metadata`; all `optional(...)` with a `null` default meaning "provider default" (`terraform-variables`: no invented default). `hash` is opt-in; computing `filemd5(source)` inside the module was rejected because it would fail at plan when the file does not exist yet and would change existing objects without a caller decision. Validations: `storage_class` in `STANDARD`, `GLACIER`, `ONEZONE_IA` when set; `metadata` keys equal to `lower(key)`.
- **Storage class alignment**: the bucket validation list `["GLACIER", "ONEZONE_IA", "STANDARD_IA"]` becomes `["STANDARD", "GLACIER", "ONEZONE_IA"]` and its message and the `buckets` description follow. `STANDARD_IA` was never valid for the provider.
- **Outputs**: add `srn = v.srn` to the `block_volumes` and `block_snapshots` objects (for imported snapshots too). New keys in an existing object output are a documented minor-level addition (`terraform-outputs`, `terraform-versioning`). `outputs.tf` descriptions list the key.
- **No other module change**: provider fixes 2.83.0 to 2.89.0 act inside the provider.

## Perpetual diff and state migration

- **Timeouts**: `null` when unset, so a configuration that does not use it plans exactly as before. Set values are written to state as given and compared as given; the framework timeouts attribute has no plan modifier that replaces the resource, so adding or changing `timeouts` is an **in-place update** with no API call (provider-side only). Existing state from provider 2.86/2.87 is upgraded by the provider (the 2.87.0 migration to the framework handles its own state upgrade); the module does not need `moved` blocks since no address changes.
- **Objects**: `hash`, `storage_class`, `metadata` default to `null`; the provider treats them as optional and unset, so existing objects show no diff. Setting `hash` on an existing object is an in-place update (re-upload) once; later plans are empty while the file is unchanged. Setting `storage_class` or `metadata` is an in-place update.
- **Outputs**: `srn` is a computed attribute known after apply; outputs are not in any resource diff.
- **Provider fixes** (2.83.0 lifecycle expiration unset when empty, 2.85.0 `expired_object_delete_marker` ignored when false, 2.86.0 auto-populated s3 endpoint) remove diffs for module inputs already supported. Task 4.2 confirms an empty second plan for `examples/complete`.
- No resource is replaced, no `moved` block is needed, `terraform-state` has nothing to migrate.

## Risks / Trade-offs

- [Major bump for one optional attribute] -> Called out in proposal.md with the minor alternative (drop item 1, keep `~> 2.86`); decision belongs to the maintainers before apply.
- [`timeouts` framework attribute with mock provider] -> `mock_provider` generates computed values only; the tests assert on the planned `timeouts` of the resource (`scaleway_block_snapshot.this[...]`), which is configuration, so no mock data is needed. If the mock rejects the object, add `mock_resource "scaleway_block_snapshot"` defaults (id, srn).
- [Consumers pinned to 2.86/2.87] -> README upgrade note: run `init -upgrade` and review the lock file.
- [Rejecting `STANDARD_IA`] -> Only affects configurations the provider already refused; stated in the upgrade note.

## Migration Plan

1. Consumers: bump the module tag, run `tofu init -upgrade` so the lock file moves to >= 2.89, plan; expect no diff unless they adopt new inputs.
2. Rollback: pin the previous module tag and provider; no state is rewritten by the module (provider-level state upgrades from 2.87 are not reversible, which is already true for any consumer on 2.87+).

## Open Questions

None blocking. Whether to ship the floor raise as a major release or defer item 1 and ship a minor is the maintainers' call at review; the tasks below assume major.
