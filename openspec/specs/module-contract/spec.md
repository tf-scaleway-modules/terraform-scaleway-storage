# module-contract Specification

## Purpose
Toolchain and provider constraints, shared inputs, project lookup and module outputs.

## Requirements

### Requirement: Toolchain and provider constraints
The module SHALL require OpenTofu/Terraform `>= 1.11.0` and the `scaleway/scaleway` provider `~> 2.86`, and SHALL NOT declare `provider` or `backend` blocks; the caller configures the provider.

#### Scenario: Consumer uses a supported toolchain
- **WHEN** the module is called with OpenTofu 1.11 or later and a scaleway provider in the 2.86 line or later 2.x
- **THEN** initialisation succeeds and the module needs no provider or backend configuration of its own

### Requirement: Project lookup
The module SHALL resolve the target Scaleway project by looking up `project_name` in `organization_id`, and SHALL create every resource in that project. The project MUST already exist.

#### Scenario: Project exists
- **WHEN** `project_name` and `organization_id` identify an existing project
- **THEN** its ID is used as `project_id` on every bucket, object and snapshot resource and as the `project_id` output

### Requirement: Organization ID validation
The `organization_id` input (required, string) SHALL be a lowercase hexadecimal UUID.

#### Scenario: Malformed organization ID
- **WHEN** `organization_id` is `not-a-uuid`
- **THEN** the plan is rejected with "Organization ID must be a valid UUID format."

### Requirement: Project name validation
The `project_name` input (required, string) SHALL be 2-63 characters, lowercase alphanumeric with hyphens, starting with a letter and ending with a letter or digit.

#### Scenario: Name starting with a digit
- **WHEN** `project_name` is `1project`
- **THEN** the plan is rejected with "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 2-63 characters."

### Requirement: Region input
The `region` input (string) SHALL default to `fr-par` and MUST be one of `fr-par`, `nl-ams`, `pl-waw`. It SHALL be used for every Object Storage resource, for the S3 endpoint and for all generated URLs.

#### Scenario: Default region
- **WHEN** `region` is not set
- **THEN** `s3_endpoint` is `https://s3.fr-par.scw.cloud`

#### Scenario: Unsupported region
- **WHEN** `region` is `us-east-1`
- **THEN** the plan is rejected with "Region must be one of: fr-par, nl-ams, pl-waw."

### Requirement: Global tags
The `tags` input (`map(string)`, default `{}`) SHALL be merged with the per-bucket `tags` on every bucket, the per-bucket value winning on a shared key.

#### Scenario: Tag merge
- **WHEN** `tags` is `{ env = "prod" }` and a bucket sets `tags = { env = "dev", team = "a" }`
- **THEN** that bucket carries `env = "dev"` and `team = "a"`

### Requirement: Optional inputs default to empty
The inputs `buckets`, `bucket_policies`, `bucket_lock_configurations`, `objects`, `block_volumes` and `block_snapshots` SHALL each be a map defaulting to `{}` so that the module creates no storage resource until one is configured.

#### Scenario: Only the required inputs set
- **WHEN** only `organization_id` and `project_name` are set
- **THEN** no bucket, object, volume or snapshot is planned and every map output is empty

### Requirement: Project and endpoint outputs
The module SHALL output `project_id` (the looked-up project ID), `region` (the input) and `s3_endpoint` (`https://s3.<region>.scw.cloud`).

#### Scenario: Paris endpoint
- **WHEN** `region` is `fr-par`
- **THEN** `s3_endpoint` is `https://s3.fr-par.scw.cloud`

### Requirement: Bucket outputs
The module SHALL output, keyed by expanded bucket key: `buckets` (id, name, endpoint, api_endpoint, versioning_enabled, object_lock_enabled, tags), `bucket_ids`, `bucket_endpoints` (`https://<name>.s3.<region>.scw.cloud`) and `bucket_arns` (`arn:scw:s3:::<name>`); and `bucket_names` as a list of names.

#### Scenario: One bucket
- **WHEN** bucket `data` named `acme-data` is created in `fr-par`
- **THEN** `bucket_endpoints["data-1"]` is `https://acme-data.s3.fr-par.scw.cloud` and `bucket_arns["data-1"]` is `arn:scw:s3:::acme-data`

### Requirement: Website and lock outputs
The module SHALL output `website_endpoints` (endpoint `https://<bucket>.s3-website.<region>.scw.cloud`, index_document, error_document) and `website_urls` for buckets with a website, and `lock_configurations` (bucket, mode, days, years) for each lock configuration.

#### Scenario: No website configured
- **WHEN** no bucket sets `website`
- **THEN** `website_endpoints` and `website_urls` are empty maps

### Requirement: Object outputs
The module SHALL output `objects` (id, bucket, key, url, content_type, visibility) and `object_urls` (`https://<bucket>.s3.<region>.scw.cloud/<key>`) keyed by the `objects` input key.

#### Scenario: One object
- **WHEN** object `index` with key `index.html` is uploaded to bucket `acme-data`
- **THEN** `object_urls["index"]` is `https://acme-data.s3.fr-par.scw.cloud/index.html`

### Requirement: Client configuration outputs
The module SHALL output `aws_cli_config` (endpoint, region and the two `aws configure set` commands) and `environment_variables` (`AWS_ENDPOINT_URL_S3`, `AWS_REGION`).

#### Scenario: Environment variables
- **WHEN** `region` is `nl-ams`
- **THEN** `environment_variables` is `AWS_ENDPOINT_URL_S3 = https://s3.nl-ams.scw.cloud` and `AWS_REGION = nl-ams`

### Requirement: Block storage outputs
The module SHALL output `block_volumes` (id, name, size_in_gb, iops, zone, volume_key, index), `block_volume_ids`, `block_volume_names` (list), `block_snapshots` (id, name, volume_id, zone, snapshot_key, index, source, export), `block_snapshot_ids` and `block_snapshot_exports` (snapshot_id, bucket, key, url, only for snapshots with an export), all keyed by expanded key.

#### Scenario: No block storage configured
- **WHEN** `block_volumes` and `block_snapshots` are empty
- **THEN** all block storage outputs are empty

### Requirement: No sensitive outputs
No output SHALL be marked sensitive and the module SHALL NOT take credentials as inputs.

#### Scenario: Credentials
- **WHEN** the module is planned
- **THEN** it declares no secret input and exposes only identifiers, names, endpoints and URLs
