# Component Map — ClaudeForge Banking Suite

| Field | Value |
|---|---|
| Document | `specs/design/component-map.md` |
| Coverage | **All 40 story IDs** from `specs/stories/`, in execution-group order |
| Layer and Group | Taken from `specs/stories/dependency-graph.md` |
| Version | 1.0 |
| Date | 2026-08-19 |

Every story ID in `specs/stories/` appears in exactly one row. A missing row would leave a
builder agent guessing a path, so this table is the routing contract: paths here are the paths
the story's **Primary paths** field names, expanded to the full set of files that story touches.

Paths are repository-relative. `<br>` separates entries within a cell.

---

## Group A — 4 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E1-S1` | Define core domain types, enums and typed error hierarchy | Types | A | `backend/src/types/__init__.py`<br>`backend/src/types/enums.py`<br>`backend/src/types/models.py`<br>`backend/src/types/errors.py` | — | `backend/tests/unit/types/test_enums.py`<br>`backend/tests/unit/types/test_errors.py` |
| `E1-S2` | Provide the Config layer with environment-sourced secrets and runtime settings | Config | A | `backend/src/config/__init__.py`<br>`backend/src/config/settings.py`<br>`backend/.env.example`<br>`backend/pyproject.toml`<br>`backend/uv.lock` | `.gitignore` | `backend/tests/unit/config/test_settings.py` |
| `E8-S2` | Layer the banking-specific substrate of hooks, skills, commands and agents | Config | A | `.claude/hooks/money-precision-check.js`<br>`.claude/hooks/audit-immutability-check.js`<br>`.claude/hooks/pii-scrub.js`<br>`.claude/skills/banking-domain/SKILL.md`<br>`.claude/skills/audit-ledger/SKILL.md`<br>`.claude/commands/money-check.md`<br>`.claude/commands/audit-trail.md`<br>`.claude/agents/money-precision-auditor.md`<br>`.claude/agents/ledger-auditor.md` | — | `tests/substrate/test_banking_hooks.py` |
| `E9-S4` | Make `specs/app_spec.md` the authoritative AC and NFR source and de-duplicate CLAUDE.md | Config | A | `specs/app_spec.md`<br>`AGENTS.md`<br>`backend/CLAUDE.md`<br>`frontend/CLAUDE.md` | `CLAUDE.md` | `tests/substrate/test_spec_authority.py` |

## Group B — 5 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E1-S3` | Implement the pure money domain policy enforcing fixed-point arithmetic | Types | B | `backend/src/domain/__init__.py`<br>`backend/src/domain/money.py` | — | `backend/tests/unit/domain/test_money.py` |
| `E1-S4` | Establish the persistence foundation with a Decimal-preserving column type and Alembic baseline | Repository | B | `backend/src/repository/__init__.py`<br>`backend/src/repository/models.py`<br>`backend/src/repository/money_type.py`<br>`backend/src/repository/session.py`<br>`backend/alembic.ini`<br>`backend/alembic/env.py`<br>`backend/alembic/script.py.mako`<br>`backend/alembic/versions/0001_baseline_schema.py` | `backend/pyproject.toml` | `backend/tests/unit/repository/test_money_type.py`<br>`backend/tests/unit/repository/test_session.py`<br>`backend/tests/migrations/test_migration_history.py` |
| `E2-S1` | Implement the KYC domain policy with deterministic stub verification | Types | B | `backend/src/domain/kyc_policy.py` | — | `backend/tests/unit/domain/test_kyc_policy.py` |
| `E9-S2` | Add a programmatic Claude Agent SDK script | Config | B | `scripts/ac_coverage_audit.py`<br>`scripts/README.md` | `backend/pyproject.toml` | `tests/substrate/test_sdk_script.py` |
| `E9-S3` | Package the banking substrate as a root `plugin.json` | Config | B | `plugin.json` | — | `tests/substrate/test_root_plugin_manifest.py` |

