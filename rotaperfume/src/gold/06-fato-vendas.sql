-- Gold.fato_vendas -- o CONTRATO da venda, escrito antes do SQL.
--
-- GOSTO DE GRANULARIDADE: UMA LINHA POR ITEM DE PEDIDO.
-- FILTRO: exclui pedidos CANCELADOS (envio nao vale). NAO exclui devolucao.
-- DECISAO DE NEGOCIO: a devolucao ENTRA no fato, com quantidade e receita
--   NEGATIVAS e a flag devolucao = true. Se tirassemos de fora, a gold somaria
--   R$ 103,6 mi e a silver R$ 102,3 mi -- R$ 1,26 milhao de divergencia entre
--   duas camadas do mesmo pipeline. Quem quiser o bruto pede:
--     SUM(receita) FILTER (WHERE NOT devolucao)
-- DIMENSOES: data_pedido, ano, mes, canal, cliente_id, razao_social, segmento,
--            cidade, vendedor_id, sku, categoria, marca, nota_olfativa
-- METRICAS:  quantidade, preco_praticado, receita, custo, margem, devolucao
--   custo  = quantidade * custo_unitario do produto
--   margem = receita - custo
-- PARTICIONE por ano e mes.
--
-- Leitura sempre da silver (itens_pedido + pedidos + produtos). ANSI mode ligado.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fato_vendas (
  data_pedido      DATE    COMMENT 'Data do pedido (derivada da silver.pedidos)',
  pedido_id        STRING  COMMENT 'Id do pedido a que o item pertence (granularidade de item, FK de rastreio)',
  ano              INT     COMMENT 'Ano extraido de data_pedido; chave de particao',
  mes              INT     COMMENT 'Mes extraido de data_pedido; chave de particao',
  canal            STRING  COMMENT 'Canal de venda do pedido (E-commerce, Loja, etc)',
  cliente_id       STRING  COMMENT 'Id do cliente comprador',
  razao_social     STRING  COMMENT 'Razao social do cliente comprador',
  segmento         STRING  COMMENT 'Segmento do cliente (varejo, atacado, etc)',
  cidade           STRING  COMMENT 'Cidade do cliente',
  vendedor_id      STRING  COMMENT 'Id do vendedor responsavel; NULL em vendas sem vendedor',
  sku              STRING  COMMENT 'Codigo do produto vendido',
  categoria        STRING  COMMENT 'Categoria do produto',
  marca            STRING  COMMENT 'Marca do produto',
  nota_olfativa    STRING  COMMENT 'Nota olfativa do produto',
  quantidade       INT     COMMENT 'Quantidade (negativa = devolucao)',
  preco_praticado  DECIMAL(18,2) COMMENT 'Preco efetivamente praticado no item',
  receita          DECIMAL(18,2) COMMENT 'quantidade * preco_praticado. Inclui devolucao como valor negativo',
  custo            DECIMAL(18,2) COMMENT 'quantidade * custo_unitario do produto. Negativo junto com a devolucao',
  margem           DECIMAL(18,2) COMMENT 'Receita menos custo do produto. NAO considera desconto comercial nem frete',
  devolucao        BOOLEAN  COMMENT 'true quando o item e devolucao (quantidade negativa). NAO filtrar aqui: use SUM(...) FILTER (WHERE NOT devolucao) para ver so o bruto',
  _processado_em   TIMESTAMP
)
USING DELTA
PARTITIONED BY (ano, mes)
COMMENT 'Contrato de vendas: uma linha por ITEM de pedido, devolucao incluida como valor negativo, particionado por ano e mes.';

INSERT INTO lakehouse_rotaperfume.gold.fato_vendas (
  data_pedido, pedido_id, ano, mes, canal,
  cliente_id, razao_social, segmento, cidade, vendedor_id,
  sku, categoria, marca, nota_olfativa,
  quantidade, preco_praticado, receita, custo, margem, devolucao, _processado_em
)
WITH mapa_cliente AS (
  -- Re-mapeia o id DESCARTADO na dedup por CNPJ para o cliente que sobrou.
  -- Pedidos antigos continuam apontando para o id descartado (guarded em
  -- cliente_ids_duplicados); sem esse Mapa o fato perderia essas vendas.
  SELECT
    expl.value AS cliente_descartado,
    c.cliente_id AS cliente_canonico
  FROM lakehouse_rotaperfume.silver.clientes c
  LATERAL VIEW explode(c.cliente_ids_duplicados) expl AS value
)
SELECT
  p.data_pedido,
  p.pedido_id,
  p.ano,
  p.mes,
  p.canal,
  c.cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  p.vendedor_id,
  pr.sku,
  pr.categoria,
  pr.marca,
  pr.nota_olfativa,
  i.quantidade,
  i.preco_praticado,
  i.quantidade * i.preco_praticado        AS receita,
  i.quantidade * pr.custo_unitario                        AS custo,
  i.quantidade * i.preco_praticado
    - i.quantidade * pr.custo_unitario                    AS margem,
  i.devolucao,
  current_timestamp()                                     AS _processado_em
FROM lakehouse_rotaperfume.silver.itens_pedido i
JOIN lakehouse_rotaperfume.silver.pedidos  p  ON p.pedido_id = i.pedido_id
JOIN lakehouse_rotaperfume.silver.produtos pr ON pr.sku = i.sku
LEFT JOIN mapa_cliente m ON m.cliente_descartado = p.cliente_id
JOIN lakehouse_rotaperfume.silver.clientes c  ON c.cliente_id = coalesce(m.cliente_canonico, p.cliente_id)
WHERE NOT p.cancelado;