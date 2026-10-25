#!/usr/bin/env bash
# Vertragstest für .github/workflows/doc-standard.yml: was nur im YAML steht, hier mit Probe.
#
# Der Wächter gegen `.doc-standard` aus dem PR kann kein Skript des Standards sein, denn er läuft,
# bevor der Standard ausgecheckt ist. Dasselbe gilt für die Bedingungen der Prüfschritte. Dieser
# Test liest die Schritte aus dem YAML, führt Wächter und Verschiebeschritt in Testverzeichnissen
# aus und prüft die Bedingungen als Text. Geprüft wird, dass
# - der Wächter vor dem Checkout des Standards steht und Datei, Verzeichnis und Symlink abweist,
# - der Standard gleich danach den geprüften Baum verlässt und kein späterer Schritt ihn dort sucht,
# - jeder Prüfschritt auch nach einem roten Schritt läuft (`!cancelled()`), Lint und Links nur bei
#   offenem Tor, und die Zusammenfassung immer,
# - der Drift-Hinweis Fork-PRs auslässt und jede Action auf einen Commit gepinnt ist.
#
# Gelesen wird ohne YAML-Bibliothek (nicht auf jedem Runner da), nach Einrückung. Findet der
# Extraktor einen erwarteten Schritt nicht, wird das als FEHLT gezählt, nicht übergangen.
# Gegenproben stehen in .github/workflows/selbsttest.yml.
set -uo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW="${WORKFLOW:-$HIER/../.github/workflows/doc-standard.yml}"
MIN_PROBEN=39
[ -f "$WORKFLOW" ] || { echo "NICHT GEPRÜFT: Workflow fehlt ($WORKFLOW)."; exit 2; }

PASS=0
FAIL=0
pruefe() {  # pruefe <bezeichnung> <soll> <ist>
  if [ "$2" = "$3" ]; then echo "ok    $1"; PASS=$((PASS + 1))
  else echo "FEHLT $1 (soll: $2, ist: $3)"; FAIL=$((FAIL + 1)); fi
}

WEG=$(mktemp -d)
trap 'rm -rf "$WEG"' EXIT

