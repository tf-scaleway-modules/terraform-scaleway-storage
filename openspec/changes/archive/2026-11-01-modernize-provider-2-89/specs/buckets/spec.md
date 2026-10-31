## MODIFIED Requirements

### Requirement: Bucket input shape
The `buckets` input SHALL be a map of objects keyed by a logical key, with required `name` and optional `count` (default 1), `acl` (`private`), `force_destroy` (`false`), `object_lock` (null), `versioning` (`false`), `tags` (`{}`), `server_side_encryption` (null), `cors_rules` (`[]`), `lifecycle_rules` (`[]`) and `website` (null).

#### Scenario: Minimal bucket
- **WHEN** `buckets = { data = { name = "acme-data" } }`
- **THEN** one private, unversioned bucket named `acme-data` is planned in the project and region the caller selected (or the provider defaults), without `force_destroy`

### Requirement: Versioning and object lock
Versioning SHALL be enabled when `versioning` is true or `object_lock` is set, so that object lock always implies versioning. The bucket output SHALL report `versioning_enabled` and `object_lock_enabled`.

#### Scenario: Object lock forces versioning
- **WHEN** a bucket sets `object_lock = {}` and `versioning = false`
- **THEN** versioning and object lock are enabled on the bucket and `buckets["<key>-1"]` reports both as true

### Requirement: Lifecycle rules
Each entry of `lifecycle_rules` SHALL produce a lifecycle rule on the bucket, built from `id`, `enabled` (default true), `prefix` (default empty), `tags` (default `{}`, a tag filter sent only when not empty), the size filters, `expiration`, `transition`, the noncurrent-version expiration and transition, and `abort_incomplete_multipart_upload`.

#### Scenario: Expiration and multipart cleanup
- **WHEN** a rule sets `expiration = { days = 30 }` and `abort_incomplete_multipart_upload = { days_after_initiation = 7 }`
- **THEN** the bucket gets a rule expiring objects after 30 days and aborting incomplete multipart uploads after 7 days

#### Scenario: Noncurrent version rules
- **WHEN** a rule sets `noncurrent_version_expiration = { noncurrent_days = 90, newer_noncurrent_versions = 3 }`
- **THEN** the rule carries both values

#### Scenario: Tag filter
- **WHEN** a rule sets `tags = { tier = "temp" }`
- **THEN** the rule applies to objects tagged `tier = temp` and a rule without `tags` sends no tag filter
