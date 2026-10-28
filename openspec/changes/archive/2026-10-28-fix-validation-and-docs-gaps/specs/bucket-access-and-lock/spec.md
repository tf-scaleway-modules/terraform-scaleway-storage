## ADDED Requirements

### Requirement: Policy and lock bucket key existence
Each `bucket_key` in `bucket_policies` and `bucket_lock_configurations` MUST be an expanded key of `buckets` (`<key>-<n>`, n from 1 to `count`).

#### Scenario: Unexpanded or unknown key in a policy
- **WHEN** bucket `data` has `count = 1` and a policy sets `bucket_key = "data"` or `"data-2"`
- **THEN** the plan is rejected with "bucket_key must be an expanded key of var.buckets (for example data-1)."

#### Scenario: Unknown key in a lock configuration
- **WHEN** a lock configuration sets `bucket_key = "missing-1"`
- **THEN** the plan is rejected with the same message