## Group C — 9 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E1-S5` | Deliver the observability spine: health endpoint, JSON logs, correlation ID and PII redaction | API | C | `backend/src/main.py`<br>`backend/src/api/__init__.py`<br>`backend/src/api/errors.py`<br>`backend/src/api/middleware/__init__.py`<br>`backend/src/api/middleware/correlation.py`<br>`backend/src/api/middleware/logging.py`<br>`backend/src/api/routes/__init__.py`<br>`backend/src/api/routes/health.py`<br>`backend/src/api/dto/__init__.py`<br>`backend/src/api/dto/common.py` | — | `backend/tests/api/test_health.py`<br>`backend/tests/api/test_logging_redaction.py` |
| `E2-S2` | Build customer and KYC record repositories | Repository | C | `backend/src/repository/customer_repository.py`<br>`backend/src/repository/kyc_repository.py` | `backend/src/repository/models.py` | `backend/tests/unit/repository/test_customer_repository.py`<br>`backend/tests/unit/repository/test_kyc_repository.py` |
| `E3-S1` | Build the append-only audit ledger with repository, trigger and hook enforcement | Repository | C | `backend/src/repository/audit_repository.py`<br>`backend/alembic/versions/0002_audit_append_only.py` | `backend/src/repository/models.py` | `backend/tests/unit/repository/test_audit_repository.py` |
| `E3-S2` | Build account and transaction repositories with balance locking support | Repository | C | `backend/src/repository/account_repository.py`<br>`backend/src/repository/transaction_repository.py` | `backend/src/repository/models.py` | `backend/tests/unit/repository/test_account_repository.py`<br>`backend/tests/unit/repository/test_transaction_repository.py` |
| `E4-S1` | Implement the transfer domain policy | Types | C | `backend/src/domain/transfer_policy.py` | — | `backend/tests/unit/domain/test_transfer_policy.py` |
| `E4-S3` | Build the notification module with in-transaction enqueue and out-of-transaction dispatch | Service | C | `backend/src/repository/notification_repository.py`<br>`backend/src/service/__init__.py`<br>`backend/src/service/notification_service.py` | `backend/src/repository/models.py` | `backend/tests/unit/service/test_notification_service.py` |
| `E5-S1` | Implement the loan policy: state machine, structural validation and mandatory reason | Types | C | `backend/src/domain/loan_eligibility_policy.py` | — | `backend/tests/unit/domain/test_loan_policy.py` |
| `E5-S2` | Build loan application and append-only state transition repositories | Repository | C | `backend/src/repository/loan_repository.py`<br>`backend/alembic/versions/0003_loan_transitions_append_only.py` | `backend/src/repository/models.py` | `backend/tests/unit/repository/test_loan_repository.py` |
| `E8-S1` | Enforce the layered architecture with structural tests | Config | C | `backend/.importlinter`<br>`frontend/.dependency-cruiser.cjs`<br>`tests/architecture/test_layer_dependencies.py`<br>`tests/architecture/test_no_controller_repository.py`<br>`tests/architecture/test_domain_purity.py`<br>`tests/architecture/test_frontend_boundaries.py`<br>`tests/architecture/test_route_auth_coverage.py` | `backend/pyproject.toml` | `tests/architecture/` (the five files listed, run by the default test command) |

## Group D — 3 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E2-S3` | Implement the auth service: registration, KYC submission, activation and JWT issuance | Service | D | `backend/src/service/auth_service.py` | `backend/pyproject.toml` (KDF and JWT deps) | `backend/tests/unit/service/test_auth_service.py` |
| `E3-S3` | Implement the account service with ownership checks and audited account opening | Service | D | `backend/src/service/account_service.py` | — | `backend/tests/unit/service/test_account_service.py` |
| `E4-S2` | Implement beneficiary management as an independent convenience feature | Service | D | `backend/src/repository/beneficiary_repository.py`<br>`backend/src/service/beneficiary_service.py` | `backend/src/repository/models.py` | `backend/tests/unit/service/test_beneficiary_service.py` |

## Group E — 3 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E2-S4` | Expose auth routes and the bearer-token authentication and role guard | API | E | `backend/src/api/routes/auth.py`<br>`backend/src/api/dependencies/__init__.py`<br>`backend/src/api/dependencies/auth.py`<br>`backend/src/api/dto/auth.py` | `backend/src/main.py` | `backend/tests/api/test_auth_routes.py` |
| `E4-S4` | Implement the atomic transfer service with row locking and full rollback | Service | E | `backend/src/service/transfer_service.py` | — | `backend/tests/unit/service/test_transfer_service.py` |
| `E5-S3` | Implement the loan service covering application, review decisions and disbursement | Service | E | `backend/src/service/loan_service.py` | — | `backend/tests/unit/service/test_loan_service.py` |

