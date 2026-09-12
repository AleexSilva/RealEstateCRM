# technical_details.md — Engineering Specification

**Project codename:** `OBRA CRM`
**Version:** 0.1 (MVP)
**Companion doc:** `agents.md` (product & UX)
**Hard constraints:**
- Everything must run on **free / open-source software**. No paid SaaS, no per-seat licenses, no cloud bills.
- Everything is **self-hosted on a single machine via Docker Compose**.
- **UI in Spanish, codebase in English** (identifiers, DB columns, API fields, logs, comments, commits, docs).
- Three currencies (`ARS`, `UYU`, `USD`) with daily FX history from `2025-01-01`.
- **Field capture must cost the worker almost nothing** — they're there to build, not to do bookkeeping. See `agents.md` §3: no mobile capture change ships that adds a field, tap, or blocking call without weighing it against this.

---

## 1. Architecture overview

```
                          ┌─────────────────────────────┐
                          │   Mobile app (Expo / RN)    │
                          │  SQLite local + outbox      │
                          │  field_user · offline-first │
                          └──────────────┬──────────────┘
                                         │ HTTPS (JWT)
                                         │ /sync/push · /sync/pull · /media
┌─────────────────────────┐              │
│  Web console (React)    │──────────────┤
│  manager · master       │   HTTPS      │
└─────────────────────────┘              │
                                  ┌──────▼───────┐
                                  │    Caddy     │  reverse proxy + TLS
                                  └──────┬───────┘
                                         │
                                  ┌──────▼────────────────────┐
                                  │  API — FastAPI (Python)   │
                                  │  auth · RBAC · CRUD · KPI │
                                  └──┬────────┬────────┬──────┘
                                     │        │        │
                    ┌────────────────▼──┐  ┌──▼─────┐ ┌▼─────────────┐
                    │  PostgreSQL 16    │  │ Redis  │ │   MinIO      │
                    │  OLTP + reporting │  │ queue  │ │ photos/audio │
                    └───────────────────┘  └──┬─────┘ └──────────────┘
                                              │
                                   ┌──────────▼───────────┐
                                   │  Worker (arq)        │
                                   │  OCR · ASR · extract │
                                   │  FX sync · exports   │
                                   └──┬────────┬──────────┘
                                      │        │
                        ┌─────────────▼──┐  ┌──▼──────────────┐
                        │  ml-service     │  │  Ollama         │
                        │  PaddleOCR (es) │  │  Qwen2.5 7B     │
                        │  faster-whisper │  │  field extract  │
                        └─────────────────┘  └─────────────────┘
```

---

## 2. Technology choices

| Layer | Choice | License | Why |
|---|---|---|---|
| API | **FastAPI** (Python 3.12) | MIT | Async, OpenAPI for free, same language as the ML pipeline and as the team's existing Python/SQL skillset — one language for API, workers, OCR/ASR glue and data work |
| ORM / migrations | SQLAlchemy 2.0 + Alembic | MIT | Versioned schema; the data model is expected to evolve |
| Validation | Pydantic v2 | MIT | Shared schemas between API, worker and the LLM extraction contract |
| Database | **PostgreSQL 16** | PostgreSQL | `numeric` for money, `jsonb` for raw AI output, window functions for KPIs, materialized views for dashboards |
| Cache / queue broker | Redis 7 | (Redis ≤7.2 BSD-3) | Use `redis:7.2-alpine` to stay on the BSD-licensed line, or `valkey/valkey` (BSD) as a fully permissive drop-in |
| Background jobs | **arq** | MIT | Async-native, Redis-backed, dramatically simpler than Celery for this scale. (Celery is the fallback if you need complex routing.) |
| Object storage | **MinIO** | AGPL-3.0 | S3-compatible; lets you move to real S3 later with zero code change. *Note the AGPL: fine for internal self-hosted use; if that's a concern, swap for SeaweedFS (Apache-2.0) or plain filesystem volumes.* |
| Web console | **React 18 + Vite + TypeScript** | MIT | Largest talent pool; shares language/types with mobile |
| UI components | shadcn/ui + Tailwind CSS + Radix | MIT | Copy-in components (no vendor lock), accessible primitives, fast to build dense data UIs |
| Data fetching | TanStack Query | MIT | Caching, retries, optimistic updates |
| Tables | TanStack Table | MIT | Virtualized, sortable, filterable expense grids |
| Charts | **Recharts** (+ `visx` if needed) | MIT | Enough for bars, lines, S-curves, scatter. Gantt: `frappe-gantt` (MIT) or a custom horizontal-bar Gantt in Recharts |
| i18n | react-i18next / i18next | MIT | Spanish strings in JSON, English keys |
| Mobile app | **React Native via Expo (bare/dev-client)** | MIT | Shares TS types and validation logic with web; excellent camera + audio + filesystem APIs; builds locally with `expo prebuild` + Gradle (no paid EAS needed) |
| Mobile local DB | **WatermelonDB** (or `expo-sqlite` + custom outbox) | MIT | Built for offline-first sync with a push/pull protocol; SQLite under the hood |
| OCR | **PaddleOCR** (`lang="es"`) | Apache-2.0 | Best free accuracy on Spanish receipts; PP-OCRv4 detection+recognition. Fallback/secondary: **Tesseract 5** with `spa.traineddata` |
| ASR | **faster-whisper** (CTranslate2) with `large-v3-turbo` or `medium`, `language="es"` | MIT (model: MIT) | 4–8× faster than reference Whisper, runs int8 on CPU, excellent Rioplatense Spanish |
| Field extraction (OCR text / transcript → structured JSON) | **Ollama** + `qwen2.5:7b-instruct` (or `llama3.1:8b-instruct`) | Apache-2.0 / Llama license | Local, free, strong Spanish + strong JSON adherence. Rule-based regex layer runs first and the LLM fills the gaps |
| Reverse proxy / TLS | **Caddy 2** | Apache-2.0 | Automatic HTTPS with one line of config |
| Auth | FastAPI + JWT (`argon2` hashing, rotating refresh tokens) | — | Keycloak (Apache-2.0) is the upgrade path if you later need SSO/SAML; it's overkill for 10 users |
| Observability | Prometheus + Grafana + Loki | Apache-2.0 / AGPL | Optional for MVP; add once in production |
| Error tracking | GlitchTip (self-hosted, Sentry-compatible) | MIT | Free alternative to Sentry cloud |
| CI | GitHub Actions free tier, or **Gitea + Gitea Actions** self-hosted | MIT | Both free |
| Backups | `pg_dump` + **restic** | BSD-2 | Encrypted, deduplicated, incremental |

### 2.1 Things deliberately *not* used
- **No Firebase / Supabase cloud / Auth0 / Sentry cloud** — free tiers become paid tiers and you asked for free-forever.
- **No Databricks / cloud warehouse** — 3 projects and a handful of users is Postgres-sized. Postgres with materialized views will answer every dashboard query in milliseconds. Revisit only if you pass ~50M rows.
- **No paid OCR/ASR APIs** (Google Vision, AWS Textract, OpenAI Whisper API) — all replaced by local models.
- **No Kubernetes** — Docker Compose is the right tool for one machine.

---

## 3. Repository structure (monorepo)

