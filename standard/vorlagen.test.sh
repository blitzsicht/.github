#!/usr/bin/env bash
# Prüft die copier-Vorlage: jedes Profil, mit und ohne geplanten Betrieb, ergibt ein Repo,
# das pruefe-repo.sh besteht und markdownlint ohne Befund durchläuft. Ausnahme L: die
# Vorlage liefert für docs/ARCHITEKTUR.md nur Platzhaltertext, ein frisches L-Repo muss
# also an genau R-MERMAID scheitern; Gegenprobe: mit Diagramm ist es grün. Dazu je Repo
# die Zeile „Betrieb: geplant“ und die .gitignore. Braucht copier und markdownlint-cli2.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
VORLAGE="$(dirname "$HIER")"
WURZEL=$(mktemp -d)
trap 'rm -rf "$WURZEL"' EXIT
PASS=0
FAIL=0
FENCE='```'
gut()      { echo "  ok   $1"; PASS=$((PASS+1)); }
schlecht() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

erzeuge() {  # erzeuge <Ziel> <Profil> <ja|nein> [weitere Optionen für copier]
  copier copy --quiet --defaults --vcs-ref HEAD "${@:4}" "$VORLAGE" "$1" \
    --data profil="$2" --data name=beispiel-werkzeug --data "zweck=Prüft Beispiele." \
    --data betrieb_geplant="$3" > /dev/null 2>&1 || return 1
  git -C "$1" init -q
  if [ "$2" = M ] || [ "$2" = L ]; then git -C "$1" remote add origin https://example.invalid/b.git; fi
}

ignoriert() {  # ignoriert <Repo> <Pfad> → 0 ignoriert, 1 nicht ignoriert, 2 git check-ignore gescheitert
  local rc=0
  git -C "$1" check-ignore -q -- "$2" || rc=$?
  case "$rc" in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

for p in S M L W; do
  for b in ja nein; do
    d="$WURZEL/$p-$b"
    if ! erzeuge "$d" "$p" "$b"; then schlecht "$p/$b: copier copy schlug fehl"; continue; fi
    aus=$(bash "$HIER/pruefe-repo.sh" "$d"); rc=$?
    if [ "$p" = L ]; then
      if [ "$rc" -eq 1 ] && [ "$(grep -c '^FEHLER' <<<"$aus")" -eq 1 ] && grep -q '^FEHLER  R-MERMAID:' <<<"$aus"
      then gut "$p/$b scheitert nur an R-MERMAID (Platzhalter statt Diagramm)"
      else schlecht "$p/$b: erwartet genau einen FEHLER R-MERMAID, Exit $rc"; fi
    else
      if [ "$rc" -eq 0 ]; then gut "$p/$b besteht pruefe-repo.sh"
      else schlecht "$p/$b besteht pruefe-repo.sh nicht"; fi
    fi
    if markdownlint-cli2 --config "$VORLAGE/.markdownlint-cli2.yaml" "$d/**/*.md" > /dev/null 2>&1
    then gut "$p/$b markdownlint ohne Befund"; else schlecht "$p/$b markdownlint mit Befund"; fi

    # pruefe-repo.sh prüft R-BETRIEB nur, wenn die Zeile in AGENTS.md steht. Fehlt sie trotz
    # „ja“, fällt die Regel still aus; deshalb bei M und L Zeile und Regel zusammen prüfen.
    zeile=$(grep -cx 'Betrieb: geplant' "$d/AGENTS.md")
    regel=$(grep -c '^ok      R-BETRIEB:' <<<"$aus")
    if [ "$b" = ja ] && [ "$zeile" -eq 1 ] && { [ "$p" = S ] || [ "$p" = W ] || [ "$regel" -eq 1 ]; }
    then gut "$p/$b AGENTS.md mit Zeile 'Betrieb: geplant'"
    elif [ "$b" = nein ] && [ "$zeile" -eq 0 ] && [ "$regel" -eq 0 ]
    then gut "$p/$b AGENTS.md ohne Zeile 'Betrieb: geplant'"
    else schlecht "$p/$b: Betrieb-Zeile $zeile-mal, R-BETRIEB $regel-mal geprüft"; fi

    # AGENTS.md sagt „.env* ist ignoriert“: das muss im erzeugten Repo auch stimmen.
    ignoriert "$d" .env; e=$?
    ignoriert "$d" .env.local; l=$?
    ignoriert "$d" .env.example; x=$?
    if [ "$e$l$x" = 001 ]; then gut "$p/$b .env und .env.local ignoriert, .env.example nicht"
    else schlecht "$p/$b .gitignore: .env=$e .env.local=$l .env.example=$x (erwartet 0 0 1)"; fi
  done
done

d="$WURZEL/L-ja"
if [ -f "$d/docs/ARCHITEKTUR.md" ]; then
  printf '\n%smermaid\nflowchart LR\n  A --> B\n%s\n' "$FENCE" "$FENCE" >> "$d/docs/ARCHITEKTUR.md"
  if bash "$HIER/pruefe-repo.sh" "$d" > /dev/null; then gut "L mit eingetragenem Diagramm besteht pruefe-repo.sh"
  else schlecht "L mit Diagramm scheitert weiter"; fi
else
  schlecht "L/ja ohne docs/ARCHITEKTUR.md erzeugt"
fi

# _skip_if_exists: eine vorhandene .gitignore gehört dem Repo. Damit die Probe nicht grün
# bleibt, weil copier gar nichts schrieb, muss dieselbe Kopie AGENTS.md erneuern.
d="$WURZEL/vorhanden"
mkdir -p "$d"
printf 'eigene-regel\n' > "$d/.gitignore"
printf 'alt\n' > "$d/AGENTS.md"
if erzeuge "$d" M nein --overwrite && [ "$(cat "$d/.gitignore")" = eigene-regel ] \
   && grep -qx 'Profil: M' "$d/AGENTS.md"
then gut "vorhandene .gitignore bleibt, AGENTS.md wird erneuert"
else schlecht "vorhandene .gitignore überschrieben oder copier schrieb nichts"; fi

echo "PASS=$PASS FAIL=$FAIL"
# Untergrenze: 8 Repos × 4 Proben + Diagramm-Gegenprobe + vorhandene .gitignore.
[ "$((PASS + FAIL))" -ge 34 ] || { echo "FEHLER: nur $((PASS + FAIL)) Fälle gelaufen, erwartet 34"; exit 1; }
[ "$FAIL" -eq 0 ]
