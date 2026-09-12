# RealEstateCRM (OBRA CRM)

A multi-project CRM for a company that buys vacant lots and builds houses from scratch in Argentina and Uruguay. Field users log every expense from their phone (typing, photo, or voice); managers get a portfolio dashboard with budget-vs-actual and progress tracking across three currencies (ARS, UYU, USD).

## Status

Planning phase — no application code yet. Full specs live in `planning/`.

## Docs

- [`planning/agents.md`](planning/agents.md) — product & UX spec: roles, permissions, screens, currency rules, microcopy, MVP scope.
- [`planning/technical_details.md`](planning/technical_details.md) — engineering spec: architecture, data model, API design, sync protocol, security, deployment.

## Planned stack

- **API:** FastAPI (Python 3.12), PostgreSQL 16, Redis, MinIO
- **Web:** React + Vite + TypeScript, shadcn/ui, TanStack Query/Table
- **Mobile:** React Native (Expo), WatermelonDB (offline-first)
- **AI:** PaddleOCR (receipts), faster-whisper (voice), Ollama/Qwen2.5 (field extraction) — all local, no paid APIs
- **Deployment:** Docker Compose on a single self-hosted machine, free/open-source components only

## Running

Not implemented yet. Sprint 0 (see `planning/technical_details.md` §15) adds `docker-compose.yml` and a `Makefile` with `make up` / `make seed` / `make migrate`.
