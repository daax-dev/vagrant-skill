# Stack

`[FILL IN]` marks an undefined entry. Treat as "ask the operator," not a guess.
Only document what is confirmed and deployable today.

This repo is a **skill package**, not a running service. There is no persistence,
messaging, auth, observability, or cloud-compute tier — those sections are omitted
deliberately. The "runtime" is the contributor toolchain plus the VM the skill provisions.

---

## Skill Format
- Agent Skills standard: `SKILL.md` with YAML frontmatter (`name`, `description`, `license`, `compatibility`, `allowed-tools`, `metadata`).
- Validated by the `validate-skill` CI job. The validator requires the skill dir to be named `vagrant`, so CI copies the checkout to `/tmp/vagrant` before validating: `mkdir -p /tmp/vagrant && cp -r ./* ./.* /tmp/vagrant/ 2>/dev/null || true; npx --yes skills-ref validate /tmp/vagrant`.
- Consumed as a Claude Code skill (`/vagrant`) and an OpenClaw skill (`metadata.openclaw` declares required bins).

## Contributor Toolchain
- Ruby — `Vagrantfile` is Ruby; validated via `ruby -c`. CI pins Ruby 3.3 (`ruby/setup-ruby@v1`). No application Ruby code, no gems beyond Vagrant plugins.
- Bash — `scripts/setup.sh`, `scripts/verify.sh`; linted with shellcheck.
- bats-core — test runner for `test/*.bats` and `examples/*/test/e2e.bats`.
- Vagrant CLI + a provider — required only to run integration/e2e tests and to use the skill. Providers: Parallels (macOS Apple Silicon), libvirt (Linux, nested KVM), VirtualBox (cross-platform). Base box `bento/ubuntu-24.04`.

## Provisioned VM (what the skill installs)
- Ubuntu 24.04, full sudo, Docker CE, Go, mage, optional nested KVM. See `references/vm-contents.md` for the authoritative inventory.
- Configurable via env vars before `vagrant up`: `VM_CPUS` (default 4), `VM_MEMORY` (default 4096 MB), `PROJECT_SRC`.

## Build / Package
- npm package `@daax-dev/vagrant-skill`; Node engine `>=22.14.0`. `package.json` `files`: `SKILL.md`, `Vagrantfile`, `scripts/`, `references/`, `LICENSE`. `publishConfig.access: public`.
- npm `scripts` proxy to make: `lint`, `test`, `test:integration`, `test:all`.
- CI: GitHub Actions — `.github/workflows/ci.yml` runs `lint` → (`test`, `validate-skill`) on push/PR to `main`. Release/publish via `.github/workflows/publish.yml`.
- Artifact registries: npm (public) and ClawHub (per `package.json` keywords / publish workflow).

## Explicitly Not in Stack
List rejected tools and the reason. Prevents re-proposal.
- Project-specific provisioning inside `scripts/setup.sh` — this is a general-purpose skill; consumers add their own tooling on top.
- Docker Desktop — the skill deliberately provides Docker CE inside a VM to avoid Docker Desktop's commercial-license constraints (see `examples/mac-docker-compose/`).
- Application databases / services — out of scope; this repo ships configuration and scripts, not a deployed app.
