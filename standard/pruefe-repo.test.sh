#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRUEFE="$SCRIPT_DIR/pruefe-repo.sh"

ok()   { echo "  ok: $1"; PASS=$((PASS+1)); }
fail() { echo "FEHLER: $1"; FAIL=$((FAIL+1)); }

# Cleanup aller temporären Repos
# shellcheck disable=SC2329
cleanup() {
  rm -rf /tmp/test-s02-*-$$
}
trap cleanup EXIT

# Hilfsfunktion: erzeuge Basis-Repo für Profil M (docs/ korrekt, git remote gesetzt)
make_m_base() {
  local dir="$1"
  mkdir -p "$dir/docs"
  printf 'Profil: M\nZweck: test\n' > "$dir/AGENTS.md"
  printf '@AGENTS.md\n' > "$dir/CLAUDE.md"
  printf '# INDEX\n' > "$dir/docs/INDEX.md"
  printf '# BETRIEB\n' > "$dir/docs/BETRIEB.md"
  git -C "$dir" init -q
  git -C "$dir" remote add origin https://example.invalid/x.git
}

# Hilfsfunktion: erzeuge vollständiges Repo für Profil L
make_l_full() {
  local dir="$1"
  local fence='```'
  make_m_base "$dir"
  # Profil M→L
  printf 'Profil: L\nZweck: test\n' > "$dir/AGENTS.md"
  printf '# ARCHITEKTUR\n\n%smermaid\ngraph TD\n  A --> B\n%s\n' "$fence" "$fence" > "$dir/docs/ARCHITEKTUR.md"
  mkdir -p "$dir/docs/decisions"
}

# Hilfsfunktion: erwarte Exit-Code 1 und mindestens eine FEHLER:-Zeile in stdout
expect_fail() {
  local desc="$1"
  local tmpdir="$2"
  local output exit_code fehler_count
  output="$(bash "$PRUEFE" "$tmpdir" 2>&1 || true)"
  exit_code=0
  bash "$PRUEFE" "$tmpdir" > /dev/null 2>&1 || exit_code=$?
  fehler_count="$(printf '%s' "$output" | grep -c '^FEHLER:' || true)"
  if [ "$exit_code" -eq 1 ] && [ "$fehler_count" -gt 0 ]; then
    ok "$desc — Exit 1, FEHLER:-Zeilen: $fehler_count"
  else
    fail "$desc — Exit $exit_code, FEHLER:-Zeilen: $fehler_count (erwartet Exit 1 + ≥1 FEHLER:)"
  fi
}

