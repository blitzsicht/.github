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
# Shell-Zeile (siehe md-dateien.sh). Namen mit Zeilenumbruch werden gemeldet und übersprungen.
#
# Exit 0: nichts verschlechtert · 1: mindestens ein FEHLER · 2: NICHT GEPRÜFT (Werkzeug fehlt
# oder brach ab).
set -uo pipefail

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
lauf() {
  local baum="$1" liste="$2" out="$WEG/out" rc n
  if [ "$MODUS" = lint ]; then
    (cd "$baum" && bash "$HIER/markdown-lint.sh" "$liste" "$REGELSATZ") > "$out" 2>&1; rc=$?
    n=$(sed -nE 's/^Summary: ([0-9]+) issue.*/\1/p' "$out" | head -n 1)
    [ "$rc" -le 1 ] && [ -n "$n" ] || { cat "$out" >&2; return 2; }
  else
    (cd "$baum" && bash "$HIER/links-pruefen.sh" "$liste") > "$out" 2>&1; rc=$?
    n=$(sed -nE 's/.*🚫 ([0-9]+) Error.*/\1/p' "$out" | head -n 1)
    [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] && [ -n "$n" ] || { cat "$out" >&2; return 2; }
  fi
  echo "$n"
}

# befunde <baum> <name>: wie lauf, für genau eine Datei.
befunde() {
  printf '%s\n' "$2" > "$WEG/eine"
  lauf "$1" "$WEG/eine"
}

zeige() { sed 's/^/        /' "$WEG/out"; }

FEHLER=0
HINWEISE=0
streng=()     # neue Dateien
paare=()      # "alt<TAB>neu" für geänderte Dateien

if [ -z "$BASIS" ]; then
  while IFS= read -r name; do streng+=("$name"); done < <(bash "$HIER/md-dateien.sh" "" "$PFAD")
else
  # Datensätze aus -z: Status, Pfad (bei R/C: alter Pfad, neuer Pfad).
  while IFS= read -r -d '' status; do
    IFS= read -r -d '' a || break
    b=""
    case "$status" in R*|C*) IFS= read -r -d '' b || break ;; esac
    for n in "$a" "$b"; do
      case "$n" in *$'\n'*) printf 'übersprungen (Zeilenumbruch im Namen): %q\n' "$n" >&2; continue 2 ;; esac
    done
    case "$status" in
      A*)   [[ "$a" == *.md ]] && streng+=("$a") ;;
      M*)   [[ "$a" == *.md ]] && paare+=("$a"$'\t'"$a") ;;
      R*)   [[ "$b" == *.md ]] || continue
            if [[ "$a" == *.md ]]; then paare+=("$a"$'\t'"$b"); else streng+=("$b"); fi ;;
      C*)   [[ "$b" == *.md ]] && streng+=("$b") ;;
    esac
  done < <(git -c core.quotePath=false diff -z --name-status -M --diff-filter=ACMR "$BASIS" HEAD -- "$PFAD")
fi

if [ "${#streng[@]}" -eq 0 ] && [ "${#paare[@]}" -eq 0 ]; then
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

echo "FEHLER=$FEHLER HINWEIS=$HINWEISE"
[ "$FEHLER" -eq 0 ]
