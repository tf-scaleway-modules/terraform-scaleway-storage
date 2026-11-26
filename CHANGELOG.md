# Changelog

All notable changes to this project will be documented in this file.


## [4.0.2] - 2026-11-26
- Fix the README bucket policy example that broke the rendering of every later section
## [4.0.1] - 2026-11-25
- Validate the module with Terraform and pin both toolchains
- Rewrite input and output descriptions as single-line prose so they render on the Terraform Registry
## [4.0.0] - 2026-11-01
- Fold object lock into buckets, add lifecycle tag filters and slim outputs; use project_id with optional region and zone

BREAKING: v4.0.0.

- organization_id and project_name are removed: pass project_id.
- region and volume/imported-snapshot zone default to the provider
  region/zone: pin region = "fr-par" and zone = "fr-par-1" or buckets and
  volumes are replaced if the provider default differs.
- bucket_lock_configurations and buckets[*].object_lock_enabled become
  buckets[*].object_lock; the lock configuration is keyed by the expanded
  bucket key (add a root moved block or state mv).
- block_volumes[*].prevent_destroy and its check are removed.
- block_snapshots[*].volume_key must be an expanded volume key.
- Global tags reach objects, volumes and snapshots (key:value).
- Outputs reduced to buckets, objects, block_volumes and block_snapshots;
  17 outputs removed (see the README mapping table).
- New lifecycle_rules[*].tags, optional size_in_gb with snapshot_id.

See "Upgrading from v3 to v4" in the README.
## [3.0.0] - 2026-10-31
- Raise provider floor to ~> 2.89 and add snapshot timeouts, object hash, storage class and metadata

BREAKING: the scaleway provider floor is raised from ~> 2.86 to ~> 2.89
(scaleway_block_snapshot.timeouts needs provider 2.88.0). Run
`tofu init -upgrade` so the lock file moves to 2.89 or later.

- block_snapshots gains `timeouts` (create/read/update/delete durations),
  applied to snapshots from a volume and imported ones.
- objects gains `hash`, `storage_class` (STANDARD, GLACIER, ONEZONE_IA) and
  `metadata` (lowercase keys).
- Lifecycle `STANDARD_IA` is now rejected by validation (the provider
  already refused it); allowed classes are STANDARD, GLACIER, ONEZONE_IA.
- block_volumes and block_snapshots outputs gain an `srn` key.
## [2.2.2] - 2026-10-28
- Fix bucket_key and name-length validation, uppercase export suffix and prevent_destroy docs

- Reject bucket_key values in bucket_policies, bucket_lock_configurations and objects that are not an expanded bucket key, instead of failing with an index error.
- Reject bucket names that exceed 63 characters once the -<count> suffix is added.
- Insert the -<n> suffix into snapshot export keys with an uppercase .QCOW/.QCOW2 extension, so exports with count > 1 no longer overwrite each other.
- Warn at plan time when a volume sets prevent_destroy = true, which the module cannot enforce, and document it in the README and SECURITY.md.
- Clarify the zone default, block tags and region output descriptions.
No upgrade action needed.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
## [2.2.1] - 2026-10-28
- Install mise 2026.10.17 in CI to avoid the GitHub API rate limit

The pre-commit job installed an old mise that resolves every tool through api.github.com without a token, and failed with 403 rate-limit errors on the shared office runner whenever its cache was cold (new refs such as merge requests and tags). mise 2026.9.14 and later resolve releases through mise-versions.jdx.dev.
- Run validate:specs in merge request pipelines

A job without rules: only runs in branch and tag pipelines, so the merge request pipeline did not validate openspec/. rules: when: always matches the other validate jobs.
- Move from Agent OS to OpenSpec and publish the baseline specs

Planning moves from Agent OS to OpenSpec: agent-os/standards/ and the
Agent OS commands are removed, the engineering standards now come from the
quality, repository and terraform OpenSpec stores. openspec/config.yaml follows the terraform-module profile
(stores pinned at quality v1.2.6, repository v4.1.0, terraform v1.2.6) and
AGENTS.md, imported by CLAUDE.md, routes to them. openspec/specs/ holds the
baseline specification of the module as released, produced by the archived
adopt-openspec change. The openspec-* skills are installed for Claude Code
and OpenCode, openspec 1.14.3 and node are pinned in mise.toml with the
spec-validate and spec-setup tasks, and the validate:specs CI job runs
openspec validate --all --strict. The module contract is unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
- ci: let osv-scanner pass on a repo without lockfiles

