# Claude Code config review — skills, hooks, agents, rules

Date: 2026-09-12
Scope: everything under `.claude/` (entirely untracked/uncommitted at time of review).

## TL;DR

Two structural bugs mean **none of the four custom skills and none of the three custom agents are currently discoverable by Claude Code** — confirmed empirically this session (they don't appear in the "available skills" / "available agent types" lists) and confirmed against Claude Code's own docs. Beyond that, there are path/naming inconsistencies left over from the spec docs living in `planning/` instead of the `docs/` path the configs assume, and a few real gaps in the hooks.

---

## Critical — not being loaded at all

### 1. Skills are missing the required `skills/` directory

Convention: `.claude/skills/<name>/SKILL.md`. Current files are one level too shallow:

| Current path | Required path |
|---|---|
| `.claude/datamodel/SKILL.md` | `.claude/skills/datamodel/SKILL.md` |
| `.claude/es-copy/SKILL.md` | `.claude/skills/es-copy/SKILL.md` |
| `.claude/money-fx/SKILL.md` | `.claude/skills/money-fx/SKILL.md` |
| `.claude/ticket/SKILL.md` | `.claude/skills/ticket/SKILL.md` |

### 2. Agents are missing the required `name:` frontmatter field

`.claude/agents/*.md` requires both `name` and `description` in frontmatter. All three files only have `description`:

- `agents/extraction-evaluator.md`
- `agents/migration-reviewer.md`
- `agents/spec-to-tickets.md`

Fix: add `name: extraction-evaluator` (etc.) to each file's frontmatter block. The name is not inferred from the filename.

### 3. `es-copy/SKILL.md` is empty

Zero bytes, no frontmatter, no content. Even after fixing #1, there's nothing here yet.

---

## Content / path inconsistencies

### 4. `docs/` vs `planning/`

Several files reference a `docs/` directory that doesn't exist in this repo — the actual specs live in `planning/`:

- `datamodel/SKILL.md` → `@docs/technical_details.md §5`
- `ticket/SKILL.md` → `@docs/technical_details.md §15`, and instructs appending to `docs/backlog.md`
- `agents/migration-reviewer.md` → `docs/technical_details.md §5`
- `agents/spec-to-tickets.md` → `docs/agents.md`, `docs/technical_details.md`

### 5. `migration-reviewer.md` cites the wrong rule filename

References `.claude/rules/migrations.md` (plural). The actual file is `.claude/rules/migration.md` (singular).

### 6. Jira project key mismatch: `OBRA` vs `CRM`

`ticket/SKILL.md` hardcodes **Project key: OBRA** and tells you to prefix backlog entries `OBRA-xxx`. The real Jira project (confirmed via the Atlassian MCP) is key `CRM` ("RealEstateCRM") — that's what `CRM-1` lives under, and it's the only project in scope per your standing instruction. `OBRA` is only the internal codename used inside the specs. As written, this skill would try to create tickets against a project key that doesn't exist.

---

## Hook issues

### 7. `block-destructive.sh` — case-sensitive SQL match

`DROP TABLE`, `DROP DATABASE`, `TRUNCATE` are matched as literal uppercase substrings inside a `case` statement (case-sensitive by default). Lowercase or mixed-case SQL — `drop table foo`, `truncate expenses` — would **not** be blocked.

### 8. `block-destructive.sh` — the stated `--force-with-lease` escape hatch doesn't work

The deny message for `git push --force` says *"Use --force-with-lease yourself if needed"* — but the match is `*"git push --force"*`, a substring test. `git push --force-with-lease` contains that substring too, so it gets blocked as well, contradicting the message.

### 9. `format-and-check.sh` doesn't go through `uv run`

Calls `ruff format` / `ruff check --fix` directly. Global CLAUDE.md mandates `uv run <tool>` for Python tooling — if `ruff` isn't on PATH outside the project's `uv` venv, this hook silently no-ops (failures are swallowed with `|| true`).

### 10. `protect-paths.sh` only guards `Edit`/`Write`, not `Bash`

`settings.json` wires it only to the `Edit|Write` matcher. A `Bash` redirect (`cat > .env`, `echo >> packages/shared-types/x.ts`) bypasses it entirely.

---

## Minor / low-priority

- `format-and-check.sh`'s hardcoded-Spanish-string heuristic checks 8 words; `agents.md` §11's microcopy table has ~15 more that won't be caught. Not wrong, just narrow.
- Several referenced paths don't exist yet (`tests/fixtures/...`, `api/alembic/...`) — expected, since there's no application code yet. These agents/hooks are inert until Sprint 0, not broken.

---

## What's solid

- `money-fx/SKILL.md` and `datamodel/SKILL.md` content (once relocated) is accurate against `technical_details.md` and internally consistent.
- `rules/backend.md`, `rules/frontend.md`, `rules/migration.md` correctly use the `paths:` frontmatter auto-load mechanism (verified against Claude Code docs) — these will load automatically once matching files exist under `api/`, `web/`, `mobile/`, `api/alembic/`.
- `settings.json` hook wiring (matchers, `PreToolUse`/`PostToolUse`/`SessionStart`) is structured correctly.

---

## Resolution (2026-09-12)

1. **Applied.** All 4 skills moved to `.claude/skills/<name>/SKILL.md`; `name:` added to all 3 agent frontmatter blocks. Also fixed the `migrations.md` → `migration.md` filename typo in `migration-reviewer.md` (a plain bug, independent of the `docs/`-path decision below).
2. **Deferred.** `docs/` vs `planning/` references left as-is for now — no changes made to any path referencing `docs/`.
3. **Applied.** `ticket/SKILL.md` now uses **Project key: CRM** (was `OBRA`), and the backlog-append instruction now says `CRM-xxx` (was `OBRA-xxx`).
4. **Deferred.** `es-copy/SKILL.md` left empty, as requested.

**Note:** while moving `es-copy/` into `skills/`, the empty `SKILL.md` file inside it did not survive the `mv` (directory arrived, file did not — cause unclear, plain ext4, no other file was affected). Recreated it as an empty file to match its prior state; flagging in case the same thing happens elsewhere.

Still open, not yet acted on: hook issues #7–#10 (case-sensitive SQL blocking, the `--force-with-lease` message that doesn't match the actual blocking behavior, `ruff`/`prettier` not going through `uv run`, and `protect-paths.sh` not covering `Bash`).