# feld <job> <schritt> <feld>: Wert eines Felds (if, run, uses, id, name, env.NAME) eines Schritts.
# <schritt> ist die id, der name oder `#N` (N-ter Schritt, ab 0). `#anzahl` gibt die Zahl der
# Schritte aus, `job-if` das if des Jobs.
feld() {
  python3 - "$WORKFLOW" "$@" <<'PY'
import sys, re
pfad, job, schritt, feld = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
zeilen = open(pfad, encoding='utf-8').read().split('\n')
# Job-Block: Zeile "  <job>:" bis zur nächsten Zeile mit Einrückung 2 (oder 0).
try:
    a = zeilen.index('  ' + job + ':')
except ValueError:
    sys.exit(3)
e = next((i for i in range(a + 1, len(zeilen)) if re.match(r'^ {0,2}\S', zeilen[i])), len(zeilen))
block = zeilen[a + 1:e]
if schritt == 'job-if':
    m = next((re.match(r'^    if: (.*)$', z) for z in block if re.match(r'^    if: ', z)), None)
    print(m.group(1) if m else ''); sys.exit(0)
# Schritte: "      - " auf Einrückung 6.
starts = [i for i, z in enumerate(block) if z.startswith('      - ')]
schritte = []
for n, s in enumerate(starts):
    ende = starts[n + 1] if n + 1 < len(starts) else len(block)
    teil = [block[s].replace('      - ', '        ', 1)] + block[s + 1:ende]
    werte, i = {}, 0
    while i < len(teil):
        m = re.match(r'^        (\w[\w-]*): ?(.*)$', teil[i])
        if m:
            k, v = m.group(1), m.group(2)
            if v == '' and k == 'env':
                i += 1
                while i < len(teil) and (m2 := re.match(r'^          (\w+): (.*)$', teil[i])):
                    werte['env.' + m2.group(1)] = m2.group(2); i += 1
                continue
            if v in ('|', '>'):
                rumpf = []
                i += 1
                while i < len(teil) and (teil[i].startswith('          ') or teil[i].strip() == ''):
                    rumpf.append(teil[i][10:]); i += 1
                werte[k] = '\n'.join(rumpf).rstrip('\n'); continue
            werte[k] = v
        i += 1
    schritte.append(werte)
if schritt == '#anzahl':
    print(len(schritte)); sys.exit(0)
if schritt.startswith('#'):
    treffer = [schritte[int(schritt[1:])]] if int(schritt[1:]) < len(schritte) else []
else:
    treffer = [s for s in schritte if s.get('id') == schritt or s.get('name') == schritt]
if len(treffer) != 1:
    sys.exit(3)
print(treffer[0].get(feld, ''))
PY
}
# index <job> <schritt>: Position des Schritts (id oder name), -1 wenn nicht eindeutig.
index() {
  local n i
  n=$(feld "$1" '#anzahl' x 2>/dev/null)
  for ((i = 0; i < ${n:-0}; i++)); do
    if [ "$(feld "$1" "#$i" id)" = "$2" ] || [ "$(feld "$1" "#$i" name)" = "$2" ]; then echo "$i"; return; fi
  done
  echo -1
}

WAECHTER='Kein .doc-standard im geprüften Repo'

# 1) Aufbau: genau ein Prüfjob mit genau einem Checkout des Standards.
pruefe "genau ein Checkout des Standards" 1 "$(grep -c 'path: \.doc-standard$' "$WORKFLOW")"
pruefe "Prüfjob 'pruefen' hat Schritte" ja "$([ "$(feld pruefen '#anzahl' x)" -gt 5 ] 2>/dev/null && echo ja || echo nein)"
pruefe "Wächter genau einmal" 1 "$(grep -c "name: $WAECHTER" "$WORKFLOW")"

# 2) Reihenfolge: Checkout Repo → Wächter → Checkout Standard → Verschieben → Tor.
W=$(index pruefen "$WAECHTER")
pruefe "Wächter ist Schritt 1 (gleich nach dem Checkout des Repos)" 1 "$W"
pruefe "danach der Checkout des Standards" ja "$(case "$(feld pruefen "#$((W + 1))" uses)" in actions/checkout@*) echo ja ;; *) echo nein ;; esac)"
pruefe "danach das Verschieben" "$((W + 2))" "$(index pruefen standard)"
pruefe "danach das Tor" "$((W + 3))" "$(index pruefen aenderungen)"

# 3) Wächter in Testverzeichnissen ausführen.
feld pruefen "$WAECHTER" run > "$WEG/waechter.sh"
waechter() {  # waechter <vorbereitung>: rc des Wächters in einem frischen Verzeichnis
  local d rc=0; d=$(mktemp -d "$WEG/w.XXXX")
  (cd "$d" && eval "$1" && bash "$WEG/waechter.sh") > /dev/null 2>&1 || rc=$?
  echo "$rc"
}
pruefe "Wächter: sauberes Repo → rc 0" 0 "$(waechter ':')"
pruefe "Wächter: Verzeichnis .doc-standard → rot" 1 "$(waechter 'mkdir .doc-standard')"
pruefe "Wächter: Datei .doc-standard → rot" 1 "$(waechter 'touch .doc-standard')"
pruefe "Wächter: Symlink nach außen → rot" 1 "$(waechter 'ln -s /tmp .doc-standard')"
pruefe "Wächter: Symlink ins Leere → rot" 1 "$(waechter 'ln -s /gibt-es-nicht .doc-standard')"

# 4) Verschieben ausführen: danach ist der Standard aus dem Baum, STANDARD zeigt auf $RUNNER_TEMP.
feld pruefen standard run > "$WEG/standard.sh"
d="$WEG/v1"; mkdir -p "$d/ws/.doc-standard/standard" "$d/tmp"
: > "$d/env"
(cd "$d/ws" && RUNNER_TEMP="$d/tmp" GITHUB_ENV="$d/env" bash "$WEG/standard.sh") > /dev/null 2>&1; rc=$?
pruefe "Verschieben: rc 0" 0 "$rc"
pruefe "Verschieben: .doc-standard nicht mehr im Baum" nein "$([ -e "$d/ws/.doc-standard" ] && echo ja || echo nein)"
pruefe "Verschieben: unter RUNNER_TEMP" ja "$([ -d "$d/tmp/standard/standard" ] && echo ja || echo nein)"
pruefe "Verschieben: STANDARD gesetzt" "STANDARD=$d/tmp/standard" "$(cat "$d/env")"
d="$WEG/v2"; mkdir -p "$d/ws/.doc-standard" "$d/tmp/standard"; : > "$d/env"
(cd "$d/ws" && RUNNER_TEMP="$d/tmp" GITHUB_ENV="$d/env" bash "$WEG/standard.sh") > /dev/null 2>&1; rc=$?
pruefe "Verschieben: vorhandenes Ziel → rot statt verschachtelt" 1 "$rc"

# 5) Kein späterer Schritt liest den Standard aus dem Baum.
S=$(index pruefen standard)
spaeter=0
for ((i = S + 1; i < $(feld pruefen '#anzahl' x); i++)); do
  feld pruefen "#$i" run | grep -q '\.doc-standard' && spaeter=$((spaeter + 1))
done
pruefe "nach dem Verschieben kein .doc-standard mehr" 0 "$spaeter"

# 6) Bedingungen der Prüfschritte, exakt: eine Teilstring-Suche ließe `success() && !cancelled()` durch.
# shellcheck disable=SC2016  # Ausdrücke von GitHub, nicht von der Shell
TOR_OFFEN='${{ !cancelled() && steps.aenderungen.outcome == '"'success'"' && steps.aenderungen.outputs.md == '"'true'"' }}'
# shellcheck disable=SC2016
pruefe "repo läuft auch nach einem roten Schritt" '${{ !cancelled() && steps.standard.outcome == '"'success'"' }}' "$(feld pruefen repo if)"
pruefe "lint: auch nach rotem Schritt, nur bei offenem Tor" "$TOR_OFFEN" "$(feld pruefen lint if)"
pruefe "links: auch nach rotem Schritt, nur bei offenem Tor" "$TOR_OFFEN" "$(feld pruefen links if)"
# shellcheck disable=SC2016
pruefe "secrets: auch nach rotem Schritt, mit ausgewertetem Tor" '${{ !cancelled() && steps.aenderungen.outcome == '"'success'"' }}' "$(feld pruefen secrets if)"
# shellcheck disable=SC2016
pruefe "Zusammenfassung immer" '${{ always() }}' "$(feld pruefen Zusammenfassung if)"

# 6b) Was die Schritte bekommen: Basis des PR (nicht sein Kopf), Basis aus dem Tor, Ausnahmen.
# shellcheck disable=SC2016
pruefe "Tor: Basis des PR" '${{ github.event.pull_request.base.sha }}' "$(feld pruefen aenderungen env.PR_BASIS)"
# shellcheck disable=SC2016
pruefe "Tor: sonst before des Pushs" '${{ github.event.before }}' "$(feld pruefen aenderungen env.VORHER)"
# shellcheck disable=SC2016
pruefe "Tor: PR-Basis vor before" 1 "$(feld pruefen aenderungen run | grep -cF '"${PR_BASIS:-$VORHER}"')"
for id in lint links secrets; do
  # shellcheck disable=SC2016
  pruefe "$id: Basis aus dem Tor" '${{ steps.aenderungen.outputs.basis }}' "$(feld pruefen "$id" env.BASIS)"
done
# shellcheck disable=SC2016
pruefe "lint: lint-ignores durchgereicht" '${{ inputs.lint-ignores }}' "$(feld pruefen lint env.LINT_AUSNAHMEN)"

# 6c) Zusammenfassung ausführen: jedes Ergebnis landet in seiner Zeile, rot bleibt rot.
feld pruefen Zusammenfassung run > "$WEG/zusammenfassung.sh"
zusammenfassung() {  # zusammenfassung VORBEREITUNG TOR MD REPO LINT LINKS SECRETS → Tabelle nach $WEG/summary
  : > "$WEG/summary"
  VORBEREITUNG="$1" TOR="$2" MD="$3" REPO="$4" LINT="$5" LINKS="$6" SECRETS="$7" \
    GITHUB_STEP_SUMMARY="$WEG/summary" bash "$WEG/zusammenfassung.sh" > /dev/null 2>&1
}
zeile() { grep -cxF "| $1 | $2 |" "$WEG/summary"; }
zusammenfassung success success true failure failure failure success
pruefe "Zusammenfassung: Struktur rot" 1 "$(zeile 'Struktur (pruefe-repo.sh)' '**rot**')"
pruefe "Zusammenfassung: Lint und Links beide rot" 2 "$(($(zeile 'Markdown-Lint' '**rot**') + $(zeile 'Interne Links' '**rot**')))"
pruefe "Zusammenfassung: Secrets grün" 1 "$(zeile 'Secrets im Diff' 'grün')"
zusammenfassung success success false success skipped skipped success
pruefe "Zusammenfassung: Tor zu → keine Markdown-Änderung" 2 "$(grep -c '| keine Markdown-Änderung |$' "$WEG/summary")"
zusammenfassung success failure '' success skipped skipped skipped
pruefe "Zusammenfassung: Tor gescheitert → nicht geprüft" 1 "$(zeile 'Tor (geänderte Markdown-Dateien)' '**nicht geprüft** (Dateiliste nicht lesbar)')"
pruefe "Zusammenfassung: danach nicht gelaufen statt grün" 3 "$(grep -c '| nicht gelaufen |$' "$WEG/summary")"
zusammenfassung skipped skipped '' skipped skipped skipped skipped
pruefe "Zusammenfassung: Vorbereitung gescheitert sichtbar" 1 "$(zeile 'Vorbereitung (Wächter, Standard)' 'nicht gelaufen')"

# 7) Drift nur für PRs aus demselben Repo; alle Actions auf einen Commit gepinnt.
pruefe "Drift lässt Fork-PRs aus" 1 "$(feld drift-hinweis job-if x | grep -c 'github.event.pull_request.head.repo.full_name == github.repository')"
pruefe "jede Action auf einen Commit gepinnt" 0 "$(grep -E '^\s*-? *uses: ' "$WORKFLOW" | grep -cvE '@[0-9a-f]{40}( |$)')"

echo "PASS=$PASS FAIL=$FAIL"
if [ $((PASS + FAIL)) -lt "$MIN_PROBEN" ]; then
  echo "NICHT GEPRÜFT: nur $((PASS + FAIL)) von mindestens $MIN_PROBEN Proben liefen."
  exit 2
fi
[ "$FAIL" -eq 0 ]
