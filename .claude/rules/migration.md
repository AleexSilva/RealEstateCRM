---
paths: ["api/alembic/**"]
---

- Never edit a migration that has already been applied to any shared environment.
  Write a new one.
- Every migration needs a working `downgrade()`. If it can't be reversed, say so
  explicitly in the docstring and flag it in the PR.
- Money columns: numeric(18,4). Currency columns: the `currency_code` enum.
  Timestamps: timestamptz. IDs: uuid. No exceptions.
- Adding a column to expenses, captures or bank_transactions? Add the index in the
  same migration and state the query it serves.
- Destructive operations (drop column, drop table, type narrowing) require an
  explicit callout in the migration docstring and a note in the PR description.