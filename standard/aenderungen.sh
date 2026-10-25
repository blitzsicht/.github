#!/usr/bin/env bash
# aenderungen.sh — Tor des reusable Workflows: gibt es Markdown zu prüfen, und gegen welche Basis?
#
#   aenderungen.sh BASIS PFAD LISTEN    # Ausgabe auf stdout: Zeilen für $GITHUB_OUTPUT
#
# BASIS ist der Kandidat aus dem Ereignis (Basis des PR, sonst `before` des Pushs). Er gilt nur,
# wenn es den Commit im Checkout gibt; ein neuer Branch (before = 000…) oder eine unbekannte
# Basis ergibt eine leere Basis, und dann gilt alles als geändert (streng).
#
# Auf stdout stehen nur `basis=…` und `md=true|false`, damit der Aufrufer sie unverändert an
# $GITHUB_OUTPUT hängen kann. Alles für Menschen geht nach stderr.
#
# Die Listen (md-nur.txt, md-uebersprungen.txt) liegen unter LISTEN, einem Verzeichnis außerhalb
# des Checkouts: eine gleichnamige Datei aus dem PR (Symlink auf /dev/null oder nach außen) hätte
# sonst das Tor geschlossen bzw. eine fremde Datei überschrieben.
#
# Auch übersprungene Namen (Zeilenumbruch, siehe md-dateien.sh) öffnen das Tor: die Prüfungen
# melden sie dann als NICHT GEPRÜFT, statt dass der Lauf mangels Liste grün wird.
#
# Exit 0: Tor ausgewertet · 2: Dateiliste nicht lesbar (dann steht nichts auf stdout).
set -uo pipefail

HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
basis="${1-}"
PFAD="${2:-.}"
LISTEN="${3:?Verzeichnis für die Listen fehlt}"

if [ -z "$basis" ] || ! git cat-file -e "$basis^{commit}" 2>/dev/null; then basis=""; fi

nur="$LISTEN/md-nur.txt"
uebersprungen="$LISTEN/md-uebersprungen.txt"
if ! bash "$HIER/md-dateien.sh" "$basis" "$PFAD" > "$nur" 2> "$uebersprungen"; then
  cat "$uebersprungen" >&2
  echo "NICHT GEPRÜFT: Dateiliste nicht lesbar" >&2
  exit 2
fi
cat "$uebersprungen" >&2

echo "basis=$basis"
if [ -s "$nur" ] || [ -s "$uebersprungen" ]; then echo "md=true"; else echo "md=false"; fi
echo "Geänderte Markdown-Dateien: $(wc -l < "$nur"), Basis: ${basis:-keine (alles streng)}" >&2
