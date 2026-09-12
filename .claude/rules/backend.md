---
paths: ["api/**/*.py", "ml-service/**/*.py"]
---

- Python 3.12, async def by default. Sync DB calls are a bug.
- SQLAlchemy 2.0 style (`select()`, not `Query`). No raw SQL strings except in
  explicitly reviewed reporting views under `app/services/metrics.py`.
- Pydantic v2 for every request/response body. No bare dicts crossing a boundary.
- Money: `Decimal` everywhere. Never `float`. Quantize to 4 dp at the boundary.
- Every endpoint that touches project data goes through `require_project_access()`.
  If you write a query without a project scope, explain why in a comment.
- Raise domain exceptions from `app/core/errors.py`; the handler maps them to
  RFC 7807 with a stable `code`. Never return Spanish text from the API.
- New background work is an arq task in `app/workers/`, registered in
  `workers/settings.py`. Never block a request on OCR, ASR or an LLM call.
- Tests use testcontainers Postgres. Never SQLite — we rely on Postgres types.