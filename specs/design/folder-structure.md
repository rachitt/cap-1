# Folder Structure — ClaudeForge Banking Suite

| Field | Value |
|---|---|
| Document | `specs/design/folder-structure.md` |
| Authority | Agrees with `.claude/architecture.md` (layer rules) and with the **Primary paths** field of all 40 story files. Every path a story names appears below verbatim. |
| Version | 1.0 |
| Date | 2026-08-19 |

Directories that already exist in the repository are marked **[exists]**. Everything else is
created by the story named in the annotation.

---

## 1. Repository root

```
capstone-1/
├── .claude/                     [exists] Harness + banking substrate (agents, skills, commands, hooks, state)
├── .gitlab-ci.yml                        CI pipeline: build, test, coverage gate, Claude Code Action   [E8-S4]
├── .gitignore                   [exists] Excludes .env, node_modules, __pycache__, *.db, coverage output
├── .mcp.json                             Playwright MCP server declaration — mandatory deliverable      [E9-S1]
├── AGENTS.md                             Table of contents only; points at the CLAUDE.md hierarchy      [E9-S4]
├── CLAUDE.md                    [exists] Root project rules; references specs/app_spec.md, does not restate it [E9-S4]
├── README.md                             Quick start: prerequisites, ./init.sh, seeded admin credentials [E8-S3]
├── backend/                              FastAPI application — layers 1..5
├── calibration-profile.json     [exists] Design ratchet weights and thresholds (authoritative at 8)
├── claude-progress.txt          [exists] Session recovery breadcrumb
├── design.md                    [exists] Harness design guidance
├── docs/                        [exists] Engineering documentation set
├── e2e/                         [exists] Playwright end-to-end suite and committed snapshots
├── features.json                [exists] 267 routing targets, one per verifiable feature
├── frontend/                             React + Vite SPA — layer 6
├── init.sh                      [exists] Single-command bootstrap; modified by [E8-S3]
├── plugin.json                           Root manifest packaging the banking substrate                  [E9-S3]
├── project-manifest.json        [exists] Fixed stack, ports, thresholds, health-check URL
├── scripts/                     [exists] Programmatic Claude Agent SDK usage
├── specs/                       [exists] BRD, stories, design, reviews, test artefacts
├── sprint-contracts/            [exists] One contract per harness sprint cycle
└── tests/                       [exists] Cross-workspace architecture structural tests
```

---

## 2. `backend/` — FastAPI, layers 1 through 5

