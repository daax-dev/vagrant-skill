# Architecture

Architectural decisions require operator approval before implementation.
ADRs log to `.logs/decisions/architecture.jsonl` (see `.claude/history.md`).

This repo is a **skill package**, not a networked application. There is no service
topology, API surface, datastore, or inter-service communication. Most generic
architecture concerns (API style, idempotency keys, cross-service clients, shared
databases) are **N/A**. The "architecture" here is the contract between the skill,
the `Vagrantfile`, the provisioning scripts, and the VM they produce.

---

## Core Design Principles
- **General-purpose, not project-specific.** `scripts/setup.sh` installs only a baseline (system deps, Docker, Go, mage, optional KVM). Consumer projects layer their own provisioning on top. Adding project-specific tooling to the base scripts is rejected.
- **Idempotent provisioning.** Every provisioning step must be safe to re-run; `vagrant provision` must converge to the same state. Guard installs with capability checks (`command -v ...`).
- **Disposable by design.** The VM holds no durable state. `vagrant destroy -f` is the recovery path. The host repo is rsynced in (read copy at `/project`), never mutated by the VM.
- **No host privilege.** All sudo/privileged operations happen inside the VM; the agent never needs host-level sudo.
- **Multi-provider parity.** The `Vagrantfile` supports Parallels, libvirt, and VirtualBox so the skill works across macOS, Linux, and Windows/WSL2. Provider-specific knobs live in their own provider blocks.

---

## Boundaries / Contracts
- **Skill ↔ host:** `SKILL.md` frontmatter declares `allowed-tools` and required bins (`metadata.openclaw.requires`). Honor these — do not assume tools outside the declared set.
- **Vagrantfile ↔ scripts:** the provisioner is invoked from the `Vagrantfile`; keep the host/guest path contract (`/project`) and env-var interface (`VM_CPUS`, `VM_MEMORY`, `PROJECT_SRC`) stable.
- **Tests ↔ behavior:** test boundary = behavior boundary. A behavior change must come with a bats assertion. Unit suites must not require a VM; integration/e2e suites may.

---

## Anti-Patterns (refuse these)
- Project-specific tooling baked into the general-purpose `scripts/setup.sh`.
- Non-idempotent provisioning (unconditional installs, appends without guards).
- Persisting state in the VM that survives `vagrant destroy` and is relied upon.
- Provider lock-in: a change that works on one provider and silently breaks the others.
- "Temporary" workarounds without an expiry date and an owner.
- Secrets in scripts, the `Vagrantfile`, source control, or CI variables.

---

## Decision Logging
Log to `.logs/decisions/architecture.jsonl`:
```json
{"id":"arch-001","date":"YYYY-MM-DD","decision":"...","rationale":"...","alternatives":"...","references":["https://..."]}
```

---

## Reference Architectures
When citing patterns, prefer primary sources:
- Vagrant official docs (developer.hashicorp.com/vagrant).
- Agent Skills standard documentation and the `skills-ref` validator.
- Provider docs: libvirt, VirtualBox, Parallels.
Cite the exact URL in `.logs/references/architecture.jsonl`.
