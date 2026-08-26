-- Silver.crm-e-financeiro -- vendedores, carteira, oportunidades, visitas,
-- pagamentos e estoque limpos e tipados.
--
-- O destaque e a carteira: existe vendedor desligado com carteira ainda vigente.
-- NAO corrigimos o dado (nao e sujeira garantida); expomos duas colunas:
--   vigente  -> carteira valida (data_fim NULL) E vendedor ativo
--   orfao_vendedor_desligado -> carteira valida MAS o vendedor foi desligado (441).
-- Uma carteira com data_fim FUTURA NAO conta como vigente nem orfa: ela tem fim
-- marcado. Por isso as duas colunas exigem data_fim IS NULL.
--
-- Oportunidades: as etapas reais sao 'Fechado ganho'/'Fechado perdido' (NUNCA
-- 'Ganha'/'Perdida'). Conferido com um SELECT DISTINCT etapa antes de escrever.
--
-- ANSI mode ligado: try_to_date() sempre.

-- ---------- vendedores ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.vendedores (
  vendedor_id       STRING,
  nome              STRING,
  regiao            STRING,
  uf                STRING,
  data_admissao     DATE COMMENT 'via coalesce(try_to_date ISO, try_to_date dd/MM/yyyy)',
  data_desligamento DATE COMMENT 'NULL para vendedor ativo',
  meta_mensal       DECIMAL(18,2),
  _processado_em    TIMESTAMP,
  _linhas_origem    LONG
)
USING DELTA
COMMENT 'Vendedores limpos: datas padronizadas, meta tipada.';

INSERT INTO lakehouse_rotaperfume.silver.vendedores (
  vendedor_id, nome, regiao, uf, data_admissao, data_desligamento, meta_mensal,
  _processado_em, _linhas_origem
)
SELECT
  vendedor_id, nome, regiao, uf,
  coalesce(try_to_date(data_admissao), try_to_date(data_admissao, 'dd/MM/yyyy')) AS data_admissao,
  NULLIF(coalesce(try_to_date(data_desligamento), try_to_date(data_desligamento, 'dd/MM/yyyy')), date '0001-01-01') AS data_desligamento,
  CAST(meta_mensal AS DECIMAL(18,2)) AS meta_mensal,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.vendedores;

-- ---------- carteira ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.carteira (
  carteira_id            STRING,
  cliente_id             STRING,
  vendedor_id            STRING,
  data_inicio            DATE,
  data_fim               DATE COMMENT 'NULL enquanto a carteira esta aberta',
  vigente                BOOLEAN COMMENT 'DERIVADO: data_fim IS NULL E o vendedor nao foi desligado',
  orfao_vendedor_desligado BOOLEAN COMMENT 'DERIVADO: EXPOSICAO do problema. data_fim IS NULL mas o vendedor ja foi desligado (441). Nao consertamos o dado; mostramos ao gestor',
  _processado_em         TIMESTAMP,
  _linhas_origem         LONG
)
USING DELTA
COMMENT 'Carteira de clientes por vendedor, com colunas auxiliares para carteiras orfas de vendedor desligado.';

INSERT INTO lakehouse_rotaperfume.silver.carteira (
  carteira_id, cliente_id, vendedor_id, data_inicio, data_fim, vigente,
  orfao_vendedor_desligado, _processado_em, _linhas_origem
)
SELECT
  c.carteira_id, c.cliente_id, c.vendedor_id,
  coalesce(try_to_date(c.data_inicio), try_to_date(c.data_inicio, 'dd/MM/yyyy')) AS data_inicio,
  NULLIF(coalesce(try_to_date(c.data_fim), try_to_date(c.data_fim, 'dd/MM/yyyy')), date '0001-01-01') AS data_fim,
  (try_to_date(c.data_fim) IS NULL AND NULLIF(try_to_date(v.data_desligamento), date '0001-01-01') IS NULL) AS vigente,
  (try_to_date(c.data_fim) IS NULL AND NULLIF(try_to_date(v.data_desligamento), date '0001-01-01') IS NOT NULL) AS orfao_vendedor_desligado,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.carteira c
LEFT JOIN lakehouse_rotaperfume.silver.vendedores v USING (vendedor_id);

-- ---------- oportunidades ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.oportunidades (
  oportunidade_id   STRING,
  cliente_id        STRING,
  vendedor_id       STRING,
  origem            STRING,
  data_abertura     DATE,
  etapa             STRING COMMENT 'Etapa da origem. Os fechamentos sao "Fechado ganho"/"Fechado perdido", nunca "Ganha"/"Perdida"',
  fechado_ganho     BOOLEAN COMMENT 'DERIVADO: etapa = "Fechado ganho"',
  probabilidade_pct INT,
  valor_estimado    DECIMAL(18,2),
  data_fechamento   DATE,
  ciclo_dias        INT COMMENT 'NULL para oportunidades ainda abertas',
  motivo_perda      STRING,
  _processado_em    TIMESTAMP,
  _linhas_origem    LONG
)
USING DELTA
COMMENT 'Oportunidades de venda limpas, com flags de fechamento derivadas das etapas reais.';

