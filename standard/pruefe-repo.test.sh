#!/usr/bin/env bash
# Selbsttest für pruefe-repo.sh.
#
# Jeder Fehlerfall baut ein gültiges Repo und verletzt genau EINE Regel. Bestanden ist er
# nur, wenn pruefe-repo.sh mit Exit 1 endet und genau eine FEHLER-Zeile meldet, die die
# Kennung dieser Regel trägt. Ein Fall, der an einer anderen Regel scheitert, zählt als
# Fehlschlag: sonst bliebe der Test grün, obwohl die geschützte Regel nichts mehr prüft.
set -uo pipefail

PRUEFE="$(cd "$(dirname "$0")" && pwd)/pruefe-repo.sh"
WURZEL=$(mktemp -d)
trap 'rm -rf "$WURZEL"' EXIT
PASS=0
FAIL=0
FENCE='```'

repo() {  # repo <Name> <Profil> → legt ein vollständiges, gültiges Repo an, gibt den Pfad aus
  local d="$WURZEL/$1" p="$2"
  mkdir -p "$d"
  git -C "$d" init -q
  printf '# beispiel-werkzeug\n' > "$d/README.md"
  printf '# beispiel-werkzeug\n\nProfil: %s\n' "$p" > "$d/AGENTS.md"
  printf '@AGENTS.md\n' > "$d/CLAUDE.md"
  if [ "$p" = M ] || [ "$p" = L ]; then
    git -C "$d" remote add origin https://example.invalid/beispiel.git
    mkdir -p "$d/docs/decisions"
    printf '# Index\n' > "$d/docs/INDEX.md"
  fi
  if [ "$p" = L ]; then
    printf '# Architektur\n\n%smermaid\nflowchart LR\n  A --> B\n%s\n' "$FENCE" "$FENCE" > "$d/docs/ARCHITEKTUR.md"
    printf '# Runbook\n' > "$d/docs/RUNBOOK.md"
    printf '# Changelog\n' > "$d/CHANGELOG.md"
  fi
  echo "$d"
}

zeilen() { local i; for ((i = 0; i < $1; i++)); do echo "Zeile $i"; done; }

erwarte_fehler() {  # erwarte_fehler <Regel> <Repo> [Optionen für pruefe-repo.sh]
  local regel="$1" d="$2" out rc treffer alle
  shift 2
  out=$(bash "$PRUEFE" "$@" "$d" 2>&1); rc=$?
  treffer=$(grep -c "^FEHLER  $regel:" <<<"$out")
  alle=$(grep -c '^FEHLER' <<<"$out")
  if [ "$rc" -eq 1 ] && [ "$treffer" -eq 1 ] && [ "$alle" -eq 1 ]; then
    echo "  ok   $regel"; PASS=$((PASS+1))
  else
    echo "  FAIL $regel: Exit $rc, $treffer Treffer, $alle FEHLER insgesamt"; echo "       ${out//$'\n'/$'\n'       }"
    FAIL=$((FAIL+1))
  fi
}