## Group F — 6 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E3-S4` | Expose authenticated account and statement endpoints | API | F | `backend/src/api/routes/accounts.py`<br>`backend/src/api/dto/accounts.py` | `backend/src/main.py` | `backend/tests/api/test_account_routes.py` |
| `E4-S5` | Expose transfer and beneficiary endpoints with precise failure codes | API | F | `backend/src/api/routes/transfers.py`<br>`backend/src/api/routes/beneficiaries.py`<br>`backend/src/api/dto/payments.py` | `backend/src/main.py`<br>`backend/src/api/errors.py` | `backend/tests/api/test_payment_routes.py` |
| `E5-S4` | Expose customer loan endpoints and the admin review queue | API | F | `backend/src/api/routes/loans.py`<br>`backend/src/api/routes/admin_loans.py`<br>`backend/src/api/dto/loans.py` | `backend/src/main.py`<br>`backend/src/api/errors.py` | `backend/tests/api/test_loan_routes.py` |
| `E5-S5` | Expose the admin audit ledger and notification log viewers | API | F | `backend/src/api/routes/admin_audit.py` | `backend/src/main.py`<br>`backend/src/api/dto/common.py` | `backend/tests/api/test_admin_audit_routes.py` |
| `E6-S1` | Establish the frontend foundation, design tokens and generated API types | UI | F | `frontend/package.json`<br>`frontend/package-lock.json`<br>`frontend/tsconfig.json`<br>`frontend/vite.config.ts`<br>`frontend/vitest.config.ts`<br>`frontend/.eslintrc.cjs`<br>`frontend/index.html`<br>`frontend/src/main.tsx`<br>`frontend/src/app/App.tsx`<br>`frontend/src/app/router.tsx`<br>`frontend/src/app/session.tsx`<br>`frontend/src/design/tokens.ts`<br>`frontend/src/design/global.css`<br>`frontend/src/design/typography.css`<br>`frontend/src/lib/api/schema.d.ts` (generated)<br>`frontend/src/lib/api/client.ts`<br>`frontend/src/lib/money/formatMoney.ts`<br>`frontend/src/components/{Money,Button,Field,Alert,DataTable,Pagination,EmptyState}.tsx` | `init.sh` | `frontend/src/__tests__/formatMoney.test.ts`<br>`frontend/src/__tests__/client.test.ts`<br>`frontend/src/__tests__/tokens.test.ts` |
| `E8-S3` | Deliver synthetic seed data and the single-command local run | Config | F | `backend/scripts/seed.py`<br>`README.md` | `init.sh` (probe `backend/alembic`, seed, health checks) | `backend/tests/integration/test_seed.py`<br>`tests/delivery/test_init_script.py` |

## Group G — 7 stories

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E6-S2` | Build the registration, KYC submission and login screens | UI | G | `frontend/src/pages/Register.tsx`<br>`frontend/src/pages/Kyc.tsx`<br>`frontend/src/pages/Login.tsx` | `frontend/src/app/router.tsx` | `frontend/src/__tests__/Register.test.tsx`<br>`frontend/src/__tests__/Kyc.test.tsx`<br>`frontend/src/__tests__/Login.test.tsx` |
| `E6-S3` | Build the dashboard and account detail screens | UI | G | `frontend/src/pages/Dashboard.tsx`<br>`frontend/src/pages/AccountDetail.tsx` | `frontend/src/app/router.tsx` | `frontend/src/__tests__/Dashboard.test.tsx`<br>`frontend/src/__tests__/AccountDetail.test.tsx` |
| `E6-S4` | Build the beneficiaries and transfer screens | UI | G | `frontend/src/pages/Beneficiaries.tsx`<br>`frontend/src/pages/Transfer.tsx` | `frontend/src/app/router.tsx` | `frontend/src/__tests__/Beneficiaries.test.tsx`<br>`frontend/src/__tests__/Transfer.test.tsx` |
| `E6-S5` | Build the customer loans screen with application and status timeline | UI | G | `frontend/src/pages/Loans.tsx` | `frontend/src/app/router.tsx` | `frontend/src/__tests__/Loans.test.tsx` |
| `E7-S1` | Build the administrator loan review queue | UI | G | `frontend/src/pages/admin/LoanQueue.tsx` | `frontend/src/app/router.tsx` | `frontend/src/__tests__/admin/LoanQueue.test.tsx` |
| `E7-S2` | Build the administrator audit ledger and notification log viewers | UI | G | `frontend/src/pages/admin/AuditLog.tsx`<br>`frontend/src/pages/admin/Notifications.tsx` | `frontend/src/app/router.tsx` | `frontend/src/__tests__/admin/AuditLog.test.tsx`<br>`frontend/src/__tests__/admin/Notifications.test.tsx` |
| `E8-S4` | Wire the GitLab CI pipeline with build, test and coverage gates | Config | G | `.gitlab-ci.yml` | `.claude/state/coverage-baseline.txt` | `tests/delivery/test_ci_config.py` |

## Group H — 1 story

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E7-S3` | Complete the responsive layout and WCAG 2.1 AA accessibility pass | UI | H | `frontend/src/design/breakpoints.ts`<br>`frontend/src/design/a11y.css`<br>`e2e/specs/a11y.spec.ts` | `frontend/src/design/tokens.ts`<br>`frontend/src/design/global.css`<br>`frontend/src/app/App.tsx`<br>`frontend/src/components/DataTable.tsx`<br>all nine files under `frontend/src/pages/` and `frontend/src/pages/admin/` | `frontend/src/__tests__/a11y.landmarks.test.tsx`<br>`e2e/specs/a11y.spec.ts` |

