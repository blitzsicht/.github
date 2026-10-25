#!/usr/bin/env bash
# basis-vergleich.sh — Lint oder Linkprüfung der geänderten Markdown-Dateien mit Ratchet.
#
#   basis-vergleich.sh lint  BASIS PFAD    # REGELSATZ=…, MARKDOWNLINT=… wie markdown-lint.sh
#   basis-vergleich.sh links BASIS PFAD    # LYCHEE=… wie links-pruefen.sh
#
# Ein Repo mit Altlasten soll den Standard einführen können, ohne vorher jede alte Datei zu
# bereinigen. Deshalb gilt:
# - Neue Dateien (auch Kopien und Umbenennungen aus Nicht-Markdown) werden streng geprüft:
#   jeder Befund ist ein FEHLER.
# - Geänderte Dateien werden an BASIS und HEAD gezählt. Mehr Befunde als vorher sind ein
#   FEHLER, gleich viele oder weniger nur ein HINWEIS. Bei Umbenennungen zählt der alte Pfad.
# - Ohne BASIS (erster Push, unbekannte Basis) gibt es nichts zu vergleichen: alles streng.
#
# Neue Dateien laufen gemeinsam in einem Lauf, geänderte je Datei einzeln, damit sich ihre
# Befunde zählen lassen. Für die Linkprüfung liegt die Basis als ganzer Baum vor (git archive),
# damit relative Links gegen den damaligen Stand aufgelöst werden.
#
# Dateinamen kommen aus `git diff -z` und gehen nur zeilenweise in Listen, nie in eine
# Shell-Zeile (siehe md-dateien.sh). Namen mit Zeilenumbruch oder Tab lassen sich so nicht
# prüfen: sie werden gemeldet, und der Lauf endet mit NICHT GEPRÜFT.
#
# Exit 0: nichts verschlechtert · 1: mindestens ein FEHLER · 2: NICHT GEPRÜFT (Werkzeug fehlt
# oder brach ab oder übersprang Eingaben, git diff scheiterte, ein Name mit Zeilenumbruch oder
# Tab ließ sich nicht prüfen, bash älter als 4.3).
# Symlinks und Typänderungen gelten als FEHLER bzw. als neue Datei.
set -uo pipefail

# Ab bash 4.3 getestet; macOS bringt 3.2 mit. Lieber NICHT GEPRÜFT als still andere Semantik.
if [ "${BASH_VERSINFO[0]}" -lt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 3 ]; }; then
  echo "NICHT GEPRÜFT: bash ${BASH_VERSION} ist zu alt (mindestens 4.3)."; exit 2
fi

HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODUS="${1:?Modus fehlt (lint oder links)}"
BASIS="${2-}"
PFAD="${3:-.}"

