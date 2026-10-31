## MODIFIED Requirements

### Requirement: Toolchain and provider constraints
The module SHALL require OpenTofu/Terraform `>= 1.11.0` and the `scaleway/scaleway` provider `~> 2.89`, and SHALL NOT declare `provider` or `backend` blocks; the caller configures the provider.

#### Scenario: Consumer uses a supported toolchain
- **WHEN** the module is called with OpenTofu 1.11 or later and a scaleway provider in the 2.89 line or later 2.x
- **THEN** initialisation succeeds and the module needs no provider or backend configuration of its own

#### Scenario: Provider older than the floor
- **WHEN** the consumer's lock file holds scaleway provider 2.87
- **THEN** `init` reports that the locked version does not satisfy `~> 2.89` until the lock is upgraded

### Requirement: Block storage outputs
The module SHALL output `block_volumes` (id, srn, name, size_in_gb, iops, zone, volume_key, index), `block_volume_ids`, `block_volume_names` (list), `block_snapshots` (id, srn, name, volume_id, zone, snapshot_key, index, source, export), `block_snapshot_ids` and `block_snapshot_exports` (snapshot_id, bucket, key, url, only for snapshots with an export), all keyed by expanded key.

#### Scenario: No block storage configured
- **WHEN** `block_volumes` and `block_snapshots` are empty
- **THEN** all block storage outputs are empty

#### Scenario: Resource names in outputs
- **WHEN** volume `db` and a snapshot of it are created
- **THEN** `block_volumes["db-1"].srn` and `block_snapshots["backup-1"].srn` carry the Scaleway Resource Name reported by the provider