```
obra-crm/
├── docker-compose.yml
├── docker-compose.override.yml        # dev-only overrides
├── .env.example
├── Caddyfile
├── Makefile                           # make up / seed / migrate / backup / test
├── api/
│   ├── Dockerfile
│   ├── pyproject.toml
│   ├── alembic/
│   └── app/
│       ├── main.py
│       ├── core/                      # config, security, deps, logging
│       ├── models/                    # SQLAlchemy models (English)
│       ├── schemas/                   # Pydantic DTOs
│       ├── api/v1/                    # routers
│       ├── services/                  # business logic
│       │   ├── fx.py
│       │   ├── expenses.py
│       │   ├── reconciliation.py
│       │   ├── metrics.py
│       │   └── sync.py
│       ├── workers/                   # arq tasks
│       │   ├── captures.py
│       │   ├── fx_sync.py
│       │   └── exports.py
│       └── tests/
├── ml-service/
│   ├── Dockerfile
│   └── app/
│       ├── main.py                    # FastAPI: /ocr, /asr
│       ├── ocr.py                     # PaddleOCR es
│       ├── asr.py                     # faster-whisper es
│       └── receipt_rules.py           # regex pre-extraction (CUIT/RUT, totals, IVA)
├── web/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── app/                       # routes
│       ├── features/                  # consolidated, projects, expenses, banks, admin
│       ├── components/
│       ├── lib/
│       ├── locales/es.json            # ALL Spanish strings live here
│       └── types/                     # generated from OpenAPI
├── mobile/
│   ├── app.json
│   ├── package.json
│   └── src/
│       ├── screens/
│       ├── db/                        # WatermelonDB schema + migrations
│       ├── sync/                      # outbox, push/pull, media uploader
│       ├── capture/                   # camera, audio recorder
│       └── locales/es.json
├── packages/
│   └── shared-types/                  # TS types generated from OpenAPI, shared web+mobile
├── seeds/
│   ├── phases_template.sql
│   ├── categories.sql
│   └── mock_data.py                   # generates 3 active + 1 closed project with mock volumes
└── docs/
    ├── agents.md
    └── technical_details.md
```

**Type generation:** `openapi-typescript` turns the FastAPI OpenAPI schema into TS types consumed by both `web` and `mobile`. One source of truth, no drift.

---

## 4. Hardware sizing (single Docker host)

| Component | RAM | Notes |
|---|---|---|
| PostgreSQL | 1–2 GB | |
| Redis | 256 MB | |
| MinIO | 512 MB | Disk is the real cost: see below |
| API + worker | 1 GB | |
| PaddleOCR | 1.5–2 GB | CPU inference ~1–3 s per receipt |
| faster-whisper `medium` int8 | 2–3 GB | CPU: ~0.3–0.6× realtime → a 60 s audio in ~25–40 s |
| Ollama + Qwen2.5 7B Q4 | 5–6 GB | CPU: ~10–25 s per extraction |
| **Total minimum** | **16 GB RAM / 6 cores** | Workable |
| **Recommended** | **32 GB RAM / 8 cores + NVIDIA GPU (8 GB+)** | GPU makes ASR ~20× and LLM ~10× faster |

**If the machine is weak (≤16 GB, no GPU):**
- Use `faster-whisper small` int8 (~1 GB) — still good on Spanish for short clips.
- Use `qwen2.5:3b-instruct` (~2 GB) instead of 7B, and lean more heavily on the regex rules layer.
- Keep OCR/ASR asynchronous (they already are) — latency only affects how fast a pre-filled form appears, never whether data is lost.

**Disk estimate (mock):** 40 expenses/project/week × 3 projects × 250 KB/photo ≈ 30 MB/week ≈ 1.6 GB/year of photos. Audio at 90 s Opus ≈ 150 KB each. Storage is not a constraint; budget 100 GB and forget about it.

---

## 5. Data model

### 5.1 ERD (text)

```
users ──┬── project_members ──┬── projects ──┬── construction_phases ──┐
        │                     │              │                          │
        │                     │              ├── project_estimates ── estimate_lines
        │                     │              │                          │
        │                     │              ├── bank_accounts ── bank_statements ── bank_transactions
        │                     │              │                                             │
        │                     │              └── expenses ──── expense_items               │
        │                     │                    │  │                                    │
        └── captures ─────────┴────────────────────┘  └──── reconciliation (FK) ───────────┘
                                                       
expense_categories ──┐                    fx_rates (independent, date-keyed)
vendors ─────────────┴── expenses         attachments (polymorphic)
                                          audit_log (polymorphic)
```

### 5.2 Design decisions

1. **Property/Unit = Project.** As you said, it's simpler. `projects` carries the property columns (`address`, `city`, `country`, `lot_area_m2`, `built_area_m2`, `cadastral_id`). If you ever build multiple units on one lot, you add a `properties` table and an FK — the schema is written so that's an additive migration, not a rewrite.
2. **"Expense details" = two tables.** `expenses` is the header (one ticket = one expense); `expense_items` is the line detail (one row per product line on the ticket). OCR naturally produces both. Managers report on headers; category analysis can drill into items.
3. **"Bank Account Extracts" = three tables.** `bank_accounts` (the account), `bank_statements` (one CSV import = one statement, with checksum for idempotency), `bank_transactions` (the rows). Re-importing the same CSV must not duplicate anything — hence the row hash.
4. **"Estimated project" = versioned.** `project_estimates` + `estimate_lines`, with a `status` and an approved baseline. Deviation math always references the approved version; earlier versions stay for comparison.
5. **Money = `numeric(18,4)` + `char(3)` currency.** Never floats. Never a single "amount in USD" column.
6. **Client-generated UUIDs.** The mobile app creates `id` (UUIDv7) locally so offline records have stable identity and sync is idempotent.
7. **Soft deletes** (`deleted_at`) everywhere that touches money, so reports are reproducible and the audit trail is intact.
8. **`jsonb` for raw AI output.** We keep `ocr_text`, `transcript`, and `raw_model_output` forever — that's the training/debug corpus and the trust mechanism ("show me what the machine actually read").

### 5.3 Enums

```sql
CREATE TYPE user_role        AS ENUM ('field_user','manager','master');
CREATE TYPE project_status   AS ENUM ('planning','active','paused','closed','cancelled');
CREATE TYPE country_code     AS ENUM ('AR','UY');
CREATE TYPE currency_code    AS ENUM ('ARS','UYU','USD');
CREATE TYPE capture_mode     AS ENUM ('manual','photo','audio');
CREATE TYPE capture_status   AS ENUM ('pending','processing','needs_review','confirmed','failed');
CREATE TYPE expense_status   AS ENUM ('draft','submitted','approved','rejected');
CREATE TYPE payment_method   AS ENUM ('cash','transfer','card','check','other');
CREATE TYPE document_type    AS ENUM ('ticket','invoice_a','invoice_b','invoice_c','e_ticket','receipt','none','other');
CREATE TYPE phase_status     AS ENUM ('not_started','in_progress','completed','blocked');
CREATE TYPE estimate_status  AS ENUM ('draft','approved','superseded');
CREATE TYPE txn_direction    AS ENUM ('debit','credit');
CREATE TYPE recon_status     AS ENUM ('unmatched','suggested','matched','ignored');
CREATE TYPE fx_rate_type     AS ENUM ('official_buy','official_sell','official_mid','blue','mep','ccl','interbank','manual');
```

### 5.4 DDL

