-- Silver.produtos + silver.itens_pedido -- tipos certos e a devolucao sinalizada.
--
-- produtos: tipa numeros e datas, ativo vira boolean.
-- itens_pedido: quantidade negativa NAO e erro, e devolucao. Nao descartamos nada
--   (descartar inflaria o faturamento em +R$1M). Sinalizamos devolucao e
--   guardamos quantidade_abs, deixando quem analisa escolher bruto vs liquido.
--   Tambem marcamos sku_descontinuado (76 itens apontam para produto inativo).
--
-- ANSI mode ligado: try_to_date() sempre.

-- ---------- produtos ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.produtos (
  sku            STRING,
  descricao      STRING,
  categoria      STRING,
  marca          STRING,
  nota_olfativa  STRING,
  preco_tabela   DECIMAL(18,2) COMMENT 'Preco de tabela tipado (era texto na bronze)',
  custo_unitario DECIMAL(18,2),
  unidade        STRING,
  ativo          BOOLEAN COMMENT "'S'/'N' da origem convertido para boolean",
  data_lancamento DATE COMMENT 'via coalesce(try_to_date ISO, try_to_date dd/MM/yyyy)',
  _processado_em TIMESTAMP,
  _linhas_origem LONG
)
USING DELTA
COMMENT 'Produtos limpos: numeros tipados, data padronizada, ativo boolean.';

INSERT INTO lakehouse_rotaperfume.silver.produtos (
  sku, descricao, categoria, marca, nota_olfativa, preco_tabela, custo_unitario,
  unidade, ativo, data_lancamento, _processado_em, _linhas_origem
)
SELECT
  sku, descricao, categoria, marca, nota_olfativa,
  CAST(preco_tabela  AS DECIMAL(18,2)) AS preco_tabela,
  CAST(custo_unitario AS DECIMAL(18,2)) AS custo_unitario,
  unidade,
  (ativo = 'S') AS ativo,
  coalesce(try_to_date(data_lancamento), try_to_date(data_lancamento, 'dd/MM/yyyy')) AS data_lancamento,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.produtos;

-- ---------- itens_pedido ----------
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.itens_pedido (
  item_id         STRING,
  pedido_id          STRING,
  sku                STRING,
  quantidade         INT COMMENT 'Quantidade original (pode ser negativa = devolucao)',
  quantidade_abs     INT COMMENT '|quantidade|: sempre > 0 (constraint). Devolucao vira positiva com a flag abaixo',
  devolucao          BOOLEAN COMMENT 'DERIVADO: true quando quantidade < 0 (2.327 devolucoes). Nao descartamos essas linhas',
  preco_praticado    DECIMAL(18,2),
  desconto_pct       DECIMAL(6,2),
  valor_bruto        DECIMAL(18,2) COMMENT 'Valor bruto do item. Manter tudo (com devolucao) nao altera o faturamento liquido',
  sku_descontinuado  BOOLEAN COMMENT 'DERIVADO: true (76 itens) quando o produto esta inativo na silver.produtos',
  _processado_em     TIMESTAMP,
  _linhas_origem     LONG
)
USING DELTA
COMMENT 'Itens de pedido: devolucao sinalizada (nao descartada), quantidade em absoluto, produto descontinuado marcado.';

INSERT INTO lakehouse_rotaperfume.silver.itens_pedido (
  item_id, pedido_id, sku, quantidade, quantidade_abs, devolucao,
  preco_praticado, desconto_pct, valor_bruto, sku_descontinuado,
  _processado_em, _linhas_origem
)
SELECT
  i.item_id,
  i.pedido_id,
  i.sku,
  CAST(i.quantidade AS INT) AS quantidade,
  abs(CAST(i.quantidade AS INT)) AS quantidade_abs,
  CAST(i.quantidade AS INT) < 0 AS devolucao,
  CAST(i.preco_praticado AS DECIMAL(18,2)) AS preco_praticado,
  CAST(i.desconto_pct AS DECIMAL(6,2)) AS desconto_pct,
  CAST(i.valor_bruto AS DECIMAL(18,2)) AS valor_bruto,
  NOT coalesce(p.ativo, FALSE) AS sku_descontinuado,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.itens_pedido i
LEFT JOIN lakehouse_rotaperfume.silver.produtos p USING (sku);

ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ADD CONSTRAINT quantidade_abs_positiva CHECK (quantidade_abs > 0);