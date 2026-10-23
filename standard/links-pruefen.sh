#!/usr/bin/env bash
# links-pruefen.sh — prüft die internen Links der gelisteten Markdown-Dateien mit lychee.
#
#   links-pruefen.sh LISTE    # LISTE: Ausgabe von md-dateien.sh, eine Datei je Zeile
#   LYCHEE=/pfad/lychee links-pruefen.sh LISTE
#
# Ersetzt die lychee-Action: die setzt ihre Argumente per `eval` in eine Shell-Zeile, ein
# Dateiname wie `x$(befehl).md` lief dort als Befehl. Hier geht jeder Name als eigenes
# Argument an lychee, ohne dass eine Shell ihn je als Text liest.
#
# Ohne --config lädt lychee die `lychee.toml` des geprüften Repos, und deren `preprocess`
# startet für jede Datei ein beliebiges Kommando (mit `command = "sh"` läuft die .md-Datei
# selbst als Skript, die Prüfung entfällt still). Deshalb immer eine leere Konfiguration
# von außerhalb des Repos. `.lycheeignore` liest lychee weiterhin: sie lockert nur.
#
# lychee behandelt Eingaben als Glob: `[x].md` fände keine Datei und würde nur gewarnt,
# nicht geprüft. Deshalb werden [ ] * ? escaped. Das `./` davor verhindert, dass ein Name
# mit führendem `-` als Option gilt.
set -uo pipefail

LYCHEE="${LYCHEE:-lychee}"
LISTE="${1:?Liste fehlt}"

dateien=()
while IFS= read -r name || [ -n "$name" ]; do
  [ -n "$name" ] || continue
  esc=""
  for ((i = 0; i < ${#name}; i++)); do
    z="${name:i:1}"
    case "$z" in
      '[') esc+='[[]' ;;
      ']') esc+='[]]' ;;
      '*') esc+='[*]' ;;
      '?') esc+='[?]' ;;
      *) esc+="$z" ;;
    esac
  done
  dateien+=("./$esc")
done < "$LISTE"

if [ "${#dateien[@]}" -eq 0 ]; then
  echo "Keine Markdown-Dateien in der Liste."
  exit 0
fi
LEER=$(mktemp)
trap 'rm -f "$LEER"' EXIT
echo "Prüfe ${#dateien[@]} Markdown-Datei(en)."
# Nur interne Links (--offline). Externe Links prüft der PR bewusst nicht.
"$LYCHEE" --config "$LEER" --offline --no-progress -- "${dateien[@]}"
