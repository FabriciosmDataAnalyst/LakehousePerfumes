-- Silver.clientes -- CNPJ normalizado, razao social padronizada, dedup.
-- A sujeira vem da bronze: CNPJ em 3 formatos (puro/pontuado/com espaco), zeros
-- a esquerda, razao social em caixa alta, datas ISO e dd/MM/yyyy misturadas, e
-- 40 CNPJs com dois cadastros. Aqui contratamos o formato.
--
-- Lembrete da armadilha deste workspace: ANSI mode ligado. to_date() sobre data
-- malformada ABORTA a query (CAST_INVALID_INPUT). Por isso usamos try_to_date()
-- sempre, em toda conversao de data.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.clientes (
  cliente_id            STRING  COMMENT 'Id original trazido da bronze; nunca reescrito',
  cnpj                  STRING  COMMENT 'CNPJ normalizado para 14 digitos: trim, remove nao-digito, lpad com zero. Nunca CAST para numero (perde zero na frente)',
  razao_social          STRING  COMMENT 'Razao social em initcap, sem espaco duplo, para colapsar caixa e espacamento inconsistentes da origem',
  segmento              STRING,
  cidade                STRING,
  uf                    STRING,
  bairro                STRING,
  data_cadastro         DATE COMMENT 'Data de cadastro via coalesce(try_to_date ISO, try_to_date dd/MM/yyyy) para nao perder nenhum formato',
  ativo                 BOOLEAN COMMENT "'S'/'N' da origem convertido para boolean",
  cliente_ids_duplicados ARRAY<STRING> COMMENT 'Ids dos cadastros descartados na dedup por CNPJ (40 no total), guardados para rastrear pedidos antigos que apontam para eles',
  _processado_em        TIMESTAMP COMMENT 'Quando a silver gravou esta linha',
  _linhas_origem        LONG COMMENT 'Quantas linhas da bronze foram consumidas para gerar esta (linha principal + descartadas na dedup)'
)
USING DELTA
COMMENT 'Clientes limpos e deduplicados por CNPJ (3.000 unicos). Dado mais antigo vence.';

INSERT INTO lakehouse_rotaperfume.silver.clientes (
  cliente_id, cnpj, razao_social, segmento, cidade, uf, bairro, data_cadastro,
  ativo, cliente_ids_duplicados, _processado_em, _linhas_origem
)
WITH base AS (
  SELECT
    cliente_id,
    lpad(regexp_replace(trim(cnpj), '[^0-9]', ''), 14, '0') AS cnpj,
    initcap(regexp_replace(regexp_replace(trim(razao_social), '[[:space:]]+', ' '), ' +', ' ')) AS razao_social,
    segmento, cidade, uf, bairro,
    coalesce(try_to_date(data_cadastro), try_to_date(data_cadastro, 'dd/MM/yyyy')) AS data_cadastro,
    (ativo = 'S') AS ativo
  FROM lakehouse_rotaperfume.bronze.clientes
),
dedup AS (
  SELECT *,
    row_number() over (partition by cnpj ORDER BY data_cadastro, cliente_id) AS pos,
    collect_list(cliente_id) over (partition by cnpj) AS todos_ids
  FROM base
)
SELECT
  cliente_id, cnpj, razao_social, segmento, cidade, uf, bairro, data_cadastro,
  ativo,
  CASE WHEN size(todos_ids) > 1 THEN array_except(todos_ids, array(cliente_id)) ELSE NULL END AS cliente_ids_duplicados,
  current_timestamp() AS _processado_em,
  size(todos_ids) AS _linhas_origem
FROM dedup
WHERE pos = 1;

ALTER TABLE lakehouse_rotaperfume.silver.clientes ADD CONSTRAINT cnpj_14 CHECK (length(cnpj) = 14);
ALTER TABLE lakehouse_rotaperfume.silver.clientes ADD CONSTRAINT data_cadastro_obrigatoria CHECK (data_cadastro IS NOT NULL);