```sql
-- ─────────────────────────── USERS & ACCESS ───────────────────────────
CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email           citext UNIQUE NOT NULL,
  full_name       text NOT NULL,
  password_hash   text NOT NULL,                -- argon2id
  global_role     user_role NOT NULL DEFAULT 'field_user',
  phone           text,
  locale          text NOT NULL DEFAULT 'es-UY',
  default_currency currency_code NOT NULL DEFAULT 'UYU',
  is_active       boolean NOT NULL DEFAULT true,
  must_change_password boolean NOT NULL DEFAULT true,
  last_login_at   timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE projects (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                text UNIQUE NOT NULL,          -- e.g. 'CARRASCO-01'
  name                text NOT NULL,
  status              project_status NOT NULL DEFAULT 'planning',
  country             country_code NOT NULL,
  address             text,
  city                text,
  cadastral_id        text,                          -- padrón / partida
  lot_area_m2         numeric(12,2),
  built_area_m2       numeric(12,2),
  base_currency       currency_code NOT NULL DEFAULT 'UYU',
  fx_policy_rate_type fx_rate_type NOT NULL DEFAULT 'official_sell',
  planned_start_date  date,
  planned_end_date    date,
  actual_start_date   date,
  actual_end_date     date,
  color_hex           text,                          -- project identity color in UI
  thumbnail_key       text,
  lessons_learned     text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz
);

CREATE TABLE project_members (
  project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        user_role NOT NULL,                    -- 'field_user' | 'manager'
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (project_id, user_id)
);
CREATE INDEX ON project_members (user_id);

-- ─────────────────────── PHASES & ESTIMATES ───────────────────────
CREATE TABLE construction_phases (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id        uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  template_code     text,                     -- stable code for cross-project comparison
  name              text NOT NULL,            -- Spanish label shown in UI
  sequence          int NOT NULL,
  status            phase_status NOT NULL DEFAULT 'not_started',
  progress_pct      numeric(5,2) NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
  planned_start     date,
  planned_end       date,
  actual_start      date,
  actual_end        date,
  planned_cost      numeric(18,4),
  planned_cost_currency currency_code,
  responsible_user_id uuid REFERENCES users(id),
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, sequence)
);

CREATE TABLE project_estimates (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id     uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  version        int NOT NULL,
  name           text,
  status         estimate_status NOT NULL DEFAULT 'draft',
  currency       currency_code NOT NULL,
  total_amount   numeric(18,4),               -- denormalized sum of lines
  contingency_pct numeric(5,2) DEFAULT 0,
  valid_from     date,
  created_by     uuid REFERENCES users(id),
  approved_by    uuid REFERENCES users(id),
  approved_at    timestamptz,
  notes          text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, version)
);
-- Only one approved estimate per project at a time:
CREATE UNIQUE INDEX one_approved_estimate_per_project
  ON project_estimates (project_id) WHERE status = 'approved';

CREATE TABLE estimate_lines (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_id  uuid NOT NULL REFERENCES project_estimates(id) ON DELETE CASCADE,
  phase_id     uuid REFERENCES construction_phases(id),
  category_id  uuid REFERENCES expense_categories(id),
  description  text NOT NULL,
  quantity     numeric(18,4),
  unit         text,                          -- m2, m3, bolsa, jornal, unidad
  unit_price   numeric(18,4),
  currency     currency_code NOT NULL,
  amount       numeric(18,4) NOT NULL,
  sequence     int
);
CREATE INDEX ON estimate_lines (estimate_id, phase_id);

-- ───────────────────── CATEGORIES & VENDORS ─────────────────────
CREATE TABLE expense_categories (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code       text UNIQUE NOT NULL,            -- MATERIALS, LABOR, SERVICES...
  name_es    text NOT NULL,                   -- Materiales, Mano de obra...
  parent_id  uuid REFERENCES expense_categories(id),
  icon       text,
  sequence   int,
  is_active  boolean NOT NULL DEFAULT true
);

CREATE TABLE vendors (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  normalized_name text NOT NULL,              -- lower, unaccented, for dedupe/matching
  tax_id       text,                          -- CUIT (AR) / RUT (UY)
  country      country_code,
  phone        text,
  notes        text,
  merged_into_id uuid REFERENCES vendors(id), -- soft merge target
  created_by   uuid REFERENCES users(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON vendors USING gin (normalized_name gin_trgm_ops);

-- ─────────────────────────── CAPTURES ───────────────────────────
CREATE TABLE captures (
  id                uuid PRIMARY KEY,              -- client-generated UUIDv7
  project_id        uuid NOT NULL REFERENCES projects(id),
  created_by        uuid NOT NULL REFERENCES users(id),
  mode              capture_mode NOT NULL,
  status            capture_status NOT NULL DEFAULT 'pending',
  media_key         text,                          -- MinIO object key
  media_mime        text,
  media_bytes       bigint,
  duration_ms       int,                           -- audio only
  ocr_text          text,
  transcript        text,
  raw_model_output  jsonb,
  extracted         jsonb,                         -- normalized candidate fields + confidence
  confidence        numeric(4,3),
  processing_ms     int,
  error_message     text,
  device_id         text,
  captured_at       timestamptz NOT NULL,          -- on-device time
  received_at       timestamptz NOT NULL DEFAULT now(),
  processed_at      timestamptz
);
CREATE INDEX ON captures (project_id, status);
CREATE INDEX ON captures (created_by, captured_at DESC);

-- ─────────────────────────── EXPENSES ───────────────────────────
CREATE TABLE expenses (
  id                uuid PRIMARY KEY,              -- client-generated UUIDv7
  project_id        uuid NOT NULL REFERENCES projects(id),
  phase_id          uuid REFERENCES construction_phases(id),
  category_id       uuid REFERENCES expense_categories(id),
  vendor_id         uuid REFERENCES vendors(id),
  capture_id        uuid REFERENCES captures(id),
  expense_date      date NOT NULL,
  description       text,
  amount            numeric(18,4) NOT NULL CHECK (amount > 0),
  currency          currency_code NOT NULL,
  tax_amount        numeric(18,4),                 -- IVA
  payment_method    payment_method,
  document_type     document_type,
  document_number   text,
  status            expense_status NOT NULL DEFAULT 'draft',
  -- frozen FX snapshot, written on approval
  fx_rate_to_usd    numeric(18,8),
  fx_rate_type      fx_rate_type,
  fx_rate_date      date,
  amount_usd        numeric(18,4),                 -- convenience, derived from the snapshot
  -- workflow
  created_by        uuid NOT NULL REFERENCES users(id),
  approved_by       uuid REFERENCES users(id),
  approved_at       timestamptz,
  rejection_reason  text,
  notes             text,
  client_updated_at timestamptz,                   -- for sync conflict resolution
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);
CREATE INDEX ON expenses (project_id, expense_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX ON expenses (project_id, status)            WHERE deleted_at IS NULL;
CREATE INDEX ON expenses (phase_id);
CREATE INDEX ON expenses (category_id);
CREATE INDEX ON expenses (vendor_id);
CREATE INDEX ON expenses (created_by, created_at DESC);

CREATE TABLE expense_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id   uuid NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  line_no      int NOT NULL,
  description  text NOT NULL,
  quantity     numeric(18,4),
  unit         text,
  unit_price   numeric(18,4),
  amount       numeric(18,4) NOT NULL,
  category_id  uuid REFERENCES expense_categories(id),
  source_confidence numeric(4,3),                  -- from OCR/ASR
  UNIQUE (expense_id, line_no)
);

-- ───────────────── BANK ACCOUNT EXTRACTS ─────────────────
CREATE TABLE bank_accounts (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id            uuid REFERENCES projects(id),   -- NULL = shared/company account
  bank_name             text NOT NULL,
  alias                 text NOT NULL,
  account_number_masked text,                           -- store masked only, e.g. '****4417'
  currency              currency_code NOT NULL,
  country               country_code NOT NULL,
  is_active             boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE bank_statements (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id),
  period_start    date NOT NULL,
  period_end      date NOT NULL,
  source_filename text,
  file_key        text,                              -- original CSV kept in MinIO
  file_checksum   text NOT NULL,                     -- sha256, idempotent re-import
  column_mapping  jsonb,                             -- remembered per account
  row_count       int NOT NULL DEFAULT 0,
  opening_balance numeric(18,4),
  closing_balance numeric(18,4),
  imported_by     uuid REFERENCES users(id),
  imported_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (bank_account_id, file_checksum)
);

CREATE TABLE bank_transactions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  statement_id        uuid NOT NULL REFERENCES bank_statements(id) ON DELETE CASCADE,
  bank_account_id     uuid NOT NULL REFERENCES bank_accounts(id),
  value_date          date NOT NULL,
  posted_date         date,
  description_raw     text NOT NULL,
  counterparty        text,
  direction           txn_direction NOT NULL,
  amount              numeric(18,4) NOT NULL CHECK (amount > 0),
  currency            currency_code NOT NULL,
  balance_after       numeric(18,4),
  external_ref        text,
  row_hash            text NOT NULL,                  -- sha256(account|date|amount|desc|ref)
  recon_status        recon_status NOT NULL DEFAULT 'unmatched',
  matched_expense_id  uuid REFERENCES expenses(id),
  match_confidence    numeric(4,3),
  matched_by          uuid REFERENCES users(id),
  matched_at          timestamptz,
  UNIQUE (bank_account_id, row_hash)
);
CREATE INDEX ON bank_transactions (bank_account_id, value_date DESC);
CREATE INDEX ON bank_transactions (recon_status);

-- ─────────────────────────── FX RATES ───────────────────────────
CREATE TABLE fx_rates (
  id             bigserial PRIMARY KEY,
  rate_date      date NOT NULL,
  base_currency  currency_code NOT NULL,        -- e.g. USD
  quote_currency currency_code NOT NULL,        -- e.g. UYU  → 1 USD = rate UYU
  rate_type      fx_rate_type NOT NULL,
  rate           numeric(18,8) NOT NULL CHECK (rate > 0),
  source         text NOT NULL,                 -- 'BCU','BCRA','dolarapi','argentinadatos','manual'
  source_payload jsonb,
  fetched_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid REFERENCES users(id),     -- only for manual overrides
  override_reason text,
  UNIQUE (rate_date, base_currency, quote_currency, rate_type, source)
);
CREATE INDEX ON fx_rates (base_currency, quote_currency, rate_type, rate_date DESC);

-- ───────────────── ATTACHMENTS & AUDIT ─────────────────
CREATE TABLE attachments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,                   -- 'expense','project','phase','capture'
  entity_id   uuid NOT NULL,
  file_key    text NOT NULL,
  filename    text,
  mime_type   text,
  size_bytes  bigint,
  doc_type    text,                            -- 'permit','plan','contract','receipt','progress_photo'
  expires_on  date,                            -- permits/insurance expiry
  uploaded_by uuid REFERENCES users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON attachments (entity_type, entity_id);

CREATE TABLE audit_log (
  id             bigserial PRIMARY KEY,
  actor_user_id  uuid REFERENCES users(id),
  action         text NOT NULL,                -- create|update|delete|approve|reject|login|export|import
  entity_type    text NOT NULL,
  entity_id      uuid,
  project_id     uuid,
  before_state   jsonb,
  after_state    jsonb,
  ip_address     inet,
  user_agent     text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON audit_log (entity_type, entity_id, created_at DESC);
CREATE INDEX ON audit_log (project_id, created_at DESC);

-- ───────────────── DEVICES & SYNC ─────────────────
CREATE TABLE devices (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id      text NOT NULL,
  platform       text,
  app_version    text,
  last_sync_at   timestamptz,
  last_seen_at   timestamptz,
  UNIQUE (user_id, device_id)
);

CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  device_id   text,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
```

