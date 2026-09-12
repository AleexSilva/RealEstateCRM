---
paths: ["web/**/*.{ts,tsx}", "mobile/**/*.{ts,tsx}"]
---

- Every user-visible string comes from `t('key')`. A Spanish literal in JSX is a bug.
  Add the key to locales/es.json in the same commit.
- Number and date formatting via the shared `formatMoney` / `formatDate` helpers
  (es-UY locale: 1.234.567,89 and DD/MM/AAAA). Never `toLocaleString` inline.
- Always render the currency marker: $U (UYU), $ (ARS), US$ (USD). Never a bare $.
- Any converted figure must display its rate type and date footnote. If you can't
  source that metadata, don't display the converted number.
- Types come from `packages/shared-types` (generated from OpenAPI). Never redeclare
  an API shape by hand.
- Server state is TanStack Query. Don't put it in useState or a global store.
- Mobile: nothing goes straight to the network. Writes go to the local DB and the
  outbox; the sync layer owns all API calls.
- Mobile capture screens (Escribir / Foto / Audio / Revisión y confirmación): the
  field user is there to build, not to enter data. Never add a required field, extra
  tap, or confirmation step to these flows without checking it against agents.md §3
  first — default what can be defaulted and let OCR/ASR pre-fill do the work.