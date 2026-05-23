# CLAUDE.md

## Project
Name: vagrant-skill (`@daax-dev/vagrant-skill`)
Purpose: A general-purpose disposable-VM Agent Skill (`vagrant`) that gives AI agents and developers Ubuntu 24.04 sandboxes with full sudo, Docker, Go, mage, and optional nested KVM — build, test, and break things without touching the host.
Goal: A correct, idempotent, shellcheck-clean skill package that installs cleanly as a Claude Code / OpenClaw skill and validates against the Agent Skills standard, with `make lint && make test` green and the bats e2e examples passing on a real provider.

`SKILL.md` is the authoritative skill specification (frontmatter, execution instructions, examples). Read it before changing skill behavior.

---

## Operator Preferences
- State facts only. No sugarcoating.
- Surface problems, blockers, and risks immediately.
- Consult before one-way-door decisions and before any architectural change.
- Never answer from a guess. Validate claims against primary sources. If validation is not possible, say so explicitly.
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
- This is a **general-purpose** skill. No project-specific tooling in `scripts/setup.sh` — consumer projects add their own provisioning on top.
- All scripts must be **idempotent** — `vagrant provision` must be safe to re-run.
- All shell scripts must pass **shellcheck**. `Vagrantfile` must pass `ruby -c`.
- The `Vagrantfile` is committed (reusable infra); `.vagrant/` stays gitignored.

### Key Commands
```bash
vagrant up                       # boot VM (project synced at /project)
PROJECT_SRC=~/myproject vagrant up
vagrant ssh -c "command here"    # run inside the VM
vagrant rsync                    # sync host changes into the VM
vagrant provision                # re-run provisioner (idempotent)
vagrant destroy -f               # full teardown, clean slate
```

### File Layout
- `Vagrantfile` — VM config, multi-provider (Parallels + libvirt + VirtualBox)
- `SKILL.md` — Agent Skills standard skill definition
- `scripts/setup.sh` — provisioner (system deps, Docker, Go, mage, KVM)
- `scripts/verify.sh` — validation suite
- `test/` — bats-core tests (`scripts.bats`, `skill.bats`, `vagrantfile.bats`, `integration.bats`)
- `references/` — provider setup and VM-contents reference docs
- `examples/` — three working e2e examples (nginx-hardened, mac-docker-compose, windows-systemd-service)
- `.claude/skills/vagrant/SKILL.md` — installed skill payload (not agent config; leave alone unless changing the skill)

---

## Required Reading
`.claude/workflow.md` is always loaded (see include below) — planning and definition of done apply to every task.

Read the matching file **before** you:
- write or edit code → `.claude/language.md` (formatting, linting, testing for that language)
- make an architectural or cross-boundary decision → `.claude/architecture.md`
- touch dependencies, runtime, or infrastructure → `.claude/stack.md`
- perform branch / PR / commit / merge operations → `.claude/sourcecontrol.md`
- write a decision or reference log entry → `.claude/history.md`

@.claude/workflow.md