case "$MODUS" in
  lint)  : "${REGELSATZ:?REGELSATZ fehlt}"
         case "$REGELSATZ" in /*) ;; *) REGELSATZ="$PWD/$REGELSATZ" ;; esac ;;
  links) ;;
  *) echo "Unbekannter Modus: $MODUS" >&2; exit 2 ;;
esac

WURZEL="$PWD"
WEG=$(mktemp -d)
trap 'rm -rf "$WEG"' EXIT

# lauf <baum> <liste>: Zahl der Befunde in den gelisteten Dateien, geprüft im Baum <baum>.
# Rückgabe 2, wenn das Werkzeug keinen auswertbaren Lauf geliefert hat.
#
# Die Zahl kommt aus der Zusammenfassung des Werkzeugs. Dateinamen stehen in derselben Ausgabe
# und gehören dem geprüften Repo: eine Datei `🚫 0 Error.md` täuschte sonst „0 Fehler“ vor.
# Darum ist die Zeile am Anfang verankert, und der Exit-Code muss zur Zahl passen
# (0 ⇔ keine Befunde). Passt beides nicht zusammen, gilt der Lauf als NICHT GEPRÜFT.
lauf() {
  local baum="$1" liste="$2" out="$WEG/out" rc n ohne mit
  if [ "$MODUS" = lint ]; then
    (cd "$baum" && bash "$HIER/markdown-lint.sh" "$liste" "$REGELSATZ") > "$out" 2>&1; rc=$?
    # markdownlint-cli2 druckt die Zusammenfassung vor den Befunden: die erste Zeile zählt.
    n=$(sed -nE 's/^Summary: ([0-9]+) issues? in [0-9]+ files?$/\1/p' "$out" | head -n 1)
    ohne=0; mit=1
  else
    (cd "$baum" && bash "$HIER/links-pruefen.sh" "$liste") > "$out" 2>&1; rc=$?
    # lychee druckt die Zusammenfassung nach den Befunden: die letzte Zeile zählt. Hinter den
    # Fehlern können weitere Zähler folgen („👻 9 Excluded“).
    n=$(sed -nE 's/^🔍 [0-9]+ Total .* 🚫 ([0-9]+) Errors?( .*)?$/\1/p' "$out" | tail -n 1)
    ohne=0; mit=2
    # lychee überspringt manche Eingaben nur mit Warnung (ungültiges UTF-8, nicht gefunden) und
    # zählt sie dann nicht: „0 Errors“ hieße hier nur „nicht gelesen“.
    if grep -qE '^[[:space:]]*\[WARN\]' "$out"; then
      { echo "lychee hat Eingaben übersprungen:"; cat "$out"; } >&2
      return 2
    fi
  fi
  if [ -n "$n" ] && { { [ "$rc" -eq "$ohne" ] && [ "$n" -eq 0 ]; } || { [ "$rc" -eq "$mit" ] && [ "$n" -gt 0 ]; }; }; then
    echo "$n"
  else
    { echo "Werkzeug-Ausgabe nicht auswertbar (rc=$rc, Zahl='${n}'):"; cat "$out"; } >&2
    return 2
  fi
}

# befunde <baum> <name>: wie lauf, für genau eine Datei.
befunde() {
  printf '%s\n' "$2" > "$WEG/eine"
  lauf "$1" "$WEG/eine"
}

zeige() { sed 's/^/        /' "$WEG/out"; }

FEHLER=0
HINWEISE=0
UNGEPRUEFT=0
streng=()     # neue Dateien
paare=()      # "alt<TAB>neu" für geänderte Dateien

# Erst in eine Datei, dann lesen: aus `< <(…)` käme ein Abbruch von git nie an, die Listen
# blieben leer und der Lauf meldete „keine Änderungen“, also grün.
if [ -z "$BASIS" ]; then
  bash "$HIER/md-dateien.sh" "" "$PFAD" > "$WEG/alle" 2> "$WEG/alle.err" \
    || { cat "$WEG/alle.err" >&2; echo "NICHT GEPRÜFT: Dateiliste nicht lesbar"; exit 2; }
  if [ -s "$WEG/alle.err" ]; then cat "$WEG/alle.err" >&2; UNGEPRUEFT=$((UNGEPRUEFT + 1)); fi
  while IFS= read -r name; do streng+=("$name"); done < "$WEG/alle"
else
  git -c core.quotePath=false diff -z --name-status -M --diff-filter=ACMRT "$BASIS" HEAD -- "$PFAD" > "$WEG/diff" \
    || { echo "NICHT GEPRÜFT: git diff gegen $BASIS gescheitert"; exit 2; }
  # Datensätze aus -z: Status, Pfad (bei R/C: alter Pfad, neuer Pfad).
  while IFS= read -r -d '' status; do
    IFS= read -r -d '' a || break
    b=""
    case "$status" in R*|C*) IFS= read -r -d '' b || break ;; esac
    # Zeilenumbruch passt in keine Zeilenliste, Tab nicht in die Paare „alt<TAB>neu“.
    for n in "$a" "$b"; do
      case "$n" in *$'\n'*|*$'\t'*)
        printf 'NICHT GEPRÜFT (Zeilenumbruch oder Tab im Namen): %q\n' "$n"; UNGEPRUEFT=$((UNGEPRUEFT + 1)); continue 2 ;;
      esac
    done
    case "$status" in
      A*)   [[ "$a" == *.md ]] && streng+=("$a") ;;
      M*)   [[ "$a" == *.md ]] && paare+=("$a"$'\t'"$a") ;;
      # Typänderung (Symlink ↔ Datei): der Basisinhalt eines Symlinks ist nur sein Ziel.
      T*)   [[ "$a" == *.md ]] && streng+=("$a") ;;
      R*)   [[ "$b" == *.md ]] || continue
            if [[ "$a" == *.md ]]; then paare+=("$a"$'\t'"$b"); else streng+=("$b"); fi ;;
      C*)   [[ "$b" == *.md ]] && streng+=("$b") ;;
    esac
  done < "$WEG/diff"
fi

# Symlinks nie lesen: cp und lychee folgten ihnen zu beliebigen Dateien des Runners, deren
# Inhalt dann in Befundzeilen im Log stünde. Eine verlinkte .md ist deshalb selbst ein FEHLER.
ist_link() {  # ist_link <eintrag>: meldet einen Symlink auf der HEAD-Seite als FEHLER
  local pfad="${1#*$'\t'}"
  [ -L "$WURZEL/$pfad" ] || return 1
  echo "FEHLER  $pfad: Symlink, wird nicht gelesen"; FEHLER=$((FEHLER + 1))
}
behalten=()
for eintrag in ${streng[@]+"${streng[@]}"}; do ist_link "$eintrag" || behalten+=("$eintrag"); done
streng=(${behalten[@]+"${behalten[@]}"})
behalten=()
for eintrag in ${paare[@]+"${paare[@]}"}; do ist_link "$eintrag" || behalten+=("$eintrag"); done
paare=(${behalten[@]+"${behalten[@]}"})

if [ "${#streng[@]}" -eq 0 ] && [ "${#paare[@]}" -eq 0 ]; then
  [ "$FEHLER" -gt 0 ] && exit 1
  [ "$UNGEPRUEFT" -gt 0 ] && exit 2
  echo "Keine geänderten Markdown-Dateien."
  exit 0
fi

# Neue Dateien in einem Lauf: ohne Basis können das alle Dateien des Repos sein.
if [ "${#streng[@]}" -gt 0 ]; then
  printf '%s\n' "${streng[@]}" > "$WEG/streng"
  n=$(lauf "$WURZEL" "$WEG/streng") || { echo "NICHT GEPRÜFT: $MODUS für neue Dateien"; exit 2; }
  if [ "$n" -eq 0 ]; then echo "ok      ${#streng[@]} neue Datei(en)"
  else echo "FEHLER  $n Befund(e) in neuen Dateien"; zeige; FEHLER=$((FEHLER + 1)); fi
fi

if [ "${#paare[@]}" -gt 0 ]; then
  BAUM="$WEG/basis"
  mkdir -p "$BAUM"
  if [ "$MODUS" = links ]; then
    # Ganzer Baum: Linkziele können überall liegen.
    git archive "$BASIS" | tar -x -C "$BAUM" || { echo "NICHT GEPRÜFT: Basis $BASIS nicht lesbar"; exit 2; }
  fi
  for paar in "${paare[@]}"; do
    alt="${paar%%$'\t'*}"
    neu="${paar#*$'\t'}"
    if [ "$MODUS" = lint ]; then
      mkdir -p "$BAUM/$(dirname -- "$alt")"
      git show "$BASIS:$alt" > "$BAUM/$alt" || { echo "NICHT GEPRÜFT: $alt an der Basis nicht lesbar"; exit 2; }
    fi
    vorher=$(befunde "$BAUM" "$alt") || { echo "NICHT GEPRÜFT: $MODUS für $alt an der Basis"; exit 2; }
    jetzt=$(befunde "$WURZEL" "$neu") || { echo "NICHT GEPRÜFT: $MODUS für $neu"; exit 2; }
    if [ "$jetzt" -eq 0 ]; then echo "ok      $neu"
    elif [ "$jetzt" -gt "$vorher" ]; then
      echo "FEHLER  $neu: $vorher → $jetzt Befund(e), verschlechtert"; zeige; FEHLER=$((FEHLER + 1))
    else
      echo "HINWEIS $neu: Altlast $vorher → $jetzt Befund(e), nicht verschlechtert"; HINWEISE=$((HINWEISE + 1))
    fi
  done
fi

echo "FEHLER=$FEHLER HINWEIS=$HINWEISE NICHT_GEPRUEFT=$UNGEPRUEFT"
[ "$FEHLER" -eq 0 ] || exit 1
[ "$UNGEPRUEFT" -eq 0 ] || exit 2
