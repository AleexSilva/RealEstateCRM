# agents.md — Product & UX Specification

**Project codename:** `OBRA CRM`
**Version:** 0.1 (MVP definition)
**Scope:** Real estate CRM for lot purchase + ground-up house construction, operating in Argentina and Uruguay.
**Audience of this file:** product, design, and anyone who needs to understand *what* we are building and *why*. No code here — see `technical_details.md` for the *how*.

---

## 1. Product in one paragraph

A multi-project CRM for a company that buys vacant lots and builds houses from scratch. Field users load every peso/dollar that moves on a construction site from their phone — by typing, by photographing a ticket, or by speaking. Project managers get a web console with a consolidated portfolio view plus deep per-project drill-downs. A master user administers everything. The whole operation runs across three currencies (ARS, UYU, USD) with automatic daily FX rates so that "how much did this house actually cost" always has a defensible answer.

---

## 2. Roles and personas

| Role | Internal name (code) | Surface | Count (MVP) | Core job |
|---|---|---|---|---|
| Field user | `field_user` | Mobile app | ≥1 per project | Load expenses fast, in the field, often without signal |
| Project manager | `manager` | Web console | 2 per project | Control budget vs. actual, approve expenses, track phase progress |
| Master / Admin | `master` | Web console | 1–2 total | See all projects, manage users, categories, FX policy, audit |

### 2.1 Persona notes

- **Field user ("Cargador de obra")**
  - Foreman, site administrator, or the owner's right hand.
  - On a construction site: dust, gloves, bad light, intermittent 4G, one hand free.
  - Not an accountant. Should never be asked to pick an accounting code.
  - Success = "I loaded a ticket in under 20 seconds without typing."
- **Project manager ("Jefe de proyecto")**
  - Sits in an office, works on a laptop, lives in spreadsheets today.
  - Cares about: am I over budget, where, and is the delay in the phase or in the payments.
  - Success = "I stopped rebuilding the same Excel every Monday."
- **Master ("Administrador")**
  - Owner or head of operations.
  - Cares about: portfolio-level cost per m², which project bleeds, closed-project lessons.
  - Success = "One screen tells me which of my 3 open projects needs me this week."

### 2.2 Permission matrix

| Capability | field_user | manager | master |
|---|---|---|---|
| See projects they are assigned to | ✅ | ✅ | ✅ (all) |
| See projects they are NOT assigned to | ❌ | ❌ | ✅ |
| Create expense / capture | ✅ | ✅ | ✅ |
| Edit own expense (while `draft`/`submitted`) | ✅ | ✅ | ✅ |
| Edit any expense in their project | ❌ | ✅ | ✅ |
| Approve / reject expense | ❌ | ✅ | ✅ |
| Delete (soft) expense | ❌ | ✅ | ✅ |
| Import bank statement (CSV) | ❌ | ✅ | ✅ |
| Reconcile bank transaction ↔ expense | ❌ | ✅ | ✅ |
| Create/edit construction phases | ❌ | ✅ | ✅ |
| Create/approve project estimate (budget) | ❌ | ✅ | ✅ |
| See consolidated multi-project dashboard | ❌ | ✅ (own projects only) | ✅ (all) |
| Create projects | ❌ | ❌ | ✅ |
| Manage users & assignments | ❌ | ❌ | ✅ |
| Manage expense categories | ❌ | ❌ | ✅ |
| Set FX policy | ❌ | ❌ | ✅ |
| View audit log | ❌ | ❌ | ✅ |
| Export CSV/XLSX | ❌ | ✅ | ✅ |

> **Rule:** every data access is scoped by project membership. `master` is the only role that bypasses it. This is enforced server-side, never in the UI only.

---

## 3. Product principles

