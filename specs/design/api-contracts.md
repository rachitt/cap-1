# API Contracts — ClaudeForge Banking Suite

| Field | Value |
|---|---|
| Business Case ID | BC-AINE-001 |
| Machine-readable counterpart | `specs/design/api-contracts.schema.json` (OpenAPI 3.0.3) |
| Base URL | `http://localhost:8000` |
| Version prefix | `/api/v1` — except `/health`, which is unversioned infrastructure (DD-17) |
| Auth | JWT bearer, access-token only, 30-minute lifetime, stateless (DD-04) |
| Money on the wire | Decimal **string**, never a JSON number (DD-05, DD-16, NFR-01) |

Where this document and the OpenAPI file disagree, the OpenAPI file is the machine-checkable
one and both must be corrected together. Where this document and the BRD disagree, the BRD
wins (Spec-Is-Truth).

---

## 0. Conventions

### 0.1 Rules that deliberately do not exist

Four rules were proposed during BRD interviewing and explicitly withdrawn. Story-level tests
grep for their identifiers and require zero matches. They must not reappear as a field, a
query parameter, an error code, or a validation message.

| Withdrawn rule | Consequence for this API |
|---|---|
| Transfer cap / daily limit / velocity control | No `daily_limit`, `max_transfer_amount` or `remaining_allowance` field. No `CAP_EXCEEDED` error code. No per-day aggregation endpoint. |
| Beneficiary precondition on transfers | `POST /api/v1/transfers` takes `destination_account_number` **directly**. There is no `beneficiary_id` field on the transfer request and no error code for "not a saved beneficiary". Beneficiaries are an independent convenience feature (AC-06). |
| Minimum applicant age / date-of-birth gate | `date_of_birth` is captured at registration as profile data. No endpoint validates it against an age threshold. |
| Loan eligibility thresholds | No principal bounds, no tenure ceiling, no income requirement, no instalment-to-income ratio, no credit score, no risk band. `declared_monthly_income` is optional and informational and no rule reads it. Loan validation is **structural only**. |

### 0.2 Uniform error envelope (DD-10)

**Every** 4xx and 5xx response in this API uses this shape. There are no exceptions.

```json
{
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Transfer declined: the available balance is lower than the requested amount.",
    "field_errors": [{ "field": "amount", "message": "at most 2 decimal places" }],
    "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE"
  }
}
```

| Key | Type | Notes |
|---|---|---|
| `error.code` | string | Machine-readable, sourced from `DomainError.error_code` (story E1-S1). The UI branches on this, never on prose. |
| `error.message` | string | Human-readable, safe to display. Never contains a credential, token or document number (NFR-03). |
| `error.field_errors` | array \| null | Present only for validation failures. |
| `error.correlation_id` | string | The same id that appears in the structured log line and in `audit_entries.correlation_id` (DD-18). |

**Error code catalogue**

| Code | HTTP | Raised when |
|---|---|---|
| `VALIDATION_ERROR` | 422 | Malformed body or a missing mandatory field |
| `UNAUTHORIZED` | 401 | Missing, malformed or expired bearer token (E-15) |
| `FORBIDDEN` | 403 | Wrong role, or resource owned by another customer (E-14, E-19) |
| `PENDING_KYC` | 403 | Login attempted before KYC verification (E-09) — deliberately distinct from 401 |
| `NOT_FOUND` | 404 | No such resource |
| `EMAIL_ALREADY_REGISTERED` | 409 | Duplicate registration email |
| `KYC_ALREADY_SUBMITTED` | 409 | Second KYC submission (E-10) |
| `DUPLICATE_BENEFICIARY` | 409 | Same account number already saved by this customer |
| `INSUFFICIENT_FUNDS` | 422 | Source balance below the requested amount (AC-05, E-01) |
| `SELF_TRANSFER` | 422 | Source and destination are the same account (E-02) |
| `INACTIVE_ACCOUNT` | 422 / 409 | Destination closed on transfer (E-03); disbursement account closed (E-22) |
| `ACCOUNT_NOT_FOUND` | 404 | Destination account number does not resolve |
| `MONEY_PRECISION` | 422 | Amount is zero, negative, or carries more than 2 decimal places (E-05, E-06) |
| `ILLEGAL_LOAN_TRANSITION` | 409 | State change not legal from the current state (E-11, E-12) |

