## MODIFIED Requirements

### Requirement: Lifecycle storage class validation
Every `storage_class` in `transition` and `noncurrent_version_transition` MUST be `STANDARD`, `GLACIER` or `ONEZONE_IA`, the classes the provider accepts.

#### Scenario: Unsupported class
- **WHEN** a transition sets `storage_class = "DEEP_ARCHIVE"`
- **THEN** the plan is rejected with "Storage class must be one of: STANDARD, GLACIER, ONEZONE_IA."

#### Scenario: Class the provider rejects
- **WHEN** a noncurrent version transition sets `storage_class = "STANDARD_IA"`
- **THEN** the plan is rejected with the same message