## Group I — 1 story

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E9-S1` | Configure Playwright MCP and prove the evaluator exercises it | UI | I | `.mcp.json`<br>`e2e/playwright.config.ts`<br>`e2e/fixtures/seeded.ts`<br>`e2e/specs/ac01-onboarding.spec.ts`<br>`e2e/specs/ac02-ac03-accounts.spec.ts`<br>`e2e/specs/ac04-ac05-transfer.spec.ts`<br>`e2e/specs/ac06-beneficiaries.spec.ts`<br>`e2e/specs/ac07-loans.spec.ts`<br>`e2e/specs/ac08-admin-queue.spec.ts`<br>`e2e/specs/ac09-audit.spec.ts`<br>`e2e/specs/ac10-notifications.spec.ts`<br>`e2e/snapshots/` (375 / 768 / 1440)<br>`specs/reviews/playwright-mcp-evidence.md` | `frontend/package.json` | `e2e/specs/` (the eight AC journey specs) |

## Group J — 1 story

| Story ID | Title | Layer | Group | Files created | Files modified | Test files |
|---|---|---|---|---|---|---|
| `E9-S5` | Produce the engineering documentation set and record an autonomous fix loop | Config | J | `docs/architecture.md`<br>`docs/tdd.md`<br>`docs/knowledge-deposits.md`<br>`docs/fix-loops/<NNN>-<slug>.md`<br>`sprint-contracts/sprint-01.json`<br>`sprint-contracts/sprint-02.json` | `.claude/state/learned-rules.md`<br>`claude-progress.txt` | `tests/delivery/test_docs_completeness.py` |

---

## Coverage check

| Group | Story IDs | Count |
|---|---|---|
| A | `E1-S1`, `E1-S2`, `E8-S2`, `E9-S4` | 4 |
| B | `E1-S3`, `E1-S4`, `E2-S1`, `E9-S2`, `E9-S3` | 5 |
| C | `E1-S5`, `E2-S2`, `E3-S1`, `E3-S2`, `E4-S1`, `E4-S3`, `E5-S1`, `E5-S2`, `E8-S1` | 9 |
| D | `E2-S3`, `E3-S3`, `E4-S2` | 3 |
| E | `E2-S4`, `E4-S4`, `E5-S3` | 3 |
| F | `E3-S4`, `E4-S5`, `E5-S4`, `E5-S5`, `E6-S1`, `E8-S3` | 6 |
| G | `E6-S2`, `E6-S3`, `E6-S4`, `E6-S5`, `E7-S1`, `E7-S2`, `E8-S4` | 7 |
| H | `E7-S3` | 1 |
| I | `E9-S1` | 1 |
| J | `E9-S5` | 1 |
| | **Total** | **40** |

All 40 story IDs present. Every story that carries features in root `features.json`
(`F001`..`F267`, all 40 stories) has a row.

---

## Shared-file write order

Four files are written by one story and appended to by several later ones. Because groups execute
in order, the sequence is unambiguous — but a builder agent must **append**, never rewrite:

| File | Created by | Appended to by |
|---|---|---|
| `backend/src/repository/models.py` | `E1-S4` (all ten tables) | `E2-S2`, `E3-S1`, `E3-S2`, `E4-S2`, `E4-S3`, `E5-S2` — each adds only the relationships and constraints its aggregate needs |
| `backend/src/main.py` | `E1-S5` (app factory, middleware, health) | `E2-S4`, `E3-S4`, `E4-S5`, `E5-S4`, `E5-S5` — each registers its router |
| `backend/src/api/errors.py` | `E1-S5` (envelope builder, generic handlers) | `E4-S5`, `E5-S4` — each adds its domain exception mappings |
| `frontend/src/app/router.tsx` | `E6-S1` (shell and guards) | `E6-S2`..`E6-S5`, `E7-S1`, `E7-S2` — each registers its route |
| `init.sh` | already exists | `E6-S1` (frontend install branch), `E8-S3` (migrate against `backend/alembic`, seed, health checks) |

`backend/alembic/versions/` is append-only by policy (NFR-05): `E1-S4`, `E3-S1` and `E5-S2` each
add a **new** revision file and never edit an existing one.