### 0.3 Pagination (DD-11)

Request `?page=1&size=20`. `page` is 1-based; `size` defaults to 20 and is **capped at 100**, so
an unbounded list is structurally impossible. Response body:

```json
{ "items": [], "page": 1, "size": 20, "total": 0, "total_pages": 0 }
```

Ordering is most-recent-first everywhere (A-06).

### 0.4 Headers

| Header | Direction | Notes |
|---|---|---|
| `Authorization: Bearer <jwt>` | request | Required on every route except `/health`, `/auth/register`, `/auth/kyc`, `/auth/login` |
| `X-Correlation-ID` | request (optional) | Honoured if supplied; otherwise generated at middleware entry |
| `X-Correlation-ID` | response | Always present. Matches the value in the log line and in any audit entry written by the request (DD-18) |
| `Content-Type: application/json` | both | The only supported media type |

### 0.5 Rate limits

**None.** No acceptance criterion requires rate limiting and none is implemented. This is a
deliberate omission recorded here so a builder agent does not invent one. See BRD §11.2.

---

## 1. Health

### `GET /health`

Unversioned, outside `/api/v1`, because `project-manifest.json` hard-codes this exact URL in
`evaluation.health_check` and `verification.health_check.url`.

| | |
|---|---|
| Auth | None |
| Query / body | None |

**200**
```json
{ "status": "ok", "database": "ok", "version": "1.0.0", "uptime_seconds": 12 }
```

Performs a trivial database round-trip and returns within 1s of successful startup (NFR-07).
The evaluator probes it with 5 retries at 2s backoff.

**503** — error envelope, `code: "SERVICE_UNAVAILABLE"`.

---

## 2. Authentication (AC-01)

### `POST /api/v1/auth/register`

| | |
|---|---|
| Auth | None |
| Purpose | Create a customer in status `PENDING_KYC` |

**Request**
```json
{
  "email": "amara.okonjo@example.invalid",
  "password": "correct-horse-battery",
  "full_name": "Amara Okonjo",
  "date_of_birth": "1991-04-22",
  "phone": "+91-90000-00001"
}
```

| Field | Type | Required | Constraint |
|---|---|---|---|
| `email` | string | yes | Valid email, unique case-insensitively |
| `password` | string | yes | 12–128 chars. Hashed with Argon2id. Never echoed, never logged (NFR-03) |
| `full_name` | string | yes | 1–120 chars |
| `date_of_birth` | date | yes | Profile data only — **no minimum-age rule reads this** |
| `phone` | string \| null | no | ≤ 32 chars |

`role` is **not accepted** from the client. Admin accounts are seeded (BRD OUT-11).

**201**
```json
{
  "id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90",
  "email": "amara.okonjo@example.invalid",
  "full_name": "Amara Okonjo",
  "date_of_birth": "1991-04-22",
  "phone": "+91-90000-00001",
  "role": "CUSTOMER",
  "status": "PENDING_KYC",
  "created_at": "2026-08-19T09:02:11Z"
}
```

**409** `EMAIL_ALREADY_REGISTERED` · **422** `VALIDATION_ERROR`

---

### `POST /api/v1/auth/kyc`

| | |
|---|---|
| Auth | None (the customer is not yet able to log in) |
| Purpose | Submit KYC documents; deterministic stub verdict; activate on pass |

**Request**
```json
{
  "email": "amara.okonjo@example.invalid",
  "document_type": "PASSPORT",
  "document_number": "P4471982"
}
```

`document_type` ∈ `PASSPORT` | `NATIONAL_ID` | `DRIVING_LICENCE`.

**Stub behaviour (A-02, deterministic — a random stub would make the failure path untestable):**
a well-formed document number verifies; the reserved synthetic value `REJECT0000000` always
rejects. `document_number` is PII and is redacted from every log line.

