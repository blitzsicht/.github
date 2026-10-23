# {{ name }}: wo was steht

| Thema | Datei |
|---|---|
| Regeln und Befehle | [AGENTS.md](../AGENTS.md) |
| Entscheidungen | [decisions/](decisions/) |
{% if betrieb_geplant == 'ja' -%}
| Betrieb, Störung, Wiederanlauf | [BETRIEB.md](BETRIEB.md) |
{% endif -%}
{% if profil == 'L' -%}
| Aufbau und Abläufe | [ARCHITEKTUR.md](ARCHITEKTUR.md) |
| Störung, Rollback | [RUNBOOK.md](RUNBOOK.md) |
{% endif -%}