Required extensions: `pgcrypto` (for `gen_random_uuid`), `citext`, `pg_trgm` (vendor fuzzy matching), `unaccent`.

### 5.5 Standard construction phase template (seed)

Stable `template_code` values are what make cross-project comparison possible. Seed every new project from this, editable afterward.

| seq | template_code | name (UI, Spanish) |
|---|---|---|
| 1 | `LAND` | Terreno y escrituración |
| 2 | `PERMITS` | Permisos y habilitaciones |
| 3 | `SITEWORK` | Movimiento de suelo |
| 4 | `FOUNDATION` | Fundaciones |
| 5 | `STRUCTURE` | Estructura |
| 6 | `MASONRY` | Mampostería |
| 7 | `ROOF` | Techos |
| 8 | `MEP` | Instalaciones (sanitaria, eléctrica, gas) |
| 9 | `PLASTER` | Revoques y contrapisos |
| 10 | `FINISHES` | Terminaciones |
| 11 | `EXTERIOR` | Exteriores y parquización |
| 12 | `HANDOVER` | Entrega final |

### 5.6 Expense category seed

`MATERIALS` Materiales · `LABOR` Mano de obra · `SUBCONTRACT` Subcontratos · `SERVICES` Servicios · `PERMITS` Permisos y tasas · `FREIGHT` Fletes · `TOOLS` Herramientas · `EQUIPMENT_RENTAL` Alquiler de equipos · `PROFESSIONAL` Honorarios profesionales · `INSURANCE` Seguros · `FINANCIAL` Gastos financieros · `OTHER` Otros

---

## 6. FX subsystem

### 6.1 Sources (all free, no API key)

| Pair / type | Primary source | Endpoint | Notes |
|---|---|---|---|
| USD→UYU interbank, official | **BCU** (Banco Central del Uruguay) SOAP web services | `https://cotizaciones.bcu.gub.uy/wscotizaciones/servlet/awsbcucotizaciones?wsdl` | Accepts `Moneda` (array of int codes), `FechaDesde`, `FechaHasta`, `Grupo` → perfect for historical backfill. `awsbcumonedas` lists currency codes; `awsultimocierre` returns the last close date. USD is code `2225`; `Grupo` 1 = international market, 2 = local quotes, 0 = both. **Verify codes against `awsbcumonedas` at build time rather than hardcoding.** |
| USD→ARS official | **BCRA** "Estadísticas Cambiarias v1.0" REST API | `https://api.bcra.gob.ar/estadisticascambiarias/v1.0/Cotizaciones/{fecha}` and `.../Cotizaciones/{ISO}?fechadesde=&fechahasta=` | Free, **no authentication**, IP-based rate limiting. Also `/Maestros/Divisas` for the ISO currency master. |
| USD→ARS blue / MEP / CCL (current) | **DolarApi** | `https://dolarapi.com/v1/dolares/{oficial\|blue\|bolsa\|contadoconliqui\|mayorista}` | Open source (MIT), no key |
| USD→ARS blue / MEP / CCL (historical, from 2025) | **ArgentinaDatos** | `https://api.argentinadatos.com/v1/cotizaciones/dolares` and `/dolares/{casa}` | Daily historical series per house; use this for the 01/01/2025 backfill |
| UYU secondary / cross-check | **DolarApi Uruguay** | `https://uy.dolarapi.com/v1/cotizaciones` | Secondary only; BCU is authoritative |
| ARS↔UYU | **Derived** | — | Cross via USD: `ARS→UYU = (UYU per USD) / (ARS per USD)`. Never scrape a direct ARS/UYU quote. |

**Reliability posture:** BCU and BCRA are the authoritative sources and are treated as primary; DolarApi/ArgentinaDatos are community projects (free, MIT, but not SLA-backed) used only for Argentine parallel rates that central banks don't publish. Every row records its `source`, so you can always tell where a number came from, and the admin screen allows a manual override with a reason.

### 6.2 Implementation

- `app/services/fx.py` exposes:
  - `sync_rates(date_from, date_to)` — idempotent upsert into `fx_rates`
  - `get_rate(date, base, quote, rate_type)` — with ≤7-day backward fallback; raises `MissingRateError` beyond that
  - `convert(amount, from_ccy, to_ccy, on_date, rate_type)` — cross via USD when needed
- Storage convention: **always store `base_currency = 'USD'`** with `quote_currency` in `ARS`/`UYU`. Everything else is derived. This keeps the table small and the math unambiguous.
- Scheduled jobs (arq cron):
  - `fx_sync_daily` — 09:00, 14:00, 20:00 ART. Three attempts a day because the BCU close and BCRA publication times differ and holidays differ between the two countries.
  - `fx_gap_check` — daily 21:00: finds missing business days since `2025-01-01` and enqueues targeted backfills; alerts master after 2 consecutive failures.
- **Backfill on first boot:** a management command `python -m app.cli fx-backfill --from 2025-01-01` pulls BCU (single SOAP call with a date range), BCRA (date-range REST call) and ArgentinaDatos (full series) — roughly 3 requests, ~450 rows per series. Runs in seconds.
- Retry policy: exponential backoff, 5 attempts, then mark the day as failed and alert. Never fabricate a rate.
- Cache: current-day rates cached in Redis for 15 minutes.

### 6.3 Conversion policy (the rule everyone must know)

```
amount_in_display_currency = amount
    × rate(expense_date, USD→display_ccy, project.fx_policy_rate_type)
    ÷ rate(expense_date, USD→expense_ccy, project.fx_policy_rate_type)
```

- Uses the **expense date**, never today.
- Once an expense is `approved`, the `fx_rate_to_usd` / `fx_rate_type` / `fx_rate_date` snapshot on the row is used instead of a live lookup, so historical reports never change.
- Reporting views expose both `amount` (original) and `amount_usd` (frozen), and convert USD→display currency at read time.

---

## 7. Capture ingestion pipeline

### 7.1 Job state machine

```
pending ──► processing ──► needs_review ──► confirmed
              │                  ▲
              └──► failed ───────┘  (user can retry, or fall back to manual)
```

### 7.2 Photo path