```
backend/
├── .env.example                          Every required variable with placeholder values only          [E1-S2]
├── .importlinter                         Layer-order contract: types → config → repository → service → api [E8-S1]
├── CLAUDE.md                             Backend-local rules: Decimal only, no float, transaction ownership [E9-S4]
├── pyproject.toml                        uv project, deps, ruff and mypy strict config, pytest config   [E1-S2]
├── uv.lock                               Locked dependency graph for reproducible CI                     [E1-S2]
├── alembic.ini                           Alembic configuration pointing at src.repository.models        [E1-S4]
├── alembic/                              Append-only migrations (NFR-05)
│   ├── env.py                            Alembic runtime wiring; reads DATABASE_URL from the Config layer [E1-S4]
│   ├── script.py.mako                    Revision template                                               [E1-S4]
│   └── versions/                         One file per revision. A shipped revision is NEVER edited (NFR-05)
│       ├── 0001_baseline_schema.py       All ten tables, indexes, CHECK constraints                       [E1-S4]
│       ├── 0002_audit_append_only.py     BEFORE UPDATE / BEFORE DELETE triggers on audit_entries          [E3-S1]
│       └── 0003_loan_transitions_append_only.py  Same triggers for loan_state_transitions                 [E5-S2]
├── scripts/
│   └── seed.py                           Synthetic seed: 2+ funded customers, a beneficiary, loans in each reviewable state, exactly one admin. Idempotent. [E8-S3]
├── src/
│   ├── __init__.py
│   ├── main.py                           FastAPI app factory, router registration, middleware stack, exception handlers [E1-S5]
│   ├── types/                            LAYER 1 — imports NOTHING from the project
│   │   ├── __init__.py                   Public re-exports for every enum, model and error               [E1-S1]
│   │   ├── enums.py                      Role, CustomerStatus, KycStatus, AccountStatus, TransactionDirection, TransferStatus, LoanStatus, NotificationStatus [E1-S1]
│   │   ├── models.py                     Pydantic value objects for every entity in data-models.md       [E1-S1]
│   │   └── errors.py                     DomainError hierarchy, each subclass carrying a machine-readable error_code [E1-S1]
│   ├── domain/                           LAYER 1 SIBLING — pure policy; imports only stdlib and src.types; no I/O
│   │   ├── __init__.py
│   │   ├── money.py                      parse_money, quantize_money, require_positive, require_non_negative, format_money [E1-S3]
│   │   ├── kyc_policy.py                 Document validation and the deterministic stub verdict. No age or DOB gate. [E2-S1]
│   │   ├── transfer_policy.py            Positive, ≤2dp, not self, destination active, sufficient funds. No cap, no beneficiary check. [E4-S1]
│   │   └── loan_eligibility_policy.py    State-transition matrix, assert_decision_reason, structural input validation only. No eligibility rule. [E5-S1]
│   ├── config/                           LAYER 2 — imports types only
│   │   ├── __init__.py
│   │   └── settings.py                   Settings: jwt_secret_key (env, no fallback), jwt_expiry_minutes, database_url, statement_page_size. No business thresholds. [E1-S2]
│   ├── repository/                       LAYER 3 — imports types and config only
│   │   ├── __init__.py
│   │   ├── models.py                     SQLAlchemy declarative models for all ten tables                 [E1-S4]
│   │   ├── money_type.py                 MoneyType TypeDecorator over Numeric(18,2); returns Decimal on read [E1-S4]
│   │   ├── session.py                    Engine, session factory, transactional scope, PRAGMA wiring      [E1-S4]
│   │   ├── customer_repository.py        create_customer, get_by_email, get_by_id                         [E2-S2]
│   │   ├── kyc_repository.py             create, mark_verified, mark_rejected, get_latest_for_customer    [E2-S2]
│   │   ├── account_repository.py         create_account, get_for_update (row lock), get_by_account_number, debit, credit [E3-S2]
│   │   ├── transaction_repository.py     record_transaction, list_statements(account_id, page, page_size) [E3-S2]
│   │   ├── audit_repository.py           append + read only. No update, no delete, no purge. (NFR-02)     [E3-S1]
│   │   ├── beneficiary_repository.py     add, list_active, soft_delete                                     [E4-S2]
│   │   ├── notification_repository.py    enqueue, mark_sent, mark_failed, list_filtered                    [E4-S3]
│   │   └── loan_repository.py            create_application, append_transition, list_transitions, list_by_status, list_for_customer [E5-S2]
│   ├── service/                          LAYER 4 — the only layer that opens a transaction
│   │   ├── __init__.py
│   │   ├── auth_service.py               register, submit_kyc, activate, login, JWT issuance               [E2-S3]
│   │   ├── account_service.py            open_account (audited), list_accounts, get_statements (ownership-checked) [E3-S3]
│   │   ├── beneficiary_service.py        add, list, remove — audited, owner-scoped, soft delete            [E4-S2]
│   │   ├── notification_service.py       enqueue (in-transaction), dispatch (out-of-transaction), stub gateway [E4-S3]
│   │   ├── transfer_service.py           The atomic transfer: lock, re-read, evaluate, debit, credit, audit, enqueue, commit [E4-S4]
│   │   └── loan_service.py               apply, review, approve, reject, disburse — each one transaction   [E5-S3]
│   └── api/                              LAYER 5 — imports types, config, service; NEVER a repository
│       ├── __init__.py
│       ├── errors.py                     DomainError → HTTP status mapping; the DD-10 envelope builder    [E1-S5]
│       ├── dependencies/
│       │   ├── __init__.py
│       │   └── auth.py                   require_principal (401), require_admin (403) — the NFR-04 boundary [E2-S4]
│       ├── middleware/
│       │   ├── __init__.py
│       │   ├── correlation.py            X-Correlation-ID in/out, ContextVar binding (DD-18)              [E1-S5]
│       │   └── logging.py                Structured JSON logs; redaction filter installed at the handler (NFR-03, NFR-06) [E1-S5]
│       ├── dto/
│       │   ├── __init__.py
│       │   ├── common.py                 ErrorEnvelope, FieldError, page envelope, money field type        [E1-S5]
│       │   ├── auth.py                   RegisterRequest, KycRequest, LoginRequest, TokenResponse, Principal [E2-S4]
│       │   ├── accounts.py               OpenAccountRequest, Account, Transaction, PageOfTransaction        [E3-S4]
│       │   ├── payments.py               CreateTransferRequest, Transfer, Beneficiary DTOs                  [E4-S5]
│       │   └── loans.py                  CreateLoanRequest, LoanApplication, LoanDetail, DecisionRequest    [E5-S4]
│       └── routes/
│           ├── __init__.py
│           ├── health.py                 GET /health — unversioned, anonymous, real DB round-trip (DD-17)  [E1-S5]
│           ├── auth.py                   /api/v1/auth/{register,kyc,login,me}                              [E2-S4]
│           ├── accounts.py               /api/v1/accounts, /api/v1/accounts/{id}/statements                 [E3-S4]
│           ├── beneficiaries.py          /api/v1/beneficiaries                                             [E4-S5]
│           ├── transfers.py              /api/v1/transfers                                                 [E4-S5]
│           ├── loans.py                  /api/v1/loans, /api/v1/loans/{id}                                 [E5-S4]
│           ├── admin_loans.py            /api/v1/admin/loans and the four decision actions                 [E5-S4]
│           └── admin_audit.py            /api/v1/admin/audit, /api/v1/admin/notifications — read-only      [E5-S5]
└── tests/                                pytest suite; mirrors src/ package by package
    ├── conftest.py                       Fixtures: temp SQLite, migrated schema, seeded principals, client
    ├── unit/
    │   ├── types/test_enums.py           F001
    │   ├── types/test_errors.py          F002, F003
    │   ├── domain/test_money.py          F012–F017
    │   ├── domain/test_kyc_policy.py     F032–F037
    │   ├── domain/test_transfer_policy.py    F086–F095
    │   ├── domain/test_loan_policy.py    F125–F132
    │   ├── config/test_settings.py       F006–F011
    │   ├── repository/test_money_type.py F018, F019, F023
    │   ├── repository/test_session.py    F020, F021
    │   ├── repository/test_customer_repository.py   F038–F040
    │   ├── repository/test_kyc_repository.py        F041, F042
    │   ├── repository/test_account_repository.py    F068–F070
    │   ├── repository/test_transaction_repository.py F071–F074
    │   ├── repository/test_audit_repository.py      F061–F067
    │   ├── repository/test_loan_repository.py       F133–F138
    │   ├── service/test_auth_service.py             F043–F050
    │   ├── service/test_account_service.py          F075–F079
    │   ├── service/test_beneficiary_service.py      F096–F101
    │   ├── service/test_notification_service.py     F102–F107
    │   ├── service/test_transfer_service.py         F108–F115
    │   └── service/test_loan_service.py             F139–F148
    ├── api/
    │   ├── test_health.py                F025–F029
    │   ├── test_logging_redaction.py     F030, F031
    │   ├── test_auth_routes.py           F051–F060
    │   ├── test_account_routes.py        F080–F085
    │   ├── test_payment_routes.py        F116–F124
    │   ├── test_loan_routes.py           F149–F159
    │   └── test_admin_audit_routes.py    F160–F166
    └── migrations/
        └── test_migration_history.py     Alembic append-only policy; upgrade head from empty (F022, NFR-05)
```

