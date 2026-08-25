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
| `<marke>-` | Eigene Marke oder eigenes Produkt | `gympanzen-brand`, `preshot-brand`, `falzmarke` |
| `joe-` | Persönlich, nicht geschäftlich | `joe-fitness` |
| *(kein Präfix)* | Werkzeuge, die keinem Venture gehören, sondern der Arbeitsweise | `orchestration`, `claude-shared`, `operator-hooks` |

Ein Kunde kann **beide** Muster tragen: `customer-digital-direkt` ist die Website,
`digital-direkt-odoo` und `digital-direkt-ops` sind der eigene Stack. Das ist gewollt — das
`customer-`-Präfix markiert das Website-Deliverable, nicht den Kunden als Ganzes.

### Rollen-Suffixe

Wo ein Repo eine klar benennbare Rolle hat, kommt sie aus dieser Liste:

| Suffix | Bedeutung |
|---|---|
| `-ops` | Backlog und Orchestrierung eines Ventures |
| `-docs` | Dokumentation |
| `-app` | lauffähige Software |
| `-brand` | Marken-Vault (Assets, Richtlinien, Texte) |
| `-infra` | Betrieb und Infrastruktur |

**Die Liste ist keine Pflicht.** Trägt ein Repo stattdessen ein Produktwort, ist das richtig so:
`siluri-preise`, `cw-seo-system`, `joe-rezepte`. Der Suffix benennt eine Rolle, wo es eine gibt —
er ersetzt keinen Namen.

### Bei Namenskollision

Wollen zwei Repos denselben Namen, gewinnt das aktive; das abgelöste bekommt `-alt` angehängt
und wird archiviert. Beispiel: `joe-fitness` bleibt aktiv, das abgelöste `pfit` würde
`joe-fitness-alt`. Eine Nummerierung (`-2`) wird nicht vergeben — sie sagt nicht, welches gilt.

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

`blitzsicht-ops/scripts/check-repo-naming.sh` meldet Abweichungen und ändert nichts.

**Was es prüft:** Großbuchstaben, Unterstriche, Punkte, ob der Remote-Name dem lokalen
Verzeichnisnamen entspricht, und ob der Name mit einem bekannten Eigentümer-Präfix beginnt.

**Was es nicht prüft:** die Rollen-Suffixe — die sind eine Empfehlung, keine Pflicht (siehe
oben), das kann ein Skript nicht entscheiden.

**Wartung:** Die Präfix-Liste im Skript ist fest verdrahtet. `<kunde>-` und `<marke>-` sind
offene Muster, die kein Skript erraten kann — ein neuer Kunde oder eine neue Marke muss dort
von Hand ergänzt werden, sonst meldet das Skript sie als „kein bekanntes Präfix".

Fällt `gh` aus oder kommt keine Repo-Liste zurück, endet das Skript mit Exit 3 und der Meldung
`NICHT GEPRUEFT` — ausdrücklich nicht mit „sauber". Ein Prüfer, der bei Ausfall grün meldet,
wäre schlimmer als keiner.

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