1. `POST /v1/captures` with metadata → returns a **presigned MinIO PUT URL**.
2. App uploads the image directly to MinIO (API never proxies media bytes).
3. App calls `POST /v1/captures/{id}/uploaded` → enqueues `process_photo_capture`.
4. Worker:
   - Downloads, then **preprocesses**: EXIF-rotate, deskew, perspective-correct (OpenCV contour detection), grayscale, adaptive threshold, downscale to ≤1600px long edge.
   - Calls `ml-service POST /ocr` → PaddleOCR (`lang="es"`, `use_angle_cls=True`) → text + per-box confidence + geometry.
   - Runs **`receipt_rules.py` first** (deterministic, fast, no LLM):
     - Total: last/largest currency-formatted number near `TOTAL`, tolerant of `TOTAL A PAGAR`, `IMPORTE`, `TOTAL $`.
     - Currency: `$U`, `UYU`, `U$S`, `US$`, `USD`, `$` + country inference from the project.
     - Date: `dd/mm/yy(yy)`, `dd-mm-yyyy`, `dd.mm.yyyy` + Spanish month names.
     - Tax ID: `CUIT \d{2}-\d{8}-\d` (AR), `RUT \d{12}` (UY).
     - Doc type: `FACTURA A|B|C`, `TICKET`, `E-TICKET`, `RECIBO`.
     - IVA: `IVA 22%|10%|21%|10,5%` amounts.
     - Line items: rows matching `qty × description × price` patterns.
   - Sends OCR text + rule results to **Ollama** for gap-filling and normalization under a strict JSON schema (§7.4).
   - Fuzzy-matches vendor name against `vendors.normalized_name` using `pg_trgm` (threshold 0.45 → suggest, 0.8 → auto-link).
   - Suggests `category_id` from vendor history and item keywords (`portland|arena|hierro` → `MATERIALS`).
   - Writes `captures.extracted` + `status='needs_review'`, stores raw OCR and raw model output.
5. App polls (or receives a push) and opens the **Review screen** pre-filled.
6. User confirms → `POST /v1/expenses` referencing `capture_id` → `captures.status='confirmed'`.

**Target latency:** < 8 s on GPU, < 25 s on CPU. Neither blocks the user: the review screen can be opened at any time, and the app falls back to an empty manual form (with the photo attached) after 15 s.

### 7.3 Audio path

1. Record on device: **Opus / m4a, 16 kHz mono**, max 90 s (~150 KB).
2. Same presigned-upload flow.
3. Worker calls `ml-service POST /asr` → faster-whisper (`language="es"`, `vad_filter=True`, `beam_size=5`, `initial_prompt` seeded with construction vocabulary to bias decoding):
   > `initial_prompt="Compra de materiales de construcción: hormigón, portland, ladrillo, hierro, arena, pallet, corralón, flete, jornal, etapa de obra, pesos uruguayos, pesos argentinos, dólares."`
4. Transcript → normalization pass:
   - Spanish spoken numbers → digits (`"dieciocho mil quinientos"` → `18500`) via a deterministic `es` number parser, **before** the LLM.
   - Currency phrase mapping: `"pesos uruguayos"|"pesos"→UYU (UY project)`, `"pesos argentinos"|"mangos"→ARS`, `"dólares"|"verdes"→USD`.
   - Relative dates: `"ayer"`, `"el lunes"`, `"antes de ayer"` → resolved against `captured_at`.
5. Same LLM extraction step and the same `extracted` JSON contract as the photo path.
6. Transcript is always persisted and shown verbatim above the form.

### 7.4 The extraction contract (shared by photo and audio)

The LLM is constrained to this JSON and nothing else. Pydantic validates it; a validation failure degrades to rules-only output rather than failing the capture.

```json
{
  "amount":            {"value": 18500.00, "confidence": 0.96},
  "currency":          {"value": "UYU",    "confidence": 0.88},
  "expense_date":      {"value": "2025-03-12", "confidence": 0.93},
  "vendor_name":       {"value": "Corralón San Martín", "confidence": 0.81},
  "vendor_tax_id":     {"value": "210123456789", "confidence": 0.70},
  "document_type":     {"value": "e_ticket", "confidence": 0.85},
  "document_number":   {"value": "A-0001-00045678", "confidence": 0.77},
  "tax_amount":        {"value": 3336.00, "confidence": 0.64},
  "payment_method":    {"value": "cash", "confidence": 0.55},
  "category_code":     {"value": "MATERIALS", "confidence": 0.90},
  "phase_template_code":{"value": "PLASTER", "confidence": 0.62},
  "items": [
    {"description": "Bolsa portland 25 kg", "quantity": 40, "unit": "bolsa",
     "unit_price": 462.5, "amount": 18500.00, "confidence": 0.87}
  ],
  "warnings": ["currency_inferred_from_project"]
}
```

**Confidence → UI mapping:** `≥0.85` green (silent), `0.60–0.84` amber (`Verificar`), `<0.60` red/empty (user must fill). These thresholds are config values, tuned against the `Calidad de datos` tab's correction-rate metric.

**Prompt engineering notes:**
- System prompt in English (it's code), input text in Spanish. Set `temperature=0`, `format="json"` (Ollama's JSON mode), and cap `num_predict`.
- Give the model the project country, project currency and today's date as context.
- Instruct: *never invent a value; omit the field or return low confidence instead.* Hallucinated amounts are the single worst failure mode — a missing field costs 3 seconds of typing, a wrong amount corrupts a budget.
- Keep the prompt, the model name and a prompt version hash in `captures.raw_model_output` so you can explain any historical extraction.

---

## 8. API design

**Base:** `/api/v1`. JSON. All field names in English `snake_case`. OpenAPI auto-generated at `/docs` (disabled in production).

### 8.1 Auth
- `POST /auth/login` → `{access_token (15 min), refresh_token (30 d)}`
- `POST /auth/refresh` → rotating refresh tokens (old one revoked; reuse detection revokes the family)
- `POST /auth/logout`
- `POST /auth/change-password`
- Passwords: **argon2id**. Rate limit: 5 attempts / 15 min / IP+email.

### 8.2 Core resources

```
GET    /projects                       # scoped by membership; master sees all
GET    /projects/{id}
POST   /projects                       # master
PATCH  /projects/{id}                  # master
GET    /projects/{id}/phases
POST   /projects/{id}/phases           # manager+
PATCH  /phases/{id}
GET    /projects/{id}/estimates
POST   /projects/{id}/estimates
POST   /estimates/{id}/approve
GET    /estimates/{id}/lines
PUT    /estimates/{id}/lines           # bulk replace

GET    /expenses?project_id&status&from&to&category_id&phase_id&vendor_id&q&page
POST   /expenses                       # idempotent on client-supplied id
GET    /expenses/{id}
PATCH  /expenses/{id}
POST   /expenses/{id}/approve
POST   /expenses/{id}/reject           # body: {reason}
DELETE /expenses/{id}                  # soft
POST   /expenses/bulk-approve

POST   /captures                       # → presigned upload URL
POST   /captures/{id}/uploaded         # → enqueue processing
GET    /captures/{id}                  # poll status + extracted
POST   /captures/{id}/retry

GET    /bank-accounts
POST   /bank-statements/upload         # multipart CSV → parse preview
POST   /bank-statements/confirm        # commit with column mapping
GET    /bank-transactions?recon_status&account_id&from&to
GET    /bank-transactions/{id}/match-suggestions
POST   /bank-transactions/{id}/match   # body: {expense_ids[]}
POST   /bank-transactions/{id}/ignore

GET    /fx/rates?base&quote&type&from&to
POST   /fx/sync                        # master; body: {from, to}
POST   /fx/manual                      # master; body: {date, base, quote, type, rate, reason}

GET    /metrics/consolidated?currency&from&to
GET    /metrics/projects/{id}/financial?currency
GET    /metrics/projects/{id}/progress
GET    /metrics/projects/{id}/expenses-breakdown?group_by=category|vendor|phase|month
GET    /metrics/projects/{id}/s-curve?currency
GET    /metrics/reconciliation?project_id
GET    /metrics/data-quality?project_id&from&to
GET    /metrics/benchmarks                        # closed-project comparison

GET    /users                          # master
POST   /users                          # master
PATCH  /users/{id}                     # master
POST   /projects/{id}/members          # master
GET    /vendors?q
POST   /vendors
POST   /vendors/{id}/merge             # body: {target_id}
GET    /categories
GET    /audit-log?entity_type&entity_id&project_id&actor&from&to   # master
POST   /exports/expenses               # → job id → presigned XLSX/CSV URL
```

