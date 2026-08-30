# rotaperfume — Databricks Asset Bundle (DAB)

Project guidance for AI agents lives in AGENTS.md.

## For AI Agents: Use Databricks AI Tools

If Databricks AI Tools are available (they may not be in this environment), read
the `databricks-core` skill BEFORE other actions: it covers CLI auth, profile
selection, data discovery, and the bundle deploy workflow.
`databricks aitools install` installs it; CLI install:
https://docs.databricks.com/dev-tools/cli/install

---

## What this is

The executable product of the course-series repo `LakehousePerfumes/` (spec in
`.llm/*.md` at the repo root). A serverless Free-Edition workspace; the whole
Unity Catalog is declared as code in `resources/*.yml`: schemas `bronze`/
`silver`/`gold`, a managed `bronze.raw` volume, a 15-task job
`rotaperfume_pipeline`, a versioned dashboard, a Genie space, and the journey
`bronze → silver → gold → ml`:

- `src/raw/conferencia.py` + `bronze/ingestao.py` — Python notebook tasks.
- `src/silver/*.sql` (4, parallel) and `src/gold/*.sql` (6, sequential) — SQL
  tasks via `sql_task.file.path`.
- `src/ml/` is gitignored but REQUIRED at deploy — the bundle only syncs it
  because of the `sync.include: src/ml/**` block in `databricks.yml`. Lives in
  the workspace only; the notebooks `11-features.py`/`12-modelo.py` and SQL
  `13-fila.sql` are NOT on disk in git.
- `.llm/prompt-03-fila-e-agente.md` is the spec for the fila/agente layer.

**Read the matching `.llm/prompt_*.md` before working on a layer** — they are
the authoritative spec and contain the exact commands and required order.

### The job chain

```
raw_conferencia → bronze_ingestao → silver_* (4× parallel)
  → gold_dimensoes → gold_fato_vendas → gold_marts → testes
  → metricas_de_negocio + auditoria_de_metadado (parallel)
  → ml_features → ml_modelo → ml_fila
```

`testes` runs LAST-but-one on purpose for gold — if any of its 9 quality checks
fail, the job stops and the dashboard keeps yesterday's data, never wrong data.
Do not reorder gold tasks to run before `testes`.

### ML layer quick facts

- `ml_features` builds `gold.features_treino`/`cliente`; `ml_modelo` trains
  `HistGradientBoostingClassifier` (never XGBoost), logs **with a model
  signature** (UC refuses registration without input+output signature), and
  writes `gold.score_propensao` + `modelo_metricas` + `calibragem_holdout`;
  `ml_fila` is SQL and builds `gold.fila_semanal` (200 rows), 4 SQL functions
  (`priorizar_carteira` etc.) and 3 quality tests, then the Genie/dashboard
  consume those objects.
- Run ONE task, not the whole job: `bash scripts/rodar-tarefa.sh <profile>
  <task_key>` (~35s vs ~3m30 for all 15). Sidecars: `scripts/run_sql.py
  <profile> <file.sql>` runs a `.sql` file one statement at a time. On Windows
  git-bash `databricks` is NOT on PATH (run the CLI from PowerShell, per the
  `.sh` gotcha below).
- Deploy-order trap for Genie/Dashboard: deploy the JOB first
  (`bundle deploy --select jobs.rotaperfume_pipeline`), run the task / SQL to
  create the tables, THEN a full `bundle deploy`. The Genie refuses to deploy
  referencing a table that doesn't exist yet (PERMISSION_DENIED … does not
  exist) and the deploy error never mentions ordering.

## Non-obvious rules (learned the hard way)

- **`databricks` commands MUST pass `--profile perfumariaaula` explicitly.**
  Never rely on the default profile. Host is
  `https://dbc-16cb5127-38eb.cloud.databricks.com`; SQL warehouse id
  `39b53a84b2a3e763`. (The `.llm/*.md` specs target the same profile — but
  always trust `databricks.yml`, not prose.)
- **Deploy order matters:** catalog must exist before the deploy creates
  schemas; the Volume must exist before uploading files:
  `criar-catalogo.sh` → `bundle validate` → `bundle deploy` → `subir-raw.sh` →
  `bundle run`.
- **Never add `mode: development` to the dev target.** It prefixes UC names —
  including schemas — with `[dev <user>]`, breaking every SQL/notebook path.
  The `presets: { trigger_pause_status: PAUSED }` in `databricks.yml` is the
  explicit way to pause the schedule; keep it.
- **The catalog is created via SQL, not in the bundle.** Free Edition has
  Default Storage enabled, so the UC API refuses `CREATE CATALOG`
  (`Metastore storage root URL does not exist / Default Storage is enabled`);
  the failure shows at deploy even though it validates fine. Use
  `scripts/criar-catalogo.sh <profile>`.
- **`databricks fs cp` to a UC Volume still needs the `dbfs:` scheme** on the
  destination: `dbfs:/Volumes/{catalog}/bronze/raw/erp`.
- Everything is serverless — **never configure a cluster**; jobs carry no
  `compute` section.

## Gotchas hit during real execution

- **`databricks experimental aitools tools query` splits SQL on spaces** when
  the query is a positional arg — pipe it via stdin and it needs `--warehouse`
  (not `--query`), `--output json`, and accepts only ONE statement (no
  multi-statement, no `INSERT ... * REPLACE`).
