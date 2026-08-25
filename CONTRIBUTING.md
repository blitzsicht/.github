# Mitarbeit an Blitzsicht-Repositories

Diese Datei liegt im Repo `blitzsicht/.github` und gilt als **Vorgabe für alle Repositories
der Organisation**, die keine eigene `CONTRIBUTING.md` mitbringen.

## Repository-Namen

Ein Repo-Name sagt zuerst, **wem er gehört**, danach welche Rolle er spielt:

```
<eigentümer>-<rolle>[-<detail>]
```

| Präfix | Für | Beispiele |
|---|---|---|
| `blitzsicht-` | Blitzsicht-eigen: Plattform, Produkte, Betrieb | `blitzsicht-ops`, `blitzsicht-platzfrei` |
| `customer-` | Website-Deliverable für einen Auftraggeber | `customer-soleno` |
| `<kunde>-` | Kunde mit eigenem Stack über die Website hinaus | `digital-direkt-odoo` |
| `siluri-` | Siluri Clothing | `siluri-preise` |
| `<marke>-` | Eigene Marke | `gympanzen-brand`, `preshot-brand` |
| `joe-` | Persönlich, nicht geschäftlich | `joe-fitness` |

### Rollen-Suffixe

Damit ein Name lesbar bleibt, ist die Rolle aus einer festen Liste:

| Suffix | Bedeutung |
|---|---|
| `-ops` | Backlog und Orchestrierung eines Ventures |
| `-docs` | Dokumentation |
| `-app` | lauffähige Software |
| `-brand` | Marken-Vault (Assets, Richtlinien, Texte) |
| `-infra` | Betrieb und Infrastruktur |

### Schreibregeln

- Durchgehend **Kleinbuchstaben**. Kein `GYMPANZEN`, kein CamelCase — beides bricht Skripte,
  die Repo-Namen aus Slugs bilden, und verhält sich auf case-insensitiven Dateisystemen
  unvorhersehbar.
- **Bindestriche**, keine Unterstriche und keine Punkte.
- Keine Abkürzungen außer etablierten Produktnamen.
- **Der Remote-Name ist identisch mit dem lokalen Verzeichnisnamen.** Weicht beides ab, zeigt
  jeder Pfadverweis in Dokumentation und Skripten ins Leere — genau daran scheitert heute
  `siluri-preise-import`, dessen Arbeitsverzeichnis `siluri-preise` heißt.

### Ausnahme: das `cw-`-Präfix

`cw-` steht für **Customer Websites** — die geteilte Plattform hinter allen `customer-*`-Repos
(Leads, Recht, SEO, Signieren, Uptime, das `@cw/core`-Framework).

Der Bestand behält das Präfix, **für neue Repos wird es nicht mehr vergeben**; die gehören
unter `blitzsicht-`.

Der Grund gegen eine Umbenennung ist messbar, nicht ästhetisch: `cw-core` steckt in 21
`package.json` und trägt den Paketnamen `@cw/core`, der in praktisch jeder Astro-Datei jeder
Kundenseite importiert wird. Eine Umbenennung zöge einen Paket-Rename durch den gesamten
Bestand nach sich — für einen rein kosmetischen Gewinn.

### Nachprüfen

`blitzsicht-ops/scripts/check-repo-naming.sh` vergleicht die Repo-Liste gegen dieses Schema
und meldet Abweichungen. Es meldet nur, es ändert nichts.

## Commits

- Commit-Nachrichten auf **Deutsch**, mit echten Umlauten.
- Die erste Zeile sagt, **was sich fachlich ändert**, nicht welche Datei angefasst wurde.
- Der Rumpf beantwortet **warum** — der Diff zeigt schon, was.
- **Keine Werkzeug-Attribution** in Commits (keine `Co-Authored-By`-Zeilen für Assistenten,
  keine „Generated with"-Hinweise).

## Branches

`main` ist der Standard-Branch. Änderungen an Repos mit Live-Deploy laufen über einen
Feature-Branch, damit eine Vorschau entsteht, bevor etwas produktiv geht.

Gemergt wird per **Squash**; der Branch wird danach automatisch gelöscht. Beides ist in den
Repo-Einstellungen voreingestellt.

## Sicherheit

Sicherheitsrelevante Funde nicht als öffentliches Issue melden — siehe [SECURITY.md](SECURITY.md).
