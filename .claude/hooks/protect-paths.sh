#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

case "$path" in
  *".env"|*".env."*)
    echo "BLOCKED: .env files are edited by humans only. Update .env.example instead." >&2
    exit 2 ;;
  */packages/shared-types/*)
    echo "BLOCKED: generated from OpenAPI. Run 'make types' instead of editing by hand." >&2
    exit 2 ;;
  */tests/fixtures/baseline.json)
    echo "BLOCKED: the extraction baseline is updated deliberately by a human." >&2
    exit 2 ;;
esac
exit 0