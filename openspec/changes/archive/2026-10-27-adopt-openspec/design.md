## Context

The module has no OpenSpec content; Agent OS standards were its only planning aid. The sibling modules (keycloak, vault, gitlab-management) already use OpenSpec with shared standards stores.

## Goals / Non-Goals

**Goals:**
- Replace Agent OS with the OpenSpec stores and a baseline contract under `openspec/specs/`.
- Make specs validate in CI.

**Non-Goals:**
- Any change to `.tf` files, inputs, outputs, resources or state.
- Fixing the inconsistencies noticed while writing the baseline (they are reported, not specified as intended behaviour).

## Decisions

1. **Stores via the profile.** `openspec/config.yaml` and `AGENTS.md` start from the `terraform-module` profile; `references:` pins `quality`, `repository` and `terraform` to a tag. Standards are fetched on demand, not copied.
2. **Skills for both agents.** `openspec-*` skills are installed in `.claude/skills/` (Claude Code) and `.opencode/skills/` (OpenCode); `CLAUDE.md` imports `AGENTS.md`, which OpenCode reads natively.
3. **CI job `validate:specs`.** `.gitlab/specs.yml` runs `openspec validate --all --strict` with the CLI version pinned by `OPENSPEC_VERSION`; locally `mise run spec-validate` runs the same command and `mise run spec-setup` registers the stores.
4. **Capability split.** Following the module files: `module-contract` (versions, inputs shared by all areas, outputs), `buckets` (`scaleway_object_bucket` and its ACL, encryption and website companions), `bucket-access-and-lock` (policies and lock configuration, both keyed by expanded bucket key), `objects`, `block-volumes`, `block-snapshots`. Requirements describe the observable contract (validation errors, resources and arguments produced, outputs), not provider internals.
5. **Baseline reflects released behaviour.** Where the code is inconsistent with its documentation, the specs state what the code does only if that is clear, and otherwise omit it.
6. **CHANGELOG via git-cliff kept.** `CHANGELOG.md` is generated from commit subjects (`.cliff.toml`, `mise run changelog`); `AGENTS.md` and the `rules` in `config.yaml` ask for commit subjects that read as CHANGELOG lines instead of a hand-edited `[Unreleased]` section.
7. **Tests.** Unit tests are `tofu test` over `tests/` (mock provider, no credentials); there is no integration fixture and no scan task.

## Risks / Trade-offs

- Baseline specs can drift from the code until the first change proposal: mitigated by reviewing each validation block against a scenario.
- Contributors without registered stores get a stop message from the skills: `mise run spec-setup` fixes it.
