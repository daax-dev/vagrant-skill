# Copilot Instructions

GitHub Copilot reads this file automatically. Rules here are enforced in every session.

---

## Project
Name: vagrant-skill (`@daax-dev/vagrant-skill`)
Purpose: A general-purpose disposable-VM Agent Skill (`vagrant`) providing Ubuntu 24.04 sandboxes with full sudo, Docker, Go, mage, and optional nested KVM for safe build/test/experimentation. Ships as a Claude Code and OpenClaw skill. `SKILL.md` is the authoritative skill spec.

---

## Operator Preferences
<!-- Operator-specific. Revise or replace when applying to a different operator. -->
- State facts only. No sugarcoating.
- Surface problems, blockers, and risks immediately.
- Consult before one-way-door or architectural decisions.
- Never answer from a guess. Say so when a claim cannot be validated.
- Objective language. No first-person pronouns. No apologies.

---

## Planning
- A plan is required for any non-trivial change. Trivial = typo fix, single-line config update, obvious rename.
- Write the plan first. Present it. Wait for approval. Do not start coding until approved.
- Present options with trade-offs. The operator decides; the agent executes.

---

## Stack
- Skill format: Agent Skills standard (`SKILL.md` with YAML frontmatter); validated by the `validate-skill` CI job. The validator requires the skill directory to be named `vagrant`, so CI copies the checkout to `/tmp/vagrant` first: `mkdir -p /tmp/vagrant && cp -r ./* ./.* /tmp/vagrant/ 2>/dev/null || true; npx --yes skills-ref validate /tmp/vagrant`.
- VM tooling: Vagrant CLI with a provider (Parallels / libvirt / VirtualBox). Base box `bento/ubuntu-24.04`.
- Languages: Ruby (Vagrantfile, syntax-checked with `ruby -c`; Ruby 3.3 in CI) and Bash (`scripts/*.sh`, shellcheck-linted).
- Package: npm (`@daax-dev/vagrant-skill`), Node `>=22.14.0`; published to npm + ClawHub.
- Test framework: bats-core.
- CI: GitHub Actions — `lint` then `test` + `validate-skill`.

---

## Code Conventions
- Bash: `set -euo pipefail` in every script. Quote all expansions. No `eval`. Must pass `shellcheck`.
- Ruby (Vagrantfile): must pass `ruby -c`. No external gems beyond Vagrant plugins.
- All provisioning must be **idempotent** — `vagrant provision` re-runs safely.
- This is a **general-purpose** skill: no project-specific tooling in `scripts/setup.sh`. Consumers layer their own.
- `Vagrantfile` is committed; `.vagrant/` is gitignored. Never commit `node_modules/` or VM state.
- All `make lint` and `make test` must pass before declaring done.
- When you change skill behavior, update `SKILL.md` and the matching bats tests.

---

## Source Control
- Repo: `github.com/daax-dev/vagrant-skill`. Default branch `main`.
- Never commit directly to `main`. All work lands via PR.
- Branch naming: `feature/`, `fix/`, `docs/`, `chore/`.
- Commits: imperative mood, present tense. Subject ≤ 72 characters. Body explains **why**.
- PR body must include: problem statement, approach, alternatives considered, test evidence.
- Never merge your own PR unless explicitly authorized.
- Never commit secrets, tokens, keys, or `.env` files with live values.

---

## Definition of Done
A task is done only when:
- `make lint && make test` pass (matching CI). Run `make test-integration` / `make test-all` locally when a provider is available and VM behavior changed.
- Skill changes validate via the CI flow (validator requires the dir named `vagrant`): `mkdir -p /tmp/vagrant && cp -r ./* ./.* /tmp/vagrant/ 2>/dev/null || true; npx --yes skills-ref validate /tmp/vagrant`.
- PR opened with problem statement, approach, and test evidence.
- No unresolved `[FILL IN]` placeholders left in affected files (the literal marker may remain in `.claude/stack.md` and `.claude/language.md`, where it documents the convention).
- Decisions logged in `.logs/decisions/` if a non-trivial choice was made.
