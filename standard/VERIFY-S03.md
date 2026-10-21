# VERIFY-S03: Actionlint, Gegenprobe und Guardrail

## Actionlint

Beide Workflow-Dateien werden ohne Befund geprüft (Exit 0):

```sh
actionlint .github/workflows/doc-standard.yml standard/beispiel-aufruf.yml
```

Ergebnis: keine Ausgabe, Exit 0.

Was actionlint prüft: Workflow-YAML-Syntax, Expressions (`${{ }}`), bekannte Action-Inputs und -Outputs, `permissions:`-Schlüssel, `on:`-Trigger-Felder. actionlint **prüft keine SHA-Gültigkeit** — das ist ein Offline-Linter ohne Netzwerkzugriff.

## Gegenprobe (sabotierter Input)

Die Gegenprobe zeigt, dass actionlint eine ungültige `inputs.*`-Referenz als Fehler meldet
(Exit 1). So entsteht die kaputte Datei:

```sh
sed -i.bak 's/inputs\.pfad/inputs.undefined_input/' .github/workflows/doc-standard.yml
actionlint .github/workflows/doc-standard.yml
echo "Exit: $?"
```

Erwartete Ausgabe (Fehler + Exit 1):

```
.github/workflows/doc-standard.yml:45:19: property "undefined_input" is not defined \
  in object type {drift-pfade: string; pfad: string; profil: string} [expression]
   |
45 |           REPO="${{ inputs.undefined_input }}"
   |                   ^~~~~~~~~~~~~~~~~~~~~~~
Exit: 1
```

Rollback:

```sh
mv .github/workflows/doc-standard.yml.bak .github/workflows/doc-standard.yml
actionlint .github/workflows/doc-standard.yml standard/beispiel-aufruf.yml
# Exit 0 — wiederhergestellt
```

**Warum diese Gegenprobe:** actionlint validiert `inputs.*`-Referenzen gegen die deklarierten
`on.workflow_call.inputs`-Felder. Eine Referenz auf ein nicht deklariertes Feld erzwingt Exit 1.
Das belegt, dass der Linter die Datei tatsächlich inhaltlich prüft und nicht blind grün meldet.

## Guardrail

Kein Dateipfad aus der lokalen Entwicklungsumgebung darf in versionierten Workflow-Dateien stehen:

```sh
grep -rE '/Volumes/|/Users/|customer-' \
  .github/ standard/beispiel-aufruf.yml .markdownlint-cli2.yaml
```

Ergebnis: keine Ausgabe, Exit 1 (grep meldet 1 = kein Treffer). Einziger erlaubter Treffer
ist der dokumentierte Befehl in dieser Datei selbst.

Wird der Lauf in `VERIFY-S03.md` mitgeprüft, erscheint genau eine Zeile:

```
standard/VERIFY-S03.md:  grep -rE '/Volumes/|/Users/|customer-' \
```

Das ist der erwartete und einzige Treffer.

## Pfadfilter-Klarstellung

`on: workflow_call` unterstützt kein natives `paths:`-Filter. GitHub Actions erlaubt `paths:`
nur bei push- und pull_request-Triggern, nicht bei `workflow_call`.

Konsequenz für Downstream-Repos: Der aufrufende Trigger im Downstream-Repo
(z. B. `on: push: paths: ['docs/**', '*.md']`) steuert, wann der reusable Workflow läuft.
`doc-standard.yml` selbst enthält deshalb kein `paths:`-Filter — ein solches wäre ein
Syntaxfehler, den actionlint meldet.

Referenz: S03-RESEARCH, Risiko 1 (workflow_call + paths-Inkompatibilität).
