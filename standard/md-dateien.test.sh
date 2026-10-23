#!/usr/bin/env bash
# Selbsttest für md-dateien.sh, links-pruefen.sh und markdown-lint.sh.
#
# Geprüft wird mit Dateinamen, an denen die erste Fassung des Workflows scheiterte: Umlaut
# (von git gequotet, still übersprungen), Leerzeichen (zerfiel in zwei Argumente), Glob-
# Zeichen (von lychee als Muster gelesen, nur gewarnt) und `$(…)` (lief per eval als Befehl).
# Jede Datei mit kaputtem Link muss lychee rot machen: daran ist belegt, dass sie wirklich
# geprüft wurde und nicht bloß in der Liste stand.
#
# markdown-lint.sh: präparierte `.markdownlint*.cjs/.mjs` im Repo legen eine Marke an und
# schalten alle Regeln ab. Weder darf die Marke entstehen noch der Regelverstoß verschwinden.
#
# Ohne lychee oder markdownlint-cli2: Exit 2, NICHT GEPRÜFT. Gegenproben am Ende der Datei.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
LYCHEE="${LYCHEE:-lychee}"
MARKDOWNLINT="${MARKDOWNLINT:-markdownlint-cli2}"
REGELSATZ="${REGELSATZ:-$HIER/../.markdownlint-cli2.yaml}"
MIN_PROBEN=20
command -v "$LYCHEE" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: lychee fehlt ($LYCHEE)."; exit 2; }
command -v "$MARKDOWNLINT" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: markdownlint-cli2 fehlt ($MARKDOWNLINT)."; exit 2; }
[ -f "$REGELSATZ" ] || { echo "NICHT GEPRÜFT: Regelsatz fehlt ($REGELSATZ)."; exit 2; }
REGELSATZ="$(cd "$(dirname "$REGELSATZ")" && pwd)/$(basename "$REGELSATZ")"

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

# lychee.toml im Repo: `preprocess` würde jede Datei durch sh schicken.
printf 'preprocess = { command = "sh" }\n' > lychee.toml
printf 'touch "%s/MARKE-lychee"\n\n[kaputt](fehlt-toml.md)\n' "$WEG" > toml.md
printf 'toml.md\n' > "$WEG/eine"
LYCHEE="$LYCHEE" bash "$HIER/links-pruefen.sh" "$WEG/eine" > "$WEG/out" 2>&1
pruefe "lychee.toml des Repos: keine Ausführung" nein "$([ -e "$WEG/MARKE-lychee" ] && echo ja || echo nein)"
pruefe "lychee.toml des Repos: kaputter Link weiter gemeldet" 1 "$(grep -c 'fehlt-toml.md' "$WEG/out")"
rm -f lychee.toml

printf 'basis.md\n' > "$WEG/heil"
LYCHEE="$LYCHEE" bash "$HIER/links-pruefen.sh" "$WEG/heil" > "$WEG/out" 2>&1
pruefe "Datei ohne kaputten Link → grün" 0 "$?"

# markdown-lint.sh: Konfiguration mit Code aus dem geprüften Repo darf nie laufen.
mkdir -p docs
for k in .markdownlint-cli2.cjs docs/.markdownlint.cjs docs/.markdownlint-cli2.mjs; do
  marke="$WEG/marke-$(basename "$k")"
  case "$k" in
    *.mjs) printf 'import fs from "node:fs"; fs.writeFileSync("%s", "x");\nexport default {config: {default: false}};\n' "$marke" > "$k" ;;
    *)     printf 'require("fs").writeFileSync("%s", "x");\nmodule.exports = {config: {default: false}};\n' "$marke" > "$k" ;;
  esac
done
printf '# Titel\n\n#kein-leerzeichen\n' > 'docs/Übersicht.md'
printf '# Sauber\n\nText.\n' > docs/sauber.md
printf '%s\n' 'docs/Übersicht.md' > "$WEG/lint-rot"
MARKDOWNLINT="$MARKDOWNLINT" bash "$HIER/markdown-lint.sh" "$WEG/lint-rot" "$REGELSATZ" > "$WEG/out" 2>&1
pruefe "markdownlint: Verstoß in 'docs/Übersicht.md' → Exit 1" 1 "$?"
pruefe "markdownlint: MD018 für genau diese Datei gemeldet" 1 "$(grep -c 'Übersicht.md:3.*MD018' "$WEG/out")"
pruefe "markdownlint: keine Repo-Konfiguration ausgeführt" 0 "$(find "$WEG" -maxdepth 1 -name 'marke-*' | wc -l | tr -d ' ')"
printf '%s\n' docs/sauber.md '-strich.md' > "$WEG/lint-gruen"
printf '# t\n' > '-strich.md'
MARKDOWNLINT="$MARKDOWNLINT" bash "$HIER/markdown-lint.sh" "$WEG/lint-gruen" "$REGELSATZ" > "$WEG/out" 2>&1
pruefe "markdownlint: saubere Dateien → Exit 0" 0 "$?"
pruefe "markdownlint: beide Dateien gelintet" 1 "$(grep -c 'Linting: 2 file' "$WEG/out")"

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
# - markdown-lint.sh ohne `cd` in die Kopie (Lint im Repo) → Marken entstehen, rot (1 Probe).
#   Die MD018-Probe schlägt dabei nicht an: --config übersteuert das `default: false` der
#   Repo-Konfiguration. Den Schutz trägt allein die Marken-Probe.
# - links-pruefen.sh ohne --config → lychee.toml des Repos läuft, rot (2 Proben).
