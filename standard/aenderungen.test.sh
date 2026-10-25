#!/usr/bin/env bash
# Selbsttest für aenderungen.sh (Tor des reusable Workflows).
#
# Geprüft wird, dass
# - eine geänderte .md das Tor öffnet und die Basis durchreicht,
# - eine Änderung ohne .md das Tor schließt,
# - ein neuer Branch (before = 000…) und eine unbekannte Basis zu „keine Basis“ werden,
# - ein Name mit Zeilenumbruch das Tor öffnet, obwohl die Liste leer ist,
# - die Listen im übergebenen Verzeichnis landen, nicht im Checkout, und eine gleichnamige
#   Datei oder ein Symlink aus dem Repo nichts daran ändert,
# - auf stdout nur die Zeilen für $GITHUB_OUTPUT stehen.
#
# Gegenproben stehen in .github/workflows/selbsttest.yml: jede Sabotage muss diesen Test rot machen.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
MIN_PROBEN=21

PASS=0
FAIL=0
pruefe() {  # pruefe <bezeichnung> <soll> <ist>
  if [ "$2" = "$3" ]; then echo "ok    $1"; PASS=$((PASS + 1))
  else echo "FEHLT $1 (soll: $2, ist: $3)"; FAIL=$((FAIL + 1)); fi
}

WEG=$(mktemp -d)
trap 'rm -rf "$WEG"' EXIT
R="$WEG/repo"
git init -q "$R"
cd "$R" || exit 1
git config user.email test@example.invalid
git config user.name test

printf '# A\n' > a.md
printf 'x\n' > code.txt
git add -- . && git commit -qm basis
BASIS=$(git rev-parse HEAD)

# tor <basis>: setzt RC, schreibt stdout nach $WEG/aus, Listen nach $WEG/listen.
tor() {
  rm -rf "$WEG/listen"; mkdir -p "$WEG/listen"
  RC=0
  bash "$HIER/aenderungen.sh" "$1" . "$WEG/listen" > "$WEG/aus" 2> "$WEG/err" || RC=$?
}
wert() { sed -n "s/^$1=//p" "$WEG/aus"; }

# 1) Geänderte .md: Tor offen, Basis durchgereicht, Liste im Listenverzeichnis.
git checkout -q -B s1 "$BASIS"
printf '# B\n' > b.md && git add b.md && git commit -qm s1
tor "$BASIS"
pruefe "md geändert: rc 0" 0 "$RC"
pruefe "md geändert: Tor offen" true "$(wert md)"
pruefe "md geändert: Basis durchgereicht" "$BASIS" "$(wert basis)"
pruefe "md geändert: Liste nennt b.md" b.md "$(cat "$WEG/listen/md-nur.txt")"
pruefe "stdout enthält nur basis= und md=" 0 "$(grep -cvE '^(basis|md)=' "$WEG/aus")"

# 2) Nur Code geändert: Tor zu.
git checkout -q -B s2 "$BASIS"
printf 'y\n' >> code.txt && git commit -qam s2
tor "$BASIS"
pruefe "ohne md: rc 0" 0 "$RC"
pruefe "ohne md: Tor zu" false "$(wert md)"
pruefe "ohne md: Liste leer" 0 "$(wc -l < "$WEG/listen/md-nur.txt" | tr -d ' ')"

# 3) Neuer Branch: before = 000…, alles gilt als geändert.
tor 0000000000000000000000000000000000000000
pruefe "Nullbasis: keine Basis" "" "$(wert basis)"
pruefe "Nullbasis: Tor offen (alle Dateien)" true "$(wert md)"
pruefe "Nullbasis: Liste nennt a.md" a.md "$(cat "$WEG/listen/md-nur.txt")"

# 4) Basis, die es im Checkout nicht gibt, und leere Basis.
tor "basis-gibt-es-nicht"
pruefe "unbekannte Basis: keine Basis" "" "$(wert basis)"
tor ""
pruefe "leere Basis: Tor offen" true "$(wert md)"

# 5) Nur ein Name mit Zeilenumbruch: Liste leer, Tor trotzdem offen.
git checkout -q -B s5 "$BASIS"
printf '# U\n' > "$(printf 'zeile\numbruch.md')" && git add -A -- . && git commit -qm s5
tor "$BASIS"
pruefe "Zeilenumbruch: Liste leer" 0 "$(wc -l < "$WEG/listen/md-nur.txt" | tr -d ' ')"
pruefe "Zeilenumbruch: Tor offen" true "$(wert md)"
pruefe "Zeilenumbruch: auf stderr gemeldet" 1 "$(grep -c 'übersprungen' "$WEG/err")"

# 6) Das Repo bringt gleichnamige Listen mit (Datei und Symlink auf /dev/null): unberührt.
git checkout -q -B s6 "$BASIS"
printf 'fremd\n' > md-nur.txt
ln -s /dev/null md-uebersprungen.txt
printf '# C\n' > c.md
git add -A -- . && git commit -qm s6
tor "$BASIS"
pruefe "fremde Listen: Tor offen" true "$(wert md)"
pruefe "fremde Listen: md-nur.txt im Repo unverändert" fremd "$(cat md-nur.txt)"
pruefe "fremde Listen: Symlink im Repo unverändert" /dev/null "$(readlink md-uebersprungen.txt)"

# 7) Kein git-Repo: nicht „Tor zu“, sondern Abbruch ohne Ausgabe.
cd "$WEG" || exit 1
mkdir -p leer && cd leer || exit 1
tor ""
pruefe "kein Repo: rc 2" 2 "$RC"
pruefe "kein Repo: nichts auf stdout" 0 "$(wc -c < "$WEG/aus" | tr -d ' ')"

echo "PASS=$PASS FAIL=$FAIL"
if [ $((PASS + FAIL)) -lt "$MIN_PROBEN" ]; then
  echo "NICHT GEPRÜFT: nur $((PASS + FAIL)) von mindestens $MIN_PROBEN Proben liefen."
  exit 2
fi
[ "$FAIL" -eq 0 ]
