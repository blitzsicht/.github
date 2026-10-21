# {{ name }}

{{ zweck }}

{% if profil in 'ML' -%}
Wo was steht: [docs/INDEX.md](docs/INDEX.md). Regeln und Befehle: [AGENTS.md](AGENTS.md).
{%- else -%}
Regeln und Befehle: [AGENTS.md](AGENTS.md).
{%- endif %}