erwarte_gruen() {  # erwarte_gruen <Name> <Repo> [Hinweis-Kennung]
  local name="$1" d="$2" hinweis="${3:-}" out rc
  out=$(bash "$PRUEFE" "$d" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^FEHLER' <<<"$out" \
     && { [ -z "$hinweis" ] || grep -q "^HINWEIS $hinweis:" <<<"$out"; }; then
    echo "  ok   $name"; PASS=$((PASS+1))
  else
    echo "  FAIL $name: Exit $rc"; echo "       ${out//$'\n'/$'\n'       }"
    FAIL=$((FAIL+1))
  fi
}

echo "Gültige Repos je Profil"
for p in S M L W; do erwarte_gruen "Profil $p vollständig" "$(repo "gruen-$p" "$p")"; done

echo "Je Regel eine Verletzung"
d=$(repo readme S);     rm "$d/README.md";                          erwarte_fehler R-README "$d"
d=$(repo agents S);     rm "$d/AGENTS.md";                          erwarte_fehler R-AGENTS "$d" --profil S
d=$(repo claude S);     rm "$d/CLAUDE.md";                          erwarte_fehler R-CLAUDE "$d"
d=$(repo import S);     printf '# Claude\n@AGENTS.md\n' > "$d/CLAUDE.md"; erwarte_fehler R-CLAUDE-IMPORT "$d"
d=$(repo profil S);     printf '# ohne Profil\n' > "$d/AGENTS.md";  erwarte_fehler R-PROFIL "$d"
d=$(repo profilx S);                                                erwarte_fehler R-PROFIL "$d" --profil X
d=$(repo groesse-s S);  zeilen 61 >> "$d/AGENTS.md";                erwarte_fehler R-AGENTS-GROESSE "$d"
d=$(repo groesse-m M);  zeilen 151 >> "$d/AGENTS.md";               erwarte_fehler R-AGENTS-GROESSE "$d"
d=$(repo index M);      rm "$d/docs/INDEX.md";                      erwarte_fehler R-INDEX "$d"
d=$(repo index-gr M);   zeilen 40 >> "$d/docs/INDEX.md";            erwarte_fehler R-INDEX-GROESSE "$d"
d=$(repo decisions M);  rmdir "$d/docs/decisions";                  erwarte_fehler R-DECISIONS "$d"
d=$(repo betrieb M);    printf 'Betrieb: geplant\n' >> "$d/AGENTS.md"; erwarte_fehler R-BETRIEB "$d"
d=$(repo remote M);     git -C "$d" remote remove origin;           erwarte_fehler R-REMOTE "$d"
d=$(repo arch L);       rm "$d/docs/ARCHITEKTUR.md";                erwarte_fehler R-ARCHITEKTUR "$d"
d=$(repo mermaid L);    printf '# Architektur\n' > "$d/docs/ARCHITEKTUR.md"; erwarte_fehler R-MERMAID "$d"
d=$(repo runbook L);    rm "$d/docs/RUNBOOK.md";                    erwarte_fehler R-RUNBOOK "$d"
d=$(repo changelog L);  rm "$d/CHANGELOG.md";                       erwarte_fehler R-CHANGELOG "$d"

echo "Grenzen und Hinweise"
d=$(repo grenze-s S);   zeilen 57 >> "$d/AGENTS.md";                erwarte_gruen "AGENTS.md mit genau 60 Zeilen" "$d"
d=$(repo betrieb-ok M); printf 'Betrieb: geplant\n' >> "$d/AGENTS.md"; printf '# Betrieb\n' > "$d/docs/BETRIEB.md"
erwarte_gruen "Betrieb geplant, BETRIEB.md vorhanden" "$d"
d=$(repo env M);        printf 'import os\nos.environ["TOKEN"]\n' > "$d/app.py"
erwarte_gruen "Umgebungsvariable ohne .env.example nur Hinweis" "$d" H-ENV-EXAMPLE
d=$(repo w-ohne W);                                                 erwarte_gruen "Profil W braucht kein docs/" "$d"

echo "Fixtures für den Workflow-Selbsttest"
FIXTURES="$(dirname "$(dirname "$PRUEFE")")/tests/fixtures"
for p in S M L W; do erwarte_gruen "Fixture profil-$p" "$FIXTURES/profil-$p"; done

echo "PASS=$PASS FAIL=$FAIL"
# Untergrenze: 4 Profile + 17 Regelfälle + 4 Grenzfälle + 4 Fixtures. Fällt ein Block still aus,
# sinkt die Summe und der Test wird rot, statt mit weniger Fällen grün zu bleiben.
[ "$((PASS + FAIL))" -ge 29 ] || { echo "FEHLER: nur $((PASS + FAIL)) Fälle gelaufen, erwartet 29"; exit 1; }
[ "$FAIL" -eq 0 ]
