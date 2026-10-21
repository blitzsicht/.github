#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

ok()    { echo "  ok: $1"; PASS=$((PASS+1)); }
fail()  { echo "FEHLER: $1"; FAIL=$((FAIL+1)); }
check() {
  # check <description> <condition-command>
  local desc="$1"; shift
  if "$@" 2>/dev/null; then ok "$desc"; else fail "$desc"; fi
}

# Cleanup-Trap
TMP_M="/tmp/test-s01-m-$$"
TMP_L="/tmp/test-s01-l-$$"
trap 'rm -rf "$TMP_M" "$TMP_L"' EXIT

echo "=== S01 End-to-End-Verify ==="
echo ""

# --- a) copier copy Profil M ---
echo "a) copier copy Profil M ..."
if copier copy "$REPO_DIR" "$TMP_M" \
    --data profil=M \
    --data name=beispiel-werkzeug \
    --data "zweck=kurz" \
    --data betrieb_geplant=nein \
    --overwrite \
    --defaults \
    --trust \
    --quiet 2>&1; then
  ok "copier copy M ohne Fehler"
else
  fail "copier copy M fehlgeschlagen"
fi

# --- b) Pflichtdateien M vorhanden ---
for f in AGENTS.md CLAUDE.md docs/INDEX.md docs/BETRIEB.md; do
  if [ -f "$TMP_M/$f" ]; then
    ok "M: $f existiert"
  else
    fail "M: $f fehlt"
  fi
done

# --- c) docs/ARCHITEKTUR.md darf bei M NICHT existieren ---
if [ ! -f "$TMP_M/docs/ARCHITEKTUR.md" ]; then
  ok "M: docs/ARCHITEKTUR.md nicht vorhanden (korrekt)"
else
  fail "M: docs/ARCHITEKTUR.md existiert — sollte durch _tasks entfernt worden sein"
fi

# --- d) Erste Zeile CLAUDE.md ist @AGENTS.md ---
first_line="$(head -1 "$TMP_M/CLAUDE.md" 2>/dev/null || echo '')"
if [ "$first_line" = "@AGENTS.md" ]; then
  ok "CLAUDE.md erste Zeile ist @AGENTS.md"
else
  fail "CLAUDE.md erste Zeile ist '$first_line' (erwartet: @AGENTS.md)"
fi

# --- e) AGENTS.md enthält 'Profil: M' ---
count="$(grep -c '^Profil: M' "$TMP_M/AGENTS.md" 2>/dev/null || echo 0)"
if [ "$count" -ge 1 ]; then
  ok "AGENTS.md enthält 'Profil: M'"
else
  fail "AGENTS.md enthält 'Profil: M' nicht (grep: $count)"
fi

# --- f) Mindestens eine Datei enthält Umlaut ---
umlaut_count="$(grep -rlc '[äöüÄÖÜß]' "$TMP_M/" 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
if [ "$umlaut_count" -gt 0 ]; then
  ok "Umlaute vorhanden in $umlaut_count Datei(en)"
else
  fail "Keine Umlaute gefunden in $TMP_M/"
fi

# --- g) copier copy Profil L ---
echo ""
echo "g) copier copy Profil L ..."
if copier copy "$REPO_DIR" "$TMP_L" \
    --data profil=L \
    --data name=beispiel-werkzeug \
    --data "zweck=kurz" \
    --data betrieb_geplant=nein \
    --overwrite \
    --defaults \
    --trust \
    --quiet 2>&1; then
  ok "copier copy L ohne Fehler"
else
  fail "copier copy L fehlgeschlagen"
fi

# --- h) ARCHITEKTUR.md enthält 'mermaid' ---
if [ -f "$TMP_L/docs/ARCHITEKTUR.md" ] && grep -qi 'mermaid' "$TMP_L/docs/ARCHITEKTUR.md"; then
  ok "L: docs/ARCHITEKTUR.md enthält 'mermaid'"
else
  fail "L: docs/ARCHITEKTUR.md fehlt oder enthält kein 'mermaid'"
fi

# --- i) decisions/0001-beispiel.md existiert ---
if [ -f "$TMP_L/docs/decisions/0001-beispiel.md" ]; then
  ok "L: docs/decisions/0001-beispiel.md existiert"
else
  fail "L: docs/decisions/0001-beispiel.md fehlt"
fi

# --- j) Idempotenz: zweiter copier copy überschreibt _skip_if_exists-Dateien nicht ---
echo "" >> "$TMP_M/AGENTS.md"
echo "testinhalt-xyz" >> "$TMP_M/AGENTS.md"
# Zweiter copy auf dasselbe Ziel — _skip_if_exists schützt vorhandene Dateien
if copier copy "$REPO_DIR" "$TMP_M" \
    --data profil=M \
    --data name=beispiel-werkzeug \
    --data "zweck=kurz" \
    --data betrieb_geplant=nein \
    --overwrite \
    --defaults \
    --trust \
    --quiet 2>&1; then
  idem_count="$(grep -c 'testinhalt-xyz' "$TMP_M/AGENTS.md" 2>/dev/null || echo 0)"
  if [ "$idem_count" -ge 1 ]; then
    ok "Idempotenz: testinhalt-xyz nach zweitem copy noch vorhanden (_skip_if_exists greift)"
  else
    fail "Idempotenz: testinhalt-xyz nach zweitem copy verschwunden — _skip_if_exists greift nicht"
  fi
else
  fail "copier copy (zweiter Lauf) fehlgeschlagen"
fi

# --- k) Public-Repo-Guardrail: keine privaten Pfade in vorlagen/ und copier.yml ---
private_hits="$(grep -rR '/Volumes/\|/Users/\|customer-' "$REPO_DIR/vorlagen/" "$REPO_DIR/copier.yml" 2>/dev/null | grep -v '^Binary' || true)"
if [ -z "$private_hits" ]; then
  ok "Public-Repo-Guardrail: keine privaten Pfade gefunden"
else
  fail "Public-Repo-Guardrail: private Pfade gefunden:
$private_hits"
fi

# --- Zusammenfassung ---
echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
