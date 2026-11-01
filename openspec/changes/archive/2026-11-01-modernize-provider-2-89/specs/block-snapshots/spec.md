## ADDED Requirements

### Requirement: Snapshot volume key existence
When set, `volume_key` MUST be an expanded key of `block_volumes` (`<key>-<n>`, n from 1 to `count`).

#### Scenario: Unknown volume key
- **WHEN** volume `db` has `count = 1` and a snapshot sets `volume_key = "db"` or `"db-2"`
- **THEN** the plan is rejected with "volume_key must be an expanded key of var.block_volumes (for example db-1)."

### Requirement: Snapshot tags
Each snapshot SHALL carry its own `tags` (list of strings, default `[]`) followed by the global `tags` rendered `key:value`, without duplicates.

#### Scenario: Global tag on a snapshot
- **WHEN** `tags = { env = "prod" }` and a snapshot sets `tags = ["backup"]`
- **THEN** the snapshot carries `backup` and `env:prod`

## MODIFIED Requirements

### Requirement: Snapshot input shape
The `block_snapshots` input SHALL be a map of objects with optional `name`, `count` (default 1), `volume_key`, `zone` (default null), `tags` (a list of strings, default `[]`), `export` (`bucket`, `key`), `import` (`bucket`, `key`) and `timeouts` (default null, optional `create`, `read`, `update`, `delete` duration strings).

#### Scenario: Empty map
- **WHEN** `block_snapshots` is empty
- **THEN** no snapshot is planned

### Requirement: Snapshot imported from Object Storage
A snapshot without `volume_key` and with `import` SHALL be created from the QCOW2 object `import.key` in bucket `import.bucket`. Its zone is `zone` when set, otherwise the module `zone`, otherwise the provider's default zone, and it depends on the module's buckets.

#### Scenario: Import in default zone
- **WHEN** a snapshot sets `import = { bucket = "backups", key = "db.qcow2" }`, no `volume_key`, and the module `zone` is `fr-par-1`
- **THEN** an imported snapshot is planned in zone `fr-par-1`, reported with `source = "import"` and `volume_id = null`

### Requirement: Snapshot export to Object Storage
When `export` is set, the snapshot SHALL be exported as a QCOW2 file to `export.key` in `export.bucket`. With `count > 1`, `-<n>` is inserted before the `.qcow` or `.qcow2` extension of the key (matched case-insensitively, the extension keeping its case) for each snapshot, so exports do not overwrite one another. The effective `bucket` and `key` are reported in `block_snapshots[*].export`.

#### Scenario: Single export
- **WHEN** a snapshot sets `export = { bucket = "backups", key = "db.qcow2" }` with `count = 1`
- **THEN** `block_snapshots["<key>-1"].export` is `{ bucket = "backups", key = "db.qcow2" }`

#### Scenario: Several exports
- **WHEN** a snapshot with `count = 2` sets `export.key = "db.qcow2"`
- **THEN** the exports use `db-1.qcow2` and `db-2.qcow2`

#### Scenario: Several exports with an uppercase extension
- **WHEN** a snapshot with `count = 2` sets `export.key = "db.QCOW2"`
- **THEN** the exports use `db-1.QCOW2` and `db-2.QCOW2`

### Requirement: Snapshot outputs
Snapshots from volumes and imported snapshots SHALL be merged in `block_snapshots` (with `source` `volume` or `import`), keyed by expanded key.

#### Scenario: Mixed snapshots
- **WHEN** one snapshot is taken from a volume and another is imported
- **THEN** `block_snapshots` contains both keys and reports `source = "volume"` and `source = "import"` respectively
