# Deployment — ClaudeForge Banking Suite

| Field | Value |
|---|---|
| Document | `specs/design/deployment.md` |
| Deployment method | **Local only.** Production deployment is explicitly out of scope (BRD OUT-04, brief §6.3). |
| Bootstrap | `./init.sh` — one command, clean checkout to running system |
| Backend | `http://localhost:8000` (uvicorn) |
| Frontend | `http://localhost:3000` (Vite dev server) |
| CI | GitLab CI (`.gitlab-ci.yml`) with the Claude Code Action wired in |
| Coverage gate | **80% hard floor**, commit- and pipeline-blocking |
| Version | 1.0 |
| Date | 2026-08-19 |

---

## 1. Environments

### 1.1 Local development — the only real environment

| Property | Value |
|---|---|
| Host | The engineer's workstation (darwin or linux) |
| Processes | Two: uvicorn on `:8000`, Vite dev server on `:3000`. No container, no orchestrator, no supervisor. |
| Datastore | One SQLite file, `backend/banking.db`, gitignored |
| Configuration | `backend/.env`, created from `backend/.env.example` by `./init.sh`. Gitignored. |
| Data | **Synthetic only.** Seeded by `backend/scripts/seed.py`. |
| Health | `GET http://localhost:8000/health` returns 200 within 1s of successful startup (NFR-07) |
| Teardown | Stop both processes; delete `backend/banking.db` to reset |

### 1.2 CI runner — ephemeral

| Property | Value |
|---|---|
| Trigger | Every push and every merge request |
| Datastore | A throwaway SQLite file created by `alembic upgrade head` inside the job |
| Secrets | GitLab CI variables only. Never a committed value. |
| Purpose | Gate merges. It builds, lints, typechecks, tests and enforces the coverage floor; it does not deploy anything. |

### 1.3 Staging and production — documented, out of scope

Brief §6.3 and BRD OUT-04 place production deployment, secret management infrastructure,
multi-region and distributed locking **out of scope**. No staging or production environment is
provisioned, configured or scripted by this project, and no work in this repository should be
spent on one.

Recorded here only so the path is not lost if the client later takes it forward:

| Concern | The documented-but-unbuilt path |
|---|---|
| Runtime | Containerise the backend (`uvicorn` behind `gunicorn` workers) and serve the built frontend as static assets from a CDN or reverse proxy |
| Datastore | Migrate SQLite → PostgreSQL. The `MoneyType` decorator over `Numeric(18,2)` and every repository query are already portable; the SQLite `RAISE(ABORT, ...)` triggers become PostgreSQL trigger functions, and `get_for_update` becomes a real `SELECT ... FOR UPDATE`. |
| Secrets | A managed secret store injected as environment variables. The Config layer is already the single read point, so no application code changes. |
| Migrations | Unchanged — Alembic, still append-only |
| Observability | Ship the existing structured JSON log lines to a log aggregator; the correlation id is already the join key |
| Not planned | Multi-region, distributed locking, autoscaling, blue/green — none is required by any AC |

---

## 2. The `./init.sh` bootstrap contract

One command, from a clean checkout, to a running system with seeded data (mandatory deliverable,
M-15, story `E8-S3`).

**Contract** — `./init.sh` must, in order:

1. **Install backend dependencies** — `cd backend && uv sync`. Fails loudly if `uv` is absent.
2. **Install frontend dependencies** — `cd frontend && npm ci`.
3. **Create configuration** — copy `backend/.env.example` → `backend/.env` if the latter does not
   exist. Never overwrite an existing `.env`.
4. **Migrate** — `cd backend && uv run alembic upgrade head`.
   > **Defect to fix in `E8-S3`:** the current `init.sh` probes `backend/migrations`. The Alembic
   > directory is `backend/alembic/` (story `E1-S4`). Until that probe is corrected the migration
   > step is silently skipped and the application starts against an empty database.
5. **Seed** — `cd backend && uv run python scripts/seed.py`. Idempotent: re-running does not
   duplicate data (`F235`).
6. **Start both services** — uvicorn on `:8000`, Vite on `:3000`, backgrounded.
7. **Probe health** — `GET http://localhost:8000/health` with 5 retries at 2s backoff (matching
   `project-manifest.json` `verification.health_check`), then `GET http://localhost:3000`. Report
   OK or FAILED per service.
8. **Print** the API URL, the UI URL and where to find the seeded administrator credentials
   (`README.md`).

**Prerequisites** (documented in `README.md`, `F239`): Python 3.12, `uv`, Node 20+, `npm`, `curl`.

