## 1. Tooling

- [x] 1.1 Pin `node` and `openspec` in `mise.toml` and add the `spec-validate` and `spec-setup` tasks
- [x] 1.2 Add `scripts/openspec-setup.sh`, `.gitlab/specs.yml` (job `validate:specs`) and `OPENSPEC_VERSION` in `.gitlab/global.yml`
- [x] 1.3 Install the `openspec-*` skills in `.claude/skills/` and `.opencode/skills/`

## 2. OpenSpec configuration

- [x] 2.1 Fill `openspec/config.yaml` `context`, `rules` and `operations` for this module, keeping `references:` as in the profile
- [x] 2.2 Fill `AGENTS.md` (project, commands) and keep `CLAUDE.md` importing it; CHANGELOG wording adapted to git-cliff

## 3. Remove Agent OS

- [x] 3.1 Delete `agent-os/standards/` and `.claude/commands/agent-os/`
- [x] 3.2 Update README "Contributing" with the OpenSpec workflow, outside the terraform-docs markers

## 4. Baseline specs

- [x] 4.1 Write the six delta specs (`module-contract`, `buckets`, `bucket-access-and-lock`, `objects`, `block-volumes`, `block-snapshots`) from `variables.tf`, `locals.tf`, `object-storage.tf`, `block-storage.tf` and `outputs.tf`
- [x] 4.2 Check that every validation block has a scenario with a rejected input
- [x] 4.3 Verify no `.tf` file changed
- [x] 4.4 `openspec validate --all --strict` passes (same command as the `validate:specs` CI job)
- [x] 4.5 Archive the change and replace the `TBD` purposes in the main specs
- [x] 4.6 `pre-commit run` passes on the changed files