# Hilfsfunktion: erwarte Exit-Code 0 und keine FEHLER:-Zeile in stdout
expect_pass() {
  local desc="$1"
  local tmpdir="$2"
  local output exit_code fail_count
  output="$(bash "$PRUEFE" "$tmpdir" 2>&1 || true)"
  exit_code=0
  bash "$PRUEFE" "$tmpdir" > /dev/null 2>&1 || exit_code=$?
  fail_count="$(printf '%s' "$output" | grep -c '^FEHLER:' || true)"
  if [ "$exit_code" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
    ok "$desc — Exit 0, kein FEHLER:"
  else
    fail "$desc — Exit $exit_code, FEHLER:-Zeilen: $fail_count (erwartet Exit 0, keine FEHLER:)
$output"
  fi
}

echo "=== S02 pruefe-repo.sh Regel-Tests ==="
echo ""

# ── 1. R-AGENTS-EXIST: AGENTS.md fehlt ─────────────────────────────────────
T1="/tmp/test-s02-r-agents-exist-$$"
mkdir -p "$T1"
printf '@AGENTS.md\n' > "$T1/CLAUDE.md"
expect_fail "R-AGENTS-EXIST: AGENTS.md fehlt" "$T1"

# ── 2. R-AGENTS-PROFIL: AGENTS.md ohne gültige Profil-Zeile ────────────────
T2="/tmp/test-s02-r-agents-profil-$$"
mkdir -p "$T2"
printf '# kein Profil\n' > "$T2/AGENTS.md"
printf '@AGENTS.md\n' > "$T2/CLAUDE.md"
expect_fail "R-AGENTS-PROFIL: AGENTS.md ohne gültige Profil-Zeile" "$T2"

# ── 3. R-CLAUDE-EXIST: CLAUDE.md fehlt ─────────────────────────────────────
T3="/tmp/test-s02-r-claude-exist-$$"
mkdir -p "$T3"
printf 'Profil: M\nZweck: test\n' > "$T3/AGENTS.md"
expect_fail "R-CLAUDE-EXIST: CLAUDE.md fehlt" "$T3"

# ── 4. R-CLAUDE-AT: erste Zeile CLAUDE.md nicht @AGENTS.md ─────────────────
T4="/tmp/test-s02-r-claude-at-$$"
mkdir -p "$T4"
printf 'Profil: M\nZweck: test\n' > "$T4/AGENTS.md"
printf '# Falsch\n' > "$T4/CLAUDE.md"
expect_fail "R-CLAUDE-AT: erste Zeile CLAUDE.md ist nicht @AGENTS.md" "$T4"

# ── 5. R-DOCS-INDEX: docs/INDEX.md fehlt bei Profil M ───────────────────────
T5="/tmp/test-s02-r-docs-index-$$"
make_m_base "$T5"
rm "$T5/docs/INDEX.md"
expect_fail "R-DOCS-INDEX: docs/INDEX.md fehlt (Profil M)" "$T5"

# ── 6. R-DOCS-BETRIEB: docs/BETRIEB.md fehlt bei Profil M ──────────────────
T6="/tmp/test-s02-r-docs-betrieb-$$"
make_m_base "$T6"
rm "$T6/docs/BETRIEB.md"
expect_fail "R-DOCS-BETRIEB: docs/BETRIEB.md fehlt (Profil M)" "$T6"

# ── 7. R-REMOTE: kein git remote bei Profil M ───────────────────────────────
T7="/tmp/test-s02-r-remote-$$"
make_m_base "$T7"
git -C "$T7" remote remove origin
expect_fail "R-REMOTE: kein git remote (Profil M)" "$T7"

# ── 8. R-ARCHITEKTUR: docs/ARCHITEKTUR.md fehlt bei Profil L ────────────────
T8="/tmp/test-s02-r-architektur-$$"
make_l_full "$T8"
rm "$T8/docs/ARCHITEKTUR.md"
expect_fail "R-ARCHITEKTUR: docs/ARCHITEKTUR.md fehlt (Profil L)" "$T8"

# ── 9. R-MERMAID: kein Mermaid-Block in ARCHITEKTUR.md bei Profil L ─────────
T9="/tmp/test-s02-r-mermaid-$$"
make_l_full "$T9"
printf '# ARCHITEKTUR\n\nKein Diagramm hier.\n' > "$T9/docs/ARCHITEKTUR.md"
expect_fail "R-MERMAID: kein Mermaid-Block in ARCHITEKTUR.md (Profil L)" "$T9"

# ── 10. R-DECISIONS: docs/decisions fehlt bei Profil L ──────────────────────
T10="/tmp/test-s02-r-decisions-$$"
make_l_full "$T10"
rm -rf "$T10/docs/decisions"
expect_fail "R-DECISIONS: docs/decisions fehlt (Profil L)" "$T10"

# ── 11. R-DOCS-INDEX: docs/INDEX.md fehlt bei Profil L ─────────────────────
T11="/tmp/test-s02-r-docs-index-l-$$"
make_l_full "$T11"
rm "$T11/docs/INDEX.md"
expect_fail "R-DOCS-INDEX: docs/INDEX.md fehlt (Profil L)" "$T11"

# ── 12. R-DOCS-BETRIEB: docs/BETRIEB.md fehlt bei Profil L ─────────────────
T12="/tmp/test-s02-r-docs-betrieb-l-$$"
make_l_full "$T12"
rm "$T12/docs/BETRIEB.md"
expect_fail "R-DOCS-BETRIEB: docs/BETRIEB.md fehlt (Profil L)" "$T12"

# ── 13. R-REMOTE: kein git remote bei Profil L ──────────────────────────────
T13="/tmp/test-s02-r-remote-l-$$"
make_l_full "$T13"
git -C "$T13" remote remove origin
expect_fail "R-REMOTE: kein git remote (Profil L)" "$T13"

echo ""
echo "=== Vollrepo-Tests (Profil S/M/L/W) ==="
echo ""

# ── 11. Profil S: vollständiges Repo, kein git-Init nötig ───────────────────
TS="/tmp/test-s02-full-s-$$"
mkdir -p "$TS"
printf 'Profil: S\nZweck: test\n' > "$TS/AGENTS.md"
printf '@AGENTS.md\n' > "$TS/CLAUDE.md"
expect_pass "Vollrepo Profil S" "$TS"

# ── 12. Profil M: vollständiges Repo mit git remote ─────────────────────────
TM="/tmp/test-s02-full-m-$$"
make_m_base "$TM"
expect_pass "Vollrepo Profil M" "$TM"

# ── 13. Profil L: vollständiges Repo mit git remote + docs/decisions ────────
TL="/tmp/test-s02-full-l-$$"
make_l_full "$TL"
expect_pass "Vollrepo Profil L" "$TL"

# ── 14. Profil W: vollständiges Repo, kein git-Init nötig ───────────────────
TW="/tmp/test-s02-full-w-$$"
mkdir -p "$TW"
printf 'Profil: W\nZweck: test\n' > "$TW/AGENTS.md"
printf '@AGENTS.md\n' > "$TW/CLAUDE.md"
expect_pass "Vollrepo Profil W" "$TW"

# ── Zählwerk-Untergrenze ─────────────────────────────────────────────────────
echo ""
echo "================================"
echo "PASS=$PASS FAIL=$FAIL"
echo "================================"

if [ "$((PASS+FAIL))" -lt 17 ]; then
  echo "FEHLER: Zählwerk-Untergrenze nicht erreicht (PASS+FAIL=$((PASS+FAIL)), Untergrenze 17)"
  exit 1
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
