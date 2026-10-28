## MODIFIED Requirements

### Requirement: Snapshot input shape
The `block_snapshots` input SHALL be a map of objects with optional `name`, `count` (default 1), `volume_key`, `zone`, `tags` (a list of strings, default `[]`), `export` (`bucket`, `key`), `import` (`bucket`, `key`) and `timeouts` (default null, optional `create`, `read`, `update`, `delete` duration strings).

#### Scenario: Empty map
- **WHEN** `block_snapshots` is empty
- **THEN** no snapshot is planned

## ADDED Requirements

### Requirement: Snapshot timeouts
When `timeouts` is set, its `create`, `read`, `update` and `delete` values SHALL be applied to every snapshot of that entry, both snapshots taken from a volume and imported ones, so a long QCOW2 export or import can wait longer than the provider default (5 minutes). A member left unset, or `timeouts` unset, keeps the provider default.

#### Scenario: Longer create wait
- **WHEN** a snapshot with `count = 2` sets `timeouts = { create = "30m" }`
- **THEN** both planned snapshots carry a create timeout of 30 minutes and the default for the other operations

#### Scenario: Not set
- **WHEN** a snapshot sets no `timeouts`
- **THEN** the planned snapshot sets no timeout and a second plan is empty

### Requirement: Snapshot timeouts validation
Every set `timeouts` member MUST be a duration made of one or more number and unit pairs with units `ns`, `us`, `ms`, `s`, `m` or `h` (for example `10m`, `1h30m`).

#### Scenario: Malformed duration
- **WHEN** a snapshot sets `timeouts = { create = "ten minutes" }`
- **THEN** the plan is rejected with "Snapshot timeouts must be durations such as 10m or 1h30m (units ns, us, ms, s, m, h)."