---

## 3. `frontend/` — React + Vite, layer 6

```
frontend/
├── .dependency-cruiser.cjs               Frontend module-boundary rules; zero violations required        [E8-S1]
├── .eslintrc.cjs                         eslint config; no raw hex literals rule                          [E6-S1]
├── CLAUDE.md                             Frontend-local rules: money is a string, never compute on it     [E9-S4]
├── index.html                            Vite entry document                                              [E6-S1]
├── package.json                          Scripts: dev, build, test, lint, typecheck, generate:api         [E6-S1]
├── package-lock.json                     Locked dependency graph                                          [E6-S1]
├── tsconfig.json                         Strict TypeScript; zero implicit any                             [E6-S1]
├── vite.config.ts                        Port 3000, proxy /api → http://localhost:8000                    [E6-S1]
├── vitest.config.ts                      jsdom environment, Testing Library, coverage reporter            [E6-S1]
└── src/
    ├── main.tsx                          React root, providers, router mount                              [E6-S1]
    ├── app/
    │   ├── App.tsx                       Layout shell, semantic landmarks, skip link                      [E6-S1]
    │   ├── router.tsx                    Route table; customer and admin route guards                     [E6-S1]
    │   └── session.tsx                   Bearer token storage, principal context, 401 redirect            [E6-S1]
    ├── design/
    │   ├── tokens.ts                     Horizon Bank palette, type scale, spacing, elevation, radii (DD-20) [E6-S1]
    │   ├── global.css                    Reset, CSS custom properties from tokens, focus-visible rings    [E6-S1]
    │   └── typography.css                Tabular-figures face for money; heading scale                    [E6-S1]
    ├── lib/
    │   ├── api/
    │   │   ├── schema.d.ts               GENERATED by openapi-typescript. Never hand-edited (DD-12)       [E6-S1]
    │   │   └── client.ts                 Typed fetch wrapper; attaches bearer; maps the DD-10 error envelope [E6-S1]
    │   └── money/
    │       └── formatMoney.ts            Decimal string in, grouped 2dp string out. No arithmetic. (DD-12, NFR-01) [E6-S1]
    ├── components/
    │   ├── Money.tsx                     Renders a money string with tabular figures and AA contrast      [E6-S1]
    │   ├── Button.tsx, Field.tsx         Primitives with associated labels and aria-describedby errors    [E6-S1]
    │   ├── Alert.tsx                     Status messaging with an aria-live region                        [E6-S1]
    │   ├── DataTable.tsx                 Responsive tabular surface for admin screens                     [E6-S1]
    │   ├── Pagination.tsx                page / page_size / total controls (DD-11)                        [E6-S1]
    │   └── EmptyState.tsx                Explicit empty states, never a blank panel                       [E6-S1]
    ├── pages/
    │   ├── Register.tsx                  AC-01 registration form                                          [E6-S2]
    │   ├── Kyc.tsx                       AC-01 KYC submission and verdict                                 [E6-S2]
    │   ├── Login.tsx                     AC-01 login; distinct KYC-pending vs invalid-credentials states  [E6-S2]
    │   ├── Dashboard.tsx                 AC-02/AC-03 accounts, balances, open-account action              [E6-S3]
    │   ├── AccountDetail.tsx             AC-03 balance plus paginated statement                           [E6-S3]
    │   ├── Beneficiaries.tsx             AC-06 list, add, remove saved payees                             [E6-S4]
    │   ├── Transfer.tsx                  AC-04/AC-05. Account-number field is always directly editable; a saved beneficiary is an optional autofill shortcut only (DD-13) [E6-S4]
    │   ├── Loans.tsx                     AC-07 application form and status timeline                       [E6-S5]
    │   └── admin/
    │       ├── LoanQueue.tsx             AC-08 filterable queue; approve/reject blocked without a reason  [E7-S1]
    │       ├── AuditLog.tsx              AC-09 read-only ledger; no edit or delete affordance             [E7-S2]
    │       └── Notifications.tsx         AC-10 dispatched notification log                                 [E7-S2]
    └── __tests__/                        vitest component tests, one file per page and per primitive      [E6-S2..E7-S3]
```