**200 — verified**
```json
{
  "id": "b8d0e1f2-3a4b-4c5d-8e9f-0a1b2c3d4e5f",
  "customer_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90",
  "kyc_status": "VERIFIED",
  "customer_status": "ACTIVE",
  "stub_reason": null,
  "verified_at": "2026-08-19T09:04:40Z"
}
```

**200 — rejected**
```json
{
  "id": "b8d0e1f2-3a4b-4c5d-8e9f-0a1b2c3d4e5f",
  "customer_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90",
  "kyc_status": "REJECTED",
  "customer_status": "PENDING_KYC",
  "stub_reason": "Reserved synthetic document number rejected by the verification stub.",
  "verified_at": null
}
```

**404** `NOT_FOUND` · **409** `KYC_ALREADY_SUBMITTED` (E-10) · **422** `VALIDATION_ERROR`

---

### `POST /api/v1/auth/login`

| | |
|---|---|
| Auth | None |

**Request** `{ "email": "...", "password": "..." }`

**200**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800,
  "role": "CUSTOMER",
  "customer_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90"
}
```

**401** `UNAUTHORIZED` — bad credentials.
**403** `PENDING_KYC` — credentials correct but KYC not verified. This is **403, not 401**, so a
test can distinguish the two (E-09):

```json
{ "error": { "code": "PENDING_KYC", "message": "Complete KYC verification before signing in.", "field_errors": null, "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE" } }
```

---

### `GET /api/v1/auth/me`

Bearer. Returns the `CustomerResponse` for the current principal. **401** if unauthenticated.

---

## 3. Accounts (AC-02, AC-03)

### `POST /api/v1/accounts`

| | |
|---|---|
| Auth | Bearer |

**Request** — optional body `{ "type": "SAVINGS" }`. There is **no opening-deposit field**:
AC-02 requires the balance to initialise to `0.00`, and no minimum-balance rule exists (OUT-08).

**201**
```json
{
  "id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d",
  "account_number": "HZN0000000101",
  "type": "SAVINGS",
  "balance": "0.00",
  "currency": "INR",
  "status": "ACTIVE",
  "opened_at": "2026-08-19T09:10:02Z"
}
```

Note `"0.00"` — a **string**. **401** `UNAUTHORIZED`.

---

### `GET /api/v1/accounts`

Bearer. Returns an array of `AccountResponse` for the authenticated customer only.

```json
[
  { "id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d", "account_number": "HZN0000000101", "type": "SAVINGS", "balance": "12480.50", "currency": "INR", "status": "ACTIVE", "opened_at": "2026-08-19T09:10:02Z" },
  { "id": "9c2e1d3f-4b5a-4c6d-8e7f-1a2b3c4d5e6f", "account_number": "HZN0000000102", "type": "SAVINGS", "balance": "0.00", "currency": "INR", "status": "ACTIVE", "opened_at": "2026-08-19T09:41:55Z" }
]
```

---

### `GET /api/v1/accounts/{account_id}/statements`

| | |
|---|---|
| Auth | Bearer, owner only |
| Query | `page` (default 1), `size` (default 20, max 100), `direction` (optional `DEBIT` \| `CREDIT`) |

**200**
```json
{
  "account_id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d",
  "balance": "12480.50",
  "items": [
    { "id": "e1a2b3c4-d5e6-4f70-8192-a3b4c5d6e7f8", "account_id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d", "counterparty_account_number": "HZN0000000202", "direction": "DEBIT", "amount": "250.00", "balance_after": "12480.50", "transfer_id": "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d", "description": "Rent share", "created_at": "2026-08-19T11:02:44Z" },
    { "id": "f2b3c4d5-e6f7-4081-92a3-b4c5d6e7f8a9", "account_id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d", "counterparty_account_number": null, "direction": "CREDIT", "amount": "5000.00", "balance_after": "12730.50", "transfer_id": null, "description": "Loan disbursement", "created_at": "2026-08-18T16:20:10Z" }
  ],
  "page": 1, "size": 20, "total": 2, "total_pages": 1
}
```

**Empty statement (E-20)** — 200 with an empty page, **never 404**:
```json
{ "account_id": "9c2e1d3f-4b5a-4c6d-8e7f-1a2b3c4d5e6f", "balance": "0.00", "items": [], "page": 1, "size": 20, "total": 0, "total_pages": 0 }
```

**401** · **403** `FORBIDDEN` when the account belongs to another customer (E-19) · **404** `NOT_FOUND`

---

## 4. Beneficiaries (AC-06)

An **optional convenience feature**. Nothing in the transfer flow requires a beneficiary to
exist. Removal is a soft delete so historical transaction and audit references survive (A-07).

### `POST /api/v1/beneficiaries`

Bearer.

**Request**
```json
{ "nickname": "Kofi — rent", "beneficiary_account_number": "HZN0000000202", "beneficiary_name": "Kofi Mensah" }
```

**201**
```json
{ "id": "c3d4e5f6-a7b8-4901-a2b3-c4d5e6f7a8b9", "nickname": "Kofi — rent", "beneficiary_account_number": "HZN0000000202", "beneficiary_name": "Kofi Mensah", "created_at": "2026-08-19T09:55:00Z" }
```

**401** · **404** `ACCOUNT_NOT_FOUND` · **409** `DUPLICATE_BENEFICIARY` · **422** `VALIDATION_ERROR`

### `GET /api/v1/beneficiaries`

Bearer. Array of `BeneficiaryResponse`, soft-deleted rows excluded.

### `DELETE /api/v1/beneficiaries/{beneficiary_id}`

Bearer, owner only. **204** no content. **401** · **403** · **404**

---

## 5. Transfers (AC-04, AC-05)

### `POST /api/v1/transfers`

| | |
|---|---|
| Auth | Bearer, must own `source_account_id` |
| Atomicity | Debit, credit, both transaction legs, the audit entry and the notification enqueue commit together or not at all |

**Request**
```json
{
  "source_account_id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d",
  "destination_account_number": "HZN0000000202",
  "amount": "250.00",
  "description": "Rent share"
}
```

| Field | Type | Required | Constraint |
|---|---|---|---|
| `source_account_id` | uuid | yes | Must be an `ACTIVE` account owned by the caller |
| `destination_account_number` | string | yes | The literal prefix HZN followed by 10 digits. **Supplied directly.** There is no `beneficiary_id` field — a saved beneficiary is not a precondition (AC-04, DR-17) |
| `amount` | money string | yes | `> 0`, at most 2 decimal places. **No upper bound** — no transfer cap exists |
| `description` | string \| null | no | ≤ 200 chars |

**201**
```json
{
  "id": "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d",
  "source_account_id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d",
  "destination_account_number": "HZN0000000202",
  "amount": "250.00",
  "status": "COMPLETED",
  "failure_code": null,
  "source_balance_after": "12230.50",
  "description": "Rent share",
  "created_at": "2026-08-19T11:02:44Z"
}
```

**422 — `INSUFFICIENT_FUNDS` (AC-05, E-01).** The whole transaction rolls back. No money moved,
no transaction rows, no notification. A `Transfer` row is recorded with `status: "FAILED"` and
`failure_code: "INSUFFICIENT_FUNDS"`, and the failed attempt is audited (A-08).
```json
{ "error": { "code": "INSUFFICIENT_FUNDS", "message": "Transfer declined: the available balance is lower than the requested amount.", "field_errors": null, "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE" } }
```

| Status | Code | Scenario |
|---|---|---|
| 401 | `UNAUTHORIZED` | No bearer token (E-15) |
| 403 | `FORBIDDEN` | Source account owned by another customer (E-19) |
| 404 | `ACCOUNT_NOT_FOUND` | Destination account number does not resolve (E-03) |
| 422 | `INSUFFICIENT_FUNDS` | Balance below amount (E-01) |
| 422 | `SELF_TRANSFER` | Destination equals source (E-02) |
| 422 | `INACTIVE_ACCOUNT` | Destination is `CLOSED` (E-03) |
| 422 | `MONEY_PRECISION` | Zero, negative, or more than 2dp (E-05, E-06) — never silently rounded |

**Concurrency (E-07).** A row lock on the source account serialises competing transfers. The
second attempt re-reads the updated balance inside the lock; no overdraft is possible.

**Notification decoupling (E-18).** Dispatch happens after commit. A dispatch failure marks the
notification `FAILED` and never rolls back a committed transfer.

### `GET /api/v1/transfers`

Bearer. Paginated `TransferPage`, includes `FAILED` attempts. Optional `?status=` filter.

---

## 6. Loans — customer (AC-07)

### `POST /api/v1/loans`

Bearer.

**Request**
```json
{ "principal": "50000.00", "tenure_months": 24, "purpose": "Home renovation", "declared_monthly_income": "85000.00", "disbursement_account_id": null }
```

| Field | Type | Required | Constraint |
|---|---|---|---|
| `principal` | money string | yes | `> 0`, at most 2dp. **No minimum and no maximum** — the brief states none |
| `tenure_months` | integer | yes | Positive whole number. **No ceiling** |
| `purpose` | string | yes | 1–200 chars, free text, not validated against a list |
| `declared_monthly_income` | money string \| null | **no** | **Informational only.** No rule, threshold, ratio or score reads it |
| `disbursement_account_id` | uuid \| null | no | Optional nomination of an `ACTIVE` `SAVINGS` account owned by the applicant, used later if the loan reaches `DISBURSED`. Nominating it has no effect on the decision |

Validation is **structural only**. There is no eligibility gate of any kind: approval is an
administrator's judgement under AC-08.

**201**
```json
{
  "id": "d4e5f6a7-b8c9-4012-b3c4-d5e6f7a8b9c0",
  "customer_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90",
  "customer_name": "Amara Okonjo",
  "principal": "50000.00",
  "tenure_months": 24,
  "declared_monthly_income": "85000.00",
  "purpose": "Home renovation",
  "status": "APPLIED",
  "disbursement_account_id": null,
  "created_at": "2026-08-19T12:00:00Z",
  "updated_at": "2026-08-19T12:00:00Z"
}
```

**401** · **422** `VALIDATION_ERROR` (structural only)

### `GET /api/v1/loans`

Bearer. Paginated `LoanPage`, own loans only. Optional `?status=`.

### `GET /api/v1/loans/{loan_id}`

Bearer, owner only. `LoanResponse` plus the full `timeline`:

```json
{
  "id": "d4e5f6a7-b8c9-4012-b3c4-d5e6f7a8b9c0",
  "principal": "50000.00", "tenure_months": 24, "purpose": "Home renovation",
  "status": "APPROVED", "disbursement_account_id": null,
  "created_at": "2026-08-19T12:00:00Z", "updated_at": "2026-08-19T14:31:09Z",
  "timeline": [
    { "id": "aa11bb22-cc33-4d44-8e55-ff66aa77bb88", "from_status": null, "to_status": "APPLIED", "actor_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90", "actor_role": "CUSTOMER", "reason": null, "created_at": "2026-08-19T12:00:00Z" },
    { "id": "bb22cc33-dd44-4e55-8f66-aa77bb88cc99", "from_status": "APPLIED", "to_status": "UNDER_REVIEW", "actor_id": "0a0a0a0a-1b1b-4c4c-8d8d-9e9e9e9e9e9e", "actor_role": "ADMIN", "reason": null, "created_at": "2026-08-19T14:02:18Z" },
    { "id": "cc33dd44-ee55-4f66-8a77-bb88cc99dd00", "from_status": "UNDER_REVIEW", "to_status": "APPROVED", "actor_id": "0a0a0a0a-1b1b-4c4c-8d8d-9e9e9e9e9e9e", "actor_role": "ADMIN", "reason": "Documentation complete and consistent with the stated purpose.", "created_at": "2026-08-19T14:31:09Z" }
  ]
}
```

**401** · **403** · **404**

---

## 7. Loans — administrator (AC-08)

All routes require bearer **and** the `ADMIN` role. A `CUSTOMER` token receives **403**
`FORBIDDEN` (E-14).

### Legal state transitions

| From | To | Endpoint | Reason |
|---|---|---|---|
| `APPLIED` | `UNDER_REVIEW` | `POST .../review` | optional |
| `UNDER_REVIEW` | `APPROVED` | `POST .../approve` | **mandatory, non-empty** |
| `UNDER_REVIEW` | `REJECTED` | `POST .../reject` | **mandatory, non-empty** |
| `APPROVED` | `DISBURSED` | `POST .../disburse` | n/a |

Every other pair is illegal and returns **409** `ILLEGAL_LOAN_TRANSITION` — including
`APPLIED → DISBURSED` (E-11) and approving an already-rejected loan (E-12). `REJECTED` and
`DISBURSED` are terminal.

### `GET /api/v1/admin/loans`

Query `page`, `size`, `status` (defaults to `APPLIED` when omitted). Returns `LoanPage`.

### `POST /api/v1/admin/loans/{loan_id}/review`

Optional body `{ "reason": null }`. **200** `LoanDetailResponse`. **409** on illegal transition.

### `POST /api/v1/admin/loans/{loan_id}/approve`

**Request** `{ "reason": "Documentation complete and consistent with the stated purpose." }`

`reason` is mandatory and must be non-empty after trimming. **200** `LoanDetailResponse`.

**422 (E-13)**
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "A decision reason is required.", "field_errors": [{ "field": "reason", "message": "must not be empty" }], "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE" } }
```

