# OBRA CRM

Multi-project CRM for a real estate company that buys lots and builds houses in
Argentina and Uruguay. Monorepo: FastAPI + Postgres backend, React web console,
React Native (Expo) mobile app, local OCR/ASR pipeline.

Full specs: @docs/agents.md (product/UX) and @docs/technical_details.md (engineering).
Read the relevant section before implementing a feature — do not infer the data
model or the FX rules from code alone.

## Non-negotiable rules

1. **Spanish UI, English code.** Every identifier, DB column, API field, log line,
   comment and commit message is in English. Every string a user sees is Spanish.
   No exceptions, no mixed-language identifiers.
2. **No hardcoded user-facing strings.** All copy lives in `web/src/locales/es.json`
   and `mobile/src/locales/es.json`, keyed in English (`expense.save_button`).
   A Spanish literal in a `.tsx` file is a bug.
3. **Money is `numeric(18,4)` plus a `currency` column.** Never float, never double,
   never a single "amount in USD" column. Python side: `Decimal`, never `float`.
4. **Never store converted amounts.** Store what was spent, in the currency it was
   spent. Convert at read time using the rate of the expense date — never today's rate.
   See the `money-fx` skill before touching anything with a currency in it.
5. **Free and self-hosted only.** Do not add a dependency that requires a paid plan,
   an API key to a commercial service, or a cloud account. If you think one is needed,
   stop and ask.
6. **Schema changes go through Alembic.** Never issue DDL against the database
   directly. One migration per logical change, always with a tested downgrade.
7. **Soft-delete financial records.** `deleted_at`, never `DELETE`, on expenses,
   captures, projects and anything they reference.
8. **Client-generated IDs.** Mobile creates UUIDv7 locally. `POST /expenses` and
   `POST /captures` are idempotent on that id — a repeat returns 200 with the
   existing record, not 409.

## Commands

- `make up` — start the full stack
- `make migrate m="message"` — generate a migration; `make upgrade` applies it
- `make seed` — load categories, phase template, and mock project data
- `make test` — pytest (testcontainers, real Postgres) + vitest
- `make lint` — ruff + mypy + eslint + tsc
- `make backup` / `make restore` — see docs/runbook-restore.md

## Repo layout

api/ (FastAPI + workers) · ml-service/ (OCR + ASR) · web/ (React console) ·
mobile/ (Expo app) · packages/shared-types/ (generated from OpenAPI) ·
seeds/ · docs/ · ops/

## Workflow

- Branch naming: `CRM-123-short-description`. The Jira key is mandatory.
- Every PR references its Jira ticket and states which acceptance criteria it satisfies.
- Regenerate `packages/shared-types` after any API schema change; never hand-edit it.
- Do not commit `.env`, fixtures containing real receipts, or anything under `/data`.