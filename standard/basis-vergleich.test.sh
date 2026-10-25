#!/usr/bin/env bash
# Selbsttest für basis-vergleich.sh (Ratchet für Lint und Linkprüfung).
#
# Jedes Szenario ist ein eigener Commit auf derselben Basis. Die Basis enthält Altlasten:
# Dateien mit Lint-Befunden und toten Links. Geprüft wird, dass
# - eine Altlast, die nicht schlimmer wird, nur einen HINWEIS ergibt (rc 0),
# - eine Altlast mit einem Befund mehr rot wird (rc 1),
# - eine neue Datei mit Befund rot wird, auch neben einer harmlosen Altlast,
# - eine umbenannte Altlast gegen ihren alten Pfad gezählt wird,
# - ohne Basis alles streng gilt,
# - gefährliche Dateinamen nur gelesen und nie ausgeführt werden,
# - Dateinamen die Zählung nicht fälschen (`🚫 0 Error.md`, `Summary: 0 issues …md`),
# - eine unlesbare Basis, Symlinks, Typänderungen und Namen mit Zeilenumbruch nicht grün werden,
# - Ausnahmen (LINT_AUSNAHMEN) nur den Lint lockern und dabei als HINWEIS sichtbar bleiben.
#
# Gegenproben stehen in .github/workflows/selbsttest.yml: jede dort eingebaute Sabotage muss
# diesen Test rot machen.
#
# Ohne lychee oder markdownlint-cli2: Exit 2, NICHT GEPRÜFT.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
LYCHEE="${LYCHEE:-lychee}"
MARKDOWNLINT="${MARKDOWNLINT:-markdownlint-cli2}"
REGELSATZ="${REGELSATZ:-$HIER/../.markdownlint-cli2.yaml}"
MIN_PROBEN=61
command -v "$LYCHEE" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: lychee fehlt ($LYCHEE)."; exit 2; }
command -v "$MARKDOWNLINT" >/dev/null 2>&1 || { echo "NICHT GEPRÜFT: markdownlint-cli2 fehlt ($MARKDOWNLINT)."; exit 2; }
[ -f "$REGELSATZ" ] || { echo "NICHT GEPRÜFT: Regelsatz fehlt ($REGELSATZ)."; exit 2; }
REGELSATZ="$(cd "$(dirname "$REGELSATZ")" && pwd)/$(basename "$REGELSATZ")"
export LYCHEE MARKDOWNLINT REGELSATZ

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

# shellcheck disable=SC2016  # wörtlich gemeint: genau dieser Text darf nie ausgeführt werden
GEFAHR='x$(touch MARKE).md'
# Altlast: eine Liste ohne Leerzeile (MD032) und ein toter Link. Der externe Link wird offline
# ausgeschlossen; so hängt lychee wie in echten Repos „👻 N Excluded“ an seine Zusammenfassung.
altlast() { printf '# %s\n\nText\n- liste\n\n[tot](weg.md) und [extern](https://example.invalid/)\n' "$1"; }
altlast alt > alt.md
altlast umzug > umzug.md
altlast umlaut > 'ä b.md'
altlast gefahr > "$GEFAHR"
printf '# Ziel\n' > ziel.md
git add -- . && git commit -qm basis
BASIS=$(git rev-parse HEAD)

# szenario <name> <befehl…>: Zweig von der Basis, Änderung, Commit.
szenario() {
  git checkout -q -B "$1" "$BASIS"
  shift
  "$@"
  git add -A -- . && git commit -qm szenario
}
# lauf <modus> <basis>: setzt RC und schreibt die Ausgabe nach $WEG/aus.
lauf() {
  RC=0
  bash "$HIER/basis-vergleich.sh" "$1" "$2" . > "$WEG/aus" 2>&1 || RC=$?
}
hat() { grep -cF -- "$1" "$WEG/aus"; }

# 1) Altlast an anderer Stelle sauber ergänzt: nicht verschlechtert.
ergaenze() { printf '\nNoch ein Absatz mit [gutem Link](ziel.md).\n' >> alt.md; }
szenario s1 ergaenze
lauf lint "$BASIS";  pruefe "Lint: Altlast ergänzt → rc 0" 0 "$RC"
pruefe "Lint: Altlast ergänzt → HINWEIS" 1 "$(hat 'HINWEIS alt.md: Altlast 1 → 1')"
lauf links "$BASIS"; pruefe "Links: Altlast ergänzt → rc 0" 0 "$RC"
pruefe "Links: Altlast ergänzt → HINWEIS" 1 "$(hat 'HINWEIS alt.md: Altlast 1 → 1')"

