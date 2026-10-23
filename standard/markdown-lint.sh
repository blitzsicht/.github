#!/usr/bin/env bash
# markdown-lint.sh — lintet die gelisteten Markdown-Dateien mit dem Regelsatz des Standards.
#
#   markdown-lint.sh LISTE CONFIG    # LISTE: Ausgabe von md-dateien.sh
#   MARKDOWNLINT=/pfad/markdownlint-cli2 markdown-lint.sh LISTE CONFIG
#
# Gelintet wird eine KOPIE der Dateien in einem frischen Verzeichnis, nicht das Repo selbst.
# markdownlint-cli2 lädt `.markdownlint-cli2.cjs/.mjs` und `.markdownlint.cjs/.mjs` aus jedem
# Verzeichnis zwischen Arbeitsverzeichnis und Datei per require/import, auch wenn --config
# gesetzt ist. Im Repo gelintet, führte so jedes geprüfte Repo eigenes JavaScript aus und
# konnte den Regelsatz still ersetzen. In der Kopie liegen nur die .md-Dateien.
#
# Jeder Name geht mit `:` davor als eigenes Argument an markdownlint-cli2 (wörtlicher Pfad,
# kein Glob), nie durch eine Shell-Zeile.
set -uo pipefail

MARKDOWNLINT="${MARKDOWNLINT:-markdownlint-cli2}"
LISTE="${1:?Liste fehlt}"
CONFIG="${2:?Regelsatz fehlt}"
case "$CONFIG" in /*) ;; *) CONFIG="$PWD/$CONFIG" ;; esac
[ -f "$CONFIG" ] || { echo "Regelsatz fehlt: $CONFIG" >&2; exit 2; }

KOPIE=$(mktemp -d)
trap 'rm -rf "$KOPIE"' EXIT

args=()
while IFS= read -r name || [ -n "$name" ]; do
  [ -n "$name" ] || continue
  mkdir -p "$KOPIE/$(dirname -- "$name")"
  cp -- "$name" "$KOPIE/$name" || exit 2
  args+=(":$name")
done < "$LISTE"

if [ "${#args[@]}" -eq 0 ]; then
  echo "Keine Markdown-Dateien in der Liste."
  exit 0
fi
cd "$KOPIE" || exit 2
"$MARKDOWNLINT" --config "$CONFIG" "${args[@]}"