**409 (E-12)**
```json
{ "error": { "code": "ILLEGAL_LOAN_TRANSITION", "message": "A loan in status REJECTED cannot be approved.", "field_errors": null, "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE" } }
```

### `POST /api/v1/admin/loans/{loan_id}/reject`

Identical contract to approve; `reason` mandatory. **200** / **409** / **422**.

### `POST /api/v1/admin/loans/{loan_id}/disburse`

**Request** `{ "disbursement_account_id": "7b1f0b0e-1c2d-4a5b-9c8d-0e1f2a3b4c5d" }`

Credits `principal` to an existing **ACTIVE** savings account of the applicant, in the same
transaction as the state change (A-04). No repayment schedule is created — `DISBURSED` is
terminal.

**200** `LoanDetailResponse` · **409** `ILLEGAL_LOAN_TRANSITION`, or `INACTIVE_ACCOUNT` when the
target account is closed (E-22).

---

## 8. Audit ledger (AC-09)

### `GET /api/v1/admin/audit`

Bearer + `ADMIN`. **Read-only by construction.** No `POST`, `PUT`, `PATCH` or `DELETE` route
exists against `audit_entries` anywhere in this API — append-only is enforced at the repository,
database-trigger and write-hook levels (NFR-02, E-17).

**Query** `page`, `size`, `action`, `entity_type`, `entity_id`, `actor_id`, `occurred_from`,
`occurred_to`. Filtering uses indexed first-class columns only; `metadata_json` is opaque and is
never used in a `WHERE` predicate (DD-15).

