# LakehousePerfumes

Course-series repository: a Databricks Asset Bundle (`rotaperfume/`) plus the raw
CSVs it ingests (`dados/`). The executable product is the bundle; the spec is the
prompt files. When instructions in the repo conflict, trust the code over prose.

## Layout

- `.llm/*.md` — the de-facto PRD. `prompt_01.md`–`prompt_06.md` are the six
  staged builds of the data pipeline (`rotaperfume_pipeline` grows a task per
  prompt, in order); `prompt-01-features.md` / `prompt-02-modelo.md` are the ML
  follow-up (features DB model + MLflow, not in the bundle job). Each contains
  the exact commands and their required order, plus the "Se der errado" table of
  live-demo failure modes.
- `dados/crm/` and `dados/erp/` — the 10 source CSVs (~14.7 MB) that
  `rotaperfume/scripts/subir-raw.sh` uploads. This is the rawest of raw; never
  regenerate or reorder it casually (bronze row-count checks hard-code 313 551).
- `rotaperfume/` — the DAB project (Databricks Asset Bundle). **All Databricks
  operational guidance for it lives in `rotaperfume/AGENTS.md` — read it before
  touching the bundle.**

## Quick facts (verify in `rotaperfume/AGENTS.md`)

- Workspace profile is always `perfumariaaula`; everything is serverless — never
  configure a cluster.
- Deploy order matters: `criar-catalogo.sh` → `bundle validate` → `bundle deploy`
  → `subir-raw.sh` → `bundle run`.
- Tests/lint run from `rotaperfume/`: `uv run pytest`, `uv run ruff`.