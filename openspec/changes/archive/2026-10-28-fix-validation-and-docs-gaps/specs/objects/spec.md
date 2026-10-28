## ADDED Requirements

### Requirement: Object bucket key existence
Each object `bucket_key` MUST be an expanded key of `buckets` (`<key>-<n>`, n from 1 to `count`).

#### Scenario: Unknown bucket key
- **WHEN** an entry sets `bucket_key = "data"` while bucket `data` is keyed `data-1`
- **THEN** the plan is rejected with "bucket_key must be an expanded key of var.buckets (for example data-1)."
