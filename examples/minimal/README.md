# Minimal Example — Scaleway Storage

Smallest viable use of the module: a single private Object Storage bucket in `fr-par`, all other settings default.

Use this as a starting point when you only need a bucket and want to validate the module wiring (auth, project lookup, naming) before layering on lifecycle, website, or block storage configuration.

## What it creates

- 1 × `scaleway_object_bucket` (`<prefix>-data-bucket`, private, versioning off)

## Usage

```bash
export SCW_ACCESS_KEY=...
export SCW_SECRET_KEY=...

export TF_VAR_organization_id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export TF_VAR_project_name=my-project

terraform init
terraform plan
terraform apply
```

`prefix` defaults to `example` — override with `TF_VAR_prefix` if the bucket name collides (bucket names are globally unique across all Scaleway users).

## Inputs

| Name              | Description                                                       | Required |
| ----------------- | ----------------------------------------------------------------- | :------: |
| `organization_id` | Scaleway Organization ID (UUID)                                   |   yes    |
| `project_name`    | Scaleway project where the bucket is created                      |   yes    |
| `prefix`          | Prefix for the bucket name (default: `example`)                   |    no    |

## Outputs

| Name              | Description                                                       |
| ----------------- | ----------------------------------------------------------------- |
| `bucket_name`     | The created bucket name                                           |
| `bucket_endpoint` | S3 endpoint for the bucket                                        |
| `s3_endpoint`     | Region-level S3 API endpoint for CLI/SDK use                      |
| `bucket_arn`      | ARN-style identifier for use in bucket policies                   |

## Cleanup

```bash
terraform destroy
```
