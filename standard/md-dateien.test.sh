#!/usr/bin/env bash
# Selbsttest für md-dateien.sh und links-pruefen.sh.
#
# Geprüft wird mit Dateinamen, an denen die erste Fassung des Workflows scheiterte: Umlaut
# (von git gequotet, still übersprungen), Leerzeichen (zerfiel in zwei Argumente), Glob-
# Zeichen (von lychee als Muster gelesen, nur gewarnt) und `$(…)` (lief per eval als Befehl).
# Jede Datei mit kaputtem Link muss lychee rot machen: daran ist belegt, dass sie wirklich
# geprüft wurde und nicht bloß in der Liste stand.
#
# Ohne lychee: Exit 2, NICHT GEPRÜFT. Gegenprobe am Ende der Datei.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
LYCHEE="${LYCHEE:-lychee}"
MIN_PROBEN=12
command -v "$LYCHEE" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: lychee fehlt ($LYCHEE)."; exit 2; }

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

# Die Marke darf nach keinem Lauf existieren: sie entsteht nur, wenn ein Name ausgeführt wird.
# shellcheck disable=SC2016  # wörtlich gemeint: genau dieser Text darf nie ausgeführt werden
GEFAHR='x$(touch MARKE).md'
NAMEN=('ä.md' 'a b.md' '[k].md' 's*?.md' "$GEFAHR" '-strich.md')
printf '# basis\n' > basis.md
printf 'kein markdown\n' > notiz.txt
git add . && git commit -qm basis
BASIS=$(git rev-parse HEAD)
for n in "${NAMEN[@]}"; do printf '# t\n\n[kaputt](fehlt-%s.md)\n' "${#n}" > "$n"; done
printf 'neu\n' > neu.txt
git add -- . && git commit -qm neu

bash "$HIER/md-dateien.sh" "$BASIS" . > "$WEG/liste" 2> "$WEG/err"
pruefe "Diff: genau die 6 neuen .md-Dateien" 6 "$(grep -c '' "$WEG/liste")"
for n in 'ä.md' 'a b.md' "$GEFAHR"; do
  pruefe "Diff: '$n' wörtlich gelistet" 1 "$(grep -cxF -- "$n" "$WEG/liste")"
done
pruefe "Diff: keine .txt" 0 "$(grep -c '\.txt$' "$WEG/liste")"

bash "$HIER/md-dateien.sh" "" . > "$WEG/alle"
pruefe "Ohne Basis: alle 7 .md-Dateien" 7 "$(grep -c '' "$WEG/alle")"

# Je Datei einzeln: rot heißt, lychee hat genau diese Datei gelesen.
for n in "${NAMEN[@]}"; do
  printf '%s\n' "$n" > "$WEG/eine"
  LYCHEE="$LYCHEE" bash "$HIER/links-pruefen.sh" "$WEG/eine" > "$WEG/out" 2>&1; rc=$?
  # Rot allein reicht nicht: auch „No files found“ o. ä. könnte rot sein. Verlangt ist
  # die Meldung über genau den kaputten Link dieser Datei.
  { [ "$rc" -ne 0 ] && grep -qF "fehlt-${#n}.md" "$WEG/out"; } && rot=ja || rot=nein
  pruefe "lychee prüft '$n' (kaputter Link → rot)" ja "$rot"
done
pruefe "Kein Name wurde als Befehl ausgeführt" nein "$([ -e MARKE ] && echo ja || echo nein)"

printf 'basis.md\n' > "$WEG/heil"
LYCHEE="$LYCHEE" bash "$HIER/links-pruefen.sh" "$WEG/heil" > "$WEG/out" 2>&1
pruefe "Datei ohne kaputten Link → grün" 0 "$?"

echo
PROBEN=$((PASS + FAIL))
if [ "$PROBEN" -lt "$MIN_PROBEN" ]; then
  echo "FEHLT Probenzahl $PROBEN unter der Untergrenze $MIN_PROBEN — der Test prüft still weniger."
  FAIL=$((FAIL + 1))
fi
echo "PROBEN=$PROBEN FEHLER=$FAIL"
[ "$FAIL" -eq 0 ]

# Gegenproben (in der CI als eigener Schritt):
# - md-dateien.sh als alte Zeilenliste ohne `-z` → 'ä.md' fehlt in der Liste, rot (3 Proben).
#   Nur `core.quotePath=false` zu entfernen bleibt grün: `-z` gibt Namen ohnehin wörtlich aus.
# - links-pruefen.sh ohne Glob-Escaping → '[k].md' nur gewarnt, nicht geprüft, rot.
# - links-pruefen.sh mit `eval` wie die lychee-Action → MARKE entsteht, rot (4 Proben).
