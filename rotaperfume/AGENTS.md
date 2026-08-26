# Declarative Automation Bundles Project

This project uses Declarative Automation Bundles (DABs) for deployment. Add project-specific instructions below.

## For AI Agents: Use Databricks AI Tools

**BEFORE any other action, read the `databricks-core` skill.**

It sets you up to work with this project reliably: CLI authentication, profile
selection, data discovery, and the bundle deployment workflow. Without it,
results are often slower and less accurate.

If this skill is not available (Databricks AI Tools are not installed), you can install them for your coding agent in seconds:

```bash
databricks aitools install
```

If the CLI is not installed, see: https://docs.databricks.com/dev-tools/cli/install

---

## Project Instructions

### What this is
A Databricks Asset Bundle (`rotaperfume/`) built for a course series on a
serverless Databricks Free Edition workspace. The whole Unity Catalog
(bronze/silver/gold schemas + a managed `bronze.raw` volume) is declared as code
in `resources/*.yml`; raw data lands in the Volume, bronze/silver/gold are tables.
`src/` is intentionally empty — later stages add notebook tasks to the
`rotaperfume_pipeline` job.

**Read `.llm/prompt_01.md` (repo root) before working here.** It is the de-facto
spec/PRD for the bundle and contains the exact commands and their required order.

### Non-obvious rules (learned the hard way)
- **`databricks` commands MUST pass `--profile perfumariaaula` explicitly.**
  Never rely on the default profile. The real workspace host is
  `https://dbc-16cb5127-38eb.cloud.databricks.com` and the SQL warehouse id is
  `39b53a84b2a3e763`. (The course spec in `.llm/prompt_01.md` was written for a
  different profile/workspace — use the values above, not the old ones.)
- **Deploy order matters:** catalog must exist before the deploy creates schemas;
  the Volume must exist before uploading files. Flow:
  `criar-catalogo.sh` → `bundle validate` → `bundle deploy` → `subir-raw.sh` → `bundle run`.
- **Do NOT add `mode: development` to the dev target.** It prefixes resource names
  (including UC schemas) with `[dev <user>]`, which breaks all pipeline SQL.
  Pause scheduling explicitly via `presets: { trigger_pause_status: PAUSED }`
  instead. `databricks.yml` already does this — keep it that way.
- **The catalog must be created via SQL, not in the bundle.** Free Edition has
  Default Storage enabled, so the UC API refuses `CREATE CATALOG` (`Metastore
  storage root URL does not exist / Default Storage is enabled`). Use
  `scripts/criar-catalogo.sh` with `databricks experimental aitools tools query`.
- **`databricks fs cp` to a UC Volume requires the `dbfs:` scheme on the
  destination**, even though it's a UC Volume (e.g. `dbfs:/Volumes/{catalog}/bronze/raw/erp`).
- Everything is serverless — **never configure a cluster**.

### Gotchas hit during real execution (fix these, don't rediscover them)
- **`databricks experimental aitools tools query` splits SQL on spaces** when the
  query is passed as a positional arg. Pass SQL via stdin:
  `echo "SQL;" | databricks experimental aitools tools query --warehouse <id> --output json`
  (and it needs `--warehouse`, not `--query`; multiple statements are rejected).
- **In the serverless notebook, list UC files with `spark.sql("LIST '/Volumes/...'")`**
  — `dbutils.fs.ls` returned empty. `LIST`/`dbutils.fs.ls` return names WITH the
  `.csv` extension, so strip it (`nome.rsplit('.',1)[0]`) before matching expected
  names. Do NOT use `databricks.sdk WorkspaceClient` in the notebook (auth fails).
- **`spark.read.csv` for counting rows: skip `inferSchema=True`** — large files
  with mixed-type columns can break; header-only is enough to count.
- **SQL `CREATE TABLE` syntax: `USING DELTA` must come BEFORE the table
  `COMMENT`** (`... ) USING DELTA COMMENT '...'`), or the parser errors at `USING`.
- **`.sh` scripts can't find `databricks` when run via `bash` on Windows**
  (PATH mismatch) — run the CLI directly or reference the exe path explicitly.
- `resources/*.yml` `schemas`/`volumes` must be **maps keyed by name** (with a
  `name` field inside), not sequences. `notebook_path` in job yml resolves
  relative to `resources/`, so use `../src/raw/conferencia.py`.
- `dbutils.widgets.get("catalog")` + `base_parameters` is how the job passes the
  catalog; `spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.bronze")` first
  (schema is created by the bundle, but the table lives there).

### Code conventions
- Notebook tasks are Python serverless with a `# Databricks notebook source`
  header and read params via `dbutils.widgets` (e.g. a `catalog` widget).
- `resources/*.yml` define schemas/volumes/jobs; add `COMMENT`s explaining each
  layer's role.

### Data
- Raw source CSVs live outside the bundle at the repo root: `dados/crm/` and
  `dados/erp/` (10 files total, ~14.7 MB).

### Tests / lint
- Run from `rotaperfume/`: `uv run pytest` (uses Databricks Connect; conftest
  falls back to serverless compute when no cluster is set). Lint: `uv run ruff`.
- Dependencies are managed by `uv` (see `pyproject.toml`, requires Python >=3.10,<3.13).