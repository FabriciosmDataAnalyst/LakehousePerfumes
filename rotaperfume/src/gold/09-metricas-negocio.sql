-- Gold.metricas-de-negocio -- seis views que falam a lingua da diretoria.
--
-- A gold ate aqui tinha nome de engenheiro: dim_*, fato_vendas, mart_*. Ninguem
-- da diretoria pergunta por `mart_produto_performance`; perguntam "quais marcas
-- estao vendendo" e "quem parou de comprar". Estas views existem para que o
-- nome da pergunta e o nome da tabela sejam o mesmo.
--
-- O COMMENT de cada view diz a PERGUNTA DE NEGOCIO que ela responde (nao o que
-- ela e). E assim que o Genie decide onde procurar. Usamos a forma compacta
-- CREATE OR REPLACE VIEW nome (col COMMENT '...', ...) para comentar toda
-- coluna sem um ALTER por coluna.
--
-- Regra de negocio embutida aqui que o modelo nao tem como adivinhar: a
-- SAZONALIDADE INVERTIDA. O pico da distribuidora e o mes ANTERIOR a data
-- comemorativa (o varejo compra antes). Abril, junho e outubro sao picos;
-- dezembro e janeiro sao VALE, por desenho do setor.
--
-- Sem CAST, sem try_to_date: a gold ja saiu limpa da silver. Leitura sempre
-- da gold (fato + dimensoes) e da silver so onde a gold nao tem (estoque).

-- ---------- receita_mensal ----------
-- Receita, margem e pedidos por mes, com o pico do setor vindo da dimensao.
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.receita_mensal (
  ano              COMMENT 'Ano da venda',
  mes              COMMENT 'Mes da venda (1-12)',
  mes_pico_setor          COMMENT 'DECISAO de negocio vinda da dim_calendario: abril, junho e outubro sao picos do setor (o varejo compra antes da data comemorativa). Dezembro e janeiro sao vale, por desenho',
  receita    COMMENT 'Soma de receita do mes, com devolucao incluida como valor negativo',
  margem    COMMENT 'Soma de margem (receita menos custo) do mes',
  pedidos              COMMENT 'Pedidos distintos (nunca cancelados) no mes'
)
COMMENT 'Qual e a receita e a margem da empresa a cada mes, e quais meses sao pico do setor?'
AS
SELECT
  f.ano,
  f.mes,
  min(c.mes_pico_setor) AS mes_pico_setor,
  round(sum(f.receita), 2)     AS receita,
  round(sum(f.margem), 2)      AS margem,
  count(DISTINCT f.pedido_id)  AS pedidos
FROM lakehouse_rotaperfume.gold.fato_vendas f
JOIN lakehouse_rotaperfume.gold.dim_calendario c ON c.data = f.data_pedido
GROUP BY f.ano, f.mes;

-- ---------- ranking_marcas ----------
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.ranking_marcas (
  marca         COMMENT 'Marca do produto',
  receita  COMMENT 'Receita total da marca, devolucao incluida como negativa',
  margem_pct   COMMENT 'Margem percentual da marca: 100 * margem / receita',
  participacao_pct   COMMENT 'Participacao da marca na receita total da empresa'
)
COMMENT 'Quais marcas mais vendem, quanto a empresa ganha com cada uma e qual o peso de cada marca na receita toda?'
AS
WITH agg AS (
  SELECT
    marca,
    sum(receita) AS receita,
    sum(margem)  AS margem
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY marca
)
SELECT
  marca,
  round(receita, 2) AS receita,
  round(100 * margem / NULLIF(receita, 0), 2)  AS margem_pct,
  round(100 * receita / NULLIF(sum(receita) OVER (), 0), 2) AS participacao_pct
FROM agg;

-- ---------- margem_por_categoria ----------
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.margem_por_categoria (
  categoria        COMMENT 'Categoria do produto',
  receita COMMENT 'Receita total da categoria, devolucao incluida como negativa',
  margem COMMENT 'Margem total da categoria (receita menos custo)',
  margem_pct  COMMENT 'Margem percentual da categoria: 100 * margem / receita'
)
COMMENT 'Qual categoria vende muito e ganha pouco? (o ranking crescente expoe onde a margem percentual esta erodida)'
AS
WITH agg AS (
  SELECT
    categoria,
    sum(receita) AS receita,
    sum(margem)  AS margem
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY categoria
)
SELECT
  categoria,
  round(receita, 2)         AS receita,
  round(margem, 2)          AS margem,
  round(100 * margem / NULLIF(receita, 0), 2) AS margem_pct
FROM agg;

