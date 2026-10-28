## MODIFIED Requirements

### Requirement: Global tags
The `tags` input (`map(string)`, default `{}`) SHALL be merged with the per-bucket `tags` on every bucket, the per-bucket value winning on a shared key. It does not apply to block volumes and snapshots, whose `tags` are lists of strings.

#### Scenario: Tag merge
- **WHEN** `tags` is `{ env = "prod" }` and a bucket sets `tags = { env = "dev", team = "a" }`
- **THEN** that bucket carries `env = "dev"` and `team = "a"`

### Requirement: Project and endpoint outputs
The module SHALL output `project_id` (the looked-up project ID), `region` (the input, the region of the Object Storage resources) and `s3_endpoint` (`https://s3.<region>.scw.cloud`).

#### Scenario: Paris endpoint
- **WHEN** `region` is `fr-par`
- **THEN** `s3_endpoint` is `https://s3.fr-par.scw.cloud`
