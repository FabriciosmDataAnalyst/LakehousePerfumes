# Rota do Perfume — Lakehouse + ML + App

> Imersão Jornada de Dados (lvgalvao) — pipeline completo de **Engenharia → Ciência de Dados → App** no Databricks Free Edition, 100% como código com **Databricks Asset Bundles (DABs)**.

Distribuidora B2B de perfumaria árabe. A pergunta que pagou o projeto: *“Tenho 3 mil clientes e 200 ligações por semana. Em quem meu vendedor liga amanhã?”* Este repo responde com uma **fila priorizada, com motivo em português e sugestão de SKU**, mais dashboard e Genie.

**Demo:** `rotaperfume-direcao` em https://rotaperfume-direcao-7474658008865974.aws.databricksapps.com · Pipeline: `rotaperfume_pipeline` (16 tasks)

---

## Arquitetura

```
dados/ (ERP/CRM, 10 CSVs)
  → Volume bronze/raw (dbfs:/Volumes/.../raw)
    → bronze (10 tabelas Delta, tudo como string)
      → silver (4 jobs paralelos, limpeza + constraints)
        → gold (dimensões → fato_vendas → marts → 9 testes de qualidade)
          → gold (views de negócio + auditoria de metadado)
            → ml_features (2.815 treino / 2.816 score, mesma função, dois cortes)
              → ml_modelo (HistGradientBoosting seed 42, MLflow UC, @prod)
                → ml_fila (200 contatos, 4 funções SQL)
                  → App + Genie (leitura) + retorno_ligacao (escrita)
```

Mesmo bundle, mesmo job, mesmos testes que quebram. ML não ganhou repo novo.

---

## Estrutura

```
LakehousePerfumes/
├── dados/                      # 10 CSVs originais (erp: 5, crm: 5) — fonte de verdade
├── .llm/                       # PRD das 4 noites (prompt_01..06 + features/modelo/fila + genie/app)
│   ├── 01-engenharia-de-dados/ # 6 prompts: raw → bronze → silver → gold → dashboard → genie
│   ├── 02-ciencia-de-dados/    # 3 prompts: features → modelo → fila
│   └── 03-app-e-genie/         # 3 prompts: genie direção → app → retorno
├── rotaperfume/                # DAB principal (o produto executável)
│   ├── databricks.yml          # bundle, sync.include: src/ml/**, targets dev/prod
│   ├── resources/              # catalogo.yml, pipeline.job.yml (16 tasks), dashboards, genies
│   ├── src/
│   │   ├── raw/conferencia.py
│   │   ├── bronze/ingestao.py
│   │   ├── silver/01..04*.sql
│   │   ├── gold/05..11*.sql
│   │   └── ml/11-features.py / 12-modelo.py / 13-fila.sql  # gitignored, obrigatório no deploy
│   ├── scripts/                # criar-catalogo.sh, subir-raw.sh, rodar-tarefa.sh, run_sql.py
│   └── tests/                  # pytest via databricks-connect
└── rotaperfume-direcao/        # Databricks App (bundle próprio, target default)
    ├── config/queries/         # kpis_semana.sql, fila.sql, vendedores.sql, acompanhamento.sql
    ├── client/                 # React + TypeScript + Tailwind
    └── server/server.ts        # POST /api/retorno → gold.retorno_ligacao
```

> `src/ml/` é `gitignored` mas **obrigatório**: o `databricks.yml` tem `sync.include: src/ml/**` para subir ao workspace.

---

## Stack

Databricks Free Edition (serverless), Unity Catalog, Delta Lake, PySpark / Spark SQL, MLflow, Databricks Apps (AppKit), DABs, `uv`, `ruff`, `pytest`.

---

## Pré-requisitos

- Databricks CLI `>=0.205` (`databricks --version`), `uv`, Python `3.10–3.12` (não 3.13), `Node 22+`
- Workspace com profile `perfumariaaula` (sempre com `--profile`, nunca default)
  ```bash
  databricks auth login --host https://dbc-16cb5127-38eb.cloud.databricks.com --profile perfumariaaula
  databricks auth profiles # deve mostrar Valid: YES
  ```
- Warehouse Serverless `39b53a84b2a3e763`

---

## Como rodar — do zero

A ordem importa (catálogo antes dos schemas, volume antes do upload, tabelas antes do Genie):

