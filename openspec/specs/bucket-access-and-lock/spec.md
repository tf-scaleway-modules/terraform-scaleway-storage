# bucket-access-and-lock Specification

## Purpose
Bucket policies and object lock (WORM) configurations.

## Requirements

### Requirement: Bucket policies
The `bucket_policies` input SHALL be a map of objects with required `bucket_key` and `policy` (a JSON string). One bucket policy SHALL be created per entry, on the bucket whose expanded key (for example `data-1`) equals `bucket_key`, with the policy document passed unchanged.

#### Scenario: Policy on an expanded key
- **WHEN** bucket `data` exists and `bucket_policies = { p = { bucket_key = "data-1", policy = jsonencode({...}) } }`
- **THEN** a policy resource with that document is planned on the bucket keyed `data-1`

#### Scenario: No policies
- **WHEN** `bucket_policies` is empty
- **THEN** no policy resource is planned

### Requirement: Policy bucket key format
Each `bucket_key` in `bucket_policies` MUST start with a letter and contain only letters, digits, underscores and hyphens.

#### Scenario: Malformed bucket key
- **WHEN** a policy sets `bucket_key = "1-bad"`
- **THEN** the plan is rejected with "Bucket key must be a valid identifier (alphanumeric with underscores/hyphens, starting with letter)."

### Requirement: Lock mode validation
The retention `mode` of `object_lock.default_retention` MUST be `GOVERNANCE` or `COMPLIANCE`.

#### Scenario: Unknown mode
- **WHEN** a bucket sets `mode = "INVALID"`
- **THEN** the plan is rejected with "Lock mode must be either GOVERNANCE or COMPLIANCE."

### Requirement: Single retention unit
Exactly one of `days` or `years` MUST be set in a default retention.

#### Scenario: Both units
- **WHEN** a bucket sets `days = 30` and `years = 1`
- **THEN** the plan is rejected with "Exactly one of 'days' or 'years' must be specified for retention period."

#### Scenario: Neither unit
- **WHEN** a bucket sets a default retention with neither `days` nor `years`
- **THEN** the plan is rejected with the same message

### Requirement: Retention ranges
`days` MUST be between 1 and 36500 and `years` between 1 and 100 when set.

#### Scenario: Days out of range
- **WHEN** a bucket sets `days = 36501`
- **THEN** the plan is rejected with "Retention days must be 1-36500, years must be 1-100."

#### Scenario: Years out of range
- **WHEN** a bucket sets `years = 0`
- **THEN** the plan is rejected with the same message

### Requirement: Bucket object lock
When a bucket sets `object_lock`, versioning and object lock SHALL be enabled on it. When `object_lock.default_retention` is also set, a default retention (`mode`, and `days` or `years`) SHALL be applied to the bucket. `object_lock` unset means no lock and no retention.

#### Scenario: Governance retention in days
- **WHEN** bucket `data` sets `object_lock = { default_retention = { mode = "GOVERNANCE", days = 30 } }`
- **THEN** bucket `data-1` is planned with object lock and a 30 day GOVERNANCE default retention

#### Scenario: Lock without default retention
- **WHEN** a bucket sets `object_lock = {}`
- **THEN** object lock is enabled and no default retention is planned

#### Scenario: No lock
- **WHEN** a bucket leaves `object_lock` unset
- **THEN** no lock configuration is planned for it

### Requirement: Policy bucket key existence
Each `bucket_key` in `bucket_policies` MUST be an expanded key of `buckets` (`<key>-<n>`, n from 1 to `count`).

#### Scenario: Unexpanded or unknown key
- **WHEN** bucket `data` has `count = 1` and a policy sets `bucket_key = "data"` or `"data-2"`
- **THEN** the plan is rejected with "bucket_key must be an expanded key of var.buckets (for example data-1)."
