# module-contract Specification

## Purpose
Toolchain and provider constraints, shared inputs, project lookup and module outputs.

## Requirements

### Requirement: Toolchain and provider constraints
The module SHALL require OpenTofu/Terraform `>= 1.11.0` and the `scaleway/scaleway` provider `~> 2.89`, and SHALL NOT declare `provider` or `backend` blocks; the caller configures the provider. Both OpenTofu and Terraform SHALL accept the module at that floor; the single `required_version` constraint serves both and no OpenTofu-only construct is used.

#### Scenario: Consumer uses a supported toolchain
- **WHEN** the module is called with OpenTofu 1.11 or later and a scaleway provider in the 2.89 line or later 2.x
- **THEN** initialisation succeeds and the module needs no provider or backend configuration of its own

#### Scenario: Provider older than the floor
- **WHEN** the consumer's lock file holds scaleway provider 2.87
- **THEN** `init` reports that the locked version does not satisfy `~> 2.89` until the lock is upgraded

#### Scenario: Terraform consumer
- **WHEN** the module and each example under `examples/` are initialised with `terraform init -backend=false` and checked with `terraform validate` on Terraform 1.11.0 or later
- **THEN** validation succeeds, exactly as with OpenTofu

### Requirement: Region input
The `region` input (string, default `null`) SHALL, when set, be one of `fr-par`, `nl-ams`, `pl-waw` and be used for every Object Storage resource. When `null`, the provider's default region is used. No URL SHALL be derived from the input; outputs report what the provider returns.

#### Scenario: Region set
- **WHEN** `region` is `nl-ams`
- **THEN** every bucket is planned in `nl-ams`

#### Scenario: Default region
- **WHEN** `region` is not set
- **THEN** no Object Storage resource sets a region

#### Scenario: Unsupported region
- **WHEN** `region` is `us-east-1`
- **THEN** the plan is rejected with "Region must be one of: fr-par, nl-ams, pl-waw."

### Requirement: Global tags
The `tags` input (`map(string)`, default `{}`) SHALL be merged into the tags of every bucket and object (the per-item value winning on a shared key) and added, as `key:value` strings merged distinct with the per-item list, to every volume and snapshot.

#### Scenario: Tag merge
- **WHEN** `tags` is `{ env = "prod" }` and a bucket sets `tags = { env = "dev", team = "a" }`
- **THEN** that bucket carries `env = "dev"` and `team = "a"`

#### Scenario: Block storage tags
- **WHEN** `tags` is `{ env = "prod" }` and a volume sets `tags = ["db"]`
- **THEN** the volume carries `db` and `env:prod`

### Requirement: Optional inputs default to empty
The inputs `buckets`, `bucket_policies`, `objects`, `block_volumes` and `block_snapshots` SHALL each be a map defaulting to `{}` and the module SHALL have no required input, so that it creates no storage resource until one is configured.

#### Scenario: Only the required inputs set
- **WHEN** the module is called without arguments
- **THEN** no bucket, object, volume or snapshot is planned and every output is an empty map

### Requirement: Bucket outputs
The module SHALL output `buckets`, keyed by expanded bucket key, with id, name, region, endpoint, api_endpoint (the last three reported by the provider), versioning_enabled, object_lock_enabled, website_endpoint (null without a website) and tags. It SHALL NOT output separate id, name, endpoint, ARN, website or lock maps.

#### Scenario: One bucket
- **WHEN** bucket `data` named `acme-data` is created in `fr-par`
- **THEN** `buckets["data-1"]` reports its id, name `acme-data`, the provider's endpoints and `website_endpoint = null`

#### Scenario: Website bucket
- **WHEN** a bucket sets `website`
- **THEN** its `website_endpoint` is the endpoint reported by the website configuration

### Requirement: Object outputs
The module SHALL output `objects`, keyed by the `objects` input key, with id, bucket, key, url (the bucket's provider endpoint followed by `/<key>`), content_type and visibility.

#### Scenario: One object
- **WHEN** object `index` with key `index.html` is uploaded to bucket `acme-data`
- **THEN** `objects["index"].url` is the endpoint of `acme-data` followed by `/index.html`

### Requirement: Block storage outputs
The module SHALL output `block_volumes` (id, srn, name, size_in_gb, iops, zone, volume_key, index) and `block_snapshots` (id, srn, name, volume_id, zone, snapshot_key, index, source, export with bucket and key), keyed by expanded key. It SHALL NOT output separate id, name or export maps.

#### Scenario: No block storage configured
- **WHEN** `block_volumes` and `block_snapshots` are empty
- **THEN** both outputs are empty

#### Scenario: Resource names in outputs
- **WHEN** volume `db` and a snapshot of it are created
- **THEN** `block_volumes["db-1"].srn` and `block_snapshots["backup-1"].srn` carry the Scaleway Resource Name reported by the provider

### Requirement: No sensitive outputs
No output SHALL be marked sensitive and the module SHALL NOT take credentials as inputs.

#### Scenario: Credentials
- **WHEN** the module is planned
- **THEN** it declares no secret input and exposes only identifiers, names, endpoints and URLs

### Requirement: Project input
The `project_id` input (string, default `null`) SHALL select the Scaleway project of every resource. When `null`, the provider's default project is used. The module SHALL NOT look a project up by name.

#### Scenario: Explicit project
- **WHEN** `project_id` is `11111111-1111-1111-1111-111111111111`
- **THEN** every bucket, object, volume and snapshot resource is planned with that project ID

#### Scenario: Provider default project
- **WHEN** `project_id` is not set
- **THEN** no resource sets a project ID and the module declares no data source

### Requirement: Project ID validation
When set, `project_id` MUST be a lowercase hexadecimal UUID.

#### Scenario: Malformed project ID
- **WHEN** `project_id` is `my-project`
- **THEN** the plan is rejected with "Project ID must be a valid UUID."

### Requirement: Zone input
The `zone` input (string, default `null`) SHALL be the default zone of volumes and imported snapshots that set no `zone`. When `null`, the provider's default zone is used. When set it MUST match `xx-xxx-N`.

#### Scenario: Module-wide zone
- **WHEN** `zone = "nl-ams-1"` and a volume sets no `zone`
- **THEN** the volume is planned in `nl-ams-1`

#### Scenario: Malformed zone
- **WHEN** `zone = "paris"`
- **THEN** the plan is rejected with "Zone must be in format: xx-xxx-N (e.g., fr-par-1, nl-ams-1)."
