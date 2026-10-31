## ADDED Requirements

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

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Project lookup
**Reason**: Replaced by the `project_id` input; the module no longer reads `data.scaleway_account_project`.
**Migration**: Pass `project_id = data.scaleway_account_project.<name>.id` or the UUID.

### Requirement: Organization ID validation
**Reason**: `organization_id` is no longer an input; no resource is organization-scoped.
**Migration**: Delete `organization_id` from the module call.

### Requirement: Project name validation
**Reason**: `project_name` is no longer an input.
**Migration**: Delete `project_name`; pass `project_id`.

### Requirement: Project and endpoint outputs
**Reason**: `project_id`, `region` and `s3_endpoint` repeat inputs or values derived from `region`, which can now be `null`.
**Migration**: Use the module's own inputs; read `buckets[*].region` and `buckets[*].api_endpoint`.

### Requirement: Website and lock outputs
**Reason**: Folded into `buckets` (`website_endpoint`, `object_lock_enabled`).
**Migration**: Read `buckets[<key>].website_endpoint`; the lock settings are the module's own `object_lock` input.

### Requirement: Client configuration outputs
**Reason**: `aws_cli_config` and `environment_variables` were command strings built from `region`.
**Migration**: Use `buckets[*].api_endpoint` and the region in the caller's tooling.
