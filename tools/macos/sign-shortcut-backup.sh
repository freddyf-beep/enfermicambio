#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' 'ERROR: la firma de Atajos requiere macOS.' >&2
  exit 1
fi
if [ "$#" -ne 1 ]; then
  printf 'Uso: %s "/ruta/EnfermiCambio Salud.shortcut"\n' "$0" >&2
  exit 2
fi

input_file=$1
if [ ! -f "$input_file" ]; then
  printf 'ERROR: no existe el archivo: %s\n' "$input_file" >&2
  exit 1
fi
case "$input_file" in
  *.shortcut) ;;
  *) printf '%s\n' 'ERROR: el archivo debe terminar en .shortcut.' >&2; exit 1 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "${script_dir}/../.." && pwd)
output_dir="${repo_root}/artifacts/ios-shortcut-session"
output_file="${output_dir}/EnfermiCambio-Salud-signed.shortcut"
checksum_file="${output_file}.sha256"
mkdir -p "$output_dir"

if [ -e "$output_file" ]; then
  printf 'ERROR: ya existe %s; muévelo antes de volver a firmar.\n' "$output_file" >&2
  exit 1
fi

shortcuts sign --mode anyone --input "$input_file" --output "$output_file"
shasum -a 256 "$output_file" > "$checksum_file"
printf 'Respaldo firmado: %s\n' "$output_file"
printf 'Checksum: %s\n' "$checksum_file"
printf '%s\n' 'Apple recibe una copia para validarla durante la firma.'
