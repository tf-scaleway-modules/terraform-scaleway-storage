# Complete Example — Scaleway Storage

Exercises every feature of the module across both Object Storage and Block Storage. Use it as a reference when you need to see how all configuration knobs fit together — and as the integration target that CI runs `terraform validate` against.

## What it creates

### Object Storage (14 buckets)

| Key       | Count |  ACL          | Features                                                                       |
| --------- | :---: | ------------- | ------------------------------------------------------------------------------ |
| `data`    |  10   | private       | Versioning + multipart cleanup lifecycle rule (`data-1` … `data-10`)           |
| `assets`  |   1   | public-read   | CORS for browser access                                                        |
| `logs`    |   1   | private       | Versioning + lifecycle (30d → GLACIER, 365d → expire; `tier=temp` objects after 7d via a tag filter)                          |
| `audit`   |   1   | private       | Object lock (WORM): GOVERNANCE default retention of 1 day, versioning forced on |
| `website` |   1   | public-read   | Static website hosting + CORS, with `index.html`/`404.html`/`robots.txt` upload |

`count > 1` produces expanded keys `data-1` … `data-N` and suffixes the bucket name (`<prefix>-data-<env>-1` … `-10`). Snapshot exports target `data-1`.

### Block Storage (4 volumes, 3 snapshots; a fifth volume with `restore_snapshot_id`)

| Key        | Count | IOPS   | Size   | Notes                                                  |
| ---------- | :---: | -----: | -----: | ------------------------------------------------------ |
| `database` |   1   | 15 000 | 100 GB | High-performance tier (DB workload)                    |
| `app`      |   2   |  5 000 |  50 GB | `count=2` → `app-1`, `app-2`                           |
| `logs`     |   1   |  5 000 |  20 GB | Standard performance, `zone = "fr-par-2"` overrides the module zone |
| `restored` |   1   |  5 000 | snapshot | Only with `restore_snapshot_id`; `size_in_gb` omitted, taken from the snapshot |

The module sets `zone = "fr-par-1"`, so the other volumes need no `zone`. The global `tags` also reach the objects, volumes (as `key:value`) and snapshots.

| Snapshot key      | Count | Source         | Export                                          |
| ----------------- | :---: | -------------- | ----------------------------------------------- |
| `database_backup` |   1   | `database-1`   | `<prefix>-data-<env>/snapshots/database-backup.qcow2` (`timeouts.create = "30m"`) |
| `app_backup`      |   2   | `app-1`        | `snapshots/app-backup-{1,2}.qcow2` (auto-suffixed)    |

## Usage

```bash
export SCW_ACCESS_KEY=...
export SCW_SECRET_KEY=...

export TF_VAR_project_id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   # optional: omit for the provider default project
# export TF_VAR_restore_snapshot_id=fr-par-1/<snapshot-uuid>    # optional: adds the restored volume
export TF_VAR_environment=dev      # dev | staging | production
export TF_VAR_prefix=acme          # used in all bucket/volume names

terraform init
terraform plan
terraform apply
```

When `environment != "production"`, `force_destroy = true` so `terraform destroy` works without manually emptying buckets first.

## Inputs

| Name              | Description                                                  | Default     |
| ----------------- | ------------------------------------------------------------ | ----------- |
| `project_id`      | Scaleway project ID (UUID); `null` uses the provider default | `null`      |
| `restore_snapshot_id` | Snapshot to restore into an extra volume (size from the snapshot) | `null` |
| `prefix`          | Prefix for resource names (must be globally unique)          | `example`   |
| `environment`     | Environment label, also gates `force_destroy` | `dev`     |

## Notable outputs

- `buckets` — All buckets with the endpoints the provider reports
- `website_endpoint` — Static website endpoint
- `block_volumes` — Map of all volumes with expanded keys
- `database_volume_srn`, `database_backup_srn` — Scaleway Resource Names of the database volume and its snapshot
- `block_snapshots` — All snapshots, with the effective export `bucket` and `key` of each QCOW2 file

## Cleanup

```bash
terraform destroy
```

If `environment = production` the buckets won't auto-empty — clean them out first or temporarily flip `environment` to `dev`.

The `audit` bucket holds objects under a GOVERNANCE retention: objects written there cannot be deleted until the retention ends (1 day), so `destroy` can fail until then.
