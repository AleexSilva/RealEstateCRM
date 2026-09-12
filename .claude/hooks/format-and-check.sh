#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
[ -f "$path" ] || exit 0

case "$path" in
  *.py)
    ruff format "$path" >/dev/null 2>&1 || true
    ruff check --fix "$path" 2>&1 | head -20
    # money safety net
    if grep -nE '\bfloat\(' "$path" | grep -iE 'amount|price|rate|total|cost'; then
      echo "WARNING: float() near a monetary value. Use Decimal."
    fi
    ;;
  *.ts|*.tsx)
    npx prettier --write "$path" >/dev/null 2>&1 || true
    npx eslint --fix "$path" 2>&1 | head -20
    # hardcoded Spanish strings in JSX: accented chars or common words in quotes
    if grep -nE '>[^<>{]*[áéíóúñ¿¡][^<>{]*<|"(Guardar|Cancelar|Gasto|Proyecto|Etapa|Monto|Fecha|Proveedor)"' "$path"; then
      echo "WARNING: possible hardcoded Spanish string. Move it to locales/es.json and use t()."
    fi
    ;;
esac
exit 0