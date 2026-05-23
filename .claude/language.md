# Language Conventions

`[FILL IN]` marks a gap. Treat as "ask the operator," not a guess.

This repo has no compiled application code. The active languages are Ruby (the
`Vagrantfile`) and Bash (the provisioning/verification scripts). Correctness is
validated by syntax checks, shellcheck, and bats-core suites — there is no unit
test framework beyond bats and no coverage tooling.

For each active language, this file records:
1. Pinned version and how it is pinned.
2. Formatter and config location.
3. Linter and config location.
4. Test / validation approach.

---

## Active Languages

### Bash
- Version target: bash 5.x (Ubuntu 24.04 guest; macOS/Linux hosts).
- Scope: `scripts/setup.sh`, `scripts/verify.sh`, inline provisioning in `Vagrantfile`, and `examples/*/test/e2e.bats` helpers.
- Formatter: none. Match existing style (4-space indent, aligned comment banners).
- Linter: `shellcheck` — `make lint` runs `shellcheck scripts/setup.sh scripts/verify.sh`. Must be clean.
- Style: `set -euo pipefail` in every script. Quote all expansions. No `eval`. All scripts must be **idempotent** (`vagrant provision` re-runs safely).
- Validation: bats-core suites assert structure and behavior (`test/scripts.bats`).

### Ruby (Vagrantfile only)
- Version: Ruby 3.3 in CI (`ruby/setup-ruby@v1`). No `.ruby-version` file pinned in repo; the runtime Ruby is whatever Vagrant bundles when the skill is used.
- Scope: `Vagrantfile` and `examples/*/Vagrantfile`. No application Ruby, no gems beyond Vagrant plugins (e.g. vagrant-libvirt).
- Formatter: none.
- Linter / validation: `ruby -c <Vagrantfile>` (`make lint` runs `ruby -c Vagrantfile`). Must report `Syntax OK`.
- Validation: `test/vagrantfile.bats` checks required configuration (box, synced_folder, providers).

---

## Skill Definition (Markdown + YAML frontmatter)
- `SKILL.md` is validated against the Agent Skills standard. The validator requires the skill directory to be named `vagrant`, so the `validate-skill` CI job copies the checkout to `/tmp/vagrant` first: `mkdir -p /tmp/vagrant && cp -r ./* ./.* /tmp/vagrant/ 2>/dev/null; npx --yes skills-ref validate /tmp/vagrant`. Running it directly from the `vagrant-skill` checkout fails on the directory-name check.
- `test/skill.bats` asserts frontmatter fields and structure.
- Keep `SKILL.md`, the `Vagrantfile`, and the bats suites in sync when behavior changes.

---

## Tests (bats-core)
- Unit (no VM): `test/scripts.bats`, `test/skill.bats`, `test/vagrantfile.bats` — run by `make test` (alias `test-unit`).
- Integration (boots a real VM, requires Vagrant + provider): `test/integration.bats` — run by `make test-integration`.
- End-to-end examples: `examples/<name>/test/e2e.bats` — boot the example VM, run bats, tear down (`vagrant destroy -f`). bats exits non-zero on any failure.
- No coverage threshold is enforced; correctness is asserted by the bats suites passing.

---

## Cross-Cutting Rules
- No language rule overrides the linter. Fix the config or script, not by suppressing the check.
- `Vagrantfile` is committed; `.vagrant/` and `node_modules/` are gitignored and never committed.
- Changing skill behavior requires updating `SKILL.md` and the matching bats suite in the same change.
