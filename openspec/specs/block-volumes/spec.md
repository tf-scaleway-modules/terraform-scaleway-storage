# block-volumes Specification

## Purpose
Block Storage volumes with count expansion, sizing, IOPS tier and zone.

## Requirements

### Requirement: Volume input shape
The `block_volumes` input SHALL be a map of objects with required `iops` and optional `size_in_gb`, `name`, `count` (default 1), `zone` (default null), `snapshot_id` and `tags` (a list of strings, default `[]`). It has no `prevent_destroy` attribute.

#### Scenario: Minimal volume
- **WHEN** `block_volumes = { db = { size_in_gb = 50, iops = 5000 } }`
- **THEN** one 50 GB, 5000 IOPS volume is planned in the module zone or the provider default zone

### Requirement: Volume count expansion and naming
Each volume SHALL be expanded into `count` volumes keyed `<key>-<n>`. Without `name`, the name is `<key>-volume` (count 1) or `<key>-<n>-volume`; with `name`, it is `<name>` (count 1) or `<name>-<n>`.

#### Scenario: Default name
- **WHEN** volume `db` has no `name` and `count = 1`
- **THEN** it is keyed `db-1` and named `db-volume`

#### Scenario: Several named volumes
- **WHEN** volume `data` has `name = "disk"` and `count = 3`
- **THEN** volumes keyed `data-1`, `data-2`, `data-3` are named `disk-1`, `disk-2`, `disk-3`

### Requirement: Volume from snapshot
When `snapshot_id` is set it SHALL be passed to the volume so that it is created from that snapshot.

#### Scenario: Restore
- **WHEN** a volume sets `snapshot_id`
- **THEN** the planned volume carries that snapshot ID

### Requirement: IOPS validation
`iops` MUST be 5000 or 15000.

#### Scenario: Unsupported tier
- **WHEN** a volume sets `iops = 10000`
- **THEN** the plan is rejected with "Block volume IOPS must be either 5000 or 15000."

### Requirement: Minimum size validation
When set, `size_in_gb` MUST be at least 5.

#### Scenario: Too small
- **WHEN** a volume sets `size_in_gb = 4`
- **THEN** the plan is rejected with "Block volume size must be at least 5 GB."

### Requirement: Zone format validation
When set, a volume `zone` MUST match `xx-xxx-N` (two letters, three letters, one digit).

#### Scenario: Malformed zone
- **WHEN** a volume sets `zone = "paris"`
- **THEN** the plan is rejected with "Zone must be in format: xx-xxx-N (e.g., fr-par-1, nl-ams-1)."

### Requirement: Volume count validation
Every volume `count` MUST be at least 1.

#### Scenario: Zero count
- **WHEN** a volume sets `count = 0`
- **THEN** the plan is rejected with "Block volume count must be at least 1."

### Requirement: Volume outputs
Volumes SHALL be reported in `block_volumes` keyed by expanded key, with `volume_key` the original key and `index` the position.

#### Scenario: Expanded output
- **WHEN** volume `db` has `count = 2`
- **THEN** `block_volumes` has keys `db-1` and `db-2`

### Requirement: Volume size source
`size_in_gb` MUST be set unless `snapshot_id` is set; with `snapshot_id` and no `size_in_gb`, the volume takes the snapshot's size.

#### Scenario: Restore without size
- **WHEN** a volume sets `snapshot_id` and `iops = 5000` and no `size_in_gb`
- **THEN** the volume is planned without a size and the plan succeeds

#### Scenario: No size and no snapshot
- **WHEN** a volume sets neither `size_in_gb` nor `snapshot_id`
- **THEN** the plan is rejected with "Block volume size_in_gb is required unless snapshot_id is set."

### Requirement: Volume zone
A volume SHALL be created in its own `zone` when set, otherwise in the module `zone`, otherwise in the provider's default zone. The input has no default of its own.

#### Scenario: Per-volume zone wins
- **WHEN** `zone = "fr-par-1"` and a volume sets `zone = "fr-par-2"`
- **THEN** the volume is planned in `fr-par-2`

### Requirement: Volume tags
Each volume SHALL carry its own `tags` (list of strings, default `[]`) followed by the global `tags` rendered `key:value`, without duplicates.

#### Scenario: Merged tags
- **WHEN** `tags = { env = "prod" }` and a volume sets `tags = ["db", "env:prod"]`
- **THEN** the volume carries `db` and `env:prod` once each
