# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Block Storage Support**: Added Scaleway Block Storage resources
  - `block_volumes` variable for creating network-attached SSD volumes
  - `block_snapshots` variable for point-in-time volume snapshots
  - `scaleway_block_volume` resource with IOPS tiers (5000/15000)
  - `scaleway_block_snapshot` resource for backups and cloning
  - Volume size validation (5 GB - 10 TB)
  - Zone format validation
  - New outputs: `block_volumes`, `block_volume_ids`, `block_volume_names`, `block_snapshots`, `block_snapshot_ids`
- **Block Storage Count**: Added `count` parameter for block volumes and snapshots
  - Create multiple identical volumes with `count = N`
  - Expanded keys: `database` with `count=3` → `database-1`, `database-2`, `database-3`
  - Snapshot `volume_key` must reference expanded volume key (e.g., `database-1`)
- **Block Storage Lifecycle**: Added `prevent_destroy` parameter to document intent
  - Note: Terraform requires literal values for lifecycle blocks
  - Parameter serves as documentation; manual code change needed for production
- **Snapshot Export to Object Storage**: Export snapshots as QCOW2 files
  - `export` block with `bucket` and `key` parameters
  - Automatic key suffix for count > 1 (e.g., `backup.qcow2` → `backup-1.qcow2`)
  - New output: `block_snapshot_exports` with export URLs
- **Snapshot Import from Object Storage**: Create snapshots from QCOW2 files
  - `import` block with `bucket` and `key` parameters
  - Alternative to `volume_key` for disaster recovery scenarios
  - Validation ensures `.qcow` or `.qcow2` extension

### Changed
- Renamed module from "Object Storage" to "Storage" to reflect broader scope
- Updated README with Block Storage documentation and examples
- Updated architecture diagram to include Block Storage
- Block storage resources now use expanded locals (`local.expanded_block_volumes`, `local.expanded_block_snapshots`)
- Block storage outputs now include `volume_key`/`snapshot_key` and `index` fields

## [1.0.0] - 2025-12-21

### Added
- Initial release with Object Storage support
- Bucket creation with versioning, lifecycle rules, and CORS
- Bucket ACL configurations (private, public-read, authenticated-read)
- Static website hosting configuration
- Object Lock (WORM) for compliance requirements
- Bucket policies for fine-grained access control
- Object uploads (file and inline content)
- Bucket count feature for creating multiple instances
- Input validations for security (blocked public-read-write ACL)

### Security
- Blocked `public-read-write` ACL for security
- Documented Scaleway policy version (2023-04-17)
- Added security best practices in README


