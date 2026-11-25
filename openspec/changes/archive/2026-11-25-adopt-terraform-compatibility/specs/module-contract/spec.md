## MODIFIED Requirements

### Requirement: Toolchain and provider constraints
The module SHALL require OpenTofu/Terraform `>= 1.11.0` and the `scaleway/scaleway` provider `~> 2.89`, and SHALL NOT declare `provider` or `backend` blocks; the caller configures the provider. Both OpenTofu and Terraform SHALL accept the module at that floor; the single `required_version` constraint serves both and no OpenTofu-only construct is used.

#### Scenario: Consumer uses a supported toolchain
- **WHEN** the module is called with OpenTofu 1.11 or later and a scaleway provider in the 2.89 line or later 2.x
- **THEN** initialisation succeeds and the module needs no provider or backend configuration of its own

#### Scenario: Provider older than the floor
- **WHEN** the consumer's lock file holds scaleway provider 2.87
- **THEN** `init` reports that the locked version does not satisfy `~> 2.89` until the lock is upgraded

#### Scenario: Terraform consumer
- **WHEN** the module and each example under `examples/` are initialised with `terraform init -backend=false` and checked with `terraform validate` on Terraform 1.11.0 or later
- **THEN** validation succeeds, exactly as with OpenTofu