- **Capture is sacred.** If loading an expense is slow or fails, the whole product is worthless. Optimize the mobile flow above everything else.
- **Never block the user on AI.** OCR and audio transcription *pre-fill*, they don't decide. The user always sees an editable form before saving.
- **Offline is the default assumption, not an edge case.** The app works with zero connectivity and syncs 1–2× a day.
- **Money is never stored converted.** We store what was actually spent, in the currency it was spent, and convert only at display/report time. See §6.
- **Spanish for users, English for the codebase.** See §4.
- **Every number on a dashboard must be clickable** down to the underlying rows. Managers won't trust a KPI they can't audit.
- **Closed projects stay queryable.** A finished project moves to `closed`, disappears from the default active view, but still feeds portfolio benchmarks (cost/m², deviation, duration).

---

## 4. Language & localization rules

**Hard rule:** 100% of what a user sees is in Spanish. 100% of the code, database, API, logs, and internal documentation is in English.

- **UI language:** Spanish (Rioplatense-neutral). Use `es-UY` as the default locale, `es-AR` as a secondary.
- **Tone:** neutral, no voseo in system copy (`"Seleccioná"` → use `"Seleccionar"` / `"Seleccione"`). Buttons in infinitive: `Guardar`, `Cargar gasto`, `Sacar foto`.
- **Number format:** `1.234.567,89` (dot thousands, comma decimals).
- **Date format:** `DD/MM/AAAA`. Month names in Spanish, lowercase (`marzo`).
- **Currency display:** `$U 1.234,56` (UYU), `$ 1.234,56` (ARS), `US$ 1.234,56` (USD). Always show the currency marker — never a bare `$`.
- **OCR language model:** Spanish. Must handle Argentine and Uruguayan ticket vocabulary (`IVA`, `CUIT`, `RUT`, `Factura A/B/C`, `e-Ticket`, `Subtotal`, `Total`, `Contado`).
- **ASR language:** Spanish, Rioplatense accent. Must handle construction vocabulary (`hormigón`, `ladrillo hueco`, `contrapiso`, `pallet`, `corralón`, `hierro del 8`, `bolsa de portland`).
- **i18n architecture:** all strings live in translation files keyed in English (`expense.save_button` → `"Guardar gasto"`). No hardcoded Spanish in components. This keeps the door open for a future `pt-BR` or `en` without a rewrite.

### 4.1 Domain glossary (code ↔ UI)

| Code / DB term (English) | UI label (Spanish) |
|---|---|
| Project | Proyecto / Obra |
| User | Usuario |
| Field user | Cargador |
| Manager | Jefe de proyecto |
| Master | Administrador |
| Expense | Gasto |
| Expense detail / line item | Detalle del gasto / Ítem |
| Construction phase | Etapa de obra |
| Project estimate | Presupuesto estimado |
| Estimate line | Línea de presupuesto |
| Bank account extract / statement | Extracto bancario |
| Bank transaction | Movimiento bancario |
| Reconciliation | Conciliación |
| Vendor / supplier | Proveedor |
| Category | Rubro |
| Capture | Carga |
| Draft | Borrador |
| Submitted | Enviado |
| Approved | Aprobado |
| Rejected | Rechazado |
| Pending review | Pendiente de revisión |
| Budget vs actual | Presupuestado vs. real |
| Deviation | Desvío |
| Progress | Avance |
| Exchange rate | Tipo de cambio / Cotización |
| Sync | Sincronizar |

---

## 5. Information architecture

```
OBRA CRM
├── 📱 APP MÓVIL  (field_user, also usable by manager)
│   ├── Ingreso (login)
│   ├── Selector de proyecto
│   ├── Inicio  → 3 big capture buttons + recent loads
│   ├── Cargar gasto
│   │   ├── Escribir  (manual form)
│   │   ├── Foto      (ticket → OCR → prefilled form)
│   │   └── Audio     (voice → transcript → prefilled form)
│   ├── Revisión y confirmación  (shared final step of all 3 modes)
│   ├── Mis cargas  (history + sync status)
│   └── Ajustes  (currency, sync, logout)
│
└── 💻 CONSOLA WEB  (manager, master)
    ├── Consolidado          ← landing page, portfolio level
    ├── Proyectos
    │   └── [Proyecto]
    │       ├── Resumen
    │       ├── Financiero
    │       ├── Avance de obra
    │       ├── Gastos
    │       ├── Bancos y conciliación
    │       ├── Presupuesto
    │       └── Documentos
    ├── Análisis (cross-project tabs)
    │   ├── Financiero
    │   ├── Avance
    │   ├── Gastos
    │   ├── Bancos
    │   ├── Calidad de datos
    │   └── Histórico / Proyectos cerrados
    └── Administración  (master only)
        ├── Usuarios y accesos
        ├── Proyectos
        ├── Rubros (categories)
        ├── Proveedores
        ├── Tipos de cambio
        └── Auditoría
```

