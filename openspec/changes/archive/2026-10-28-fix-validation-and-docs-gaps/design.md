## Context

Issues found while baselining the released contract. Constraint: nothing breaking unless a security problem has no alternative (`terraform-versioning`); no provider behaviour is assumed.

## Decisions

- **prevent_destroy (1)**: `lifecycle.prevent_destroy` only accepts a literal, so the module cannot honour a per-volume value. Removing the input is major; leaving it silent is a weakened control (`quality-security`). A top-level `check "block_volume_prevent_destroy_not_enforced"` (`block-storage.tf`) warns naming the volumes that set `true`; guardrail per `terraform-testing` ("dangerous but legal configurations ... `check`"). Descriptions, README and `SECURITY.md` say the input is not enforced and point to plan review and least-privilege credentials as the protection. The hard-coded `prevent_destroy = false` stays (a literal `true` would block destroy for every consumer). `locals.tf` no longer copies the unused attribute. Resource addresses and arguments are unchanged: no perpetual diff, no state migration.
- **Case-insensitive suffix (2)**: `replace(key, "/(?i)(\\.qcow2?)$/", "-${i}$1")` (RE2 inline flag). The captured extension keeps its original case. Lowercase keys produce the same string as before: no diff for existing exports.
- **Key validation (3)**: validations on `bucket_policies`, `bucket_lock_configurations` and `objects` compare `bucket_key` with `flatten([for k, b in var.buckets : [for i in range(1, b.count + 1) : "${k}-${i}"]])`. Variable validations may reference other variables (OpenTofu/Terraform >= 1.9, floor is 1.11). A count below 1 already fails the `buckets` validation and yields no keys. The message lists the rule, not the keys, and names expanded keys (`data-1`).
- **Name length (5)**: `count == 1 || length(name) + 1 + length(tostring(count)) <= 63`; the widest suffix is the one of `count` itself.
- **Zone and tags (4, 6)**: documentation only, see proposal.

## Risks

Configs with a dangling `bucket_key` or a name over 63 characters already failed at plan or apply; they now fail earlier with a message. No config that applied before is rejected.
