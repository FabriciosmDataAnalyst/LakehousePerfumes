# LakehousePerfumes

Course-series repo: a Databricks Asset Bundle (`rotaperfume/`) plus raw CSVs (`dados/`).
The executable product is the bundle; the spec is in `.llm/*.md`. When instructions
conflict, trust the code over prose.

## Layout

- `.llm/*.md` — the de-facto PRD. `prompt_01.md`–`prompt_06.md` are the six staged
  builds of the data pipeline (`rotaperfume_pipeline` grows one task per prompt,
  in order); `prompt-01-features.md` / `prompt-02-modelo.md` are the ML follow-up.
- `dados/crm/` and `dados/erp/` — 10 source CSVs (~14.7 MB) that
  `rotaperfume/scripts/subir-raw.sh` uploads. **Never regenerate or reorder
  casually** — bronze row-count checks hard-code 313551.
- `rotaperfume/` — the DAB project. **All operational guidance lives in
  `rotaperfume/AGENTS.md`** — read it before touching the bundle.

## Quick facts (verify in `rotaperfume/AGENTS.md`)

- Workspace profile is always `perfumariaaula`; everything is serverless — never
  configure a cluster.
- **Deploy order matters** (must follow this exact order):
  `criar-catalogo.sh` → `bundle validate` → `bundle deploy` → `subir-raw.sh` →
  `bundle run`.
- Tests/lint run from `rotaperfume/`: `uv run pytest`, `uv run ruff` (line-length
  = 120 in `pyproject.toml`).

## Critical commands

| Command | Description |
|---|---|
| `bash scripts/criar-catalogo.sh <profile>` | Creates the UC catalog via SQL. Required before bundle deploy on Free Edition. |
| `databricks bundle validate --target dev --profile <profile>` | Validates the bundle. |
| `databricks bundle deploy --target dev --profile <profile>` | Deploys the bundle. |
| `bash scripts/subir-raw.sh <profile>` | Uploads CSVs from `dados/` to UC Volume `dbfs:/Volumes/{catalog}/bronze/raw/erp` and `/crm`. |
| `databricks bundle run rotaperfume_pipeline --target dev --profile <profile> --only <task>` | Runs a single task (via `scripts/rodar-tarefa.sh`). |
| `uv run pytest` | Runs tests from `rotaperfume/`. |
| `uv run ruff` | Lints from `rotaperfume/`. |

## Non-obvious rules (learned the hard way)

- **`databricks` commands MUST pass `--profile perfumariaaula` explicitly.** Never
  rely on the default profile.
- **Never add `mode: development` to the dev target.** It prefixes UC names
  (including schemas) with `[dev <user>]`, breaking every SQL/notebook path. The
  `presets: { trigger_pause_status: PAUSED }` in `databricks.yml` is the explicit
  way to pause the schedule; keep it.
- **The catalog is created via SQL, not in the bundle.** Free Edition has Default
  Storage enabled, so the UC API refuses `CREATE CATALOG`; the failure shows at
  deploy even though it validates fine. Use `scripts/criar-catalogo.sh <profile>`.
- **`databricks fs cp` to a UC Volume still needs the `dbfs:` scheme** on the
  destination: `dbfs:/Volumes/{catalog}/bronze/raw/erp`.
- **SQL tasks need `sql_task: { file: { path: ... } }`, NOT `sql_file_path`**
  (cleanly rejected only at validate, not deploy). Each silver/gold SQL uses full
  `lakehouse_rotaperfume.silver.x` identifiers — SQL tasks don't substitute params.
- **ANSI mode is ON in this workspace.** Use `try_to_date()` for all date
  conversions; `to_date()`/`date_trunc()` on malformed data ABORT the query
  (`CAST_INVALID_INPUT`) instead of returning NULL.
- **`CREATE OR REPLACE TABLE ... (defs) AS SELECT` is REJECTED** — "RTAS" cannot
  carry a column list. Use two statements: `CREATE OR REPLACE TABLE ... (defs)
  USING DELTA COMMENT '...';` then `INSERT INTO ... SELECT ...;`.
- **Correlated scalar subqueries must be aggregated** (`max()`/`min()`) or they
  fail: "Correlated scalar subqueries must be aggregated to return at most one
  row".
- **`testes` runs LAST-but-one on purpose for gold.** If any of its 9 quality
  checks fail, the job stops and the dashboard keeps yesterday's data. Do not
  reorder gold tasks to run before `testes`.
- **`src/ml/` is gitignored but REQUIRED at deploy.** The bundle only syncs it
  because of the `sync.include: src/ml/**` block in `databricks.yml`; without
  it the notebook never reaches the workspace and `ml_features` fails with
  "Unable to access the notebook".
- **Never rename the dashboard resource key** (`dashboard-comercial`) — the bundle
  treats a new key as a new resource and deletes/recreates it, changing the URL.
  Do not `--auto-approve` a deploy without checking its diff.
- **Dashboard datasets must NOT be prefixed with `gold.`** in their SQL — the
  dashboard's biceps resolver ignores them.
- **Genie `.geniespace.json` takes exactly ONE `text_instructions` item** (IDs are
  deterministic md5 of the content, sorted); merge new guidance into the existing
  instruction.
- **UC model registration requires a model signature.** Log with
  `artifact_path="modelo"` (not MLflow 3 `name=`), set
  `mlflow.set_registry_uri("databricks-uc")`, alias `@prod`.
- **SQL `CREATE FUNCTION` rejects a non-constant `LIMIT`** (`LIMIT p_quantos`
  → `INVALID_LIMIT_LIKE_EXPRESSION`): filter `WHERE ordem <= p_quantos` in a
  pre-numbered result instead. Prefix params with `p_`.
- **SQL tasks: `CREATE OR REPLACE VIEW (col INT COMMENT ...)` — types in the
  column list are discontinued** (`INVALID_VIEW_COLUMN_SPEC`); write `col
  COMMENT '...'` only.
- **Brine row-count: 313551 total lines** across all 10 CSV files — checked in
  `src/bronze/ingestao.py`.