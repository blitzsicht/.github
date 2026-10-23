#!/usr/bin/env bash
# Prüft die copier-Vorlage: jedes Profil, mit und ohne geplanten Betrieb, ergibt ein Repo,
# das pruefe-repo.sh besteht und markdownlint ohne Befund durchläuft. Gegenprobe: ein
# L-Repo ohne Diagramm muss an R-MERMAID scheitern. Braucht copier und markdownlint-cli2.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
VORLAGE="$(dirname "$HIER")"
WURZEL=$(mktemp -d)
trap 'rm -rf "$WURZEL"' EXIT
PASS=0
FAIL=0
gut()      { echo "  ok   $1"; PASS=$((PASS+1)); }
schlecht() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

erzeuge() {  # erzeuge <Ziel> <Profil> <ja|nein>
  copier copy --quiet --defaults --vcs-ref HEAD "$VORLAGE" "$1" \
    --data profil="$2" --data name=beispiel-werkzeug --data "zweck=Prüft Beispiele." \
    --data betrieb_geplant="$3" > /dev/null 2>&1 || return 1
  git -C "$1" init -q
  if [ "$2" = M ] || [ "$2" = L ]; then git -C "$1" remote add origin https://example.invalid/b.git; fi
}

for p in S M L W; do
  for b in ja nein; do
    d="$WURZEL/$p-$b"
    if ! erzeuge "$d" "$p" "$b"; then schlecht "$p/$b: copier copy schlug fehl"; continue; fi
    if bash "$HIER/pruefe-repo.sh" "$d" > /dev/null; then gut "$p/$b besteht pruefe-repo.sh"
    else schlecht "$p/$b besteht pruefe-repo.sh nicht"; fi
    if markdownlint-cli2 --config "$VORLAGE/.markdownlint-cli2.yaml" "$d/**/*.md" > /dev/null 2>&1
    then gut "$p/$b markdownlint ohne Befund"; else schlecht "$p/$b markdownlint mit Befund"; fi
  done
done

d="$WURZEL/L-ja"
if [ -f "$d/docs/ARCHITEKTUR.md" ]; then
  printf '# Architektur\n' > "$d/docs/ARCHITEKTUR.md"
  aus=$(bash "$HIER/pruefe-repo.sh" "$d")
  if grep -q '^FEHLER  R-MERMAID:' <<<"$aus"; then gut "L ohne Diagramm scheitert an R-MERMAID"
  else schlecht "L ohne Diagramm wird nicht erkannt"; fi
else
  schlecht "L/ja ohne docs/ARCHITEKTUR.md erzeugt"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$((PASS + FAIL))" -ge 17 ] || { echo "FEHLER: nur $((PASS + FAIL)) Fälle gelaufen, erwartet 17"; exit 1; }
[ "$FAIL" -eq 0 ]