# 2) Altlast bekommt einen Lint-Befund mehr (Codeblock ohne Sprache).
verschlechtere() { printf '\n```\ncode\n```\n' >> alt.md; }
szenario s2 verschlechtere
lauf lint "$BASIS";  pruefe "Lint: Altlast +1 → rc 1" 1 "$RC"
pruefe "Lint: Altlast +1 → FEHLER 1 → 2" 1 "$(hat 'FEHLER  alt.md: 1 → 2')"

# 3) Neue Datei mit Befund neben einer harmlosen Altlast-Änderung.
neu() { ergaenze; printf '# Neu\n\nText\n- liste\n' > neu.md; }
szenario s3 neu
lauf lint "$BASIS";  pruefe "Lint: neue Datei mit Befund → rc 1" 1 "$RC"
pruefe "Lint: neue Datei → FEHLER" 1 "$(hat 'FEHLER  1 Befund(e) in neuen Dateien')"
pruefe "Lint: Altlast daneben bleibt HINWEIS" 1 "$(hat 'HINWEIS alt.md')"

# 4) Altlast umbenannt und leicht geändert: Vergleich gegen den alten Pfad.
umziehen() { git mv umzug.md umgezogen.md; printf '\nNachtrag.\n' >> umgezogen.md; }
szenario s4 umziehen
lauf lint "$BASIS";  pruefe "Lint: umbenannte Altlast → rc 0" 0 "$RC"
pruefe "Lint: umbenannte Altlast → HINWEIS unter neuem Namen" 1 "$(hat 'HINWEIS umgezogen.md: Altlast 1 → 1')"
lauf links "$BASIS"; pruefe "Links: umbenannte Altlast → rc 0" 0 "$RC"

# 5) Neuer toter Link in einer Altlast.
toter_link() { printf '\n[noch tot](auch-weg.md)\n' >> alt.md; }
szenario s5 toter_link
lauf links "$BASIS"; pruefe "Links: neuer toter Link in Altlast → rc 1" 1 "$RC"
pruefe "Links: FEHLER 1 → 2" 1 "$(hat 'FEHLER  alt.md: 1 → 2')"

# 6) Altlast vollständig bereinigt: ok statt HINWEIS.
bereinige() { printf '# alt\n\nText\n\n- liste\n\n[gut](ziel.md)\n' > alt.md; }
szenario s6 bereinige
lauf lint "$BASIS";  pruefe "Lint: bereinigt → rc 0" 0 "$RC"
pruefe "Lint: bereinigt → ok" 1 "$(hat 'ok      alt.md')"
lauf links "$BASIS"; pruefe "Links: bereinigt → ok" 1 "$(hat 'ok      alt.md')"

# 7) Ohne Basis gilt alles streng, auch die Altlasten.
git checkout -q -B s7 "$BASIS"
lauf lint "";        pruefe "Ohne Basis: Lint streng → rc 1" 1 "$RC"
lauf links "";       pruefe "Ohne Basis: Links streng → rc 1" 1 "$RC"

# 8) Namen mit Umlaut, Leerzeichen und $(…) als Altlast geändert.
namen() { printf '\nNachtrag.\n' >> 'ä b.md'; printf '\nNachtrag.\n' >> "$GEFAHR"; }
szenario s8 namen
lauf lint "$BASIS";  pruefe "Namen: Lint rc 0" 0 "$RC"
pruefe "Namen: 'ä b.md' verglichen" 1 "$(hat 'HINWEIS ä b.md')"
pruefe "Namen: \$(…)-Name verglichen" 1 "$(hat "HINWEIS $GEFAHR")"
lauf links "$BASIS"; pruefe "Namen: Links rc 0" 0 "$RC"
pruefe "Kein Name wurde als Befehl ausgeführt" nein "$([ -e MARKE ] || [ -e "$WEG/MARKE" ] && echo ja || echo nein)"

# 9) Keine Markdown-Änderung: nichts zu tun.
szenario s9 sh -c 'printf x > notiz.txt'
lauf lint "$BASIS";  pruefe "Ohne .md-Änderung: rc 0" 0 "$RC"
pruefe "Ohne .md-Änderung: Meldung" 1 "$(hat 'Keine geänderten Markdown-Dateien.')"