- **In the serverless notebook, list UC files with `spark.sql("LIST
  '/Volumes/...'")`** — `dbutils.fs.ls` came back empty there. LIST returns
  names WITH `.csv`; strip it (`nome.rsplit(".",1)[0]`) before matching
  expected names. Do NOT use `databricks.sdk WorkspaceClient` in the notebook
  (auth fails).
- **`spark.read.csv` for counting rows: omit `inferSchema=True`** — big files
  with mixed-type columns can break reading; header-only suffices to count.
- **`CREATE TABLE ... USING DELTA` must precede the table `COMMENT`** (`...) USING DELTA COMMENT '...'`), or the parser errors at `USING`.
- **`.sh` scripts can't find `databricks` via `bash` on Windows** (PATH) — run
  the CLI directly or call the exe explicitly.
- `resources/*.yml` `schemas`/`volumes` must be **maps keyed by name** (each
  with a `name` field), not sequences. Job `notebook_path`/`sql_task.file.path`
  are relative to `resources/`, so they use `../src/...`.
- Just after raw ingestion the schema may exist, but tables are written with
  `spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.bronze")` first (as in
  `src/raw/conferencia.py`); the job passes the catalog via a `catalog`
  `dbutils.widgets` + `base_parameters`.
- **SQL tasks need `sql_task: { file: { path: ... } }`, NOT `sql_file_path`**
  (cleanly rejected only at validate, not deploy). Each silver/gold SQL uses
  full `lakehouse_rotaperfume.silver.x` identifiers — SQL tasks don't
  substitute params. Silver does `USING DELTA COMMENT` within the SQL files.
- **SQL-task engine quirks (hit on real runs, SQL validates fine elsewhere):**
  - `CREATE OR REPLACE TABLE ... (defs) AS SELECT` is REJECTED — "RTAS" cannot
    carry a column list. Use `CREATE OR REPLACE TABLE ... (defs) USING DELTA
    COMMENT '...';` then `INSERT INTO ... SELECT ...;` (two statements), the
    pipeline's pattern.
  - Correlated scalar subqueries must be **aggregated** (`max(...)`/`min(...)`)
    or they fail: "Correlated scalar subqueries must be aggregated to return
    at most one row". Wrap the scalar value in `max()`.
  - `CREATE OR REPLACE VIEW (col INT COMMENT ...)` — types in the view column
    list are discontinued (`INVALID_VIEW_COLUMN_SPEC`); write `col COMMENT '...'`
    only.
  - SQL `CREATE FUNCTION` rejects a **non-constant `LIMIT`** (`LIMIT p_quantos`
    → `INVALID_LIMIT_LIKE_EXPRESSION`): filter `WHERE ordem <= p_quantos` in a
    pre-numbered result instead. Prefix params with `p_` (param named like a
    column is ambiguous).
  - Genie `.geniespace.json` takes **exactly ONE** `text_instructions` item
    (IDs are deterministic md5 of the content, sorted); merge new guidance into
    the existing instruction.
- **UC model registration requires a model signature** — `mlflow.sklearn
  .log_model(..., signature=ModelSignature(...), input_example=...)` or
  `register_model` fails with "did not contain any signature metadata". Log
  with `artifact_path="modelo"` (not MLflow 3 `name=`), set
  `mlflow.set_registry_uri("databricks-uc")`, alias `@prod`.
- **Always `try_to_date()`/`try_*`** for data/date conversion: ANSI mode is ON
  in this workspace, so malformed input ABORTS the query
  (`CAST_INVALID_INPUT`) instead of returning NULL. Silver SQLs use
  `coalesce(try_to_date(ISO), try_to_date('dd/MM/yyyy'))`.
- **`src/ml/` is gitignored but REQUIRED at deploy.** The bundle only syncs it
  because of the `sync.include: src/ml/**` block in `databricks.yml`; without
  it the notebook never reaches the workspace and `ml_features` fails with
  "Unable to access the notebook".
- **Genie space APIs are strict:** the `.geniespace.json` requires tables and
  `column_configs` sorted by `identifier`/`column_name`, and every
  instruction/sample question store id is a deterministic 32-hex md5 (see
  `resources/genie.genie_space.yml`). Dashboard datasets must NOT be prefixed
  with `gold.` in their SQL (the dashboard's biceps resolver ignores them).
- **Never rename the dashboard resource key** (`dashboard-comercial`) — the
  bundle treats a new key as a new resource and deletes/recreates it, changing
  the URL. Do not `--auto-approve` a deploy without checking its diff.

## Data (outside the bundle)

Raw CSVs live at the repo root: `dados/crm/` and `dados/erp/` (10 files,
~14.7 MB). Bronze row-count checks hard-code `313551` total lines (in
`src/bronze/ingestao.py`) — don't regenerate or reorder the data casually.

## Tests / lint

- Run from `rotaperfume/` (bundle root, where `uv.lock` sits):
  - `uv run pytest` — DATABRICKS CONNECT; `tests/conftest.py` falls back to
    serverless compute when no cluster is set (`SPARK_REMOTE` etc.).
  - `uv run ruff` — lint. `line-length = 120` in `pyproject.toml`.
- Managed by `uv` (Python `>=3.10,<3.13`); no runtime deps beyond the bundle
  itself — dev group adds pytest/ruff/databricks-connect.