**Seed contents** (assumption A-12, `F236`, `F237`, `F238`): at least two customers with funded
accounts so a transfer is demonstrable end to end, at least one saved beneficiary, at least one
loan in each reviewable state, and **exactly one** administrator. Every email uses the reserved
`.test` domain; every account number is `HZN`-prefixed and fictional; no document number is
plausible as a real one.

---

## 3. GitLab CI pipeline (`.gitlab-ci.yml`, story `E8-S4`)

GitLab, not GitHub Actions: the graded submission target is a Virtusa GitLab repository, so
`.gitlab-ci.yml` is the CI artefact and no GitHub workflow is used as the graded one (`F241`).

### 3.1 Stages

```
stages: [build, lint, test, quality, agent]
```

| Stage | Job | Does | Blocking |
|---|---|---|---|
| `build` | `build:backend` | `uv sync --frozen`; import the app to prove it loads | yes |
| `build` | `build:frontend` | `npm ci`; `npm run build` | yes |
| `lint` | `lint:backend` | `uv run ruff check .` | yes |
| `lint` | `lint:frontend` | `npm run lint` (eslint) | yes |
| `lint` | `typecheck:backend` | `uv run mypy --strict src/` — zero untyped defs | yes |
| `lint` | `typecheck:frontend` | `npm run typecheck` (`tsc --noEmit`) — zero `any` | yes |
| `test` | `test:backend` | `uv run pytest --cov=src --cov-report=term --cov-report=xml` | yes |
| `test` | `test:frontend` | `npm run test -- --coverage` | yes |
| `test` | `test:architecture` | `uv run pytest tests/architecture/` — the NFR-08 structural tests | yes |
| `quality` | `coverage:gate` | Enforces the **80% hard floor** on both workspaces; see §4 | yes |
| `quality` | `e2e` | `npx playwright test` against a booted stack; uploads `e2e/snapshots/` diffs | yes |
| `agent` | `claude:review` | Claude Code Action reviews the merge request diff | non-blocking, advisory |

`test:architecture` also runs inside `test:backend` because the architecture tests live under the
default test path (`F222`); the separate job exists so a layering violation is legible in the
pipeline view without reading the full test log.

### 3.2 The Claude Code Action job

```yaml
claude:review:
  stage: agent
  image: node:20
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
  variables:
    ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY   # GitLab CI variable, masked and protected
  script:
    - npx -y @anthropic-ai/claude-code-action review --diff
  allow_failure: true
```

The credential is read from a **masked, protected GitLab CI variable** (`F243`). No key, token or
secret is committed anywhere in the repository; the `detect-secrets` hook blocks such a write at
the tool-call boundary and the `protect-env` hook blocks writes to `.env` files.

### 3.3 Artefacts

| Artefact | Path | Retained |
|---|---|---|
| Backend coverage | `backend/coverage.xml`, `backend/htmlcov/` | Per pipeline |
| Frontend coverage | `frontend/coverage/` | Per pipeline |
| Committed coverage baseline | `.claude/state/coverage-baseline.txt` | In the repository (M-05) |
| Playwright report | `playwright-report/` | Per pipeline |
| Playwright snapshots | `e2e/snapshots/` | In the repository (M-27) |

---

## 4. Coverage gate — 80% hard floor

| Property | Value |
|---|---|
| Target | 100% meaningful coverage |
| **Hard floor** | **80%.** Below it, the pipeline exits non-zero and the merge is blocked (`F242`). |
| Backend measurement | `pytest --cov=src`, line coverage over `backend/src/` |
| Frontend measurement | `vitest --coverage`, line coverage over `frontend/src/` |
| Local enforcement | The `pre-commit-gate` hook runs the suite and refuses a commit below the floor |
| Regression detection | `.claude/state/coverage-baseline.txt` records the last accepted figure. A drop below the baseline is reported even when still above 80%, so coverage ratchets forward and never backward. |
| Source of the number | `project-manifest.json` → `execution.coverage_threshold: 80`. That file is authoritative; do not hard-code 80 in a second place. |

Generated code is not exempt. Migrations are excluded from the coverage denominator (they are
executed by `test_migration_history.py` end to end, not line-covered), and
`frontend/src/lib/api/schema.d.ts` is excluded because it is generated type declarations with no
runtime.

---

## 5. Secrets management

