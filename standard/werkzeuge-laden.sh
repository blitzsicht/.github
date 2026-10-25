#!/usr/bin/env bash
# werkzeuge-laden.sh — lädt lychee oder gitleaks passend zur Architektur des Runners.
#
#   werkzeuge-laden.sh lychee|gitleaks ZIELVERZEICHNIS    # gibt den Pfad des Programms aus
#
# Die einzige Stelle für Versionen und Prüfsummen: der reusable Workflow und der Selbsttest
# laden beide hierüber. Aufrufer mit eigenem arm64-Runner bekommen so dieselben Versionen.
# Die Architektur kommt aus RUNNER_ARCH (X64, ARM64), außerhalb von Actions aus `uname -m`.
# Eine unbekannte Architektur bricht ab, statt still ein falsches Paket zu laden.
#
# Prüfsummen: je zwei Quellen des Herausgebers verglichen (Asset-Digest im Release und die
# veröffentlichte Prüfsummendatei).
set -euo pipefail

WERKZEUG="${1:?Werkzeug fehlt (lychee oder gitleaks)}"
ZIEL="${2:?Zielverzeichnis fehlt}"

LYCHEE_VERSION=0.24.2
GITLEAKS_VERSION=8.30.1

ARCH="${RUNNER_ARCH:-}"
if [ -z "$ARCH" ]; then
  case "$(uname -m)" in
    x86_64) ARCH=X64 ;;
    aarch64|arm64) ARCH=ARM64 ;;
    *) ARCH="$(uname -m)" ;;
  esac
fi

case "$WERKZEUG:$ARCH" in
  lychee:X64)
    paket=lychee-x86_64-unknown-linux-gnu
    sha=1f4e0ef7f6554a6ed33dd7ac144fb2e1bbed98598e7af973042fc5cd43951c9a ;;
  lychee:ARM64)
    paket=lychee-aarch64-unknown-linux-gnu
    sha=91a7bd65685da41b90ccb9bc867a3d649a7818042dae04ff405e55a25bddee4c ;;
  gitleaks:X64)
    paket=gitleaks_${GITLEAKS_VERSION}_linux_x64
    sha=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
  gitleaks:ARM64)
    paket=gitleaks_${GITLEAKS_VERSION}_linux_arm64
    sha=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080 ;;
  lychee:*|gitleaks:*)
    echo "Architektur '$ARCH' wird nicht unterstützt (X64, ARM64)." >&2; exit 1 ;;
  *)
    echo "Unbekanntes Werkzeug: $WERKZEUG" >&2; exit 2 ;;
esac

case "$WERKZEUG" in
  lychee)   url="https://github.com/lycheeverse/lychee/releases/download/lychee-v${LYCHEE_VERSION}/${paket}.tar.gz"
            innen="${paket}/lychee"; tiefe=1 ;;
  gitleaks) url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${paket}.tar.gz"
            innen="gitleaks"; tiefe=0 ;;
esac

mkdir -p "$ZIEL"
archiv="$ZIEL/$WERKZEUG.tgz"
curl -fsSL -o "$archiv" "$url"
# Erst prüfen, dann entpacken: bei falscher Prüfsumme bleibt kein Programm zurück.
if ! echo "$sha  $archiv" | sha256sum -c - >&2; then
  rm -f "$archiv"
  echo "Prüfsumme für $paket stimmt nicht." >&2
  exit 1
fi
tar -xzf "$archiv" -C "$ZIEL" --strip-components="$tiefe" "$innen"
rm -f "$archiv"
echo "$ZIEL/$WERKZEUG"