---

## 4. `tests/` — cross-workspace structural tests

```
tests/
└── architecture/                [exists] NFR-08 in executable form; run by the default test command
    ├── test_layer_dependencies.py        import-linter contract passes; an injected upward import fails it (F223, F224) [E8-S1]
    ├── test_no_controller_repository.py  No api/routes/* module imports a repository module (F225)         [E8-S1]
    ├── test_domain_purity.py             domain/ imports only stdlib and src.types; no I/O (F226)          [E8-S1]
    ├── test_frontend_boundaries.py       Runs dependency-cruiser; asserts zero violations (F227)           [E8-S1]
    └── test_route_auth_coverage.py       Every route except health, register and login carries an auth dependency (NFR-04) [E8-S1]
```

---

## 5. `e2e/` — Playwright

```
e2e/                             [exists]
├── playwright.config.ts                  Projects at 375, 768 and 1440; baseURL http://localhost:3000     [E9-S1]
├── fixtures/seeded.ts                    Seeded synthetic principals and account numbers                  [E9-S1]
├── specs/
│   ├── ac01-onboarding.spec.ts           Register → KYC → login                                            [E9-S1]
│   ├── ac02-ac03-accounts.spec.ts        Open account at 0.00; paginated statement                         [E9-S1]
│   ├── ac04-ac05-transfer.spec.ts        Money conservation in the browser; unmistakable insufficient-funds state [E9-S1]
│   ├── ac06-beneficiaries.spec.ts        Add, list, remove; transfer without a saved beneficiary succeeds  [E9-S1]
│   ├── ac07-loans.spec.ts                Apply and follow the status timeline                              [E9-S1]
│   ├── ac08-admin-queue.spec.ts          Review, approve/reject with a mandatory reason, disburse          [E9-S1]
│   ├── ac09-audit.spec.ts                Filterable read-only ledger                                       [E9-S1]
│   ├── ac10-notifications.spec.ts        Transfer and loan notifications appear                            [E9-S1]
│   └── a11y.spec.ts                      axe scan; zero serious or critical violations (F217)              [E7-S3]
└── snapshots/                            Committed UI snapshots at 375 / 768 / 1440 (M-27, F249)           [E9-S1]
```

