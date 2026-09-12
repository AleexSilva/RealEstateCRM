---
name: datamodel
description: OBRA CRM database schema — which table holds what, and the invariants. Use before writing any query, model or migration.
---

Read @docs/technical_details.md §5 for the full DDL. Key points Claude gets wrong:

- **Property/unit == project.** There is no `properties` table. Address, areas and
  cadastral id are columns on `projects`.
- **An expense is a header; `expense_items` is the ticket's line detail.** OCR
  produces both. Category analysis can use either — say which you're using.
- **Bank extracts are three tables:** `bank_accounts` → `bank_statements` (one CSV
  import, with `file_checksum` for idempotency) → `bank_transactions` (rows, with
  `row_hash` unique per account). Re-importing the same CSV must be a no-op.
- **Estimates are versioned.** Deviation math always references the single
  `status='approved'` estimate (enforced by a partial unique index).
- **`captures` is the raw AI record.** `ocr_text`, `transcript`, `raw_model_output`
  and `extracted` are kept forever — that's the debug corpus and the audit trail.
  Never overwrite them when the user edits the resulting expense.
- **Phases have a `template_code`.** Cross-project benchmarks group on it, not on
  `name` (which users edit).
- RLS is enabled on expenses, captures, bank_transactions, construction_phases and
  project_estimates. The app sets `app.current_user_id` per transaction.