---

## 6. Currency & FX — product rules

This is the highest-risk area of the product. Get it wrong and every number is wrong.

### 6.1 Rules

1. **Three currencies:** `ARS` (peso argentino), `UYU` (peso uruguayo), `USD` (dólar).
2. **Default currency = UYU.** The currency dropdown is present on: the mobile capture form, every web dashboard header, and every export.
3. **Store original.** An expense stores `amount` + `currency` exactly as it happened. Nothing is converted on write.
4. **Convert on read.** All dashboards convert to the *selected display currency* using the rate of the **expense date**, not today's rate.
5. **Rate snapshot on approval.** When a manager approves an expense, we persist the rate that was used (`fx_rate`, `fx_rate_type`, `fx_rate_date`). This freezes history so a report re-run in 6 months returns the same number.
6. **Argentina needs multiple rate types.** `oficial` and `blue`/`MEP` diverge enormously. Each project has an **FX policy** chosen by the master:
   - `oficial` — conservative / for formal accounting
   - `blue` — reflects real purchasing power for cash purchases
   - `mep` — for formalized dollar operations
   - Default for AR projects: `blue`. Default for UY projects: BCU interbank (`oficial`).
7. **History from 01/01/2025.** The system backfills daily rates from January 1st 2025 and updates daily thereafter.
8. **Missing rate fallback:** use the most recent previous business day, up to 7 days back. If still missing, flag the expense with `⚠️ Sin cotización` and exclude it from converted totals until resolved (never silently use 1:1).
9. **Always show the disclosure.** Any converted figure carries a subtle footnote: `"Convertido a USD · cotización blue · 12/03/2025"`.

### 6.2 UI touchpoints

