# Minimal Example — Scaleway Storage

Smallest viable use of the module: a single private Object Storage bucket in `fr-par`, all other settings default.

Use this as a starting point when you only need a bucket and want to validate the module wiring (auth, project, naming) before layering on lifecycle, website, or block storage configuration.

## What it creates

- 1 × `scaleway_object_bucket` (`<prefix>-data-bucket`, private, versioning off)

## Usage

```bash
export SCW_ACCESS_KEY=...
export SCW_SECRET_KEY=...

export TF_VAR_project_id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   # optional: omit for the provider default project

terraform init
terraform plan
terraform apply
```

`prefix` defaults to `example` — override with `TF_VAR_prefix` if the bucket name collides (bucket names are globally unique across all Scaleway users).

## Inputs

| Name              | Description                                                       | Required |
| ----------------- | ----------------------------------------------------------------- | :------: |
| `project_id`      | Scaleway project ID (UUID); `null` uses the provider default      |    no    |
| `prefix`          | Prefix for the bucket name (default: `example`)                   |    no    |

## Outputs

| Name              | Description                                                       |
| ----------------- | ----------------------------------------------------------------- |
| `bucket_name`     | The created bucket name                                           |
| `bucket_endpoint` | S3 endpoint for the bucket, as reported by the provider           |
| `s3_endpoint`     | Region-level S3 API endpoint for CLI/SDK use                      |

## Cleanup

```bash
terraform destroy
```
