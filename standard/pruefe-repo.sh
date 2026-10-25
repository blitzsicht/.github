#!/usr/bin/env bash
# pruefe-repo.sh — prüft ein Repo gegen den Doku-Standard (Profile S, M, L, W).
#
#   pruefe-repo.sh [--profil S|M|L|W] [REPO-PFAD]
#
# Je Regel eine Zeile „ok …“ oder „FEHLER …“, Heuristiken als „HINWEIS …“.
# Exit 1 bei mindestens einem FEHLER, Hinweise ändern den Exit-Code nie.
# Jede Regel trägt eine Kennung (R-…), der Selbsttest prüft genau diese.
set -uo pipefail

PROFIL_VORGABE=""
if [ "${1:-}" = "--profil" ]; then
  PROFIL_VORGABE="${2:-}"
  shift 2
fi
REPO="${1:-.}"

PASS=0
FAIL=0
HINWEIS=0
ok()      { echo "ok      $1"; PASS=$((PASS+1)); }
fehler()  { echo "FEHLER  $1"; FAIL=$((FAIL+1)); }
hinweis() { echo "HINWEIS $1"; HINWEIS=$((HINWEIS+1)); }

datei_pflicht() {  # datei_pflicht <Regel> <Pfad relativ zum Repo>
  if [ -f "$REPO/$2" ]; then ok "$1: $2 vorhanden"; else fehler "$1: $2 fehlt"; fi
}

hoechstens_zeilen() {  # hoechstens_zeilen <Regel> <Pfad> <Grenze>
  [ -f "$REPO/$2" ] || return 0
  local n
  n=$(wc -l < "$REPO/$2" | tr -d ' ')
  if [ "$n" -le "$3" ]; then ok "$1: $2 hat $n Zeilen (Grenze $3)"
  else fehler "$1: $2 hat $n Zeilen, erlaubt sind $3"; fi
}

if [ ! -d "$REPO" ]; then
  fehler "R-REPO: Verzeichnis $REPO fehlt"
  echo "PASS=$PASS FAIL=$FAIL HINWEIS=$HINWEIS"
  exit 1
fi

# ── Für alle Profile ─────────────────────────────────────────────────────────
datei_pflicht R-README README.md
datei_pflicht R-AGENTS AGENTS.md
datei_pflicht R-CLAUDE CLAUDE.md

if [ -f "$REPO/CLAUDE.md" ]; then
  erste=$(head -n 1 "$REPO/CLAUDE.md")
  if [ "$erste" = "@AGENTS.md" ]; then ok "R-CLAUDE-IMPORT: CLAUDE.md beginnt mit @AGENTS.md"
  else fehler "R-CLAUDE-IMPORT: erste Zeile von CLAUDE.md ist '$erste', erwartet '@AGENTS.md'"; fi
fi

# AGENTS.md sagt „.env* ist ignoriert“; bei der Erstausstattung bleibt eine vorhandene .gitignore
# aber stehen. Globale und systemweite Regeln zählen nicht: sie gelten nur auf einem Rechner.
rc=0
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$REPO" check-ignore -q -- .env 2>/dev/null || rc=$?
case "$rc" in
  0) ok "R-ENV-IGNORE: .env ist per .gitignore ausgeschlossen" ;;
  1) fehler "R-ENV-IGNORE: .env wird nicht ignoriert ('.env*' fehlt in .gitignore, oder .env ist eingecheckt)" ;;
  *) fehler "R-ENV-IGNORE: nicht prüfbar, $REPO ist kein git-Repo" ;;
esac

PROFIL="$PROFIL_VORGABE"
if [ -z "$PROFIL" ] && [ -f "$REPO/AGENTS.md" ]; then
  PROFIL=$(grep -m1 -E '^Profil: [SMLW]$' "$REPO/AGENTS.md" | cut -d' ' -f2 || true)
fi
case "$PROFIL" in
  S|M|L|W) ok "R-PROFIL: Profil $PROFIL" ;;
  "")      fehler "R-PROFIL: keine Zeile 'Profil: S|M|L|W' in AGENTS.md" ;;
  *)       fehler "R-PROFIL: unbekanntes Profil '$PROFIL'"; PROFIL="" ;;
esac

case "$PROFIL" in
  S|W) hoechstens_zeilen R-AGENTS-GROESSE AGENTS.md 60 ;;
  M|L) hoechstens_zeilen R-AGENTS-GROESSE AGENTS.md 150 ;;
esac

# ── M und L ──────────────────────────────────────────────────────────────────
if [ "$PROFIL" = M ] || [ "$PROFIL" = L ]; then
  datei_pflicht R-INDEX docs/INDEX.md
  hoechstens_zeilen R-INDEX-GROESSE docs/INDEX.md 40

  if [ -d "$REPO/docs/decisions" ]; then ok "R-DECISIONS: docs/decisions/ vorhanden"
  else fehler "R-DECISIONS: docs/decisions/ fehlt"; fi

  if grep -qE '^Betrieb: geplant$' "$REPO/AGENTS.md" 2>/dev/null; then
    datei_pflicht R-BETRIEB docs/BETRIEB.md
  fi

  if [ -n "$(git -C "$REPO" remote 2>/dev/null)" ]; then ok "R-REMOTE: git remote vorhanden"
  else fehler "R-REMOTE: kein git remote, das Repo hat kein Backup"; fi

  if [ ! -f "$REPO/.env.example" ] && grep -rIlqE 'os\.environ|os\.getenv|getenv\(|process\.env|ENV\[' \
       --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude='*.md' "$REPO" 2>/dev/null; then
    hinweis "H-ENV-EXAMPLE: der Code liest Umgebungsvariablen, .env.example fehlt"
  fi
fi

# ── nur L ────────────────────────────────────────────────────────────────────
if [ "$PROFIL" = L ]; then
  datei_pflicht R-ARCHITEKTUR docs/ARCHITEKTUR.md
  if [ -f "$REPO/docs/ARCHITEKTUR.md" ]; then
    if grep -qE '^```mermaid' "$REPO/docs/ARCHITEKTUR.md"; then ok "R-MERMAID: Diagramm in docs/ARCHITEKTUR.md"
    else fehler "R-MERMAID: docs/ARCHITEKTUR.md ohne mermaid-Block"; fi
  fi
  datei_pflicht R-RUNBOOK docs/RUNBOOK.md
  datei_pflicht R-CHANGELOG CHANGELOG.md
fi

echo "PASS=$PASS FAIL=$FAIL HINWEIS=$HINWEIS"
[ "$FAIL" -eq 0 ]
