# VERIFY-S04 — End-to-End-Abnahme Milestone M001

Datum: 2026-10-21  
Branch: feat/doc-standard

---

## Abschnitt 1: Shell-Test + Gegenprobe

### Item 1: `bash standard/pruefe-repo.test.sh`

```
bash standard/pruefe-repo.test.sh
```

Ergebnis: Exit 0 · PASS=17 FAIL=0 · PASS+FAIL=17 ≥ 17

```
=== S02 pruefe-repo.sh Regel-Tests ===

  ok: R-AGENTS-EXIST: AGENTS.md fehlt — Exit 1, FEHLER:-Zeilen: 2
  ok: R-AGENTS-PROFIL: AGENTS.md ohne gültige Profil-Zeile — Exit 1, FEHLER:-Zeilen: 1
  ok: R-CLAUDE-EXIST: CLAUDE.md fehlt — Exit 1, FEHLER:-Zeilen: 5
  ok: R-CLAUDE-AT: erste Zeile CLAUDE.md ist nicht @AGENTS.md — Exit 1, FEHLER:-Zeilen: 4
  ok: R-DOCS-INDEX: docs/INDEX.md fehlt (Profil M) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-DOCS-BETRIEB: docs/BETRIEB.md fehlt (Profil M) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-REMOTE: kein git remote (Profil M) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-ARCHITEKTUR: docs/ARCHITEKTUR.md fehlt (Profil L) — Exit 1, FEHLER:-Zeilen: 2
  ok: R-MERMAID: kein Mermaid-Block in ARCHITEKTUR.md (Profil L) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-DECISIONS: docs/decisions fehlt (Profil L) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-DOCS-INDEX: docs/INDEX.md fehlt (Profil L) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-DOCS-BETRIEB: docs/BETRIEB.md fehlt (Profil L) — Exit 1, FEHLER:-Zeilen: 1
  ok: R-REMOTE: kein git remote (Profil L) — Exit 1, FEHLER:-Zeilen: 1

=== Vollrepo-Tests (Profil S/M/L/W) ===

  ok: Vollrepo Profil S — Exit 0, kein FEHLER:
  ok: Vollrepo Profil M — Exit 0, kein FEHLER:
  ok: Vollrepo Profil L — Exit 0, kein FEHLER:
  ok: Vollrepo Profil W — Exit 0, kein FEHLER:

================================
PASS=17 FAIL=0
================================
```

### Item 2: Gegenprobe — R-DOCS-INDEX auskommentieren → Exit 1, Rollback sauber

Regel R-DOCS-INDEX in `standard/pruefe-repo.sh` auskommentiert:

```diff
-    # R-DOCS-INDEX
-    if [ -f "$REPO/docs/INDEX.md" ]; then
-      ok "R-DOCS-INDEX: docs/INDEX.md vorhanden"
-    else
-      fehler "R-DOCS-INDEX: docs/INDEX.md fehlt"
-    fi
+    # GEGENPROBE: R-DOCS-INDEX auskommentiert
+    # if [ -f "$REPO/docs/INDEX.md" ]; then
+    #   ok "R-DOCS-INDEX: docs/INDEX.md vorhanden"
+    # else
+    #   fehler "R-DOCS-INDEX: docs/INDEX.md fehlt"
+    # fi
```

`bash standard/pruefe-repo.test.sh` → Exit 1 · PASS=15 FAIL=2

Beleg-Zeile aus stdout:
```
FEHLER: R-DOCS-INDEX: docs/INDEX.md fehlt (Profil M) — Exit 0, FEHLER:-Zeilen: 0 (erwartet Exit 1 + ≥1 FEHLER:)
```

Rollback: `git diff standard/pruefe-repo.sh` zeigt ausschließlich den R-MERMAID-Fix (kein Gegenprobe-Diff). Exit 0 auf dem diff.

---

## Abschnitt 2: shellcheck + actionlint

### Item 3: shellcheck

```
shellcheck standard/pruefe-repo.sh standard/pruefe-repo.test.sh
```

Exit 0 · keine Ausgabe · kein Fund

### Item 4: actionlint

```
actionlint .github/workflows/doc-standard.yml .github/workflows/selbsttest.yml standard/beispiel-aufruf.yml
```

Exit 0 · keine Ausgabe · kein Fund

---

## Abschnitt 3: Copier M (grün) + Copier L (rot, via Fixture)

### Item 5: Copier Profil M → pruefe-repo.sh → Exit 0

```
copier copy . /tmp/s04-m --data profil=M --data name=beispiel-werkzeug --data zweck=kurz --data betrieb_geplant=nein --defaults --trust
git -C /tmp/s04-m init -q
git -C /tmp/s04-m remote add origin https://example.invalid/beispiel-werkzeug.git
bash standard/pruefe-repo.sh /tmp/s04-m
```

copier Exit 0 · pruefe-repo.sh Exit 0 · PASS=7 FAIL=0

```
  ok: R-AGENTS-EXIST: AGENTS.md vorhanden
  ok: R-AGENTS-PROFIL: Zeile 'Profil: <S|M|L|W>' vorhanden
  ok: R-CLAUDE-EXIST: CLAUDE.md vorhanden
  ok: R-CLAUDE-AT: erste Zeile von CLAUDE.md ist '@AGENTS.md'
  ok: R-DOCS-INDEX: docs/INDEX.md vorhanden
  ok: R-DOCS-BETRIEB: docs/BETRIEB.md vorhanden
  ok: R-REMOTE: git remote konfiguriert

PASS=7 FAIL=0 HINWEIS=0
```