### 8.3 Authorization enforcement

- A FastAPI dependency `require_project_access(project_id, min_role)` resolves membership on every request.
- **Additionally**, enable **PostgreSQL Row-Level Security** on `expenses`, `captures`, `bank_transactions`, `construction_phases`, `project_estimates`, with the app setting `SET LOCAL app.current_user_id` / `app.current_role` per transaction. Defense in depth: a forgotten `WHERE project_id = ...` in a query cannot leak another project's data.
- `master` bypasses via a dedicated `BYPASSRLS`-adjacent policy predicate, not by connecting as superuser.

### 8.4 Conventions
- Pagination: cursor-based (`?cursor=&limit=`) on expense/transaction lists.
- Idempotency: `POST /expenses` and `POST /captures` accept the client-generated `id`; a repeat with the same id returns the existing record (`200`, not `409`). Essential for offline retry.
- Errors: RFC 7807 problem+json with a stable `code` the clients map to Spanish messages. **The API never returns user-facing Spanish text** — the clients own all copy.
- Timestamps: UTC, ISO-8601, always `timestamptz`. Display timezone: `America/Montevideo` / `America/Argentina/Buenos_Aires`.

---

## 9. Offline sync protocol

### 9.1 Model
Mobile keeps a local mirror (WatermelonDB/SQLite) of: assigned projects, their phases, categories, vendors, recent FX rates, and **the user's own** expenses/captures from the last 90 days.

### 9.2 Endpoints
```
POST /sync/push
  { device_id, last_pulled_at, changes: { expenses: {created[], updated[]}, captures: {...} } }
  → { accepted[], rejected[{id, code, message}], server_time }

GET  /sync/pull?last_pulled_at=&device_id=
  → { changes: { projects, phases, categories, vendors, expenses, fx_rates }, server_time }
```

### 9.3 Rules
- **Push before pull**, always, in one sync session.
- Client IDs are UUIDv7 → globally unique, chronologically sortable, no server round-trip needed to create records.
- **Conflict resolution:**
  - Field users can only modify their own `draft`/`submitted`/`rejected` records → conflicts are rare by construction.
  - If the server record is `approved` and the client sends an update → server wins, client is told (`code: RECORD_LOCKED`), local copy is overwritten, user sees `"Este gasto fue modificado por el jefe de proyecto"`.
  - Otherwise last-write-wins on `client_updated_at`, with the loser's version written to `audit_log` so nothing is silently lost.
- **Media is separate from data.** Text records sync first (kilobytes), media follows (megabytes), on Wi-Fi by default. An expense is valid and visible to managers before its photo arrives; the UI shows `📷 Foto pendiente de subir`.
- Media upload is chunked/resumable with retry; the local file is deleted only after the server confirms the object exists.
- `devices.last_sync_at` powers the `Calidad de datos` tab's "oldest unsynced item" metric.
- FX rates are pushed down to the device so the mobile app can show approximate converted amounts offline.

---

## 10. Metrics layer

Keep it in Postgres. No warehouse, no dbt, no Databricks at this scale.

### 10.1 Approach
- **Views** for everything cheap and always-fresh.
- **Materialized views** for the portfolio dashboard and the S-curve, refreshed by an arq cron every 15 minutes with `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
- A single canonical view `v_expenses_reporting` that every other metric builds on — so the definition of "an expense that counts" exists in exactly one place.

```sql
-- The one source of truth for reporting
CREATE VIEW v_expenses_reporting AS
SELECT
  e.id, e.project_id, e.phase_id, e.category_id, e.vendor_id,
  e.expense_date, e.amount, e.currency, e.status,
  COALESCE(
    e.amount_usd,                                        -- frozen snapshot if approved
    e.amount / NULLIF(fx.rate, 0)                        -- live lookup otherwise
  ) AS amount_usd,
  date_trunc('month', e.expense_date)::date AS month
FROM expenses e
JOIN projects p ON p.id = e.project_id
LEFT JOIN LATERAL (
  SELECT r.rate
  FROM fx_rates r
  WHERE r.base_currency = 'USD'
    AND r.quote_currency = e.currency
    AND r.rate_type = p.fx_policy_rate_type
    AND r.rate_date <= e.expense_date
    AND r.rate_date >= e.expense_date - INTERVAL '7 days'
  ORDER BY r.rate_date DESC
  LIMIT 1
) fx ON e.currency <> 'USD'
WHERE e.deleted_at IS NULL
  AND e.status IN ('submitted','approved');   -- business rule, defined once
```

```sql
-- Budget vs actual by phase
CREATE VIEW v_phase_budget_vs_actual AS
WITH budget AS (
  SELECT el.phase_id, SUM(el.amount) AS budget_amount, pe.currency
  FROM estimate_lines el
  JOIN project_estimates pe ON pe.id = el.estimate_id
  WHERE pe.status = 'approved'
  GROUP BY el.phase_id, pe.currency
),
actual AS (
  SELECT phase_id, SUM(amount_usd) AS actual_usd, COUNT(*) AS expense_count
  FROM v_expenses_reporting
  GROUP BY phase_id
)
SELECT
  cp.id AS phase_id, cp.project_id, cp.template_code, cp.name, cp.sequence,
  cp.progress_pct, cp.status,
  b.budget_amount, b.currency AS budget_currency,
  a.actual_usd, a.expense_count,
  CASE WHEN COALESCE(b.budget_amount,0) > 0
       THEN ROUND((a.actual_usd / b.budget_amount - 1) * 100, 2) END AS deviation_pct
FROM construction_phases cp
LEFT JOIN budget b ON b.phase_id = cp.id
LEFT JOIN actual a ON a.phase_id = cp.id;
```

```sql
-- Portfolio dashboard (materialized)
CREATE MATERIALIZED VIEW mv_project_kpis AS
SELECT
  p.id AS project_id, p.code, p.name, p.status, p.country, p.built_area_m2,
  (SELECT total_amount FROM project_estimates
    WHERE project_id = p.id AND status = 'approved')            AS budget_amount,
  (SELECT SUM(amount_usd) FROM v_expenses_reporting
    WHERE project_id = p.id)                                    AS actual_usd,
  (SELECT SUM(amount_usd) FROM v_expenses_reporting
    WHERE project_id = p.id AND expense_date >= current_date - 90) AS actual_usd_90d,
  (SELECT ROUND(SUM(cp.progress_pct * COALESCE(cp.planned_cost,1))
              / NULLIF(SUM(COALESCE(cp.planned_cost,1)),0), 2)
     FROM construction_phases cp WHERE cp.project_id = p.id)     AS physical_progress_pct,
  (SELECT COUNT(*) FROM expenses
    WHERE project_id = p.id AND status = 'submitted' AND deleted_at IS NULL) AS pending_approvals,
  (SELECT name FROM construction_phases
    WHERE project_id = p.id AND status = 'in_progress'
    ORDER BY sequence LIMIT 1)                                  AS current_phase
FROM projects p
WHERE p.deleted_at IS NULL;

CREATE UNIQUE INDEX ON mv_project_kpis (project_id);   -- required for CONCURRENTLY
```

Additional views to build: `v_s_curve` (planned cumulative from estimate + phase dates vs. actual cumulative by month), `v_reconciliation_kpis`, `v_capture_quality` (correction rate per field, comparing `captures.extracted` against the saved `expenses` row), `v_project_benchmarks` (cost per m², duration, final deviation for `closed` projects).

### 10.2 Cost-per-m² benchmark
`actual_usd / built_area_m2`, only for `status='closed'` projects, grouped by `country` and completion year. This is the number that makes the next project's estimate credible.

---

## 11. Docker Compose

`docker-compose.yml` (production-ish; a `.override.yml` adds hot-reload and exposed ports for dev):

```yaml
name: obra-crm

