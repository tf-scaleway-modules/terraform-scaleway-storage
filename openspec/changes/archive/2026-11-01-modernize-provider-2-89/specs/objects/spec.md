## ADDED Requirements

### Requirement: Object tags
Each object SHALL carry the merge of the global `tags` and its own `tags`, the object value winning on a shared key.

#### Scenario: Global tag reaches an object
- **WHEN** `tags = { env = "prod" }` and an object sets `tags = { kind = "page" }`
- **THEN** the object has `env = "prod"` and `kind = "page"`

#### Scenario: No tags
- **WHEN** neither the global `tags` nor the object sets a tag
- **THEN** the object sets no tags and a second plan is empty