Hinweis: `copier --trust` erforderlich wegen `_tasks`-Eintrag in `copier.yml`. `git init` und `remote add` bilden den Deployed-Zustand nach; Fixtures nutzen stattdessen git-Traversal zum Haupt-Repo.

### Item 6: Profil L (Mermaid fehlt) → pruefe-repo.sh → Exit 1

Verwendet deterministisch `tests/fixtures/profil-L-ohne-mermaid` (empfohlen laut S04-RESEARCH).

```
bash standard/pruefe-repo.sh tests/fixtures/profil-L-ohne-mermaid
```

Exit 1 · PASS=9 FAIL=1 · Fehler: R-MERMAID

```
  ok: R-ARCHITEKTUR: docs/ARCHITEKTUR.md vorhanden
FEHLER: R-MERMAID: kein Mermaid-Block (^```mermaid) in docs/ARCHITEKTUR.md
  ok: R-DECISIONS: Verzeichnis docs/decisions vorhanden

PASS=9 FAIL=1 HINWEIS=0
```

---

## Abschnitt 4: Fixture-Positiv (M) + Fixture-Negativ (L-ohne-mermaid)

### Item 7: `bash standard/pruefe-repo.sh tests/fixtures/profil-M` → Exit 0

```
bash standard/pruefe-repo.sh tests/fixtures/profil-M
```

Exit 0 · PASS=7 FAIL=0

```
  ok: R-AGENTS-EXIST: AGENTS.md vorhanden
  ok: R-AGENTS-PROFIL: Zeile 'Profil: <S|M|L|W>' vorhanden
  ok: R-CLAUDE-EXIST: CLAUDE.md vorhanden
  ok: R-CLAUDE-AT: erste Zeile von CLAUDE.md ist '@AGENTS.md'
  ok: R-DOCS-INDEX: docs/INDEX.md vorhanden
  ok: R-DOCS-BETRIEB: docs/BETRIEB.md vorhanden
  ok: R-REMOTE: git remote konfiguriert

PASS=7 FAIL=0 HINWEIS=0
```

### Item 8: `bash standard/pruefe-repo.sh tests/fixtures/profil-L-ohne-mermaid` → Exit 1

```
bash standard/pruefe-repo.sh tests/fixtures/profil-L-ohne-mermaid
```

Exit 1 · PASS=9 FAIL=1 · Fehler: R-MERMAID (kein Mermaid-Block in docs/ARCHITEKTUR.md)

---

## Abschnitt 5: gitleaks + Guardrail

### Item 9: gitleaks

```
gitleaks detect --no-git --source .
```

Exit 0 · scanned ~53.64 KB · no leaks found

`.gitleaks.toml` schließt `.gsd/` aus (enthält WAL-Dateien mit generischen API-Key-Pattern-Treffern, die kein echter Leak sind).

### Item 10: Guardrail — keine lokalen Pfade / customer-Strings

```
grep -rE '/Volumes/|/Users/|customer-' tests/fixtures/ .github/workflows/selbsttest.yml
```

Exit 1 · keine Treffer (grep Exit 1 = kein Match = OK)

---

## Änderungen am Standard während T03

Zwei Defekte in `standard/pruefe-repo.sh` behoben:

1. **R-MERMAID Integer-Fehler** (Zeile 84): `grep -c ... || echo 0` erzeugt auf macOS mit `set -euo pipefail` den String `"0\n0"`, was den Integer-Vergleich abbricht. Fix: `grep -q ... && mermaid_count=1 || true`.

2. **`.gitleaks.toml`** angelegt: `.gsd/`-Verzeichnis aus dem gitleaks-Scan ausgeschlossen (WAL-Datei enthält false-positives).

---

## Zusammenfassung

| # | Prüfung | Befehl | Exit | Ergebnis |
|---|---------|--------|------|----------|
| 1 | Shell-Test | `bash standard/pruefe-repo.test.sh` | 0 | PASS=17 FAIL=0 ≥17 |
| 2 | Gegenprobe | R-DOCS-INDEX auskommentiert → Test Exit 1; Rollback sauber | 1 | PASS=15 FAIL=2 |
| 3 | shellcheck | `shellcheck pruefe-repo.sh pruefe-repo.test.sh` | 0 | kein Fund |
| 4 | actionlint | `actionlint *.yml` (3 Dateien) | 0 | kein Fund |
| 5 | Copier M | `copier copy … profil=M` + `pruefe-repo.sh /tmp/s04-m` | 0 | PASS=7 FAIL=0 |
| 6 | Copier L rot | `pruefe-repo.sh tests/fixtures/profil-L-ohne-mermaid` | 1 | FAIL=1 R-MERMAID |
| 7 | Fixture M | `pruefe-repo.sh tests/fixtures/profil-M` | 0 | PASS=7 FAIL=0 |
| 8 | Fixture L-neg | `pruefe-repo.sh tests/fixtures/profil-L-ohne-mermaid` | 1 | FAIL=1 R-MERMAID |
| 9 | gitleaks | `gitleaks detect --no-git --source .` | 0 | 0 leaks |
| 10 | Guardrail | `grep -rE '/Volumes/\|/Users/\|customer-'` | 1 | 0 Treffer |
