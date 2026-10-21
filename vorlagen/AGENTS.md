# {{ name }}

Profil: {{ profil }}
{% if betrieb_geplant == 'ja' -%}
Betrieb: geplant
{% endif %}
{{ zweck }}

## Lies zuerst

{% if profil in 'ML' -%}
1. [docs/INDEX.md](docs/INDEX.md): wo was steht.
2. Offene Issues bzw. den Stand des Planungswerkzeugs.
3. Die jüngsten Dateien in [docs/decisions/](docs/decisions/).
{%- else -%}
1. [README.md](README.md).
{%- endif %}

## Regeln

- Befehle stehen nur in dieser Datei; andere Dateien verlinken hierher.
{% if profil in 'ML' -%}
- Eigene Entscheidungen als eine Datei je Entscheidung in `docs/decisions/`.
{% endif -%}
- Keine Secrets im Repo. `.env*` ist ignoriert, `.env.example` enthält nur Platzhalter.
- Höchstens {{ 150 if profil in 'ML' else 60 }} Zeilen; Details gehören in `docs/`.

## Befehle
