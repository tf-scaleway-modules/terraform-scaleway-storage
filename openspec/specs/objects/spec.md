# objects Specification

## Purpose
Objects uploaded to buckets from a local file or inline content.

## Requirements

### Requirement: Object input shape
The `objects` input SHALL be a map of objects with required `bucket_key` and `key`, and optional `source`, `content`, `content_type`, `visibility` (default `private`), `tags` (default `{}`), `hash`, `storage_class` and `metadata` (each default null). One object SHALL be uploaded per entry to the bucket whose expanded key equals `bucket_key`, with `source` as the local file and `content` as the inline body. `hash`, `storage_class` and `metadata` SHALL be sent only when set.

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

### Requirement: Source xor content
Exactly one of `source` or `content` MUST be set for each object.

#### Scenario: Both set
- **WHEN** an entry sets `source` and `content`
- **THEN** the plan is rejected with "Exactly one of 'source' or 'content' must be specified for each object."

#### Scenario: Neither set
- **WHEN** an entry sets neither
- **THEN** the plan is rejected with the same message

### Requirement: Visibility
`visibility` MUST be `private` or `public-read`.

#### Scenario: Unsupported visibility
- **WHEN** an entry sets `visibility = "public-read-write"`
- **THEN** the plan is rejected with "Object visibility must be either 'private' or 'public-read'."

### Requirement: Object key format
Each object `key` MUST NOT start with `/` and MUST be 1-1024 characters long.

#### Scenario: Leading slash
- **WHEN** an entry sets `key = "/images/logo.png"`
- **THEN** the plan is rejected with "Object key must not start with '/', must be 1-1024 characters."

#### Scenario: Empty key
- **WHEN** an entry sets `key = ""`
- **THEN** the plan is rejected with the same message

### Requirement: Object output
Uploaded objects SHALL be reported in the `objects` and `object_urls` outputs, keyed by the `objects` map key.

#### Scenario: Output URL
- **WHEN** an object with key `images/logo.png` is uploaded to bucket `acme-data` in `fr-par`
- **THEN** its URL is `https://acme-data.s3.fr-par.scw.cloud/images/logo.png`

### Requirement: Object bucket key existence
Each object `bucket_key` MUST be an expanded key of `buckets` (`<key>-<n>`, n from 1 to `count`).

#### Scenario: Unknown bucket key
- **WHEN** an entry sets `bucket_key = "data"` while bucket `data` is keyed `data-1`
- **THEN** the plan is rejected with "bucket_key must be an expanded key of var.buckets (for example data-1)."

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