- **Mobile:** currency selector is a segmented control (`$U` / `$` / `US$`) directly next to the amount field, defaulting to UYU (or to the project's country default). Remembering the last used currency per project is a nice-to-have.
- **Web:** a global currency toggle in the top bar. Changing it re-renders every chart and KPI on the page. It persists per user.
- **Admin:** a `Tipos de cambio` screen showing the rate table, last sync timestamp, source per rate, gaps in the series, and a manual "re-sync range" button plus manual rate override (with audit trail).

---

## 7. Mobile app — screen by screen

**Design target:** Android-first (most field phones), iOS supported. One-handed use. Big tap targets (≥48dp). High contrast for sunlight.

### 7.1 `Ingreso` — Login
- Email + password. "Recordarme" on by default.
- After first login the session persists for 30 days (field users shouldn't re-auth on a rooftop).
- Biometric unlock (optional, phase 2).

### 7.2 `Selector de proyecto`
- Shown only if the user belongs to >1 project; otherwise skipped.
- Card per project: name, photo/thumbnail, city, `Etapa actual: Estructura`, sync badge.
- The chosen project is sticky and shown permanently in the app header — **wrong-project loading is the #1 data quality risk**, so the header chip is colored per project.

### 7.3 `Inicio` — Home
- **Top:** project chip + sync status pill:
  - `✅ Sincronizado · hace 2 h`
  - `⏳ 4 cargas pendientes`
  - `⚠️ Sin conexión`
- **Center: three large buttons, equal weight.**
  - `⌨️ Escribir`
  - `📷 Foto`
  - `🎤 Audio`
- **Below:** `Últimas cargas` — last 5 with amount, vendor, date, status dot.
- **Bottom bar:** Inicio · Mis cargas · Ajustes.

### 7.4 Capture mode A — `Escribir` (manual)

A single-column form, ordered by what a person knows fastest:

| Field | Control | Notes |
|---|---|---|
| Monto | Numeric keypad, huge font | First field, autofocused |
| Moneda | Segmented `$U / $ / US$` | Default UYU |
| Fecha | Date picker | Defaults to today |
| Proveedor | Searchable dropdown + "Nuevo proveedor" | Autocomplete from history |
| Rubro | Icon grid (Materiales, Mano de obra, Servicios, Permisos, Herramientas, Fletes, Otros) | Never a long text list |
| Etapa de obra | Dropdown | Pre-selected to the project's current phase |
| Medio de pago | Chips: Efectivo / Transferencia / Tarjeta / Cheque | |
| Tipo de comprobante | Chips: Ticket / Factura / Recibo / Sin comprobante | |
| Nº de comprobante | Text | Optional |
| Detalle (ítems) | Expandable "Agregar ítems" | Optional in MVP, required for material purchases >X |
| Nota | Multiline | Optional |
| Foto adjunta | Camera/gallery | Optional even in manual mode |

- Validation: amount > 0, date not in the future, vendor OR note required.
- `Guardar` → goes straight to the outbox (no network needed).

### 7.5 Capture mode B — `Foto` (ticket OCR)

**Flow:**
1. Camera opens immediately with a rectangular guide overlay: `"Encuadrá el ticket completo"`.
2. Auto-capture assist: edge detection + `"Mantené el celular quieto"`.
3. Shot taken → local preview → `Usar esta foto` / `Repetir`.
4. Photo saved locally at once. **The expense is never lost even if processing fails.**
5. If online → upload + OCR immediately. If offline → queued, status `⏳ Pendiente de procesar`.
6. Processing screen: `"Leyendo el ticket…"` with a skeleton form (never a blank spinner). Max 15 s, then fall back to manual with the photo attached.
7. Result → **Review screen** (§7.7) with fields pre-filled and confidence-highlighted.

**What OCR must extract:**
- Total amount, currency, date, vendor name, tax ID (CUIT/RUT), document type & number, subtotal, IVA, and line items (description, qty, unit price, amount).

**Confidence UI:**
- Green left border = high confidence, silently accepted.
- Amber border + `"Verificar"` label = medium, user must tap to confirm.
- Red/empty = not found, user must fill in.
- Tapping any field shows the cropped region of the photo where the value came from (big trust-builder — phase 2 if costly).

### 7.6 Capture mode C — `Audio`

**Flow:**
1. Big circular record button. Press and hold, or tap to start/tap to stop (both supported; hold is better with gloves).
2. Live waveform + timer. Max 90 s.
3. Prompt shown on screen so users learn the pattern:
   > *"Contá qué compraste, cuánto costó, en qué moneda, a quién y para qué etapa."*
   > *Ejemplo: "Compré 40 bolsas de portland en el corralón San Martín, 18.500 pesos uruguayos, para la etapa de contrapiso, pagué en efectivo."*
4. Stop → audio stored locally → transcription (online) or queued (offline).
5. Transcript shown **verbatim and editable** above the pre-filled form. Users must be able to see what the system heard — it's how they learn to speak to it.
6. Result → Review screen.

**What ASR + extraction must produce:** same field set as OCR, plus the free transcript persisted as the expense note.

**Robustness requirements:**
- Handle "mil quinientos" and "1500" alike.
- Handle "pesos" ambiguously → if the speaker says just "pesos", use the project country default and flag it amber.
- Handle mixed content ("y también pagué el flete, 3 mil") → produce a **single expense with multiple line items**, or offer `"Detecté 2 gastos. ¿Separar?"`.

### 7.7 `Revisión y confirmación` — shared final step

The single most important screen in the app. Identical for all three capture modes (manual just arrives pre-filled by the user).

- Header: `Revisá y confirmá`
- Source badge: `📷 Desde foto` / `🎤 Desde audio` / `⌨️ Manual`
- The full form from §7.4, pre-filled, all fields editable.
- Attachment thumbnail (photo) or audio player (audio) pinned at top.
- A summary line: **`Total: $U 18.500 · Materiales · Etapa: Contrapiso`**
- Two actions: `Confirmar y guardar` (primary) and `Descartar`.
- On save: toast `"Gasto guardado ✓"`, haptic feedback, return to Inicio with the item at the top of `Últimas cargas`.

**Non-negotiable:** nothing is written to the server without passing through this screen.

### 7.8 `Mis cargas`
- Chronological list, grouped by day.
- Each row: amount + currency, vendor, category icon, status dot, sync icon.
- Status dots: `Borrador` (grey), `Enviado` (blue), `Aprobado` (green), `Rechazado` (red, with the manager's reason visible), `Pendiente de procesar` (amber).
- Filters: date range, status, capture mode.
- Rejected items are **editable and re-submittable** — closing the loop matters.

### 7.9 `Ajustes`
- Default currency, default phase.
- `Sincronizar ahora` button with last-sync timestamp and pending count.
- Storage used by queued photos/audio + `Liberar espacio` (only deletes already-synced media).
- Language (Spanish only in MVP, but the switch exists).
- Logout.

### 7.10 Offline & sync UX

- **The app is fully usable offline.** Every screen works from local data.
- **Sync targets 1–2× per day** but opportunistically syncs whenever connectivity + Wi-Fi is detected.
- Sync order: text records first (small, fast), then photos, then audio. A manager sees the expense appear before the heavy media arrives.
- Persistent banner when there are >0 pending items, with a count. Never a blocking modal.
- Conflict handling (rare, since field users only edit their own recent items): server wins on approved records; the user is told `"Este gasto fue modificado por el jefe de proyecto"` and shown the current version.
- Media upload is resumable and Wi-Fi-preferred by default (`Subir fotos solo con Wi-Fi` toggle, on by default).

---

## 8. Web console — Manager & Master

**Design target:** desktop-first, 1440px. Dense but breathable. Works down to 1024px. Not designed for phones (managers use the mobile app for capture only).

### 8.1 `Consolidado` — the landing page

This is the screen the master opens every morning. **Portfolio level, all projects at once.**

- **Header:** currency toggle (`UYU / ARS / USD`), date range, project filter (`Activos` / `Todos` / `Cerrados`).
- **KPI strip (mock numbers):**

| KPI | Mock value | Detail |
|---|---|---|
| Proyectos activos | `3` | +1 cerrado en 2025 |
| Inversión total ejecutada | `US$ 742.380` | acumulado los 3 proyectos |
| Presupuesto total aprobado | `US$ 905.000` | |
| Ejecución presupuestaria | `82,0 %` | barra de progreso |
| Desvío global | `+4,3 %` | 🔴 rojo si > +5 % |
| Avance físico promedio | `61 %` | ponderado por presupuesto |
| Gastos pendientes de aprobación | `17` | acción directa |
| Movimientos sin conciliar | `34` | acción directa |

- **Project cards (one per active project)** — the core of this screen:
  - Project name, city, country flag, thumbnail.
  - Two parallel bars: **Avance físico** (`61 %`) vs **Avance financiero** (`74 %`). The gap between these two bars is the single most useful signal in the whole product — if money outruns progress, there's a problem.
  - `Presupuesto: US$ 320.000 · Ejecutado: US$ 236.800 · Desvío: +2,1 %`
  - Current phase chip: `Etapa: Mampostería`
  - Alert badges: `⚠️ 6 gastos pendientes`, `🔴 Desvío en Estructura`
  - Click → project detail.
- **Two portfolio charts:**
  - Stacked monthly spend across all projects (last 12 months).
  - Scatter: `Costo por m² construido` vs `% de avance`, one dot per project, closed projects in grey as benchmarks.

### 8.2 Cross-project analysis — tabbed

Per your request, metrics are grouped into separate tabs. Same tabs exist at portfolio level (`Análisis`) and, filtered, inside each project.

#### Tab 1 — `Financiero`
- Budget vs. actual, by project and by phase (grouped bar).
- **Curva S**: planned cumulative spend vs actual cumulative spend, over time.
- Burn rate: average monthly spend, last 3 months, + projected completion cost.
- Deviation table: phase, budgeted, actual, deviation $, deviation %, status light.
- Currency exposure donut: how much of the total was spent in ARS / UYU / USD.
- FX impact line: what the same project cost in USD over time (shows devaluation effects).
- Mock: `Presupuestado US$ 320.000 · Ejecutado US$ 236.800 · Proyección al cierre US$ 327.000 · Desvío proyectado +2,2 %`

#### Tab 2 — `Avance de obra`
- Gantt of construction phases: planned bar vs actual bar, per project.
- Phase completion table: phase, planned start/end, actual start/end, `% avance`, days late, responsible.
- Milestone tracker with `🟢 En fecha / 🟡 En riesgo / 🔴 Atrasado`.
- Physical vs financial progress line chart (the divergence chart).
- Mock: `Etapa Estructura · 100 % · 12 días de atraso`; `Etapa Mampostería · 45 % · en fecha`.

#### Tab 3 — `Gastos`
- Spend by category (Materiales, Mano de obra, Servicios, Permisos, Fletes, Herramientas, Otros) — treemap or horizontal bars.
- Spend by vendor — top 15, with count and average ticket.
- Top 20 individual expenses.
- Expense table with every filter (project, phase, category, vendor, currency, payment method, capture mode, status, date, amount range) and full-text search on notes/transcripts.
- Approval queue: everything `submitted`, with inline `Aprobar` / `Rechazar` (reason required) and bulk-approve.
- Export to CSV/XLSX.
- Mock: `Materiales 54 % · Mano de obra 31 % · Servicios 8 % · Permisos 4 % · Otros 3 %`.

#### Tab 4 — `Bancos y conciliación`
- CSV import wizard: upload → map columns → preview → confirm. Remembers the mapping per bank account.
- Imported statements list: account, period, rows, imported by, date.
- Reconciliation workspace, two panes:
  - Left: unmatched bank transactions.
  - Right: unmatched expenses.
  - System proposes matches (amount ±1 %, date ±5 days, vendor name similarity) with a confidence score. `Confirmar` / `Descartar` / manual match / split match (1 transaction ↔ N expenses).
- KPIs: `% conciliado`, `Movimientos sin respaldo` (money left the bank but no expense loaded — the fraud/omission signal), `Gastos sin movimiento` (loaded but never hit the bank — cash or error).
- Mock: `Conciliado 78 % · 34 movimientos sin conciliar · US$ 12.430 sin respaldo`.

#### Tab 5 — `Calidad de datos y actividad`
Operational health of the capture pipeline. Managers won't ask for this, but they need it.
- Captures by mode: `Foto 61 % · Audio 24 % · Manual 15 %`.
- **AI correction rate**: % of OCR/ASR-prefilled fields that the user edited before saving. Tracks per field (amount, date, vendor, category). This is how we know whether the AI is helping or hurting.
- Median time from capture to sync; oldest unsynced item.
- Active users per project per week; days since last capture per user (`⚠️ Sin cargas hace 6 días`).
- Failed captures (OCR/ASR errors) with the original media, so a manager can rescue them manually.
- Expenses missing a receipt photo, % of total amount.

#### Tab 6 — `Histórico / Proyectos cerrados`
- Benchmark table across closed projects: total cost, cost per m² built, cost per m² of land, duration planned vs actual, final deviation %, cost split by category.
- "Compare project" selector: put 2–4 projects side by side, including active ones against closed benchmarks.
- `Lecciones aprendidas`: a free-text field per closed project, plus the auto-computed top 3 deviating phases.
- Mock: `Casa Carrasco (cerrado 2025) · US$ 298.400 · 210 m² · US$ 1.421/m² · 14 meses (plan 11) · desvío final +9,4 %`.

### 8.3 Project detail (drill-down)

Reached by clicking a project card. Same tabs as above but scoped to one project, plus:

- **`Resumen`**: hero with address, lot area, built area, start date, estimated end, current phase, thumbnail gallery, team (who is assigned with which role), and the 6 headline KPIs.
- **`Presupuesto`**: the estimate versions. Line items by phase and category, planned quantity/unit/unit price/total. `Aprobar versión` creates an immutable baseline; the S-curve and all deviation math compute against the approved baseline. Older versions remain visible and comparable (`v1 vs v3`).
- **`Documentos`**: permits, plans, contracts, insurance. Simple file store with type tags and expiry dates (`Permiso municipal vence 12/08/2026`).

### 8.4 Expense detail (drill-down)

Everything a manager needs to trust a number:
- All fields, editable with an edit history.
- Original photo (zoomable) or audio player + transcript.
- The raw OCR/ASR output vs. the final saved values, side by side.
- Conversion detail: `$U 18.500 → US$ 462,50 · cotización BCU interbancario venta 40,00 · 12/03/2025`.
- Linked bank transaction, if reconciled.
- Full audit trail: who created, who edited what and when, who approved.
- Actions: `Aprobar`, `Rechazar` (reason mandatory), `Reasignar etapa/rubro`, `Adjuntar documento`.

### 8.5 `Administración` (master only)

- **`Usuarios y accesos`**: create user, set global role, assign to projects with a per-project role, deactivate, force password reset. Never hard-delete a user who has created records.
- **`Proyectos`**: create/edit project, set country, base currency, FX policy, areas, dates, status (`planning` / `active` / `paused` / `closed`), archive.
- **`Rubros`**: category tree, active/inactive, merge two categories (with reassignment of existing expenses).
- **`Proveedores`**: vendor list, dedupe/merge tool (field users will create `"San Martin"` and `"Corralón San Martín"` — you need the merge button on day one).
- **`Tipos de cambio`**: rate table, sources, sync status, gap detection, manual override with reason.
- **`Auditoría`**: filterable audit log of every create/update/delete/approve/login, exportable.

---

## 9. Notifications & alerts

MVP keeps this small and email-based (plus in-app badges); push notifications are phase 2.

| Trigger | Recipient | Channel |
|---|---|---|
| New expense submitted | Project managers | In-app badge + daily digest email |
| Expense rejected | The field user who created it | In-app + push (phase 2) |
| Phase deviation exceeds 10 % | Project managers + master | Email |
| No captures in a project for 5 days | Project managers | Email |
| FX sync failed 2 days in a row | Master | Email |
| Bank statement imported | Project managers | In-app |
| Capture processing failed | The field user + project managers | In-app |

---

## 10. Design system

- **Look:** clean, high-contrast, data-first. Not a consumer app — a work tool. Think "well-designed internal tool", not "startup landing page".
- **Palette:**
  - Primary: deep slate blue `#1E3A5F` (trust, neutral, not a bank cliché).
  - Accent: warm ochre `#D98E32` (construction, action buttons).
  - Semantic: green `#2E7D52` (aprobado/en fecha), amber `#C9931F` (en riesgo/verificar), red `#C1422E` (rechazado/atrasado), grey `#6B7280` (borrador/cerrado).
  - Each project also gets an auto-assigned identity color used in the mobile header chip and portfolio charts.
- **Typography:** Inter (or system stack). Mobile amount field ≥ 32px. Web tabular numbers everywhere (`font-variant-numeric: tabular-nums`) so columns align.
- **Charts:** no 3D, no pie charts with more than 5 slices, always a value label on hover, always the currency in the axis label.
- **Icons:** single consistent set (Lucide). Category icons are memorized by field users — never change them once shipped.
- **Accessibility:** WCAG AA contrast, ≥48dp tap targets on mobile, never color alone to convey status (always icon + text), full keyboard navigation on web, screen-reader labels in Spanish.
- **Empty states:** always illustrated + one clear action. `"Todavía no cargaste ningún gasto. Empezá sacando una foto del primer ticket."`
- **Error states:** plain Spanish, never technical. `"No pudimos leer el ticket. Podés cargarlo a mano, la foto queda guardada."` Never `"Error 500"`.
- **Loading states:** skeleton screens matching the final layout, not spinners.

---

## 11. Key microcopy (Spanish)

| Context | Copy |
|---|---|
| Home capture buttons | `Escribir` · `Foto` · `Audio` |
| Photo guide | `Encuadrá el ticket completo y mantené el celular quieto` |
| OCR processing | `Leyendo el ticket…` |
| Audio prompt | `Contá qué compraste, cuánto costó, en qué moneda y para qué etapa` |
| Audio processing | `Transcribiendo el audio…` |
| Review header | `Revisá y confirmá` |
| Field needs check | `Verificar` |
| Save success | `Gasto guardado ✓` |
| Offline banner | `Sin conexión · 4 cargas pendientes de enviar` |
| Sync success | `Todo sincronizado · hace un momento` |
| OCR failure | `No pudimos leer el ticket. Cargalo a mano — la foto queda guardada.` |
| Rejection notice | `Tu jefe de proyecto rechazó este gasto. Motivo: {motivo}` |
| Missing FX rate | `Sin cotización para esta fecha` |
| Delete confirm | `¿Descartar esta carga? La foto se va a borrar.` |
| Conversion footnote | `Convertido a USD · cotización {tipo} · {fecha}` |

---

## 12. MVP scope

### In scope ✅
- 3 roles, project-scoped access, master override.
- Mobile app: login, project selector, 3 capture modes, review screen, my loads, offline + sync.
- Web console: consolidado, project detail, the 6 analysis tabs, admin section.
- The 5 core entities + the supporting ones (see `technical_details.md` §5).
- Bank statement CSV import + assisted reconciliation.
- FX: ARS/UYU/USD, daily auto-update, backfill from 01/01/2025, per-project rate policy.
- CSV/XLSX export.
- Audit log.
- Spanish UI end to end.

### Out of scope (explicitly, for MVP) ❌
- Direct bank API integration (CSV only, as agreed).
- Accounting software integration.
- Invoicing / receivables / sales pipeline.
- Client or buyer portal.
- Push notifications.
- Multi-company / multi-tenant.
- Payroll or timesheets.
- Inventory / material stock control.
- Native tablet layouts.
- iOS App Store / Google Play publication (internal distribution in MVP).

---

## 13. Success criteria

| Metric | Target |
|---|---|
| Time to load an expense by photo (capture → saved) | < 25 s median |
| Time to load an expense by audio | < 30 s median |
| OCR field accuracy (amount + date) | ≥ 90 % accepted without edit |
| ASR field accuracy (amount + vendor) | ≥ 80 % accepted without edit |
| Expenses loaded through the app vs. total known expenses | ≥ 95 % |
| Captures stuck unsynced > 48 h | < 2 % |
| Manager time to answer "how are we vs. budget" | < 30 s (was: hours of Excel) |
| Bank reconciliation coverage | ≥ 90 % of transactions matched |

---

## 14. Open questions for you

1. **Expense approval** — should field-user expenses require manager approval before counting toward totals, or count immediately and be correctable? (I've assumed approval required, `submitted → approved`. It's safer but adds manager workload.)
2. **Labor costs** — are workers paid by the day/week in cash and loaded as expenses, or do you need a separate labor/headcount module? This changes the phase-cost model significantly.
3. **Land purchase** — is the lot purchase itself an expense inside the project, a separate estimate line, or tracked outside the CRM?
4. **Construction phases** — do you want a fixed standard phase template (Terreno, Movimiento de suelo, Fundaciones, Estructura, Mampostería, Techos, Instalaciones, Revoques, Terminaciones, Exteriores, Entrega) applied to every new project, or free-form phases per project? I'd recommend a template that's editable per project, so cross-project benchmarks actually compare like with like.
5. **Who imports the bank CSV** — manager or master? (I've assumed manager.)
6. **Physical progress %** — who updates it and how? Manual slider per phase by the manager, or derived from milestones/checklists? (I've assumed manual, with milestones in phase 2.)
7. **Photos of progress** — do you want field users to also upload site progress photos (not just tickets)? It's cheap to add and managers always end up wanting it.
8. **Retention** — how long must receipts and audio be kept? (Tax rules differ: ~5–10 years in AR/UY. Affects storage sizing.)