```bash
# 0. dentro de rotaperfume/
cd rotaperfume

# 1. catálogo (Free Edition não cria via API)
bash scripts/criar-catalogo.sh perfumariaaula
# ou: echo "CREATE CATALOG IF NOT EXISTS lakehouse_rotaperfume;" | databricks experimental aitools tools query --profile perfumariaaula --warehouse 39b53a84b2a3e763 --output json

# 2. validar e subir só o job + schemas (gold ainda não existe para o Genie)
databricks bundle validate --target dev --profile perfumariaaula
databricks bundle deploy --target dev --profile perfumariaaula --select jobs.rotaperfume_pipeline --select schemas.bronze --select schemas.silver --select schemas.gold --select volumes.raw

# 3. subir os 10 CSVs para o Volume
databricks fs cp --recursive --overwrite ../../dados/erp dbfs:/Volumes/lakehouse_rotaperfume/bronze/raw/erp --profile perfumariaaula
databricks fs cp --recursive --overwrite ../../dados/crm dbfs:/Volumes/lakehouse_rotaperfume/bronze/raw/crm --profile perfumariaaula
# ou: bash scripts/subir-raw.sh perfumariaaula

# 4. rodar o pipeline completo (16 tasks, ~7 min)
databricks bundle run rotaperfume_pipeline --target dev --profile perfumariaaula

# 5. agora que a gold existe, subir Genie + Dashboard
databricks bundle deploy --target dev --profile perfumariaaula

# 6. App da direção (bundle próprio, target default)
cd ../rotaperfume-direcao
databricks apps deploy --profile perfumariaaula --auto-approve
# conceder acesso ao dado (o App é um service principal novo a cada criação)
SP=$(databricks apps get rotaperfume-direcao --profile perfumariaaula -o json | python -c "import json,sys; print(json.load(sys.stdin)['service_principal_client_id'])")
echo "GRANT USE CATALOG ON CATALOG lakehouse_rotaperfume TO \`$SP\`" | databricks experimental aitools tools query --profile perfumariaaula --warehouse 39b53a84b2a3e763 --output json
echo "GRANT USE SCHEMA ON SCHEMA lakehouse_rotaperfume.gold TO \`$SP\`" | databricks experimental aitools tools query --profile perfumariaaula --warehouse 39b53a84b2a3e763 --output json
echo "GRANT SELECT ON SCHEMA lakehouse_rotaperfume.gold TO \`$SP\`" | databricks experimental aitools tools query --profile perfumariaaula --warehouse 39b53a84b2a3e763 --output json
echo "GRANT MODIFY ON TABLE lakehouse_rotaperfume.gold.retorno_ligacao TO \`$SP\`" | databricks experimental aitools tools query --profile perfumariaaula --warehouse 39b53a84b2a3e763 --output json
```

**Atalho para uma task só (35s vs 3m30):**
```bash
bash scripts/rodar-tarefa.sh perfumariaaula ml_fila
python scripts/run_sql.py perfumariaaula src/gold/08-testes.sql
```

---

## Pipeline em detalhe

| Camada | Entrega | Teste que quebra o job |
|---|---|---|
| **raw** | `bronze._raw_arquivos` — conferência dos 10 arquivos | falta de arquivo ou vazio |
| **bronze** | 10 tabelas Delta, tudo `STRING` + `_ingerido_em` | linhas 313.551 |
| **silver** | 4 jobs: clientes (CNPJ normalizado, dedup 40→3000), pedidos, itens/produtos, crm/financeiro | `length(cnpj)=14`, datas não nulas, `quantidade_abs>0` |
| **gold** | `dim_*` (4), `fato_vendas` (191.080, R$ 102.303.828,05), `marts` (3), **9 testes** | receita gold = silver, CNPJs únicos, sem receita negativa fora de devolução |
| **ml** | `features_treino` (corte 01/08 + alvo 7d), `features_cliente` (31/08), `propensao_compra` UC `@prod`, `fila_semanal` (200) + 4 funções | `AUC>baseline+0.05`, `lift>=2.5`, fila 200 linhas com motivo |

Detalhe e ordem dos prompts: `.llm/01-engenharia-de-dados/prompt_0*.md`, `.llm/02-ciencia-de-dados/*`, `.llm/03-app-e-genie/*`.

---

## Dados

`dados/erp` (produtos, pedidos, itens_pedido, pagamentos, estoque) e `dados/crm` (clientes, vendedores, carteira, oportunidades, visitas). Gerados com `seed 42` — não regenerar casualmente, os testes validam totais.

---

## App

Três telas sobre a mesma `gold.fila_semanal`: **A semana** (fila filtrável + 4 botões que gravam `gold.retorno_ligacao`), **Acompanhamento** (fila vs retorno), **Perguntar** (Genie `Rota do Perfume · Direção` embutido). Leituras em `config/queries/*.sql` com tipos gerados do Unity Catalog (`npm run typegen`).

```bash
cd rotaperfume-direcao
npm run dev        # local, warehouse remoto
npm run typecheck && npm run lint
databricks apps deploy -t default --profile perfumariaaula
```

---

## Testes & Qualidade

```bash
cd rotaperfume
uv sync --dev
uv run ruff          # line-length 120
uv run pytest        # via databricks-connect, sem cluster
```

---

## Gotchas (aprendidos na prática)

- **Profile sempre explícito:** `--profile perfumariaaula` em todo `databricks`.
- **Nunca `mode: development` no `dev`:** prefixa schemas com `[dev user]` e quebra todo SQL. Use `presets: {trigger_pause_status: PAUSED}`.
- **Catálogo via SQL, não via API:** Free Edition com Default Storage recusa `CREATE CATALOG` pela API.
- **`dbfs:` obrigatório** em `databricks fs cp` para Volume UC.
- **`sql_task: {file: {path: ...}}`** para SQL tasks, não `sql_file_path`.
- **ANSI mode ON:** use `try_to_date()`, nunca `to_date()`.
- **`CREATE TABLE (cols) AS SELECT` é rejeitado:** faça `CREATE TABLE (cols) USING DELTA; INSERT INTO ... SELECT`.
- **Subqueries correlatas precisam `max()`/`min()`.**
- **`src/ml/` gitignored mas obrigatório** por `sync.include`.

Guia completo para agentes: `rotaperfume/AGENTS.md`.

---

## Reset

```bash
bash .llm/01-engenharia-de-dados/00-reset.sh perfumariaaula        # dry-run
bash .llm/01-engenharia-de-dados/00-reset.sh perfumariaaula --apagar  # apaga catalog + deploy
```

---

## Crédito

Baseado na **Imersão Jornada de Dados** com Leo Galvão — https://github.com/lvgalvao/projeto-dados-ia-databricks

*Data Analyst em transição para Analytics Engineering — de quem responde para quem entrega o produto.*
