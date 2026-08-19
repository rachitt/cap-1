# Claude Harness Engine v1 — Design Reference

Harness architecture reference for the ClaudeForge Banking Suite. Describes the agent
substrate, the ratchet loop, hook order, and state files. For the *application's* own
architecture, see `docs/architecture.md`.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User / CI                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ slash commands
┌─────────────────────▼───────────────────────────────────────┐
│                   Orchestrator (Claude)                      │
│  /brd → /spec → /design → /build → /test → /evaluate        │
└──┬──────────┬──────────┬──────────┬──────────┬──────────────┘
   │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼
Planner   Generator  Evaluator  Test Eng  Security Rev
   │          │          │          │          │
   └──────────┴──────────┴──────────┴──────────┘
                         │
              ┌──────────▼──────────┐
              │     State Layer      │
              │  features.json       │
              │  claude-progress.txt │
              │  learned-rules.md    │
              │  failures.md         │
              │  iteration-log.md    │
              └──────────────────────┘
```

## Karpathy Ratchet Loop

```
        ┌──────────────────────────────────┐
        │         Build Feature            │
        └──────────────┬───────────────────┘
                       │
        ┌──────────────▼───────────────────┐
        │       Evaluate vs Design         │◄──────────┐
        └──────────────┬───────────────────┘           │
                       │                               │
              score ≥ threshold?                       │
                  /         \                          │
                Yes           No                       │
                 │             │                       │
        ┌────────▼──┐  ┌───────▼────────┐             │
        │  Proceed  │  │  Design Critic  │             │
        └───────────┘  │  suggests fix   │             │
                       └───────┬─────────┘             │
                               │                       │
                       ┌───────▼─────────┐             │
                       │  Generator      │─────────────┘
                       │  applies fix    │  (max 10 iterations)
                       └─────────────────┘
```

Scoring is calibrated by `calibration-profile.json` (consumer-facing profile:
threshold 8, per-criterion minimum 5, plateau pivot after 3 flat iterations).

## Agent Roles

| Agent            | File                          | Responsibility                         |
|------------------|-------------------------------|----------------------------------------|
| Planner          | `.claude/agents/planner.md`   | Sprint planning, story breakdown       |
| Generator        | `.claude/agents/generator.md` | Feature implementation                 |
| Evaluator        | `.claude/agents/evaluator.md` | API + Playwright verification          |
| Design Critic    | `.claude/agents/design-critic.md` | Design scoring (Karpathy loop)     |
| UI Designer      | `.claude/agents/ui-designer.md`   | Mockups, design tokens             |
| Test Engineer    | `.claude/agents/test-engineer.md` | Test authoring and execution       |
| Security Reviewer| `.claude/agents/security-reviewer.md` | Vulnerability auditing         |

Banking-specific agents (e.g. `loan-approval-agent`, `transaction-auditor-agent`) are
added to `.claude/agents/` on top of this foundation.

## Hook Execution Order

| # | Hook                  | File                               | Trigger                        |
|---|-----------------------|------------------------------------|--------------------------------|
| 1 | enforce-length-pre    | `hooks/enforce-length-pre.js`      | PreToolUse: Write/Edit         |
| 2 | scope-directory       | `hooks/scope-directory.js`         | PostToolUse: Write/Edit        |
| 3 | protect-env           | `hooks/protect-env.js`             | PostToolUse: Write/Edit        |
| 4 | detect-secrets        | `hooks/detect-secrets.js`          | PostToolUse: Write/Edit        |
| 5 | lint-on-save          | `hooks/lint-on-save.js`            | PostToolUse: Write/Edit        |
| 6 | typecheck             | `hooks/typecheck.js`               | PostToolUse: Write/Edit        |
| 7 | check-architecture    | `hooks/check-architecture.js`      | PostToolUse: Write/Edit        |
| 8 | check-function-length | `hooks/check-function-length.js`   | PostToolUse: Write/Edit        |
| 9 | check-file-length     | `hooks/check-file-length.js`       | PostToolUse: Write/Edit        |
|10 | track-writes          | `hooks/track-writes.js`            | PostToolUse: Write/Edit        |
|11 | pre-commit-gate       | `hooks/pre-commit-gate.js`         | PostToolUse: Bash              |
|12 | sprint-contract-gate  | `hooks/sprint-contract-gate.js`    | PostToolUse: Bash              |
|13 | require-review        | `hooks/require-review.js`          | Stop                           |
|14 | task-completed        | `hooks/task-completed.js`          | TaskCompleted                  |
|15 | teammate-idle-check   | `hooks/teammate-idle-check.js`     | TeammateIdle                   |

Banking-specific hooks (e.g. `money-precision-check`, `audit-immutability-check`,
`pii-scrub`) are appended to the PostToolUse chain in `.claude/settings.json`.

## State Files

| File                  | Purpose                                              |
|-----------------------|------------------------------------------------------|
| `features.json`       | Feature registry with status tracking                |
| `claude-progress.txt` | Session progress and current pipeline position       |
| `learned-rules.md`    | Accumulated rules from past failures (ratchet memory)|
| `failures.md`         | Failure log for pattern analysis                     |
| `iteration-log.md`    | Evaluator iteration history per feature              |
| `eval-scores.json`    | Design scores per component per iteration            |
| `coverage-baseline.txt` | Test coverage baseline for regression detection    |

## Sprint Contract Format

A sprint contract (`sprint-contracts/{group-id}.json`) defines a unit of work:

```json
{
  "contract_id": "group-01",
  "group_name": "Authentication",
  "stories": ["auth-01", "auth-02", "auth-03"],
  "acceptance_criteria": [],
  "dependencies": [],
  "estimated_complexity": "medium",
  "approved": false
}
```

The sprint-contract-gate hook blocks `/build` until `approved: true`.

## Quality Principles

1. **Correctness first** — all tests must pass before a feature is considered done
2. **Type safety** — strict typing enforced by hooks on every save
3. **Layered architecture** — one-way dependency boundaries enforced by check-architecture hook
4. **Test coverage** — coverage gate enforced at ≥ 80%; regressions block merges
5. **Security by default** — secrets detection runs on every commit; env files are protected
6. **Iterative improvement** — Karpathy ratchet ensures quality only moves forward
