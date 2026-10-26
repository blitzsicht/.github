# Mitarbeit an Repositories

Diese Datei gilt als Vorgabe für alle Repositories dieser Organisation ohne eigene
`CONTRIBUTING.md`. Der Abschnitt **Repository-Namen** gilt darüber hinaus für alle
Organisationen und das Personenkonto des Betreibers.

## Repository-Namen

```text
<bereich>-<rolle>[-<detail>]
```

### Warum ein Präfix, wo doch die Organisation den Besitzer nennt?

Der Grund liegt **außerhalb von GitHub**: Die lokale Ablage ist **flach**. Alle
Arbeitsverzeichnisse liegen direkt nebeneinander, und was auf GitHub die Organisation trennt,
muss dort der Name allein leisten. Ohne Präfix gäbe es mehrere Verzeichnisse namens `ops` oder
`docs` nebeneinander.

Dazu kommt die Bindung an den lokalen Verzeichnisnamen (siehe Schreibregeln): Ein Repo, das
auf GitHub `ops` hieße, müsste lokal auch `ops` heißen und kollidierte sofort.

**Das Präfix benennt also nicht den Besitzer, sondern macht den Namen für sich allein
eindeutig**: als Verzeichnis, in einer Suche, in einem Skriptpfad. Wer die Ablage eines Tages
nach Organisationen gliedert, kann die Präfixe fallen lassen; solange sie flach ist, tragen sie.

### Arten von Präfixen

| Präfix | Für | Beispiel |
|---|---|---|
| `<bereich>-` | ein Geschäftsbereich: Betrieb, Produkte | `beispiel-ops` |
| `<kunde>-` | ein Kunde mit eigenem Stack | `kunde-a-app` |
| `<marke>-` | eine eigene Marke oder ein eigenes Produkt | `marke-x-brand` |
| `<person>-` | persönlich, nicht geschäftlich | `person-rezepte` |
| *(kein Präfix)* | Werkzeuge, die keinem Bereich gehören, sondern der Arbeitsweise | `werkzeug` |

Die gültige Liste der Präfixe führt das interne Betriebs-Repo. Ein neuer Bereich, Kunde oder
eine neue Marke wird dort ergänzt.

Ein Präfix kann auch eine **Rolle** statt eines Besitzers angeben, etwa um Kundenprojekte von
Plattformbausteinen zu trennen. Dann bleibt es auch innerhalb einer Organisation sinnvoll.

### Rollen-Suffixe

Wo ein Repo eine klar benennbare Rolle hat, kommt sie aus dieser Liste:

| Suffix | Bedeutung |
|---|---|
| `-ops` | Backlog und Orchestrierung eines Bereichs |
| `-docs` | Dokumentation |
| `-app` | lauffähige Software |
| `-brand` | Marken-Vault (Assets, Richtlinien, Texte) |
| `-infra` | Betrieb und Infrastruktur |

**Die Liste ist keine Pflicht.** Trägt ein Repo stattdessen ein Produktwort, ist das richtig so:
`beispiel-preise`, `person-rezepte`. Der Suffix benennt eine Rolle, wo es eine gibt, er ersetzt
keinen Namen.

### Bei Namenskollision

Wollen zwei Repos denselben Namen, gewinnt das aktive; das abgelöste bekommt `-alt` angehängt
und wird archiviert. Beispiel: `beispiel-app` bleibt aktiv, ein abgelöstes Repo gleichen Namens
würde `beispiel-app-alt`. Eine Nummerierung (`-2`) wird nicht vergeben, sie sagt nicht, welches
gilt.

### Schreibregeln

- Durchgehend **Kleinbuchstaben**. Kein `BEISPIEL`, kein CamelCase: beides bricht Skripte,
  die Repo-Namen aus Slugs bilden, und verhält sich auf case-insensitiven Dateisystemen
  unvorhersehbar.
- **Bindestriche**, keine Unterstriche und keine Punkte.
- Keine Abkürzungen außer etablierten Produktnamen.
- **Der Remote-Name ist identisch mit dem lokalen Verzeichnisnamen.** Weicht beides ab, zeigt
  jeder Pfadverweis in Dokumentation und Skripten ins Leere.

### Nachprüfen

Ein Prüfskript im internen Betriebs-Repo meldet Abweichungen und ändert nichts.

**Was es prüft:** Großbuchstaben, Unterstriche, Punkte, ob der Remote-Name dem lokalen
Verzeichnisnamen entspricht, und ob der Name mit einem bekannten Präfix beginnt.

**Was es nicht prüft:** die Rollen-Suffixe. Die sind eine Empfehlung, keine Pflicht (siehe
oben), das kann ein Skript nicht entscheiden.

**Archivierte Repos sind ausgenommen.** Ein archiviertes Repo ist eingefroren; eine
Umbenennung ist dort nicht mehr vorgesehen, also wäre ein gemeldeter Fehler ein Auftrag, den
niemand ausführen soll. Das ist zugleich der Weg, eine Altlast aus der Meldung zu bekommen,
die den Namen aus guten Gründen behält, etwa ein altes öffentliches Repo mit einem Punkt im
Namen, dessen Umbenennung fremde Klon-URLs bräche. Wichtig dabei: `gh repo list` liefert
archivierte Repos per Default **mit**; das Skript filtert sie ausdrücklich heraus. Archivieren
allein genügt also nicht, wenn jemand die Abfrage im Skript später wieder vereinfacht.

Fällt `gh` aus oder kommt keine Repo-Liste zurück, endet das Skript mit Exit 3 und der Meldung
`NICHT GEPRUEFT`, ausdrücklich nicht mit „sauber“. Ein Prüfer, der bei Ausfall grün meldet,
wäre schlimmer als keiner.

## Doku-Standard

Die Vorlage für `AGENTS.md`, `docs/` und den Prüf-Workflow liegt in diesem Repo
(`copier.yml`, Ordner `vorlagen/`).

- **`copier copy` immer gegen die GitHub-Quelle** (`copier copy gh:blitzsicht/.github <ziel>`),
  nie gegen einen lokalen Checkout. copier schreibt die Quelle als `_src_path` in
  `.copier-answers.yml`; ein lokaler Pfad landet so im Repo und lässt `copier update` auf
  jedem anderen Rechner ins Leere laufen.
- **Profil L ist nach dem Anlegen rot**, bis `docs/ARCHITEKTUR.md` ein Mermaid-Diagramm hat
  (R-MERMAID). Die Vorlage liefert bewusst keins; copier weist nach dem Kopieren darauf hin.
- **Erstausstattung eines bestehenden Repos:** Eine vorhandene `.gitignore` bleibt stehen. Fehlt
  dort die Regel für Umgebungsdateien, meldet die Prüfung R-ENV-IGNORE.
- **Groß- und Kleinschreibung bei Dateinamen:** Auf Dateisystemen, die sie nicht
  unterscheiden (macOS), sind `docs/betrieb.md` und `docs/BETRIEB.md` dieselbe Datei. Eine
  Datei mit falscher Schreibweise per `git mv` umbenennen, ohne Platzhalter unter dem alten
  Namen: der überschriebe auf solchen Systemen die neue Datei oder kollidierte beim Checkout.

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