**200**
```json
{
  "items": [
    { "id": "11112222-3333-4444-8555-666677778888", "occurred_at": "2026-08-19T11:02:44Z", "actor_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90", "actor_role": "CUSTOMER", "action": "TRANSFER_COMPLETED", "entity_type": "TRANSFER", "entity_id": "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d", "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE", "metadata_json": { "amount": "250.00", "source_account_number": "HZN0000000101", "destination_account_number": "HZN0000000202" } },
    { "id": "22223333-4444-5555-8666-777788889999", "occurred_at": "2026-08-19T14:31:09Z", "actor_id": "0a0a0a0a-1b1b-4c4c-8d8d-9e9e9e9e9e9e", "actor_role": "ADMIN", "action": "LOAN_APPROVED", "entity_type": "LOAN", "entity_id": "d4e5f6a7-b8c9-4012-b3c4-d5e6f7a8b9c0", "correlation_id": "01J8ZQM4N7P2R5T8W1Y3B6D9F2", "metadata_json": { "from_status": "UNDER_REVIEW", "to_status": "APPROVED", "reason": "Documentation complete and consistent with the stated purpose." } }
  ],
  "page": 1, "size": 20, "total": 2, "total_pages": 1
}
```

**401** · **403** `FORBIDDEN` for a non-admin.

