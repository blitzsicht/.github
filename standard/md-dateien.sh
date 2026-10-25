#!/usr/bin/env bash
# md-dateien.sh — listet die geänderten Markdown-Dateien eines Repos, eine je Zeile.
#
#   md-dateien.sh BASIS PFAD    # BASIS leer: alle getrackten Dateien unter PFAD
#
# Für den reusable Workflow: das Tor (aenderungen.sh) und der Ratchet (basis-vergleich.sh) lesen
# ihre Liste hier, statt sie je Schritt neu zusammenzubauen.
#
# Zwei Fallen, gegen die das Skript steht:
# - git setzt Namen mit Umlaut in der Zeilenausgabe in Anführungszeichen ("\303\244.md").
#   Ein Filter auf `\.md$` verwarf solche Dateien dann still, Lint und Linkprüfung sahen sie
#   nie. Was schützt, ist `-z`: dort gibt git jeden Namen wörtlich aus. Die Gegenprobe im
#   Selbsttest entfernt `-z` und wird rot. `core.quotePath=false` steht nur zusätzlich da.
# - Ein Dateiname ist Eingabe aus dem geprüften Repo. Wer die Liste in eine Shell-Zeile
#   einsetzt, führt `x$(befehl).md` aus. Aufrufer lesen die Liste deshalb zeilenweise in
#   ein Array (links-pruefen.sh), nie per Ersetzung in einen Befehlstext.
#
# Namen mit Zeilenumbruch lassen sich in einer Zeilenliste nicht darstellen. Sie werden
# übersprungen und auf stderr gemeldet, nicht still verworfen. Wer die Liste als Tor nutzt
# („gibt es überhaupt etwas zu prüfen?“), wertet deshalb auch stderr aus.
#
# T (Typänderung, etwa Symlink → Datei) zählt als Änderung: sonst sah das Tor eine leere Liste.
set -euo pipefail

BASIS="${1-}"
PFAD="${2:-.}"

if [ -n "$BASIS" ]; then
  git -c core.quotePath=false diff -z --name-only --diff-filter=ACMRT "$BASIS" HEAD -- "$PFAD"
else
  git -c core.quotePath=false ls-files -z -- "$PFAD"
fi | while IFS= read -r -d '' name; do
  case "$name" in
    *$'\n'*) printf 'übersprungen (Zeilenumbruch im Namen): %q\n' "$name" >&2 ;;
    *.md) printf '%s\n' "$name" ;;
  esac
done
