## MODIFIED Requirements

### Requirement: Bucket name validation
Every bucket `name` MUST be 3-63 characters of lowercase letters, digits, dots and hyphens, starting and ending with a letter or digit. When `count > 1`, the name with its `-<n>` suffix, for the largest n (`count`), MUST also be at most 63 characters.

#### Scenario: Uppercase name
- **WHEN** a bucket has `name = "Invalid_Bucket"`
- **THEN** the plan is rejected with "Bucket name must be 3-63 characters, lowercase alphanumeric with hyphens and dots, start/end with alphanumeric."

#### Scenario: Suffix overflows
- **WHEN** a bucket has a 62-character name and `count = 2`
- **THEN** the plan is rejected with "Bucket name plus the -<count> suffix must not exceed 63 characters when count > 1."

#### Scenario: Suffix fits
- **WHEN** a bucket has a 61-character name and `count = 2`
- **THEN** the plan succeeds
