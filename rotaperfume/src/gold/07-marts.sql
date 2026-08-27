-- Gold.marts -- um mart por diretoria, todos sobre o MESMO fato.
-- Conformado significa que somam igual: os tres marts fecham na mesma
-- receita do fato (R$ 102.303.828,05). O que separa um mart do outro e a
-- DIMENSAO dominante e as METRICAS, nunca a tabela base.
--
--   mart_vendas_por_vendedor     grao vendedor x mes   -> diretoria comercial
--   mart_produto_performance     grao SKU x mes        -> diretoria de produto
--   mart_financeiro_recebimento  grao mes de vencimento-> diretoria financeira
--
-- Os dois primeiros leem SO do fato_vendas. O financeiro le naturalmente da
-- silver.pagamentos (o grao nao e venda, e contas a receber) - por isso ele
-- nao entra no teste 8, que compara apenas o mart de produto contra o fato.

-- ---------- mart_vendas_por_vendedor ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor (
  ano                 INT,
  mes                 INT,
  vendedor_id         STRING,
  nome                STRING,
  regiao              STRING,
  receita             DECIMAL(18,2),
  margem              DECIMAL(18,2),
  meta                DECIMAL(18,2) COMMENT 'Meta mensal do vendedor, repetida no grao vendedor x mes',
  atingimento_pct     DECIMAL(8,2) COMMENT '100 * receita / meta no grao. NULL sem meta',
  clientes_atendidos  INT COMMENT 'Clientes distintos atendidos no grao vendedor x mes',
  ticket_medio        DECIMAL(18,2) COMMENT 'receita / clientes_atendidos no grao',
  _processado_em      TIMESTAMP
)
USING DELTA
COMMENT 'Mart comercial: vendedor x mes, com meta, atingimento, clientes e ticket medio.';

INSERT INTO lakehouse_rotaperfume.gold.mart_vendas_por_vendedor (
  ano, mes, vendedor_id, nome, regiao, receita, margem, meta,
  atingimento_pct, clientes_atendidos, ticket_medio, _processado_em
)
SELECT
  f.ano,
  f.mes,
  f.vendedor_id,
  v.nome,
  v.regiao,
  sum(f.receita) AS receita,
  sum(f.margem)  AS margem,
  max(v.meta_mensal) AS meta,
  CASE WHEN max(v.meta_mensal) IS NULL OR sum(f.receita) IS NULL THEN NULL
       ELSE round(100 * sum(f.receita) / max(v.meta_mensal), 2) END AS atingimento_pct,
  count(DISTINCT f.cliente_id) AS clientes_atendidos,
  round(sum(f.receita) / NULLIF(count(DISTINCT f.cliente_id), 0), 2) AS ticket_medio,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.gold.fato_vendas f
LEFT JOIN lakehouse_rotaperfume.gold.dim_vendedor v ON v.vendedor_id = f.vendedor_id
GROUP BY f.ano, f.mes, f.vendedor_id, v.nome, v.regiao;

-- ---------- mart_produto_performance ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_produto_performance (
  ano           INT,
  mes           INT,
  sku           STRING,
  marca         STRING,
  categoria     STRING,
  nota_olfativa STRING,
  receita       DECIMAL(18,2),
  margem        DECIMAL(18,2),
  margem_pct    DECIMAL(8,2) COMMENT '100 * margem / receita no grao. NULL quando receita e zero',
  quantidade    DECIMAL(18,2) COMMENT 'Soma de quantidades, com devolucao negativa',
  curva_abc     STRING COMMENT 'A (ate 70% da receita acumulada do mes), B (ate 90%), C (resto)',
  _processado_em TIMESTAMP
)
USING DELTA
COMMENT 'Mart de produto: SKU x mes, com margem percentual e curva ABC por receita acumulada.';

INSERT INTO lakehouse_rotaperfume.gold.mart_produto_performance (
  ano, mes, sku, marca, categoria, nota_olfativa,
  receita, margem, margem_pct, quantidade, curva_abc, _processado_em
)
WITH grupo AS (
  SELECT
    ano, mes, sku, marca, categoria, nota_olfativa,
    sum(receita)    AS receita,
    sum(margem)     AS margem,
    sum(quantidade) AS quantidade
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY ano, mes, sku, marca, categoria, nota_olfativa
)
SELECT
  g.ano, g.mes, g.sku, g.marca, g.categoria, g.nota_olfativa,
  g.receita,
  g.margem,
  CASE WHEN g.receita = 0 THEN NULL ELSE round(100 * g.margem / g.receita, 2) END AS margem_pct,
  g.quantidade,
  c.curva_abc,
  current_timestamp() AS _processado_em
FROM grupo g
LEFT JOIN (
  SELECT
    aux.ano, aux.mes, aux.sku,
    CASE WHEN aux.fracao_acumulada <= 0.70 THEN 'A'
         WHEN aux.fracao_acumulada <= 0.90 THEN 'B'
         ELSE 'C' END AS curva_abc
  FROM (
    SELECT
      ano, mes, sku,
      sum(receita) OVER (PARTITION BY ano, mes ORDER BY receita DESC
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / NULLIF(sum(receita) OVER (PARTITION BY ano, mes), 0) AS fracao_acumulada
    FROM grupo
  ) aux
) c ON c.ano = g.ano AND c.mes = g.mes AND c.sku = g.sku;

-- ---------- mart_financeiro_recebimento ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento (
  mes_vencimento     DATE,
  valor_a_receber    DECIMAL(18,2) COMMENT 'Soma de valor dos titulos com vencimento no mes',
  valor_recebido     DECIMAL(18,2) COMMENT 'Soma de valor dos titulos ja recebidos (data_pagamento preenchida) no mes',
  atraso_medio_dias  DECIMAL(10,2) COMMENT 'Media de dias pagos apos o vencimento. NULL se nada atrasou',
  custo_de_taxa      DECIMAL(18,2) COMMENT 'Soma de valor * (taxa_percent / 100) no mes de vencimento',
  _processado_em     TIMESTAMP
)
USING DELTA
COMMENT 'Mart financeiro: mes de vencimento com saldo a receber, recebido, atraso medio e custo de taxa.';

INSERT INTO lakehouse_rotaperfume.gold.mart_financeiro_recebimento (
  mes_vencimento, valor_a_receber, valor_recebido, atraso_medio_dias, custo_de_taxa, _processado_em
)
SELECT
  date_trunc('month', data_vencimento) AS mes_vencimento,
  round(sum(valor), 2) AS valor_a_receber,
  round(sum(valor) FILTER (WHERE data_pagamento IS NOT NULL), 2) AS valor_recebido,
  round(avg(CASE WHEN data_pagamento IS NOT NULL AND data_pagamento > data_vencimento
                 THEN datediff(data_pagamento, data_vencimento) END), 2) AS atraso_medio_dias,
  round(sum(valor * (taxa_percent / 100)), 2) AS custo_de_taxa,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.pagamentos
GROUP BY date_trunc('month', data_vencimento);