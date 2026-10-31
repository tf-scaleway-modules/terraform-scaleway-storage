## MODIFIED Requirements

### Requirement: Object input shape
The `objects` input SHALL be a map of objects with required `bucket_key` and `key`, and optional `source`, `content`, `content_type`, `visibility` (default `private`), `tags` (default `{}`), `hash` (default null), `storage_class` (default null) and `metadata` (default null). One object SHALL be uploaded per entry to the bucket whose expanded key equals `bucket_key`, with `source` sent as the local file and `content` as the inline body. `hash`, `storage_class` and `metadata` SHALL be sent only when set, otherwise the provider default applies.

#### Scenario: Inline content
- **WHEN** an entry sets `bucket_key = "data-1"`, `key = "hello.txt"` and `content = "hi"`
- **THEN** an object `hello.txt` with that body and private visibility is planned in the bucket keyed `data-1`

#### Scenario: Local file
- **WHEN** an entry sets `source = "./index.html"` and no `content`
- **THEN** the object is uploaded from that file

#### Scenario: Re-upload on file change
- **WHEN** an entry sets `source = "./index.html"` and `hash = filemd5("./index.html")` and the file later changes
- **THEN** the next plan updates the object in place to upload the new file

#### Scenario: Archive class and metadata
- **WHEN** an entry sets `storage_class = "GLACIER"` and `metadata = { owner = "backup" }`
- **THEN** the planned object carries that storage class and metadata

## ADDED Requirements

### Requirement: Object storage class validation
When set, an object `storage_class` MUST be `STANDARD`, `GLACIER` or `ONEZONE_IA`.

#### Scenario: Unsupported class
- **WHEN** an entry sets `storage_class = "DEEP_ARCHIVE"`
- **THEN** the plan is rejected with "Object storage_class must be one of: STANDARD, GLACIER, ONEZONE_IA."

### Requirement: Object metadata keys
When set, every object `metadata` key MUST be lowercase.

#### Scenario: Uppercase key
- **WHEN** an entry sets `metadata = { Owner = "backup" }`
- **THEN** the plan is rejected with "Object metadata keys must be lowercase."