---

## 6. `scripts/` — programmatic Claude Agent SDK

```
scripts/                         [exists]
├── ac_coverage_audit.py                  Imports the Claude Agent SDK and drives an agent programmatically; audits AC-NN coverage across tests and writes an artefact. Credentials from the environment. (M-22) [E9-S2]
└── README.md                             How to run it, including the dry-run mode                         [E9-S2]
```

---

## 7. `docs/` — engineering documentation set

```
docs/                            [exists]
├── business-case.md             [exists] Business context the reviewer plugin reads (gap G-01, closed)
├── architecture.md                       Rendered diagram of the six layers plus the cross-cutting audit and notification modules [E9-S5]
├── tdd.md                                Test-first discipline with a concrete red-then-green worked example [E9-S5]
├── knowledge-deposits.md                 Reusable lessons, cross-referenced to .claude/state/learned-rules.md [E9-S5]
└── fix-loops/                   [exists] One file per recorded autonomous fix loop: detect → reproduce → fix → validate → PR [E9-S5]
```

---

## 8. `specs/` — the specification substrate

```
specs/                           [exists]
├── app_spec.md                           Authoritative statement of AC-01..AC-10 and NFR-01..NFR-08. CLAUDE.md references it rather than restating it. [E9-S4]
├── brd/brd.md                   [exists] Approved BRD — wins under Spec-Is-Truth
├── stories/                     [exists] E1-S1.md .. E9-S5.md (40 files) plus dependency-graph.md
├── design/                      [exists] This phase's output
│   ├── architecture-brainstorm.md  [exists] DD-01..DD-20
│   ├── system-design.md                  Components, layers, data flows, design decisions, traceability
│   ├── api-contracts.md                  Every endpoint in full
│   ├── api-contracts.schema.json         OpenAPI 3.0.3
│   ├── data-models.md                    Every entity in full, plus triggers and the transition matrix
│   ├── data-models.schema.json           JSON Schema draft-07
│   ├── folder-structure.md               This document
│   ├── component-map.md                  All 40 story IDs → files
│   ├── deployment.md                     Environments, CI, bootstrap, secrets, coverage gate, rollback
│   ├── amendments/              [exists] Post-approval design amendments, one file each
│   └── mockups/                 [exists] ui-designer output; tokens reused from frontend/src/design
├── reviews/                     [exists] Evaluator outputs, including the Playwright MCP evidence artefact (F246)
└── test_artefacts/              [exists] Test corpus directory named by project-manifest.json
```

