-- Gold.dimensoes conformadas -- quatro dimensoes para consumo direto no dashboard.
-- A gold NAO e "a camada limpa" (isso e a silver). A gold e modelada para um
-- consumidor especifico: cada dimensao tem UMA linha por entidade (constela- \
-- cao de fato unica) e as regras de negocio que a silver deixou de fora ficam
-- aqui, escritas uma vez, com COMMENT.
--
-- Leitura sempre da silver, nunca da bronze. ANSI mode ligado: try_to_date().
--
-- Dimensao conformada = somavel e consistente com o fato. dim_cliente calcula
-- receita/ordens so dos pedidos NAO cancelados, igual ao fato_vendas.

-- ---------- dim_cliente ----------
-- Uma linha por cliente. Indicadores de compra codificados aqui para a
-- analise de RFM nao depender de JOIN com fato todo dia.
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_cliente (
  cliente_id            STRING,
  razao_social          STRING,
  segmento              STRING,
  cidade                STRING,
  uf                    STRING,
  data_cadastro         DATE,
  data_primeiro_pedido  DATE COMMENT 'Primeiro pedido NAO cancelado; NULL para cliente sem pedido valido',
  data_ultimo_pedido    DATE COMMENT 'Ultimo pedido NAO cancelado; NULL para cliente sem pedido',
  total_pedidos         INT    COMMENT 'Pedidos NAO cancelados do cliente',
  receita_acumulada     DECIMAL(18,2) COMMENT 'Soma de valor_liquido dos pedidos NAO cancelados do cliente',
  dias_sem_comprar      INT    COMMENT 'DECISAO: dias desde o ultimo pedido NAO cancelado ate hoje; NULL para cliente que nunca comprou. Coluna vocal para a analise de cadencia/RFM',
  _processado_em        TIMESTAMP
)
USING DELTA
COMMENT 'Clientes conformados, uma linha por cliente, com indicadores de compra para a analise de cadencia.';

INSERT INTO lakehouse_rotaperfume.gold.dim_cliente (
  cliente_id, razao_social, segmento, cidade, uf, data_cadastro,
  data_primeiro_pedido, data_ultimo_pedido, total_pedidos, receita_acumulada,
  dias_sem_comprar, _processado_em
)
SELECT
  c.cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  c.uf,
  c.data_cadastro,
  min(p.data_pedido) AS data_primeiro_pedido,
  max(p.data_pedido) AS data_ultimo_pedido,
  count(p.pedido_id) AS total_pedidos,
  coalesce(sum(p.valor_liquido), 0) AS receita_acumulada,
  datediff(current_date(), max(p.data_pedido)) AS dias_sem_comprar,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.clientes c
LEFT JOIN lakehouse_rotaperfume.silver.pedidos p
       ON p.cliente_id = c.cliente_id
      AND NOT p.cancelado
GROUP BY c.cliente_id, c.razao_social, c.segmento, c.cidade, c.uf, c.data_cadastro;

-- ---------- dim_produto ----------
-- Uma linha por SKU, com o que e intrínseco ao produto e a decisao de
-- descontinuado (derivada da flag ativo da silver).
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_produto (
  sku             STRING,
  descricao       STRING,
  marca           STRING,
  categoria       STRING,
  nota_olfativa   STRING,
  custo_unitario  DECIMAL(18,2),
  preco_tabela    DECIMAL(18,2),
  data_lancamento DATE,
  descontinuado   BOOLEAN COMMENT 'DERIVADO: true quando o produto esta inativo na silver.produtos (nao e mais vendido)'
)
USING DELTA
COMMENT 'Produtos conformados, uma linha por SKU, com marca, categoria, nota olfativa e preco/custo.';

INSERT INTO lakehouse_rotaperfume.gold.dim_produto (
  sku, descricao, marca, categoria, nota_olfativa, custo_unitario,
  preco_tabela, data_lancamento, descontinuado
)
SELECT
  sku, descricao, marca, categoria, nota_olfativa, custo_unitario,
  preco_tabela, data_lancamento, (NOT ativo) AS descontinuado
FROM lakehouse_rotaperfume.silver.produtos;

-- ---------- dim_vendedor ----------
-- Uma linha por vendedor. ativo = vendedor ainda na empresa (sem data de
-- desligamento). meta mensal conform period (meta vs atingimento no mart).
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_vendedor (
  vendedor_id     STRING,
  nome            STRING,
  regiao          STRING,
  uf              STRING,
  data_admissao    DATE,
  data_desligamento DATE,
  meta_mensal      DECIMAL(18,2),
  ativo            BOOLEAN COMMENT 'DERIVADO: true quando o vendedor nao tem data de desligamento'
)
USING DELTA
COMMENT 'Vendedores conformados, com regiao e meta mensal para o mart comercial.';

INSERT INTO lakehouse_rotaperfume.gold.dim_vendedor (
  vendedor_id, nome, regiao, uf, data_admissao, data_desligamento, meta_mensal, ativo
)
SELECT
  vendedor_id, nome, regiao, uf, data_admissao, data_desligamento, meta_mensal,
  (data_desligamento IS NULL) AS ativo
FROM lakehouse_rotaperfume.silver.vendedores;

-- ---------- dim_calendario ----------
-- Uma linha por dia dos 24 meses que cobrem a janela de dados. Serve para a
-- analise responder "o dia X feriado?" ou pivotar por mes de forma conformada.
-- mes_pico_setor e DECISÃO de negocio (nao tecnica): abril, junho e outubro.
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_calendario (
  data            DATE,
  ano             INT,
  mes             INT,
  nome_mes        STRING,
  trimestre       INT,
  dia_da_semana   STRING,
  mes_pico_setor  BOOLEAN COMMENT 'DECISAO: abril, junho e outubro sao os picos sazonais do setor (dia das maes, dos namorados, criancas). TRUE nesses meses'
)
USING DELTA
COMMENT 'Calendario conformado, uma linha por dia dos 24 meses da janela, com a coluna de pico sazonal do setor.';

INSERT INTO lakehouse_rotaperfume.gold.dim_calendario (
  data, ano, mes, nome_mes, trimestre, dia_da_semana, mes_pico_setor
)
WITH bounds AS (
  SELECT
    add_months(date_trunc('month', min(data_pedido)), -23) AS inicio,
    date_trunc('month', max(data_pedido))                     AS fim
  FROM lakehouse_rotaperfume.silver.pedidos
),
dias AS (
  SELECT explode(sequence(to_date(b.inicio), last_day(b.fim), interval 1 day)) AS data
  FROM bounds b
)
SELECT
  d.data,
  year(d.data)   AS ano,
  month(d.data)  AS mes,
  date_format(d.data, 'MMMM') AS nome_mes,
  quarter(d.data) AS trimestre,
  date_format(d.data, 'EEEE') AS dia_da_semana,
  month(d.data) IN (4, 6, 10) AS mes_pico_setor
FROM dias d;