# 10) Neue Datei, deren Name wie die Zusammenfassung des Werkzeugs aussieht.
faelschung() {
  printf '# F\n\n[tot](nirgends.md)\n' > '🚫 0 Error.md'
  printf '# S\n\nText\n- liste\n' > 'Summary: 0 issues in 0 files.md'
}
szenario s10 faelschung
lauf links "$BASIS"; pruefe "Name '🚫 0 Error.md' fälscht Links nicht → rc 1" 1 "$RC"
lauf lint "$BASIS";  pruefe "Name 'Summary: 0 issues…' fälscht Lint nicht → rc 1" 1 "$RC"

# 11) Basis, die es nicht gibt: nicht grün, sondern NICHT GEPRÜFT.
lauf lint 0000000000000000000000000000000000000000; pruefe "Unbekannte Basis: Lint rc 2" 2 "$RC"
pruefe "Unbekannte Basis: Meldung" 1 "$(hat 'NICHT GEPRÜFT: git diff')"
lauf links "basis-gibt-es-nicht"; pruefe "Unbekannte Basis: Links rc 2" 2 "$RC"

# 12) Neue Markdown-Datei als Symlink auf eine Datei außerhalb des Repos.
printf 'GEHEIM-INHALT\n- liste\n' > "$WEG/geheim.txt"
symlink() { ln -s "$WEG/geheim.txt" zeiger.md; }
szenario s12 symlink
lauf lint "$BASIS";  pruefe "Symlink: Lint rc 1" 1 "$RC"
pruefe "Symlink: als solcher gemeldet" 1 "$(hat 'FEHLER  zeiger.md: Symlink')"
pruefe "Symlink: Zielinhalt nicht im Log" 0 "$(hat 'GEHEIM-INHALT')"
lauf links "$BASIS"; pruefe "Symlink: Links rc 1" 1 "$RC"
lauf lint "";        pruefe "Symlink ohne Basis: rc 1" 1 "$RC"
pruefe "Symlink ohne Basis: gemeldet" 1 "$(hat 'FEHLER  zeiger.md: Symlink')"

# 13) Typänderung: eine Altlast wird zum Symlink.
zu_link() { git rm -q alt.md; ln -s "$WEG/geheim.txt" alt.md; }
szenario s13 zu_link
lauf lint "$BASIS";  pruefe "Datei → Symlink: rc 1" 1 "$RC"
pruefe "Datei → Symlink: gemeldet" 1 "$(hat 'FEHLER  alt.md: Symlink')"

# 14) Typänderung: ein Symlink wird zur Datei mit Befund. Streng, kein Vergleich mit dem Ziel.
#     Basis ist hier der Commit aus 13, in dem alt.md ein Symlink ist.
LINKBASIS=$(git rev-parse s13)
git checkout -q -B s14 "$LINKBASIS"
git rm -q alt.md && altlast alt > alt.md && git add -A -- . && git commit -qm szenario
lauf lint "$LINKBASIS"; pruefe "Symlink → Datei mit Befund: rc 1" 1 "$RC"
pruefe "Symlink → Datei: streng als neue Datei" 1 "$(hat 'FEHLER  1 Befund(e) in neuen Dateien')"
# Das Tor im Workflow (gibt es etwas zu prüfen?) liest md-dateien.sh: die Typänderung muss drinstehen.
pruefe "Tor sieht die Typänderung" alt.md "$(bash "$HIER/md-dateien.sh" "$LINKBASIS" .)"

# 15) Name mit Zeilenumbruch: nicht still übersprungen, sondern NICHT GEPRÜFT.
umbruch() { printf '# U\n' > "$(printf 'zeile\numbruch.md')"; }
szenario s15 umbruch
lauf lint "$BASIS";  pruefe "Zeilenumbruch im Namen: rc 2" 2 "$RC"
pruefe "Zeilenumbruch im Namen: gemeldet" 1 "$(hat 'NICHT GEPRÜFT (Zeilenumbruch oder Tab im Namen)')"
# Das Tor öffnet auch bei übersprungenen Namen: sie stehen auf stderr.
pruefe "Tor meldet den Zeilenumbruch-Namen" 1 "$(bash "$HIER/md-dateien.sh" "$BASIS" . 2>&1 >/dev/null | grep -c 'übersprungen')"