---

## 9. `.claude/` — the agent substrate

```
.claude/                         [exists]
├── .claude-plugin/plugin.json   [exists] Harness foundation manifest — DISTINCT from the root plugin.json (G-03)
├── architecture.md              [exists] Layer rules enforced by check-architecture.js at write time
├── program.md                   [exists] Human control knobs
├── settings.json                [exists] NOT modified by any agent (BRD A-10, R-07)
├── agents/                      [exists] design-critic, evaluator, generator, planner, security-reviewer, test-engineer, ui-designer
│   ├── ledger-auditor.md                 Banking agent: audits append-only guarantees end to end          [E8-S2]
│   └── money-precision-auditor.md        Banking agent: hunts float leakage across every layer            [E8-S2]
├── commands/                    [exists] scaffold.md
│   ├── audit-trail.md                    Banking command: trace one entity through the ledger             [E8-S2]
│   └── money-check.md                    Banking command: sweep the repo for money-precision violations   [E8-S2]
├── hooks/                       [exists] check-architecture, check-file-length, detect-secrets, lint-on-save, protect-env, scope-directory, track-writes, typecheck, ...
│   ├── money-precision-check.js          Blocks float( , : float on a money field, %f in backend source (F228) [E8-S2]
│   ├── audit-immutability-check.js       Blocks UPDATE/DELETE or ORM mutation against audit tables (F229)  [E8-S2]
│   └── pii-scrub.js                      Blocks writes that log a password, token or document number (F230) [E8-S2]
├── skills/                      [exists] Harness skills
│   ├── banking-domain/SKILL.md           Money, audit and transfer invariants as reusable guidance        [E8-S2]
│   └── audit-ledger/SKILL.md             How to append correctly and why nothing may mutate                [E8-S2]
├── state/                       [exists] coverage-baseline.txt, eval-scores.json, failures.md, iteration-log.md, learned-rules.md
└── templates/                   [exists] docker-compose, features-template, init-sh, playwright.config, sprint-contract
```

---

## 10. Notes for the builder agents

1. **`backend/alembic/`, not `backend/migrations/`.** Story `E1-S4` fixes the path as
   `backend/alembic/`. The existing `init.sh` currently probes `backend/migrations`; `E8-S3` owns
   `init.sh` and must update that probe to `backend/alembic` or the migration step is silently
   skipped and the app starts against an empty database.
2. **`src/domain/` is a Layer-1 sibling, not a subpackage of `service/`.** It appears under
   `backend/src/` at the same level as `types/`. `tests/architecture/test_domain_purity.py`
   asserts it imports only the standard library and `src.types`.
3. **`api/routes/*` must never import `src.repository`.** Route handlers call services only;
   `tests/architecture/test_no_controller_repository.py` fails the build otherwise.
4. **`frontend/src/lib/api/schema.d.ts` is generated.** Do not hand-edit it. `npm run generate:api`
   regenerates it from `http://localhost:8000/openapi.json` (DD-12).
5. **Migration files are append-only.** Never edit a shipped revision; add a new one (NFR-05).
6. **Files under 300 lines, functions under 50.** The `check-file-length` and
   `check-function-length` hooks block writes at the hard limit for `.py`, `.ts` and `.tsx`.
7. **A `CLAUDE.md` lives at each of `backend/` and `frontend/`** with layer-local rules; root
   `AGENTS.md` is a table of contents only (IN-21).
