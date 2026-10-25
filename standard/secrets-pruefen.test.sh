#!/usr/bin/env bash
# Selbsttest für secrets-pruefen.sh (gitleaks über den Diff oder den Baum).
#
# Geprüft wird, dass
# - ein Schlüssel im Diff gefunden wird, auch wenn die .gitattributes des Repos `* -diff` setzt,
# - ein Diff ohne Schlüssel grün bleibt, auch wenn an der Basis schon einer lag,
# - bei einem Push mit mehreren Commits jeder Commit zählt, nicht nur der letzte,
# - ohne Basis der ganze Baum gescannt wird,
# - ein fehlendes gitleaks NICHT GEPRÜFT ergibt, nicht grün.
#
# Der Schlüssel entsteht erst zur Laufzeit: als Literal stünde er in diesem Repo und schlüge bei
# jedem Secret-Scan an. Gegenproben stehen in .github/workflows/selbsttest.yml.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
GITLEAKS="${GITLEAKS:-gitleaks}"
MIN_PROBEN=9
command -v "$GITLEAKS" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: gitleaks fehlt ($GITLEAKS)."; exit 2; }
export GITLEAKS

PASS=0
FAIL=0
pruefe() {  # pruefe <bezeichnung> <soll> <ist>
  if [ "$2" = "$3" ]; then echo "ok    $1"; PASS=$((PASS + 1))
  else echo "FEHLT $1 (soll: $2, ist: $3)"; FAIL=$((FAIL + 1)); fi
}
# schluessel: ein Zugangsschlüssel in der Form, die gitleaks als AWS-Schlüssel erkennt.
schluessel() { printf 'AKIA%s' "$(LC_ALL=C tr -dc 'A-Z2-7' < /dev/urandom | head -c 16)"; }

WEG=$(mktemp -d)
trap 'rm -rf "$WEG"' EXIT
R="$WEG/repo"
git init -q "$R"
cd "$R" || exit 1
git config user.email test@example.invalid
git config user.name test

# Basis mit `* -diff`: ohne --text sähe gitleaks jeden Diff als binär und leer.
printf '* -diff\n' > .gitattributes
printf 'harmlos\n' > notiz.txt
git add -- . && git commit -qm basis
BASIS=$(git rev-parse HEAD)

# scan <basis>: setzt RC, Ausgabe nach $WEG/aus.
scan() {
  RC=0
  bash "$HIER/secrets-pruefen.sh" "$1" > "$WEG/aus" 2>&1 || RC=$?
}
hat() { grep -ciF -- "$1" "$WEG/aus"; }

# 1) Schlüssel im Diff, trotz `* -diff`.
git checkout -q -B s1 "$BASIS"
printf 'aws_access_key_id = %s\n' "$(schluessel)" > zugang.txt
git add -- . && git commit -qm s1
scan "$BASIS"
pruefe "Schlüssel im Diff: rc 1" 1 "$RC"
pruefe "Schlüssel im Diff: gemeldet" 1 "$(hat 'leaks found: 1')"
pruefe "Schlüssel im Diff: geschwärzt (--redact)" 0 "$(grep -c 'AKIA[A-Z2-7]\{16\}' "$WEG/aus")"

# 2) Diff ohne Schlüssel, während an der Basis (s1) schon einer liegt: nur der Diff zählt.
S1=$(git rev-parse s1)
git checkout -q -B s2 "$S1"
printf 'noch harmloser\n' >> notiz.txt && git commit -qam s2
scan "$S1"
pruefe "sauberer Diff: rc 0" 0 "$RC"
pruefe "sauberer Diff: nichts gemeldet" 1 "$(hat 'no leaks found')"

# 2b) Push mit zwei Commits: der Schlüssel im ersten, der zweite sauber. HEAD~1..HEAD sähe ihn nicht.
git checkout -q -B s2b "$BASIS"
printf 'aws_access_key_id = %s\n' "$(schluessel)" > zugang2.txt
git add -- . && git commit -qm s2b-1
printf 'danach\n' >> notiz.txt && git commit -qam s2b-2
scan "$BASIS"
pruefe "zwei Commits, Schlüssel im ersten: rc 1" 1 "$RC"
git checkout -q s2

# 3) Ohne Basis: der ganze Baum, also auch der alte Schlüssel.
scan ""
pruefe "ohne Basis: Baum gescannt, rc 1" 1 "$RC"

# 4) gitleaks fehlt: NICHT GEPRÜFT.
RC=0; GITLEAKS="$WEG/gibt-es-nicht" bash "$HIER/secrets-pruefen.sh" "$BASIS" > "$WEG/aus" 2>&1 || RC=$?
pruefe "gitleaks fehlt: rc 2" 2 "$RC"
pruefe "gitleaks fehlt: gemeldet" 1 "$(hat 'NICHT GEPRÜFT')"

echo "PASS=$PASS FAIL=$FAIL"
if [ $((PASS + FAIL)) -lt "$MIN_PROBEN" ]; then
  echo "NICHT GEPRÜFT: nur $((PASS + FAIL)) von mindestens $MIN_PROBEN Proben liefen."
  exit 2
fi
[ "$FAIL" -eq 0 ]
