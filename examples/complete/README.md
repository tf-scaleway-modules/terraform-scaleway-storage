# Complete Example — Scaleway Storage

Exercises every feature of the module across both Object Storage and Block Storage. Use it as a reference when you need to see how all configuration knobs fit together — and as the integration target that CI runs `terraform validate` against.

## What it creates

### Object Storage (4 buckets)

| Key       | ACL           | Features                                                                       |
| --------- | ------------- | ------------------------------------------------------------------------------ |
| `data`    | private       | Versioning + multipart cleanup lifecycle rule                                  |
| `assets`  | public-read   | CORS for browser access                                                        |
| `logs`    | private       | Versioning + lifecycle (30d → GLACIER, 365d → expire)                          |
| `website` | public-read   | Static website hosting + CORS, with `index.html`/`404.html`/`robots.txt` upload |

### Block Storage (4 volumes, 3 snapshots)

| Key        | Count | IOPS   | Size   | Notes                                                  |
| ---------- | :---: | -----: | -----: | ------------------------------------------------------ |
| `database` |   1   | 15 000 | 100 GB | High-performance tier (DB workload)                    |
| `app`      |   2   |  5 000 |  50 GB | `count=2` → `app-1`, `app-2`                           |
| `logs`     |   1   |  5 000 |  20 GB | Standard performance                                   |

| Snapshot key      | Count | Source         | Export                                          |
| ----------------- | :---: | -------------- | ----------------------------------------------- |
| `database_backup` |   1   | `database-1`   | `<prefix>-data-<env>/snapshots/database-backup.qcow2` |
| `app_backup`      |   2   | `app-1`        | `snapshots/app-backup-{1,2}.qcow2` (auto-suffixed)    |

## Usage

```bash
export SCW_ACCESS_KEY=...
export SCW_SECRET_KEY=...

export TF_VAR_organization_id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export TF_VAR_project_name=my-project
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
| `organization_id` | Scaleway Organization ID (UUID)                              | required    |
| `project_name`    | Scaleway project name                                        | required    |
| `prefix`          | Prefix for resource names (must be globally unique)          | `example`   |
| `environment`     | Environment label, also gates `force_destroy`/`prevent_destroy` | `dev`     |

## Notable outputs

- `bucket_endpoints` — S3 endpoint per bucket
- `website_url` — Static website URL
- `block_volumes` — Map of all volumes with expanded keys
- `block_snapshot_exports` — QCOW2 URLs for offsite backups
- `aws_cli_commands` — Ready-to-paste `aws configure` commands for Scaleway

## Cleanup

```bash
terraform destroy
```

If `environment = production` the buckets won't auto-empty — clean them out first or temporarily flip `environment` to `dev`.
