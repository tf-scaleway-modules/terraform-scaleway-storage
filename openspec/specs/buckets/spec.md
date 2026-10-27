# buckets Specification

## Purpose
Object Storage buckets: count expansion, ACL, versioning, encryption, lifecycle, CORS and website hosting.

## Requirements

### Requirement: Bucket input shape
The `buckets` input SHALL be a map of objects keyed by a logical key, with required `name` and optional `count` (default 1), `acl` (`private`), `force_destroy` (`false`), `object_lock_enabled` (`false`), `versioning` (`false`), `tags` (`{}`), `server_side_encryption` (null), `cors_rules` (`[]`), `lifecycle_rules` (`[]`) and `website` (null).

#### Scenario: Minimal bucket
- **WHEN** `buckets = { data = { name = "acme-data" } }`
- **THEN** one private, unversioned bucket named `acme-data` is planned in `var.region` and the project, without `force_destroy`

### Requirement: Count expansion
Each bucket SHALL be expanded into `count` buckets keyed `<key>-<n>` for n from 1 to `count`. With `count = 1` the name is unchanged; with `count > 1` the name is `<name>-<n>`.

#### Scenario: Single bucket
- **WHEN** bucket `data` has `name = "acme-data"` and the default count
- **THEN** one bucket keyed `data-1` is planned and named `acme-data`

#### Scenario: Three buckets
- **WHEN** bucket `logs` has `name = "acme-logs"` and `count = 3`
- **THEN** buckets keyed `logs-1`, `logs-2`, `logs-3` are planned, named `acme-logs-1`, `acme-logs-2`, `acme-logs-3`

### Requirement: Count validation
Every bucket `count` MUST be at least 1.

#### Scenario: Zero count
- **WHEN** a bucket sets `count = 0`
- **THEN** the plan is rejected with "Bucket count must be at least 1."

### Requirement: Bucket name validation
Every bucket `name` MUST be 3-63 characters of lowercase letters, digits, dots and hyphens, starting and ending with a letter or digit. The check applies to the given name, before any count suffix.

#### Scenario: Uppercase name
- **WHEN** a bucket has `name = "Invalid_Bucket"`
- **THEN** the plan is rejected with "Bucket name must be 3-63 characters, lowercase alphanumeric with hyphens and dots, start/end with alphanumeric."

### Requirement: ACL
The `acl` of a bucket MUST be `private`, `public-read` or `authenticated-read`. A `scaleway_object_bucket_acl` SHALL be created only for buckets whose ACL is not `private`.

#### Scenario: Public read bucket
- **WHEN** a bucket sets `acl = "public-read"`
- **THEN** an ACL resource with `public-read` is planned for it

#### Scenario: Private bucket
- **WHEN** a bucket keeps the default `acl`
- **THEN** no ACL resource is planned for it

#### Scenario: Public write ACL
- **WHEN** a bucket sets `acl = "public-read-write"`
- **THEN** the plan is rejected with an error stating that ACL must be one of private, public-read, authenticated-read

### Requirement: Versioning and object lock
Versioning SHALL be enabled when `versioning` or `object_lock_enabled` is true, so that object lock always implies versioning. The bucket output SHALL report `versioning_enabled` and `object_lock_enabled`.

#### Scenario: Object lock forces versioning
- **WHEN** a bucket sets `object_lock_enabled = true` and `versioning = false`
- **THEN** versioning is enabled on the bucket

### Requirement: Default server-side encryption
When `server_side_encryption` is set, a default encryption configuration SHALL be created for the bucket with `sse_algorithm` (default `AES256`), `kms_master_key_id` and `bucket_key_enabled`. `sse_algorithm` MUST be `AES256` or `aws:kms`, and `kms_master_key_id` MUST be set with `aws:kms` and only with it.

#### Scenario: SSE-S3
- **WHEN** a bucket sets `server_side_encryption = {}`
- **THEN** a default encryption configuration with `AES256` and no key is planned

#### Scenario: SSE-KMS
- **WHEN** a bucket sets `sse_algorithm = "aws:kms"` and a `kms_master_key_id`
- **THEN** a default encryption configuration with that algorithm and key is planned

#### Scenario: KMS without key
- **WHEN** a bucket sets `sse_algorithm = "aws:kms"` without `kms_master_key_id`
- **THEN** the plan is rejected with "server_side_encryption.sse_algorithm must be AES256 or aws:kms, and kms_master_key_id must be set with aws:kms only."

#### Scenario: Key with AES256
- **WHEN** a bucket sets `sse_algorithm = "AES256"` and a `kms_master_key_id`
- **THEN** the plan is rejected with the same message

#### Scenario: Unknown algorithm
- **WHEN** a bucket sets `sse_algorithm = "AES128"`
- **THEN** the plan is rejected with the same message

### Requirement: Lifecycle rules
Each entry of `lifecycle_rules` SHALL produce a lifecycle rule on the bucket, built from `id`, `enabled` (default true), `prefix` (default empty), the size filters, `expiration`, `transition`, the noncurrent-version expiration and transition, and `abort_incomplete_multipart_upload`.

#### Scenario: Expiration and multipart cleanup
- **WHEN** a rule sets `expiration = { days = 30 }` and `abort_incomplete_multipart_upload = { days_after_initiation = 7 }`
- **THEN** the bucket gets a rule expiring objects after 30 days and aborting incomplete multipart uploads after 7 days

#### Scenario: Noncurrent version rules
- **WHEN** a rule sets `noncurrent_version_expiration = { noncurrent_days = 90, newer_noncurrent_versions = 3 }`
- **THEN** the rule carries both values

### Requirement: Lifecycle storage class validation
Every `storage_class` in `transition` and `noncurrent_version_transition` MUST be `GLACIER`, `ONEZONE_IA` or `STANDARD_IA`.

#### Scenario: Unsupported class
- **WHEN** a transition sets `storage_class = "DEEP_ARCHIVE"`
- **THEN** the plan is rejected with "Storage class must be one of: GLACIER, ONEZONE_IA, STANDARD_IA."

### Requirement: CORS rules
Each entry of `cors_rules` SHALL produce a CORS rule with `allowed_headers` (default `["*"]`), `allowed_methods`, `allowed_origins`, `expose_headers` (default `[]`) and `max_age_seconds` (default 3600). Every allowed method MUST be `GET`, `PUT`, `POST`, `DELETE` or `HEAD`.

#### Scenario: Defaults applied
- **WHEN** a rule sets only `allowed_methods = ["GET"]` and `allowed_origins = ["https://example.com"]`
- **THEN** the rule allows headers `*` and caches preflight for 3600 seconds

#### Scenario: Unsupported method
- **WHEN** a rule sets `allowed_methods = ["PATCH"]`
- **THEN** the plan is rejected with "CORS allowed_methods must be one of: GET, PUT, POST, DELETE, HEAD."

### Requirement: Static website hosting
When `website` is set, a website configuration SHALL be created for the bucket with `index_document` and `error_document` (default `error.html`).

#### Scenario: Website with default error page
- **WHEN** a bucket sets `website = { index_document = "index.html" }`
- **THEN** a website configuration with suffix `index.html` and error key `error.html` is planned and appears in `website_urls`

#### Scenario: No website
- **WHEN** a bucket leaves `website` unset
- **THEN** no website configuration is planned for it

### Requirement: Bucket tags
Each bucket SHALL carry the merge of `var.tags` and its own `tags`.

#### Scenario: Per-bucket tag
- **WHEN** `tags = { env = "prod" }` and the bucket sets `tags = { team = "a" }`
- **THEN** the bucket has both tags
