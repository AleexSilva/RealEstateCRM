---
name: ticket
description: Create a Jira ticket for OBRA CRM in the house format.
disable-model-invocation: true
---

Create a Jira issue via the Jira MCP server using exactly this shape.

**Project key:** CRM
**Epics:** map to the sprint plan in @docs/technical_details.md §15.

Fields:
- **Summary:** imperative, ≤ 80 chars, no ticket-speak. "Add FX backfill command"
  not "As a developer I want...".
- **Description:**
  - *Context* — 1–2 sentences, with a link to the spec section it implements
    (e.g. `technical_details.md §6.2`).
  - *Scope* — bullets of what's in.
  - *Out of scope* — bullets of what is explicitly not in. This field prevents
    more rework than any other.
- **Acceptance criteria:** Given/When/Then bullets. Every one must be testable by
  someone who didn't write the code.
- **Definition of done:** tests written and passing · migration has a downgrade ·
  no hardcoded Spanish strings · types regenerated if the API changed · spec
  updated if behaviour diverged from it · if the ticket touches a mobile capture
  screen (Escribir/Foto/Audio/Revisión), it does not add a required field, tap, or
  confirmation step without a note justifying it against agents.md §3.
- **Labels:** one of `backend` `frontend` `mobile` `ml` `infra` `data-model`,
  plus `fx` / `security` / `offline-sync` where relevant.
- **Estimate:** story points (1, 2, 3, 5, 8). Anything you'd call 13 must be split.

Rules:
- One ticket = one reviewable PR. If acceptance criteria exceed 6 bullets, split it.
- Never create a ticket whose description is a restatement of its summary.
- After creating, append `CRM-xxx | summary | spec section` to docs/backlog.md
  so future sessions can map tickets back to the spec.