x-common: &common
  restart: unless-stopped
  env_file: [.env]
  logging:
    driver: json-file
    options: { max-size: "10m", max-file: "3" }

services:
  postgres:
    <<: *common
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      TZ: America/Montevideo
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./ops/postgres/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    # no ports published: only reachable on the internal network

  redis:
    <<: *common
    image: redis:7.2-alpine        # BSD-licensed line; or valkey/valkey:8-alpine
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${REDIS_PASSWORD}"]
    volumes: [redisdata:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "--pass", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      retries: 5

  minio:
    <<: *common
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes: [miniodata:/data]
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 15s
      retries: 5

  minio-init:
    image: minio/mc:latest
    depends_on: { minio: { condition: service_healthy } }
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 $$MINIO_ROOT_USER $$MINIO_ROOT_PASSWORD &&
      mc mb --ignore-existing local/receipts &&
      mc mb --ignore-existing local/audio &&
      mc mb --ignore-existing local/documents &&
      mc mb --ignore-existing local/exports &&
      mc anonymous set none local/receipts"
    env_file: [.env]
    restart: "no"

  api:
    <<: *common
    build: ./api
    depends_on:
      postgres: { condition: service_healthy }
      redis:    { condition: service_healthy }
      minio:    { condition: service_healthy }
    command: >
      sh -c "alembic upgrade head &&
             uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2"
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request;urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 20s
      retries: 5

  worker:
    <<: *common
    build: ./api
    depends_on:
      api:        { condition: service_started }
      ml-service: { condition: service_started }
    command: ["arq", "app.workers.settings.WorkerSettings"]

  scheduler:
    <<: *common
    build: ./api
    depends_on: { redis: { condition: service_healthy } }
    command: ["arq", "app.workers.settings.CronSettings"]   # FX sync, MV refresh, digests, backups

  ml-service:
    <<: *common
    build: ./ml-service
    environment:
      WHISPER_MODEL: ${WHISPER_MODEL:-medium}
      WHISPER_COMPUTE_TYPE: ${WHISPER_COMPUTE_TYPE:-int8}
      OCR_LANG: es
    volumes:
      - mlmodels:/models          # cache PaddleOCR + Whisper weights across rebuilds
    # Uncomment for GPU:
    # deploy:
    #   resources:
    #     reservations:
    #       devices: [{ driver: nvidia, count: 1, capabilities: [gpu] }]

  ollama:
    <<: *common
    image: ollama/ollama:latest
    volumes: [ollamadata:/root/.ollama]
    # deploy: (same GPU block as above)

  ollama-init:
    image: ollama/ollama:latest
    depends_on: [ollama]
    entrypoint: ["/bin/sh","-c","OLLAMA_HOST=http://ollama:11434 ollama pull ${LLM_MODEL:-qwen2.5:7b-instruct}"]
    restart: "no"

  web:
    <<: *common
    build:
      context: ./web
      args: { VITE_API_URL: ${PUBLIC_API_URL} }
    # serves the static build on :80 inside the network

  caddy:
    <<: *common
    image: caddy:2-alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddydata:/data
      - caddyconfig:/config
    depends_on: [api, web]

  backup:
    <<: *common
    build: ./ops/backup          # alpine + postgresql-client + restic
    volumes:
      - backups:/backups
      - miniodata:/minio-data:ro
    entrypoint: ["/usr/local/bin/backup-cron.sh"]

volumes:
  pgdata: {}
  redisdata: {}
  miniodata: {}
  mlmodels: {}
  ollamadata: {}
  caddydata: {}
  caddyconfig: {}
  backups: {}
```

`Caddyfile`:

```
{$PUBLIC_DOMAIN} {
    encode zstd gzip

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    handle /api/* {
        reverse_proxy api:8000
    }

    handle /media/* {
        reverse_proxy minio:9000
    }

    handle {
        reverse_proxy web:80
    }
}
```

**Deployment notes**
- Only Caddy publishes ports. Postgres, Redis, MinIO and the ML services are unreachable from outside the Docker network.
- TLS: Caddy gets a free Let's Encrypt certificate automatically if the host has a public DNS name. For a LAN-only deployment use `tls internal` (Caddy's local CA) and install its root cert on the phones — **the mobile app must not talk plain HTTP**.
- `make up` / `make seed` / `make migrate` / `make backup` / `make logs` wrap the common commands so nobody memorizes Compose flags.
- `docker compose --profile monitoring up` adds Prometheus + Grafana + Loki when you want them, without them taxing RAM on day one.

---

## 12. Security & compliance

You mentioned no prior experience here, so this is a concrete, prioritized checklist rather than a discussion. Items marked **[MVP]** should ship with v1.

### 12.1 Application security
- **[MVP]** Passwords hashed with **argon2id** (never bcrypt-with-low-cost, never SHA).
- **[MVP]** JWT access tokens 15 min + rotating refresh tokens 30 days, with reuse detection.
- **[MVP]** RBAC enforced server-side on every endpoint + **Postgres RLS** as a second layer.
- **[MVP]** Rate limiting on `/auth/*` (5/15min) and on media upload endpoints.
- **[MVP]** All input validated by Pydantic; SQL only through SQLAlchemy parameter binding (no string-built SQL).
- **[MVP]** Presigned URLs for all media, expiring in 15 minutes. **No public buckets, ever.**
- **[MVP]** HTTPS everywhere, HSTS, secure headers (see Caddyfile), CORS restricted to the known web origin.
- **[MVP]** Secrets in `.env`, never in git. `.env.example` committed with dummy values. Rotate the JWT signing key with a documented procedure.
- **[MVP]** Dependency scanning: `pip-audit` + `npm audit` in CI; Trivy on built images.
- Phase 2: 2FA (TOTP) for `master` and `manager`; account lockout after repeated failures; session list with remote revoke.

### 12.2 Data protection
- **[MVP]** **Store bank account numbers masked only** (`****4417`). You have no business need for the full number, and not storing it removes an entire class of risk.
- **[MVP]** Full-disk encryption on the host (LUKS). This is what actually protects the database and the receipt photos if the machine is stolen — and it's free.
- **[MVP]** Encrypted, off-machine backups (see §13). An unencrypted backup on the same disk is not a backup.
- **[MVP]** Immutable **audit log** covering create/update/delete/approve/reject/login/export/import, with actor, IP and before/after JSON. Append-only: no `UPDATE`/`DELETE` grants on `audit_log` for the app role.
- **[MVP]** Soft deletes on financial records; hard deletion only through a documented, audited admin procedure.
- **[MVP]** PII minimization: the app stores names, emails, phones and work data. **Don't** store national ID numbers, salaries, or home addresses of workers unless a specific need appears — and if it does, revisit this section first.
- Phase 2: column-level encryption (`pgcrypto`) for vendor tax IDs; ClamAV scanning of uploads; automated retention/purge jobs.

### 12.3 Legal context (Argentina + Uruguay)
Not legal advice — this is the shortlist to raise with a local lawyer, plus the technical work that satisfies it.

- **Argentina — Ley 25.326 (Protección de Datos Personales)**, enforced by the AAIP. Relevant obligations: lawful purpose, data subject access/rectification rights, security measures proportional to sensitivity, and registration of databases containing personal data.
- **Uruguay — Ley 18.331 (Protección de Datos Personales)**, enforced by URCDP. Similar duties: database registration with URCDP, consent/purpose limitation, security measures, and breach notification.
- **What both imply, technically:** documented purpose for each data category, access controls (done), audit trail (done), encryption (done), a defined retention period, a process to honor access/deletion requests, and named responsibility for the database.
- **Tax/document retention:** receipts and supporting documentation generally need to be retained for several years in both countries (commonly cited as 5–10). **Confirm the exact figure with your accountant** and set the retention config accordingly — the system should never purge a receipt before that window ends.
- **Employment records:** if you later track workers' hours or pay, you cross into labor-law record-keeping obligations. Out of MVP scope deliberately.
- **[MVP] deliverables:** a one-page internal data-handling policy, a register of what data is stored where and why, and named owner + defined retention per table.

### 12.4 Operational security
- **[MVP]** Host hardening: SSH keys only (no passwords), UFW allowing only 22/80/443, automatic security updates, fail2ban.
- **[MVP]** Docker: containers run as non-root users, read-only root filesystems where feasible, no `privileged`, no unnecessary published ports (see §11).
- **[MVP]** Separate Postgres roles: `app_rw` for the API (no DDL), `app_migrate` for Alembic, `app_ro` for analytics/BI. The API must not connect as superuser.
- **[MVP]** Quarterly restore drill — a backup you've never restored is a hypothesis, not a backup.

---

## 13. Backups & disaster recovery

| What | How | Frequency | Retention |
|---|---|---|---|
| Postgres logical | `pg_dump -Fc` → restic repo | Hourly (business hours), daily full | 7 daily, 4 weekly, 12 monthly |
| Postgres WAL | `pgBackRest` (BSD) or `wal-g` (Apache-2.0) | Continuous | 7 days (enables point-in-time recovery) |
| MinIO objects | `mc mirror` → restic repo | Daily | 30 daily, 12 monthly |
| Config / secrets | Encrypted vault + printed copy in a safe | On change | Forever |

- **restic** encrypts client-side with a passphrase; the destination can be a second disk, a NAS, or an external drive rotated weekly. All free.
- **Rule:** at least one copy off the machine and one copy offline. A single Docker host is a single point of failure — plan for its disk dying, not just for a bad deploy.
- **RPO target:** ≤1 hour. **RTO target:** ≤4 hours with a documented, tested runbook in `docs/runbook-restore.md`.
- Mobile devices are not a backup, but they do hold unsynced captures — which is one more reason to make sync frequent and visible.

---

## 14. Observability & testing

**Observability (add after MVP is stable):**
- `structlog` JSON logs → Loki → Grafana. Every log line carries `request_id`, `user_id`, `project_id`.
- Prometheus metrics from the API: request latency/status, queue depth, capture processing duration by mode, OCR/ASR confidence distribution, FX sync success.
- Grafana alerts: FX sync failed 2× consecutively; capture queue > 20; any capture older than 1 h in `processing`; disk > 80 %; backup job failed.
- GlitchTip for exception tracking (self-hosted, Sentry SDK compatible).

**Testing:**
- `pytest` + `testcontainers` (real Postgres, not SQLite) for API and services.
- **Golden-file tests for extraction:** a fixture set of ~50 real Argentine and Uruguayan tickets and ~30 Spanish audio clips with hand-labeled expected output. Assert field-level accuracy and **fail CI if accuracy regresses**. This is the highest-value test suite in the project — without it, a model or prompt change silently degrades data quality.
- FX tests: recorded HTTP fixtures (`vcr.py`) for BCU/BCRA/DolarApi, plus explicit tests for holidays, weekends, missing days, and the 7-day fallback boundary.
- Money tests: cross-currency conversion round-trips, rate-snapshot immutability after approval, reconciliation matching edge cases.
- Frontend: Vitest + React Testing Library; Playwright for the critical manager flows.
- Mobile: Jest for sync logic (the outbox and conflict resolution deserve exhaustive unit tests), Detox or manual QA for capture flows on real devices.
- Load: `locust` — simulate 200 captures/day and 10 concurrent dashboard users. Trivial for this stack, but worth a baseline.

**CI pipeline (free):** lint (`ruff`, `eslint`) → type check (`mypy`, `tsc`) → tests → build images → security scan → push to a self-hosted registry. GitHub Actions free tier covers this comfortably for a private repo at this size; Gitea Actions on the same Docker host if you want zero external dependencies.

---

## 15. Delivery plan

| Sprint (2 weeks) | Deliverable |
|---|---|
| **0** | Repo, Docker Compose up, Postgres + migrations, seed data (3 active + 1 closed project with mock volumes), auth + RBAC, CI skeleton |
| **1** | Full data model, project/phase/estimate CRUD, web shell (routing, i18n, layout, currency toggle), admin: users + projects |
| **2** | **FX subsystem end to end**: BCU + BCRA + ArgentinaDatos connectors, backfill from 01/01/2025, conversion service, admin rate screen. *Do this early — every later number depends on it.* |
| **3** | Mobile app shell: login, project selector, **manual capture**, local DB, outbox, full sync protocol. Ship this to one real field user and watch them use it. |
| **4** | Photo capture: MinIO uploads, PaddleOCR, rules layer, LLM extraction, review screen, confidence UI |
| **5** | Audio capture: recorder, faster-whisper, Spanish number/date/currency normalization, shared review screen |
| **6** | Web console metrics: consolidado + the 6 analysis tabs, materialized views, expense approval workflow, exports |
| **7** | Bank CSV import wizard + reconciliation workspace + matching suggestions |
| **8** | Hardening: audit log surfacing, backups + restore drill, security checklist, golden-file extraction test suite, observability, docs & runbooks |

**Cut-line advice:** sprints 0–3 are the real MVP. If you have to ship something in 8 weeks, ship manual capture + the consolidated dashboard + FX. Photo and audio are the product's magic, but *reliable manual capture with correct multi-currency math* is what makes it trustworthy — and trust is harder to win back than a delayed feature.

---

## 16. Key risks

| Risk | Impact | Mitigation |
|---|---|---|
| OCR accuracy on faded thermal tickets | High — field users abandon photo mode | Rules layer + LLM fallback; always land on the editable review screen; track correction rate in the `Calidad de datos` tab and iterate on the prompt |
| ASR confusion on amounts (`"quince mil"` vs `"cincuenta mil"`) | **Very high — wrong amount corrupts a budget** | Deterministic Spanish number parser before the LLM; amount always shown amber (requires confirmation) in audio mode regardless of confidence |
| ARS blue vs oficial rate choice | High — changes reported cost by 30–80 % | Per-project explicit FX policy; every converted figure carries its rate type and date; the admin can re-state a policy and re-run reports |
| Community FX APIs going offline | Medium | BCU + BCRA (official, authoritative) are primary; community APIs only for AR parallel rates; manual override always available; gap detection alerts |
| Single Docker host failure | High | Tested off-machine encrypted backups; documented restore runbook; the mobile app keeps working offline while the server is down |
| Field users bypassing the app | High — data gaps make every metric a lie | Capture speed as a tracked product metric; `Calidad de datos` tab flags silent users; bank reconciliation catches spend with no matching expense |
| Vendor name duplication | Medium — breaks vendor analytics | `pg_trgm` fuzzy autocomplete at entry; admin merge tool from day one |
| Data model churn | Medium | Alembic from sprint 0; `jsonb` escape hatches for raw AI output; additive-migration discipline |
| LLM hallucinating amounts | **Very high** | `temperature=0`, JSON mode, explicit "never invent" instruction, confidence thresholds, golden-file regression tests in CI |

---

## 17. Answers I need from you (technical)

1. **Host machine specs** — CPU, RAM, GPU? This determines the ASR/LLM model sizes in §4 and whether photo processing feels instant or takes 25 s.
2. **Network** — will the server be reachable from the internet with a public DNS name (Caddy auto-TLS, phones work anywhere), or LAN/VPN only (Tailscale is free and excellent for this, but field users need connectivity to sync)?
3. **Mobile distribution** — internal APK sideload, Google Play internal testing track (needs a one-time $25 developer account), or Expo dev client? This affects the update workflow.
4. **Bank CSV formats** — please send one real CSV per bank/account. Column layouts vary wildly and the import mapper needs the actual files to be built against.
5. **Sample tickets and audio** — 30–50 photographed tickets (AR and UY, thermal and printed) and 20–30 Spanish voice notes recorded the way your field users actually talk. **This is the single most valuable thing you can give the team**, and it's needed before sprint 4.
6. **Existing data** — are there spreadsheets from current/past projects to migrate? A closed project's real numbers would make the benchmark features meaningful from day one.
7. **iOS** — needed? iOS builds require a Mac for local builds (or paid EAS). Android-only is meaningfully cheaper for MVP.
8. **Accountant's requirements** — ask them now what document retention period applies and what export format they want. Cheap to build in sprint 1, expensive to retrofit.
