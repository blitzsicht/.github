#!/usr/bin/env bash
# secrets-pruefen.sh — scannt den Diff (oder ohne Basis den ganzen Baum) mit gitleaks.
#
#   GITLEAKS=… secrets-pruefen.sh BASIS    # im Wurzelverzeichnis des geprüften Repos
#
# gitleaks als CLI mit Prüfsumme (werkzeuge-laden.sh): die gitleaks-Action verlangt für
# Organisationen eine Lizenz.
#
# --text in den log-opts: sonst macht `* -diff` in der .gitattributes des Repos jeden Diff
# „binär“, gitleaks sieht ~0 Bytes und meldet „no leaks found“. Die Gegenprobe im Selbsttest
# entfernt --text und wird rot.
#
# Der Standard darf dabei nicht im Arbeitsbaum liegen: ohne Basis scannte `dir` ihn mit. Der
# Workflow verschiebt ihn deshalb gleich nach dem Checkout nach $RUNNER_TEMP.
#
# Exit wie gitleaks: 0 nichts gefunden · 1 Fund (oder Fehler von gitleaks) · 2 Werkzeug fehlt.
set -uo pipefail

GITLEAKS="${GITLEAKS:-gitleaks}"
BASIS="${1-}"
command -v "$GITLEAKS" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: gitleaks fehlt ($GITLEAKS)."; exit 2; }

if [ -n "$BASIS" ]; then
  "$GITLEAKS" git --no-banner --redact --log-opts="--text ${BASIS}..HEAD" .
else
  "$GITLEAKS" dir --no-banner --redact .
fi
