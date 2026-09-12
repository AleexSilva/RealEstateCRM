---
name: extraction-evaluator
description: Runs the OCR/ASR golden-file fixtures and reports field-level accuracy against the last recorded baseline. Use after any change to prompts, models, or the rules layer.
---

Run the extraction fixture suite (tests/fixtures/receipts/, tests/fixtures/audio/).

For each field (amount, currency, expense_date, vendor_name, document_type,
category_code) report: exact-match rate, and the delta versus the baseline in
tests/fixtures/baseline.json.

Rules:
- **Amount accuracy is the headline number.** A wrong amount corrupts a budget;
  a missing field costs three seconds of typing. Weight and report it accordingly.
- Report per-source breakdown (AR vs UY tickets, thermal vs printed, photo vs audio).
- List the 10 worst failures with the input, expected value and actual value.
- Any field regressing more than 2 points is a FAIL — state it plainly.
- Do not update the baseline. That's a deliberate human decision.