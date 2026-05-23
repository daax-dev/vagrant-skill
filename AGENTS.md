<!-- CLAUDE.md and AGENTS.md share the Operator Preferences and Hard Guardrails below. Keep them in sync. -->

# AGENTS.md

Entry point for OpenAI Codex and compatible agents.

---

## Project
Name: vagrant-skill (`@daax-dev/vagrant-skill`)
Purpose: A general-purpose disposable-VM Agent Skill (`vagrant`) providing Ubuntu 24.04 sandboxes with full sudo, Docker, Go, mage, and optional nested KVM for safe build/test/experimentation. Ships as a Claude Code and OpenClaw skill.

`SKILL.md` is the authoritative skill specification. Read it before changing skill behavior.

---

## Operator Preferences
<!-- Operator-specific. Revise or replace when applying to a different operator. -->
- State facts only. No sugarcoating.
- Surface problems, blockers, and risks immediately.
- Consult before one-way-door decisions and before any architectural change.
- Never guess. If validation is not possible, say so explicitly.
- Objective language. No first-person pronouns. No apologies or hedges.

---

## Hard Guardrails (always apply)
- Plan before any non-trivial change. Write the plan down. Wait for approval.
- Never commit or merge directly to `main`.
- Never commit secrets, tokens, keys, or `.env` files with live values.
- No destructive git (`reset --hard`, force-push, branch delete) without explicit operator approval.
- Never overwrite uncommitted user changes. Inspect existing patterns before editing.
- Run formatter, linter, and tests after changes. If that is not possible, state exactly why.
- Log non-trivial decisions to `.logs/decisions/<topic>.jsonl`.
- Repo-local instructions override these template defaults.

---

## Skill-Specific Rules (this repo)
- General-purpose skill: no project-specific tooling in `scripts/setup.sh`. Consumers add their own provisioning.
- All scripts idempotent (`vagrant provision` is re-run-safe) and shellcheck-clean. `Vagrantfile` passes `ruby -c`.
- `Vagrantfile` is committed; `.vagrant/` is gitignored.

---

## Repository Layout
- `SKILL.md` — Agent Skills standard skill definition (frontmatter + execution instructions + examples). Authoritative spec.
- `Vagrantfile` — Ruby VM config, multi-provider (Parallels, libvirt, VirtualBox).
- `scripts/setup.sh` — bash provisioner (system deps, Docker, Go, mage, optional KVM).
- `scripts/verify.sh` — bash validation suite run inside the VM.
- `test/` — bats-core suites: `scripts.bats`, `skill.bats`, `vagrantfile.bats` (unit, no VM); `integration.bats` (boots a VM).
- `references/` — `platform-setup.md`, `vm-contents.md`.
- `examples/` — `nginx-hardened/`, `mac-docker-compose/`, `windows-systemd-service/` (each with its own `Vagrantfile` + `test/e2e.bats`).
- `docs/` — supplementary reference docs.
- `Makefile` — `lint`, `test` (= `test-unit`), `test-integration`, `test-all`, `up`, `destroy`, `clean`.
- `package.json` — npm package metadata; scripts proxy to `make`.
- `.github/workflows/` — `ci.yml` (lint → test + validate-skill), `publish.yml` (release).

---

## Required Reading
`.claude/workflow.md` — planning and definition of done — applies to every task. Read it before starting work.

Read the matching file **before** you:
- write or edit code → `.claude/language.md` (formatting, linting, testing for that language)
- make an architectural or cross-boundary decision → `.claude/architecture.md`
- touch dependencies, runtime, or infrastructure → `.claude/stack.md`
- perform branch / PR / commit / merge operations → `.claude/sourcecontrol.md`
- write a decision or reference log entry → `.claude/history.md`
