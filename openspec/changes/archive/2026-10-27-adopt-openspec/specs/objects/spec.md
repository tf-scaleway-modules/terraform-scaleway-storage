## ADDED Requirements

### Requirement: Object input shape
The `objects` input SHALL be a map of objects with required `bucket_key` and `key`, and optional `source`, `content`, `content_type`, `visibility` (default `private`) and `tags` (default `{}`). One object SHALL be uploaded per entry to the bucket whose expanded key equals `bucket_key`, with `source` sent as the local file and `content` as the inline body.

#### Scenario: Inline content
- **WHEN** an entry sets `bucket_key = "data-1"`, `key = "hello.txt"` and `content = "hi"`
- **THEN** an object `hello.txt` with that body and private visibility is planned in the bucket keyed `data-1`

#### Scenario: Local file
- **WHEN** an entry sets `source = "./index.html"` and no `content`
- **THEN** the object is uploaded from that file

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