---

## 9. Notifications (AC-10)

### `GET /api/v1/admin/notifications`

Bearer + `ADMIN`. Query `page`, `size`, `status`, `event_type`, `channel`.

A notification is enqueued **inside** the business transaction and dispatched **outside** it.
`event_type` covers a successful transfer and **every** loan state transition.

**200**
```json
{
  "items": [
    { "id": "33334444-5555-6666-8777-888899990000", "customer_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90", "channel": "EMAIL", "event_type": "TRANSFER_COMPLETED", "payload": "You sent 250.00 INR to account ending 0202.", "status": "SENT", "failure_reason": null, "correlation_id": "01J8ZQK7M2C4X9N0RT5VB3DHYE", "created_at": "2026-08-19T11:02:44Z", "sent_at": "2026-08-19T11:02:44Z" },
    { "id": "44445555-6666-7777-8888-999900001111", "customer_id": "3f2a9c10-7d4e-4b8a-9f11-2c5d6e7f8a90", "channel": "SMS", "event_type": "LOAN_APPROVED", "payload": "Your loan application has been approved.", "status": "FAILED", "failure_reason": "Stub dispatcher returned a simulated gateway error.", "correlation_id": "01J8ZQM4N7P2R5T8W1Y3B6D9F2", "created_at": "2026-08-19T14:31:09Z", "sent_at": null }
  ],
  "page": 1, "size": 20, "total": 2, "total_pages": 1
}
```

