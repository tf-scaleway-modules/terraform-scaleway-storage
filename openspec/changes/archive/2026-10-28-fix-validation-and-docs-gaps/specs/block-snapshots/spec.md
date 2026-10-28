## MODIFIED Requirements

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