INSERT INTO lakehouse_rotaperfume.silver.oportunidades (
  oportunidade_id, cliente_id, vendedor_id, origem, data_abertura, etapa,
  fechado_ganho, probabilidade_pct, valor_estimado, data_fechamento,
  ciclo_dias, motivo_perda, _processado_em, _linhas_origem
)
SELECT
  oportunidade_id, cliente_id, vendedor_id, origem,
  coalesce(try_to_date(data_abertura), try_to_date(data_abertura, 'dd/MM/yyyy')) AS data_abertura,
  etapa,
  (etapa = 'Fechado ganho') AS fechado_ganho,
  CAST(probabilidade_pct AS INT) AS probabilidade_pct,
  CAST(valor_estimado AS DECIMAL(18,2)) AS valor_estimado,
  coalesce(try_to_date(data_fechamento), try_to_date(data_fechamento, 'dd/MM/yyyy')) AS data_fechamento,
  CAST(ciclo_dias AS INT) AS ciclo_dias,
  motivo_perda,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.oportunidades;

-- ---------- visitas ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.visitas (
  visita_id     STRING,
  cliente_id    STRING,
  vendedor_id   STRING,
  data_visita   DATE,
  resultado     STRING,
  duracao_min   INT,
  _processado_em TIMESTAMP,
  _linhas_origem LONG
)
USING DELTA
COMMENT 'Visitas a clientes.';

INSERT INTO lakehouse_rotaperfume.silver.visitas (
  visita_id, cliente_id, vendedor_id, data_visita, resultado, duracao_min,
  _processado_em, _linhas_origem
)
SELECT
  visita_id, cliente_id, vendedor_id,
  coalesce(try_to_date(data_visita), try_to_date(data_visita, 'dd/MM/yyyy')) AS data_visita,
  resultado,
  CAST(duracao_min AS INT) AS duracao_min,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.visitas;

-- ---------- pagamentos ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pagamentos (
  pagamento_id      STRING,
  pedido_id         STRING,
  forma_pagamento   STRING,
  parcelas          INT,
  valor             DECIMAL(18,2),
  taxa_percent      DECIMAL(6,2),
  valor_liquido     DECIMAL(18,2),
  data_vencimento   DATE,
  data_pagamento    DATE,
  status_pagamento  STRING,
  _processado_em    TIMESTAMP,
  _linhas_origem    LONG
)
USING DELTA
COMMENT 'Pagamentos de pedidos, valor e datas tipados.';

INSERT INTO lakehouse_rotaperfume.silver.pagamentos (
  pagamento_id, pedido_id, forma_pagamento, parcelas, valor, taxa_percent,
  valor_liquido, data_vencimento, data_pagamento, status_pagamento,
  _processado_em, _linhas_origem
)
SELECT
  pagamento_id, pedido_id, forma_pagamento,
  CAST(parcelas AS INT) AS parcelas,
  CAST(valor AS DECIMAL(18,2)) AS valor,
  CAST(taxa_pct AS DECIMAL(6,2)) AS taxa_percent,
  CAST(valor_liquido AS DECIMAL(18,2)) AS valor_liquido,
  coalesce(try_to_date(data_vencimento), try_to_date(data_vencimento, 'dd/MM/yyyy')) AS data_vencimento,
  coalesce(try_to_date(data_pagamento), try_to_date(data_pagamento, 'dd/MM/yyyy')) AS data_pagamento,
  status_pagamento,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.pagamentos;

-- ---------- estoque ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.estoque (
  data_snapshot DATE,
  sku           STRING,
  saldo         INT,
  ruptura       BOOLEAN COMMENT 'DERIVADO: saldo = 0. Ruptura vira boolean, nao letra',
  _processado_em TIMESTAMP,
  _linhas_origem  LONG
)
USING DELTA
COMMENT 'Estoque por SKU por dia, com flag de ruptura derivada do saldo.';

INSERT INTO lakehouse_rotaperfume.silver.estoque (
  data_snapshot, sku, saldo, ruptura, _processado_em, _linhas_origem
)
SELECT
  coalesce(try_to_date(data_snapshot), try_to_date(data_snapshot, 'dd/MM/yyyy')) AS data_snapshot,
  sku,
  CAST(saldo AS INT) AS saldo,
  (CAST(saldo AS INT) = 0) AS ruptura,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.estoque;