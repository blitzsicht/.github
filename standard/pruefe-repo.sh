#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-.}"

PASS=0
FAIL=0
HINWEIS=0

ok()     { echo "  ok: $1";     PASS=$((PASS+1)); }
fehler() { echo "FEHLER: $1";   FAIL=$((FAIL+1)); }
hinweis(){ echo "HINWEIS: $1";  HINWEIS=$((HINWEIS+1)); }

# ── R-AGENTS-EXIST ────────────────────────────────────────────────────────────
if [ -f "$REPO/AGENTS.md" ]; then
  ok "R-AGENTS-EXIST: AGENTS.md vorhanden"
else
  fehler "R-AGENTS-EXIST: AGENTS.md fehlt"
fi

# ── R-AGENTS-PROFIL ───────────────────────────────────────────────────────────
profil_line="$(grep -m1 '^Profil: [SMLW]$' "$REPO/AGENTS.md" 2>/dev/null || true)"
if [ -n "$profil_line" ]; then
  ok "R-AGENTS-PROFIL: Zeile 'Profil: <S|M|L|W>' vorhanden"
else
  fehler "R-AGENTS-PROFIL: Keine gültige Profil-Zeile (^Profil: [SMLW]$) in AGENTS.md"
fi

# ── Profil auslesen ───────────────────────────────────────────────────────────
PROFIL=""
if [ -n "$profil_line" ]; then
  PROFIL="${profil_line#Profil: }"
fi

# ── R-CLAUDE-EXIST ────────────────────────────────────────────────────────────
if [ -f "$REPO/CLAUDE.md" ]; then
  ok "R-CLAUDE-EXIST: CLAUDE.md vorhanden"
else
  fehler "R-CLAUDE-EXIST: CLAUDE.md fehlt"
fi

# ── R-CLAUDE-AT ───────────────────────────────────────────────────────────────
first_line="$(head -1 "$REPO/CLAUDE.md" 2>/dev/null || true)"
if [ "$first_line" = "@AGENTS.md" ]; then
  ok "R-CLAUDE-AT: erste Zeile von CLAUDE.md ist '@AGENTS.md'"
else
  fehler "R-CLAUDE-AT: erste Zeile von CLAUDE.md ist '$first_line' (erwartet: @AGENTS.md)"
fi

# ── Profil-spezifische Regeln ─────────────────────────────────────────────────
case "$PROFIL" in
  M|L)
    # R-DOCS-INDEX
    if [ -f "$REPO/docs/INDEX.md" ]; then
      ok "R-DOCS-INDEX: docs/INDEX.md vorhanden"
    else
      fehler "R-DOCS-INDEX: docs/INDEX.md fehlt"
    fi

    # R-DOCS-BETRIEB
    if [ -f "$REPO/docs/BETRIEB.md" ]; then
      ok "R-DOCS-BETRIEB: docs/BETRIEB.md vorhanden"
    else
      fehler "R-DOCS-BETRIEB: docs/BETRIEB.md fehlt"
    fi

    # R-REMOTE
    remote_out="$(git -C "$REPO" remote 2>/dev/null || true)"
    if [ -n "$remote_out" ]; then
      ok "R-REMOTE: git remote konfiguriert"
    else
      fehler "R-REMOTE: kein git remote konfiguriert"
    fi

    if [ "$PROFIL" = "L" ]; then
      # R-ARCHITEKTUR
      if [ -f "$REPO/docs/ARCHITEKTUR.md" ]; then
        ok "R-ARCHITEKTUR: docs/ARCHITEKTUR.md vorhanden"
      else
        fehler "R-ARCHITEKTUR: docs/ARCHITEKTUR.md fehlt"
      fi

      # R-MERMAID
      mermaid_count="$(grep -c '^```mermaid' "$REPO/docs/ARCHITEKTUR.md" 2>/dev/null || echo 0)"
      if [ "$mermaid_count" -gt 0 ]; then
        ok "R-MERMAID: Mermaid-Block in docs/ARCHITEKTUR.md vorhanden"
      else
        fehler "R-MERMAID: kein Mermaid-Block (^\`\`\`mermaid) in docs/ARCHITEKTUR.md"
      fi

      # R-DECISIONS
      if [ -d "$REPO/docs/decisions" ]; then
        ok "R-DECISIONS: Verzeichnis docs/decisions vorhanden"
      else
        fehler "R-DECISIONS: Verzeichnis docs/decisions fehlt"
      fi
    fi
    ;;

  S|W)
    # R-REMOTE-SW — Hinweis statt Fehler
    remote_out="$(git -C "$REPO" remote 2>/dev/null || true)"
    if [ -z "$remote_out" ]; then
      hinweis "R-REMOTE-SW: kein git remote konfiguriert (bei Profil $PROFIL optional)"
    else
      ok "R-REMOTE-SW: git remote konfiguriert"
    fi
    ;;

  "")
    # Profil nicht lesbar — Regeln übersprungen, FEHLER schon oben gezählt
    ;;

  *)
    fehler "Unbekanntes Profil '$PROFIL'"
    ;;
esac

# ── Zusammenfassung ───────────────────────────────────────────────────────────
echo ""
echo "PASS=$PASS FAIL=$FAIL HINWEIS=$HINWEIS"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