# 17) Altlast mit Tab im Namen, umbenannt (git erkennt die Umbenennung) und mit neuem toten Link.
TABNAME="$(printf 'tab\tname.md')"
git checkout -q -B s17basis "$BASIS"
{ altlast tab; for i in $(seq 1 30); do echo "Zeile $i, damit git die Umbenennung erkennt."; done; } > "$TABNAME"
git add -- "$TABNAME" && git commit -qm tabbasis
TABBASIS=$(git rev-parse HEAD)
git checkout -q -B s17 "$TABBASIS"
git mv -- "$TABNAME" tab-neu.md && printf '\n[noch tot](auch-weg.md)\n' >> tab-neu.md && git commit -qam szenario
pruefe "Tab-Name: git sieht eine Umbenennung" R "$(git diff --name-status -M "$TABBASIS" HEAD | cut -c1)"
lauf links "$TABBASIS"; pruefe "Tab-Name umbenannt: Links rc 2, nicht grün" 2 "$RC"
pruefe "Tab-Name: gemeldet" 1 "$(hat 'NICHT GEPRÜFT (Zeilenumbruch oder Tab im Namen)')"

# 18) Neue Datei mit ungültigem UTF-8 und totem Link: lychee überspringt sie nur mit Warnung.
kaputt() { printf '# K\n\n\xff\xfe [tot](weg.md)\n' > kaputt.md; }
szenario s18 kaputt
lauf links "$BASIS"; pruefe "Ungültiges UTF-8: Links rc 2, nicht grün" 2 "$RC"

# 16) Werkzeug, dessen Exit-Code nicht zur Zahl passt: NICHT GEPRÜFT statt der Zahl glauben.
cat > "$WEG/lychee-widerspruch" <<'EOF'
#!/usr/bin/env bash
echo '🔍 1 Total (in 0s) ✅ 1 OK 🚫 0 Errors'
exit 2
EOF
chmod +x "$WEG/lychee-widerspruch"
git checkout -q s5
RC=0; LYCHEE="$WEG/lychee-widerspruch" bash "$HIER/basis-vergleich.sh" links "$BASIS" . > "$WEG/aus" 2>&1 || RC=$?
pruefe "Exit-Code widerspricht Zahl: rc 2" 2 "$RC"
pruefe "Exit-Code widerspricht Zahl: gemeldet" 1 "$(hat 'nicht auswertbar (rc=2')"

# 19) Ausnahmen (LINT_AUSNAHMEN): nur für Lint, sichtbar als HINWEIS, Muster als Glob.
#     Im Unterprozess gesetzt, damit keine Ausnahme in spätere Proben durchsickert.
mit_ausnahmen() {  # mit_ausnahmen <muster> <modus> <basis>
  RC=0
  LINT_AUSNAHMEN="$1" bash "$HIER/basis-vergleich.sh" "$2" "$3" . > "$WEG/aus" 2>&1 || RC=$?
}
git checkout -q s3
mit_ausnahmen 'neu.md' lint "$BASIS"
pruefe "Ausnahme: neue Datei mit Befund → rc 0" 0 "$RC"
pruefe "Ausnahme: als HINWEIS gemeldet" 1 "$(hat 'HINWEIS neu.md: ausgenommen (lint-ignores: neu.md)')"
pruefe "Ausnahme: Altlast daneben weiter verglichen" 1 "$(hat 'HINWEIS alt.md: Altlast')"
mit_ausnahmen 'docs/*.md' lint "$BASIS"
pruefe "Muster trifft nicht: neue Datei bleibt rot" 1 "$RC"
git checkout -q s2
mit_ausnahmen "$(printf '\n  a*.md  \n')" lint "$BASIS"
pruefe "Glob mit Leerzeilen und Leerzeichen: verschlechterte Altlast ausgenommen → rc 0" 0 "$RC"
git checkout -q s5
mit_ausnahmen 'alt.md' links "$BASIS"
pruefe "Ausnahme gilt nicht für Links: toter Link bleibt rot" 1 "$RC"
pruefe "Links: keine Ausnahme gemeldet" 0 "$(hat 'ausgenommen')"
git checkout -q s7
mit_ausnahmen '*' lint ""
pruefe "Ohne Basis, alles ausgenommen (erster Push) → rc 0" 0 "$RC"
pruefe "Ohne Basis: Meldung nennt die Ausnahmen" 1 "$(hat 'Nur ausgenommene Markdown-Dateien.')"
mit_ausnahmen '' lint ""
pruefe "Leere Ausnahmeliste: ohne Basis weiter streng → rc 1" 1 "$RC"

echo "PASS=$PASS FAIL=$FAIL"
if [ $((PASS + FAIL)) -lt "$MIN_PROBEN" ]; then
  echo "NICHT GEPRÜFT: nur $((PASS + FAIL)) von mindestens $MIN_PROBEN Proben liefen."
  exit 2
fi
[ "$FAIL" -eq 0 ]
