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
  printf '.env*\n!.env.example\n' > "$d/.gitignore"
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
auf_zeilen() {  # auf_zeilen <Datei> <Anzahl>: füllt die Datei auf genau so viele Zeilen auf
  local n
  n=$(wc -l < "$1")
  zeilen $(( $2 - n )) >> "$1"
}

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

# Datei genau auf die Grenze auffüllen: grün, und die ok-Zeile nennt Zeilenzahl und Grenze.
# Mit dem Regelfall „Grenze + 1“ zusammen ist die Grenze von beiden Seiten festgehalten.
erwarte_grenze() {  # erwarte_grenze <Regel> <Repo> <Datei relativ zum Repo> <Grenze>
  local regel="$1" d="$2" datei="$3" n="$4" out rc
  auf_zeilen "$d/$datei" "$n"
  out=$(bash "$PRUEFE" "$d" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && grep -qx "ok      $regel: $datei hat $n Zeilen (Grenze $n)" <<<"$out"; then
    echo "  ok   $datei mit genau $n Zeilen"; PASS=$((PASS+1))
  else
    echo "  FAIL $datei mit genau $n Zeilen: Exit $rc"; echo "       ${out//$'\n'/$'\n'       }"
    FAIL=$((FAIL+1))
  fi
}

echo "Gültige Repos je Profil"
for p in S M L W; do erwarte_gruen "Profil $p vollständig" "$(repo "gruen-$p" "$p")"; done

echo "Je Regel eine Verletzung"
erwarte_fehler R-REPO "$WURZEL/gibt-es-nicht"
d=$(repo readme S);     rm "$d/README.md";                          erwarte_fehler R-README "$d"
d=$(repo agents S);     rm "$d/AGENTS.md";                          erwarte_fehler R-AGENTS "$d" --profil S
d=$(repo claude S);     rm "$d/CLAUDE.md";                          erwarte_fehler R-CLAUDE "$d"
d=$(repo import S);     printf '# Claude\n@AGENTS.md\n' > "$d/CLAUDE.md"; erwarte_fehler R-CLAUDE-IMPORT "$d"
d=$(repo profil S);     printf '# ohne Profil\n' > "$d/AGENTS.md";  erwarte_fehler R-PROFIL "$d"
d=$(repo profilx S);                                                erwarte_fehler R-PROFIL "$d" --profil X
d=$(repo groesse-s S);  auf_zeilen "$d/AGENTS.md" 61;               erwarte_fehler R-AGENTS-GROESSE "$d"
d=$(repo groesse-w W);  auf_zeilen "$d/AGENTS.md" 61;               erwarte_fehler R-AGENTS-GROESSE "$d"
d=$(repo groesse-m M);  auf_zeilen "$d/AGENTS.md" 151;              erwarte_fehler R-AGENTS-GROESSE "$d"
d=$(repo groesse-l L);  auf_zeilen "$d/AGENTS.md" 151;              erwarte_fehler R-AGENTS-GROESSE "$d"
d=$(repo index M);      rm "$d/docs/INDEX.md";                      erwarte_fehler R-INDEX "$d"
d=$(repo index-gr M);   auf_zeilen "$d/docs/INDEX.md" 41;           erwarte_fehler R-INDEX-GROESSE "$d"
d=$(repo decisions M);  rmdir "$d/docs/decisions";                  erwarte_fehler R-DECISIONS "$d"
d=$(repo betrieb M);    printf 'Betrieb: geplant\n' >> "$d/AGENTS.md"; erwarte_fehler R-BETRIEB "$d"
d=$(repo remote M);     git -C "$d" remote remove origin;           erwarte_fehler R-REMOTE "$d"
d=$(repo arch L);       rm "$d/docs/ARCHITEKTUR.md";                erwarte_fehler R-ARCHITEKTUR "$d"
d=$(repo mermaid L);    printf '# Architektur\n' > "$d/docs/ARCHITEKTUR.md"; erwarte_fehler R-MERMAID "$d"
d=$(repo runbook L);    rm "$d/docs/RUNBOOK.md";                    erwarte_fehler R-RUNBOOK "$d"
d=$(repo changelog L);  rm "$d/CHANGELOG.md";                       erwarte_fehler R-CHANGELOG "$d"
d=$(repo ignore S);     rm "$d/.gitignore";                         erwarte_fehler R-ENV-IGNORE "$d"
d=$(repo ignore-ein S); : > "$d/.env"; git -C "$d" add -f -- .env;  erwarte_fehler R-ENV-IGNORE "$d"
d=$(repo ignore-git S); rm -rf "$d/.git";                           erwarte_fehler R-ENV-IGNORE "$d"
# Eine globale Regel des Rechners zählt nicht: sie fehlt auf jedem anderen Rechner und im CI.
d=$(repo ignore-gl S);  rm "$d/.gitignore"
printf '.env*\n' > "$WURZEL/global-ignore"
printf '[core]\n\texcludesFile = %s\n' "$WURZEL/global-ignore" > "$WURZEL/global-config"
export GIT_CONFIG_GLOBAL="$WURZEL/global-config"
erwarte_fehler R-ENV-IGNORE "$d"
unset GIT_CONFIG_GLOBAL

echo "Grenzen und Hinweise"
erwarte_grenze R-AGENTS-GROESSE "$(repo grenze-s S)" AGENTS.md 60
erwarte_grenze R-AGENTS-GROESSE "$(repo grenze-w W)" AGENTS.md 60
erwarte_grenze R-AGENTS-GROESSE "$(repo grenze-m M)" AGENTS.md 150
erwarte_grenze R-AGENTS-GROESSE "$(repo grenze-l L)" AGENTS.md 150
erwarte_grenze R-INDEX-GROESSE "$(repo grenze-i M)" docs/INDEX.md 40
d=$(repo betrieb-ok M); printf 'Betrieb: geplant\n' >> "$d/AGENTS.md"; printf '# Betrieb\n' > "$d/docs/BETRIEB.md"
erwarte_gruen "Betrieb geplant, BETRIEB.md vorhanden" "$d"
d=$(repo env M);        printf 'import os\nos.environ["TOKEN"]\n' > "$d/app.py"
erwarte_gruen "Umgebungsvariable ohne .env.example nur Hinweis" "$d" H-ENV-EXAMPLE
d=$(repo w-ohne W);                                                 erwarte_gruen "Profil W braucht kein docs/" "$d"

echo "Fixtures für den Workflow-Selbsttest"
FIXTURES="$(dirname "$(dirname "$PRUEFE")")/tests/fixtures"
for p in S M L W; do erwarte_gruen "Fixture profil-$p" "$FIXTURES/profil-$p"; done

echo "PASS=$PASS FAIL=$FAIL"
# Untergrenze: 4 Profile + 24 Regelfälle + 8 Grenzfälle und Hinweise + 4 Fixtures. Fällt ein Block still aus,
# sinkt die Summe und der Test wird rot, statt mit weniger Fällen grün zu bleiben.
[ "$((PASS + FAIL))" -ge 40 ] || { echo "FEHLER: nur $((PASS + FAIL)) Fälle gelaufen, erwartet 40"; exit 1; }
[ "$FAIL" -eq 0 ]