The `FAILED` row above is E-18: the loan approval stands; only the notification failed.

---

## 10. Coverage of BRD §11.1 edge cases

| Edge | Endpoint | Status / code |
|---|---|---|
| E-01 | `POST /transfers` | 422 `INSUFFICIENT_FUNDS` |
| E-02 | `POST /transfers` | 422 `SELF_TRANSFER` |
| E-03 | `POST /transfers` | 404 `ACCOUNT_NOT_FOUND` / 422 `INACTIVE_ACCOUNT` |
| E-05 | `POST /transfers` | 422 `MONEY_PRECISION` |
| E-06 | `POST /transfers` | 422 `MONEY_PRECISION` |
| E-07 | `POST /transfers` | Serialised by row lock; second attempt sees updated balance |
| E-09 | `POST /auth/login` | 403 `PENDING_KYC` |
| E-10 | `POST /auth/kyc` | 409 `KYC_ALREADY_SUBMITTED` |
| E-11 | `POST /admin/loans/{loan_id}/disburse` | 409 `ILLEGAL_LOAN_TRANSITION` |
| E-12 | `POST /admin/loans/{loan_id}/approve` | 409 `ILLEGAL_LOAN_TRANSITION` |
| E-13 | `POST /admin/loans/{loan_id}/approve` · `/reject` | 422 `VALIDATION_ERROR` on `reason` |
| E-14 | any `/admin/*` | 403 `FORBIDDEN` |
| E-15 | any protected route | 401 `UNAUTHORIZED` |
| E-16 | `POST /transfers` | Audit write failure rolls back the whole transaction |
| E-17 | — | No mutation route against `audit_entries` exists at all |
| E-18 | `GET /admin/notifications` | Notification `FAILED`, transfer still `COMPLETED` |
| E-19 | statements, beneficiaries, loans | 403 `FORBIDDEN` |
| E-20 | `GET /accounts/{account_id}/statements` | 200, empty `items` |
| E-22 | `POST /admin/loans/{loan_id}/disburse` | 409 `INACTIVE_ACCOUNT` |
