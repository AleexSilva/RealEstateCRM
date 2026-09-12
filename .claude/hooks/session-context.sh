#!/usr/bin/env bash
echo "branch: $(git branch --show-current 2>/dev/null || echo none)"
echo "uncommitted: $(git status --porcelain 2>/dev/null | wc -l) files"
echo "stack: $(docker compose ps --services --filter status=running 2>/dev/null | tr '\n' ' ')"
echo "latest migration: $(ls -1 api/alembic/versions/*.py 2>/dev/null | tail -1 | xargs -r basename)"