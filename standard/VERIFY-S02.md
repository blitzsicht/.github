# Verify-Report S02

Erstellt: 2026-10-21  
Skripte: `standard/pruefe-repo.sh`, `standard/pruefe-repo.test.sh`

---

## Shellcheck

```
$ shellcheck standard/pruefe-repo.sh standard/pruefe-repo.test.sh
```

**Exit-Code: 0** — keine Befunde, beide Skripte shellcheck-sauber.

---

## Gegenprobe (Sabotage: R-AGENTS-PROFIL auskommentiert)

### Sabotage-Änderung in `standard/pruefe-repo.sh`

**Vor:**
```sh
  fehler "R-AGENTS-PROFIL: Keine gültige Profil-Zeile (^Profil: [SMLW]$) in AGENTS.md"
```

**Nach (sabotiert):**
```sh
  : # fehler "R-AGENTS-PROFIL: Keine gültige Profil-Zeile (^Profil: [SMLW]$) in AGENTS.md"
```

### Lauf mit sabotiertem Skript

```
$ bash standard/pruefe-repo.test.sh
  ok: R-AGENTS-EXIST: AGENTS.md fehlt — Exit 1, FEHLER:-Zeilen: 1
FEHLER: R-AGENTS-PROFIL: AGENTS.md ohne gültige Profil-Zeile — Exit 0, FEHLER:-Zeilen: 0 (erwartet Exit 1 + ≥1 FEHLER:)
  ok: R-CLAUDE-EXIST: CLAUDE.md fehlt — Exit 1, FEHLER:-Zeilen: 5
  ...
PASS=16 FAIL=1
```

**Exit-Code sabotierter Lauf: 1** (FAIL=1 → Selbsttest merkt die fehlende Regel)

### Wiederherstellung und Bestätigung

Regel wiederhergestellt via Edit (identischer Originaltext).

```
$ bash standard/pruefe-repo.test.sh
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
  ok: Vollrepo Profil S — Exit 0, kein FEHLER:
  ok: Vollrepo Profil M — Exit 0, kein FEHLER:
  ok: Vollrepo Profil L — Exit 0, kein FEHLER:
  ok: Vollrepo Profil W — Exit 0, kein FEHLER:
PASS=17 FAIL=0
```

**Exit-Code nach Wiederherstellung: 0** — PASS=17 FAIL=0, Schwelle ≥ 17 erfüllt.

---

## Public-Repo-Guardrail

```
$ grep -rE '/Volumes/|/Users/|customer-' standard/ || echo 'ok: keine privaten Tokens'
ok: keine privaten Tokens
```

**Exit-Code: 0** — keine privaten Pfade oder Kundentokens in `standard/`.
