# block-snapshots Specification

## Purpose
Block Storage snapshots from a volume or imported from Object Storage, with QCOW2 export.

## Requirements

### Requirement: Snapshot input shape
The `block_snapshots` input SHALL be a map of objects with optional `name`, `count` (default 1), `volume_key`, `zone`, `tags` (a list of strings, default `[]`), `export` (`bucket`, `key`) and `import` (`bucket`, `key`).

#### Scenario: Empty map
- **WHEN** `block_snapshots` is empty
- **THEN** no snapshot is planned

### Requirement: Snapshot count expansion and naming
Each snapshot SHALL be expanded into `count` snapshots keyed `<key>-<n>`. Without `name`, the name is `<key>-snapshot` (count 1) or `<key>-<n>-snapshot`; with `name`, it is `<name>` (count 1) or `<name>-<n>`.

#### Scenario: Default name
- **WHEN** snapshot `backup` has no `name` and `count = 1`
- **THEN** it is keyed `backup-1` and named `backup-snapshot`

### Requirement: Snapshot count validation
Every snapshot `count` MUST be at least 1.

#### Scenario: Zero count
- **WHEN** a snapshot sets `count = 0`
- **THEN** the plan is rejected with "Block snapshot count must be at least 1."

### Requirement: Snapshot from a volume
A snapshot with `volume_key` SHALL be created from the volume whose expanded key (for example `db-1`) equals `volume_key`. Its zone is `zone` when set, otherwise the volume's zone. When `volume_key` is set, any `import` block is ignored.

#### Scenario: Zone inherited
- **WHEN** a snapshot sets `volume_key = "db-1"` and no `zone`
- **THEN** it is created in the zone of volume `db-1`

### Requirement: Snapshot imported from Object Storage
A snapshot without `volume_key` and with `import` SHALL be created from the QCOW2 object `import.key` in bucket `import.bucket`. Its zone is `zone` when set, otherwise `<region>-1`, and it depends on the module's buckets.

#### Scenario: Import in default zone
- **WHEN** a snapshot sets `import = { bucket = "backups", key = "db.qcow2" }`, no `volume_key` and `region` is `fr-par`
- **THEN** an imported snapshot is planned in zone `fr-par-1`, reported with `source = "import"` and `volume_id = null`

### Requirement: Volume key or import
Each snapshot MUST set `volume_key` or `import`.

#### Scenario: Neither set
- **WHEN** a snapshot sets neither
- **THEN** the plan is rejected with "Either volume_key or import block must be specified for each snapshot."

### Requirement: Volume key format
When set, `volume_key` MUST start with a letter and contain only letters, digits, underscores and hyphens.

#### Scenario: Malformed key
- **WHEN** a snapshot sets `volume_key = "1-db"`
- **THEN** the plan is rejected with "Volume key must be a valid identifier (alphanumeric with underscores/hyphens, starting with letter)."

### Requirement: Snapshot export to Object Storage
When `export` is set, the snapshot SHALL be exported as a QCOW2 file to `export.key` in `export.bucket`. With `count > 1`, `-<n>` is inserted before the `.qcow` or `.qcow2` extension of the key (matched case-insensitively, the extension keeping its case) for each snapshot, so exports do not overwrite one another. Exports are reported in `block_snapshot_exports` with a URL `https://<bucket>.s3.<region>.scw.cloud/<key>`.

#### Scenario: Single export
- **WHEN** a snapshot sets `export = { bucket = "backups", key = "db.qcow2" }` with `count = 1`
- **THEN** `block_snapshot_exports` lists `https://backups.s3.fr-par.scw.cloud/db.qcow2` for it

#### Scenario: Several exports
- **WHEN** a snapshot with `count = 2` sets `export.key = "db.qcow2"`
- **THEN** the exports use `db-1.qcow2` and `db-2.qcow2`

#### Scenario: Several exports with an uppercase extension
- **WHEN** a snapshot with `count = 2` sets `export.key = "db.QCOW2"`
- **THEN** the exports use `db-1.QCOW2` and `db-2.QCOW2`

### Requirement: Export key extension
An `export.key` MUST end with `.qcow` or `.qcow2`.

#### Scenario: Wrong extension
- **WHEN** a snapshot sets `export = { bucket = "b", key = "snapshots/db.img" }`
- **THEN** the plan is rejected with "Export key must end with .qcow or .qcow2 extension."

### Requirement: Import key extension
An `import.key` MUST end with `.qcow` or `.qcow2`.

#### Scenario: Wrong extension
- **WHEN** a snapshot sets `import = { bucket = "b", key = "snapshots/db.img" }`
- **THEN** the plan is rejected with "Import key must end with .qcow or .qcow2 extension."

### Requirement: Snapshot outputs
Snapshots from volumes and imported snapshots SHALL be merged in `block_snapshots` (with `source` `volume` or `import`) and `block_snapshot_ids`, keyed by expanded key.

#### Scenario: Mixed snapshots
- **WHEN** one snapshot is taken from a volume and another is imported
- **THEN** `block_snapshot_ids` contains both keys and `block_snapshots` reports `source = "volume"` and `source = "import"` respectively
