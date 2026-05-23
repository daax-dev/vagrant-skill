# Source Control

---

## Repository
- Host: GitHub — `github.com/daax-dev/vagrant-skill`
- Default branch: `main`
- All work lands via PR. No direct commits to main.

---

## Branch Naming
- Feature: `feature/<short-topic>`
- Bug fix: `fix/<short-topic>`
- Docs: `docs/<short-topic>`
- Chore / tooling: `chore/<short-topic>`
- Release: `release/vX.Y.Z` and version bumps `bump-X.Y.Z` (existing convention in this repo).
- Claude Code sessions: harness-assigned name (e.g., `claude/<task>-<id>`). Do not rename mid-session.
- Lowercase, hyphen-separated. Keep names short.

---

## Commits
- Imperative mood, present tense: "add X", not "added X" or "adds X".
- Subject line ≤ 72 characters.
- Body explains the **why**. The diff shows the what.
- One logical change per commit. Mixed-purpose commits get rejected at review.
- Do not amend a commit that has already been pushed unless explicitly asked.

---

## Pull Requests
- Open a PR as soon as the branch has a meaningful commit. Draft is fine.
- PR title = leading commit subject line.
- PR body must include:
  - Problem statement (link the GitHub Issue when one exists).
  - Approach taken and alternatives considered.
  - Test evidence (commands run, output — at minimum `make lint && make test`).
  - Which model produced and which model validated (if AI-assisted).
- Never merge your own PR unless explicitly authorized by the operator.
- Squash-merge by default unless the branch history is intentionally curated.

---

## Worktrees
- Long-running parallel work uses `git worktree` rather than branch-switching in place.
- Worktree paths live outside the primary checkout (e.g., `/tmp/<repo>-<branch>`).
- Worktrees are disposable. Clean them up when the branch lands (`git worktree remove`).

---

## What Never Gets Committed
- Secrets, tokens, keys, connection strings, npm publish tokens.
- `.env` files with live values.
- VM state (`.vagrant/`) and `node_modules/` — both gitignored.
- IDE / OS noise (`.DS_Store`, `Thumbs.db`) — already in `.gitignore`.

---

## Destructive Operations
- Force-push to a shared branch requires explicit operator authorization.
- `git reset --hard`, branch deletion, and history rewrites require confirmation when recovery is uncertain.
- Treat destructive git operations as high-risk: pause, verify the target, get confirmation.

---

## Tags and Releases
- Tag scheme: semver `vX.Y.Z`, matching `package.json` `version` (currently 0.7.x).
- Release flow: version-bump branch (`bump-X.Y.Z`) → PR → publish via `.github/workflows/publish.yml` to npm + ClawHub.