-- ---------- clientes_em_risco ----------
-- Clientes sem compra ha mais de 90 dias, com o quanto compravam por mes
-- antes de sumirem. Cobre a pergunta "quem parou de comprar e quanto isso custa".
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.clientes_em_risco (
  cliente_id        COMMENT 'Id do cliente',
  razao_social        COMMENT 'Razao social do cliente',
  segmento        COMMENT 'Segmento do cliente (varejo, atacado, etc)',
  cidade        COMMENT 'Cidade do cliente',
  dias_sem_comprar           COMMENT 'Dias desde o ultimo pedido nao cancelado ate hoje; sempre acima de 90',
  data_ultimo_pedido          COMMENT 'Data do ultimo pedido nao cancelado',
  meses_comprados           COMMENT 'Quantos meses distintos o cliente comprou no historico',
  receita_media_mensal COMMENT 'Quanto o cliente comprava por mes antes de sumir (receita total / meses comprados)'
)
COMMENT 'Quais clientes pararam de comprar ha mais de 90 dias e quanto de receita mensal cada um representava?'
AS
SELECT
  c.cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  c.dias_sem_comprar,
  c.data_ultimo_pedido,
  count(DISTINCT date_trunc('month', f.data_pedido))                AS meses_comprados,
  round(sum(f.receita)
        / NULLIF(count(DISTINCT date_trunc('month', f.data_pedido)), 0), 2) AS receita_media_mensal
FROM lakehouse_rotaperfume.gold.dim_cliente c
LEFT JOIN lakehouse_rotaperfume.gold.fato_vendas f ON f.cliente_id = c.cliente_id
WHERE c.dias_sem_comprar IS NOT NULL
  AND c.dias_sem_comprar > 90
GROUP BY c.cliente_id, c.razao_social, c.segmento, c.cidade,
         c.dias_sem_comprar, c.data_ultimo_pedido;

-- ---------- efeito_lancamento ----------
-- Receita dos SKUs nos 120 dias apos o lancamento contra o resto do periodo.
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.efeito_lancamento (
  sku        COMMENT 'Codigo do produto lancado',
  descricao        COMMENT 'Descricao do produto',
  marca        COMMENT 'Marca do produto',
  data_lancamento          COMMENT 'Data oficial de lancamento do produto',
  receita_periodo_lancamento COMMENT 'Receita do SKU nos primeiros 120 dias apos o lancamento',
  receita_restante COMMENT 'Receita do SKU fora da janela de 120 dias do lancamento',
  receita_lancamento_pct  COMMENT 'Porcentagem da receita total que veio do periodo de lancamento'
)
COMMENT 'Um produto recem-lancado vende mais nos primeiros 120 dias do que depois? (mede se o lancamento tem impulsionamento)'
AS
SELECT
  p.sku,
  p.descricao,
  p.marca,
  p.data_lancamento,
  round(sum(f.receita) FILTER (
    WHERE f.data_pedido >= p.data_lancamento
      AND f.data_pedido <  date_add(p.data_lancamento, 120)), 2) AS receita_periodo_lancamento,
  round(sum(f.receita) FILTER (
    WHERE f.data_pedido <  p.data_lancamento
      OR  f.data_pedido >= date_add(p.data_lancamento, 120)), 2) AS receita_restante,
  round(100 * sum(f.receita) FILTER (
    WHERE f.data_pedido >= p.data_lancamento
      AND f.data_pedido <  date_add(p.data_lancamento, 120))
    / NULLIF(sum(f.receita), 0), 2) AS receita_lancamento_pct
FROM lakehouse_rotaperfume.gold.fato_vendas f
JOIN lakehouse_rotaperfume.gold.dim_produto p ON p.sku = f.sku
WHERE p.data_lancamento IS NOT NULL
GROUP BY p.sku, p.descricao, p.marca, p.data_lancamento;

-- ---------- ruptura_por_marca ----------
-- Porcentagem dos snapshots diarios em que a marca ficou sem estoque.
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.ruptura_por_marca (
  marca        COMMENT 'Marca do produto',
  snapshots           COMMENT 'Quantos snapshots diarios de estoque a marca tem no historico',
  snapshots_em_ruptura           COMMENT 'Snapshots em que algum SKU da marca estava com saldo zero (ruptura)',
  ruptura_pct  COMMENT 'Porcentagem dos snapshots da marca em ruptura'
)
COMMENT 'Quais marcas mais vezes ficaram sem estoque (ruptura) nos snapshots diarios, ou seja, com venda na mao perdida?'
AS
SELECT
  p.marca,
  count(*)                          AS snapshots,
  count(*) FILTER (WHERE e.ruptura) AS snapshots_em_ruptura,
  round(100 * count(*) FILTER (WHERE e.ruptura) / count(*), 2) AS ruptura_pct
FROM lakehouse_rotaperfume.silver.estoque e
JOIN lakehouse_rotaperfume.gold.dim_produto p ON p.sku = e.sku
GROUP BY p.marca;