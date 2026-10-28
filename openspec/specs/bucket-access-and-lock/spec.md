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

### Requirement: Object lock configuration
The `bucket_lock_configurations` input SHALL be a map of objects with `bucket_key` and `rule.default_retention` (`mode`, optional `days`, optional `years`). One lock configuration SHALL be created per entry on the bucket whose expanded key equals `bucket_key`, and exposed in the `lock_configurations` output. The target bucket is expected to have `object_lock_enabled = true`.

#### Scenario: Governance retention in days
- **WHEN** an entry targets `data-1` with `mode = "GOVERNANCE"` and `days = 30`
- **THEN** a lock configuration with default retention of 30 days in GOVERNANCE mode is planned and `lock_configurations` reports bucket, mode, days and years

### Requirement: Lock mode validation
The retention `mode` MUST be `GOVERNANCE` or `COMPLIANCE`.

#### Scenario: Unknown mode
- **WHEN** an entry sets `mode = "INVALID"`
- **THEN** the plan is rejected with "Lock mode must be either GOVERNANCE or COMPLIANCE."

### Requirement: Single retention unit
Exactly one of `days` or `years` MUST be set in a default retention.

#### Scenario: Both units
- **WHEN** an entry sets `days = 30` and `years = 1`
- **THEN** the plan is rejected with "Exactly one of 'days' or 'years' must be specified for retention period."

#### Scenario: Neither unit
- **WHEN** an entry sets neither `days` nor `years`
- **THEN** the plan is rejected with the same message

### Requirement: Retention ranges
`days` MUST be between 1 and 36500 and `years` between 1 and 100 when set.

#### Scenario: Days out of range
- **WHEN** an entry sets `days = 36501`
- **THEN** the plan is rejected with "Retention days must be 1-36500, years must be 1-100."

#### Scenario: Years out of range
- **WHEN** an entry sets `years = 0`
- **THEN** the plan is rejected with the same message
