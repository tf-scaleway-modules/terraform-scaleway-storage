## MODIFIED Requirements

### Requirement: Volume input shape
The `block_volumes` input SHALL be a map of objects with required `size_in_gb` and `iops`, and optional `name`, `count` (default 1), `zone` (default `fr-par-1`), `snapshot_id`, `prevent_destroy` (default `false`) and `tags` (a list of strings, default `[]`). The zone default does not depend on `region`.

#### Scenario: Minimal volume
- **WHEN** `block_volumes = { db = { size_in_gb = 50, iops = 5000 } }`
- **THEN** one 50 GB, 5000 IOPS volume is planned in zone `fr-par-1` in the project

## ADDED Requirements

### Requirement: Prevent destroy is not enforced
The volume `prevent_destroy` input SHALL be accepted but not enforced, because the module cannot set a per-volume `lifecycle.prevent_destroy`, so the volume resource never blocks destruction. Volume `tags` SHALL be passed as given and are not merged with the global `tags`.

#### Scenario: Volume destroyed
- **WHEN** a volume sets `prevent_destroy = true` and is removed from the configuration
- **THEN** the plan still destroys it, after the warning described in "Prevent destroy warning"

### Requirement: Prevent destroy warning
A `check` SHALL warn at plan time when any volume sets `prevent_destroy = true`, naming those volumes and stating that the setting is not enforced. It SHALL NOT warn when no volume sets it.

#### Scenario: prevent_destroy requested
- **WHEN** volume `db` sets `prevent_destroy = true`
- **THEN** the plan succeeds and a warning states that `prevent_destroy` is not enforced for `db`

#### Scenario: Default
- **WHEN** no volume sets `prevent_destroy = true`
- **THEN** no warning is emitted
