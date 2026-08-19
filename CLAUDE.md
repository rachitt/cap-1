# ClaudeForge Banking Suite

Digital-first retail banking platform for Horizon Bank (Business Case BC-AINE-001).
Customer onboarding with KYC stub, savings accounts, atomic transfers, beneficiary
management, personal loans with an admin review queue, an append-only audit ledger,
and stub notifications on transfer success and every loan state transition.

Built end-to-end by Claude Code agents under supervision. See **Project Rules** below.

## Quick Reference

**Backend:** `cd backend && uv run pytest -x -q` | `uv run ruff check --fix .` | `uv run mypy src/`
**Frontend:** `cd frontend && npm test` | `npm run lint` | `npm run typecheck`
**Full stack:** `./init.sh` (installs deps, migrates, seeds, starts both dev servers)
**API:** http://localhost:8000 · **UI:** http://localhost:3000 · **Health:** http://localhost:8000/health

## Project Rules

These are non-negotiable and apply to every agent and every session.

| Rule | Meaning |
|------|---------|
| No-Hand-Coding | All production code, tests, and migrations are agent-generated. Hand-edits limited to specs, CLAUDE.md, agents, hooks, skills, commands. |
| Spec-Is-Truth | When spec and code disagree, the spec wins. Update the spec deliberately, then regenerate. |
| PR-Only Merge | No direct commits to `main`. Every change lands via agent-reviewed PR (`git merge --no-ff`). |
| Synthetic-Data | Dummy data only. Never real or confidential customer data. |

## Architecture

Strict layered architecture: Types → Config → Repository → Service → API → UI.
One-way dependencies only; controllers never call repositories directly.
Enforced by `.claude/hooks/check-architecture.js` and by structural tests in `tests/architecture/`.
See `.claude/architecture.md` for full rules and `docs/architecture.md` for the system diagram.

## Domain Invariants

| ID | Invariant |
|----|-----------|
| NFR-01 | Money is `Decimal` fixed-point everywhere. Never float. |
| NFR-02 | Audit log is append-only. No UPDATE, no DELETE. |
| NFR-03 | Card numbers, passwords, and tokens never reach logs. |
| NFR-04 | Auth enforced at the API layer. No anonymous customer/admin routes. |
| NFR-05 | Migrations are append-only. Never edit a shipped migration. |
| NFR-06 | Structured JSON logs carry a request correlation ID. |
| NFR-07 | `/health` returns 200 within 1s of successful startup. |
| NFR-08 | Architecture rules are automated tests, not conventions. |

Every acceptance criterion (`AC-01`..`AC-10`) must have at least one test referencing its ID.

## Where to Find Things

| What | Where |
|------|-------|
| Business case | `docs/business-case.md` |
| Root spec / feature specs | `specs/app_spec.md`, `specs/<feature>_spec.md` |
| Architecture rules | `.claude/architecture.md` |
| Quality principles | `.claude/skills/code-gen/SKILL.md` |
| Testing patterns | `.claude/skills/testing/SKILL.md` |
| Evaluation rubric | `.claude/skills/evaluation/SKILL.md` |
| Sprint contract format | `.claude/skills/evaluation/references/contract-schema.json` |
| Playwright patterns | `.claude/skills/evaluation/references/playwright-patterns.md` |
| Human control knobs | `.claude/program.md` |
| Session recovery | `claude-progress.txt` |
| Feature tracking | `features.json` |
| Learned rules | `.claude/state/learned-rules.md` |
| Post-mortems / fix loops | `docs/fix-loops/`, `docs/knowledge-deposits.md` |

This is the root of a layered CLAUDE.md hierarchy. Each module (`backend/`, `frontend/`)
and each significant folder carries its own CLAUDE.md with local rules; `AGENTS.md` is a
table of contents only.

## Pipeline Commands

| Command | Purpose |
|---------|---------|
| `/brd` | Socratic interview → BRD |
| `/spec` | BRD → stories + features.json |
| `/design` | Architecture + schemas + mockups |
| `/build` | Full 8-phase pipeline |
| `/auto` | Autonomous ratcheting loop |
| `/implement` | Code gen with agent teams |
| `/evaluate` | Run app, verify contract |
| `/review` | Evaluator + security review |
| `/test` | Test plan + Playwright E2E |
| `/deploy` | Local run scripts + init.sh |

## Code Style

- TDD mandatory: test first, then implement
- 100% meaningful coverage target, 80% floor
- Functions < 50 lines, files < 300 lines
- Static typing everywhere (zero `any`, zero untyped defs)
- See `.claude/skills/code-gen/SKILL.md` for full rules

## Git

Branch: `<type>/<description>` (e.g., `feat/user-auth`)
Commits: conventional format (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`)
Merges: `git merge --no-ff` to preserve PR history. Zero direct commits to `main`.
