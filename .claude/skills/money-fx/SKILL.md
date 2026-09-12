---
name: money-fx
description: Rules for currency, exchange rates and any monetary calculation in OBRA CRM. Use whenever code touches amounts, currencies, fx_rates, conversion, budget-vs-actual, or reporting totals.
---

# Money and FX rules

## Storage
- Amounts: `numeric(18,4)`. Python: `Decimal`. Never float, anywhere, ever.
- Every amount is paired with a `currency` column (`ARS` | `UYU` | `USD`).
- `fx_rates` always stores `base_currency = 'USD'`. Quote is ARS or UYU.
  1 USD = `rate` units of quote currency. Everything else is derived.
- ARS↔UYU is always crossed through USD. There is no direct pair.

## Conversion
amount_display = amount
  × rate(expense_date, USD→display_ccy, project.fx_policy_rate_type)
  ÷ rate(expense_date, USD→expense_ccy, project.fx_policy_rate_type)

- Use the **expense date**, never today's date.
- Once an expense is `approved`, use its frozen snapshot columns
  (`fx_rate_to_usd`, `fx_rate_type`, `fx_rate_date`) instead of a live lookup.
  Historical reports must never change.
- Missing rate: walk back up to 7 days. Beyond that, raise `MissingRateError` and
  exclude the row from converted totals with a visible warning.
  **Never fall back to 1:1. Never interpolate. Never invent a rate.**

## Rate types
- Argentina diverges enormously between `official` and `blue`/`mep`. The rate type
  is per-project (`projects.fx_policy_rate_type`), never hardcoded.
- Uruguay uses BCU interbank.
- Every converted figure displayed to a user carries its rate type and date.

## Sources (all free, no key)
- BCU (UY, authoritative): SOAP at cotizaciones.bcu.gub.uy/wscotizaciones,
  accepts a date range — one call backfills a year.
- BCRA (AR official, authoritative): REST, no auth, IP rate-limited.
- DolarApi / ArgentinaDatos (AR blue/MEP/CCL only): community APIs, not SLA-backed.
- Always record `source` on the row. Manual overrides require a reason and are audited.

## Reporting
- All metrics build on the `v_expenses_reporting` view. The definition of
  "an expense that counts" (`status IN ('submitted','approved') AND deleted_at IS NULL`)
  lives there and only there. Do not re-implement it in another query.