| Rule | Mechanism |
|---|---|
| Secrets are read from the environment, never from source | `backend/src/config/settings.py` is the single read point. `JWT_SECRET_KEY` has **no committed default**; instantiating `Settings` without it raises a validation error rather than falling back to a built-in key (`F006`). |
| `.env` is never committed | Listed in `.gitignore`. The `protect-env` hook blocks any write to a `.env` file at the tool-call boundary. |
| `.env.example` carries placeholders only | Documents every required variable with a non-secret placeholder. No value in it matches a high-entropy secret pattern (`F011`). |
| No secret reaches a log line | The redaction filter is installed at the logging handler, so no caller can bypass it. Reinforced by the `pii-scrub` hook at write time (NFR-03). |
| CI credentials | Masked, protected GitLab CI variables. Never in `.gitlab-ci.yml` itself (`F243`). |
| Detection | The `detect-secrets` hook scans every write; the `claude:review` job flags anything that slips past. |

**Required variables**

| Variable | Purpose | Default |
|---|---|---|
| `JWT_SECRET_KEY` | HS256 signing key | **none — required, no fallback** |
| `DATABASE_URL` | SQLAlchemy URL | `sqlite:///./banking.db` |
| `JWT_EXPIRY_MINUTES` | Access-token lifetime | `30` |
| `STATEMENT_PAGE_SIZE` | Default pagination size | `20` |
| `LOG_LEVEL` | Root log level | `INFO` |

No configuration key exists for a transfer cap, daily limit, velocity control or loan eligibility
threshold, and none may be added (`F009`, DD-14).

---

## 6. Rollback procedure

### 6.1 Application rollback — revert the merge

Every change lands on `main` through a `git merge --no-ff` merge commit (PR-Only Merge rule,
M-10, M-11). Rollback is therefore a single operation:

```bash
git checkout main
git revert -m 1 <merge-commit-sha>     # -m 1 keeps main's first parent
git push origin main                    # via a merge request, per the PR-Only Merge rule
```

The revert is itself a commit, so the history stays append-only and the incident remains visible.
Redeploying is `./init.sh` again — there is no deployment artefact to roll back, only source.

### 6.2 Database rollback — **forward fix only, never a migration edit** (NFR-05)

**Alembic migrations in this project are append-only. A shipped migration is never edited, and
`alembic downgrade` is not the operational rollback path.**

This is NFR-05 and it is not negotiable. The reasons:

- A shipped revision has already run against a database somewhere. Editing it makes the recorded
  revision hash disagree with the file, and any environment that ran the old version can never be
  brought to a consistent state again.
- `downgrade()` functions exist for completeness and local experimentation only. Depending on one
  in an incident means trusting reverse logic that has never been exercised against real data.
- The audit ledger is append-only by design (NFR-02). A schema rollback that dropped or rewrote
  `audit_entries` would defeat the guarantee the whole system is built to provide.

**The procedure when a shipped migration is wrong:**

1. Leave the bad revision in place. Do not edit it, do not delete it, do not rewrite its hash.
2. Write a **new** forward revision that corrects the schema — add the missing index, widen the
   column, drop the mistaken constraint, backfill the wrong data.
3. Land it through the normal merge-request path with tests.
4. `alembic upgrade head` moves every environment forward to the corrected state.

`test_migration_history.py` asserts the policy mechanically: revision files are only ever added,
and `alembic upgrade head` from an empty database produces the full schema in `data-models.md`
(`F022`).

### 6.3 Local reset

For local development only, a full reset is cheap and is not a rollback procedure:

```bash
rm -f backend/banking.db
cd backend && uv run alembic upgrade head && uv run python scripts/seed.py
```

---

## 7. Deployment checklist

Before a merge to `main` is accepted:

- [ ] `./init.sh` brings the stack up from a clean checkout; both health checks report OK
- [ ] `/health` returns 200 within 1s of successful startup
- [ ] All ten ACs pass, each with at least one test carrying its `AC-NN` identifier
- [ ] All eight NFRs are enforced by a hook, a structural test or a unit test — not by convention
- [ ] Coverage is at or above 80% on both workspaces and the artefact is committed
- [ ] `ruff`, `mypy --strict`, `eslint` and `tsc --noEmit` are all clean
- [ ] `tests/architecture/` passes — at least three structural tests, zero layering violations
- [ ] The Playwright suite is green and snapshots at 375 / 768 / 1440 are committed and stable
- [ ] `.gitlab-ci.yml` passes on `main`
- [ ] The merge is `--no-ff`; there are zero direct commits to `main`
- [ ] No new revision edits an existing migration file
- [ ] No secret, key or token appears in the diff
