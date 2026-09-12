#!/usr/bin/env bash
# Reads the tool call JSON on stdin; exit 2 blocks the call.
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

deny() { echo "BLOCKED: $1" >&2; exit 2; }

case "$cmd" in
  *"docker compose down -v"*|*"docker-compose down -v"*)
    deny "this deletes the Postgres volume and the FX backfill. Use 'make down' (keeps volumes), or run it yourself if you really mean it." ;;
  *"docker volume rm"*|*"docker volume prune"*)
    deny "volume deletion is a human decision." ;;
  *"DROP TABLE"*|*"DROP DATABASE"*|*"TRUNCATE"*)
    deny "DDL goes through Alembic, never through psql." ;;
  *"rm -rf /"*|*"rm -rf ~"*)
    deny "no." ;;
  *"git push --force"*|*"git push -f"*)
    deny "force-push is a human decision. Use --force-with-lease yourself if needed." ;;
  *"alembic downgrade"*)
    deny "downgrades on a shared DB are a human decision." ;;
esac
exit 0