- pre-commit: osv-scanner 2.x exits 128 with "No package sources found"
  on this Terraform-only repo, which failed the job and skipped
  create:release; pass --allow-no-lockfiles.
- Cache keys follow mise.toml / .pre-commit-config.yaml instead of the
  ref, so branches and tags share one cache instead of each leaving its
  own copy on the runner disk.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
## [2.2.0] - 2026-10-14
- feat: add bucket default encryption and noncurrent version lifecycle rules

- buckets: add server_side_encryption (AES256 or aws:kms) using
  scaleway_object_bucket_server_side_encryption_configuration.
- lifecycle_rules: add noncurrent_version_expiration,
  noncurrent_version_transition, object size filters and
  expiration.expired_object_delete_marker (expiration.days is optional).
- Bump the scaleway provider constraint to ~> 2.86 (module and examples).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
## [2.1.0] - 2026-04-27
- Adds `count` parameter for object storage buckets

Introduces the `count` attribute to object storage bucket definitions, allowing multiple buckets to be created from a single configuration block. Buckets with `count > 1` will have numerically suffixed names (e.g., `data-1`, `data-10`).

The complete example is updated to demonstrate this feature by creating 10 data buckets, and block storage snapshot exports are adjusted to target the first instance of a counted bucket (`data-1`).

A new `examples.tftest.hcl` is added to provide comprehensive validation of the complete example's resource topology, including assertions for bucket counts, naming conventions, and proper referencing of counted resources. Additional tests for `count` behavior are also added to `main.tftest.hcl`.
## [2.0.0] - 2026-04-27
- Updates Scaleway provider version in README

Updates the Scaleway provider version constraint in the documentation to ~> 2.73 to match the project's requirements.
- Updates toolchain, provider, and dependency versions

Upgrades the required OpenTofu version to 1.11.0 and the Scaleway provider to ~> 2.73.

The development toolchain is also updated across CI/CD workflows, mise configuration, and project documentation, including:
- tflint v0.62.0
- git-cliff 2.13.1
- pre-commit 4.6
- osv-scanner 2.3.5
- terraform-docs 0.22.0
- sops 3.12, age 1.3, shfmt 3.13, and yamlfmt 0.21
- Adds Agent OS profile and refactors storage module structure

Introduces a standardized Agent OS profile including AI-driven commands for discovery, planning, and standards injection.

Key changes:
- Adds HCL coding standards and repository configuration templates.
- Refactors Scaleway storage resources into domain-specific files (object-storage.tf, block-storage.tf).
- Introduces native OpenTofu/Terraform tests and complete usage examples.
- Adds SECURITY.md and TESTING.md documentation.
## [1.0.0] - 2025-12-21
- Adds Scaleway Block Storage support

Adds support for Scaleway Block Storage, including volume and snapshot creation, snapshot export/import to object storage, and lifecycle management.

Renames the module to "Storage" to reflect broader scope including both Object and Block Storage.
- Enhances Scaleway Object Storage module

Updates the module to support bucket counts for creating multiple buckets of the same type, and emphasizes the importance of using expanded bucket keys when referencing buckets.

Also clarifies bucket policy requirements and blocks `public-read-write` ACL.
- Enhances Scaleway bucket configuration and security

Improves bucket configuration options by validating bucket naming conventions, ACL values, and CORS methods.

Removes the `public-read-write` ACL option for enhanced security and restricts its use.

Updates bucket policy documentation to align with Scaleway S3 compatibility, including versioning and resource formatting, and enhances validation.

Adds validation that the bucket count is at least 1.

Adds documentation indicating that the key names passed to bucket_lock_configuration, bucket_policy and object keys must reference the expanded key.
- WIP major enhancement with the count dimension
- WIP example testing
- WIP Implements Scaleway Object Storage module

Adds a Terraform module for managing Scaleway Object Storage.

This module provides comprehensive features for creating and managing buckets, including support for:
- Access control (ACLs and bucket policies)
- Versioning
- Lifecycle rules
- Static website hosting
- Object Lock (WORM)
- CORS
- Object uploads

Provides examples for minimal setup, compliance buckets, and static websites.

Follows infrastructure-as-code best practices with extensive validation and sensible defaults.
- first commit
- Initial commit
