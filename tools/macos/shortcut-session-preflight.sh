#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' 'ERROR: este script debe ejecutarse en macOS.' >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "${script_dir}/../.." && pwd)
report_dir="${repo_root}/artifacts/ios-shortcut-session"
report_file="${report_dir}/preflight.txt"
mkdir -p "$report_dir"

if ! command -v shortcuts >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: macOS no incluye el comando shortcuts en esta cuenta.' >&2
  exit 1
fi

{
  printf 'EnfermiCambio Apple Shortcut preflight\n'
  printf 'Date: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  sw_vers
  printf '\nShortcuts command: %s\n' "$(command -v shortcuts)"
  printf '\nExisting shortcut names:\n'
  shortcuts list || true
} > "$report_file"

printf 'Reporte creado: %s\n' "$report_file"
if shortcuts list 2>/dev/null | grep -Fqx 'EnfermiCambio Salud'; then
  printf '%s\n' 'OK: EnfermiCambio Salud ya existe en esta cuenta.'
else
  printf '%s\n' 'PENDIENTE: crear EnfermiCambio Salud en la app Atajos.'
fi

open -a Shortcuts
open "${repo_root}/docs/MAC_24H_SHORTCUT_RUNBOOK.md"
printf '%s\n' 'Atajos y el runbook quedaron abiertos. No escribas tokens dentro de la plantilla.'
