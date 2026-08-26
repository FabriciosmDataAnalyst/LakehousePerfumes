-- Silver.pedidos -- data normalizada, valor tipado, cancelamento e liquido.
-- A bronze guarda data_pedido em dois formatos (ISO e dd/MM/yyyy) e valor_total
-- como texto. Pedido cancelado chega com valor zerado e sem flag clara: aqui
-- expomos o cancelamento e o valor liquido (zero quando cancelado).
--
-- ANSI mode ligado neste workspace: usamos try_to_date() sempre, nunca to_date().

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pedidos (
  pedido_id      STRING,
  cliente_id     STRING,
  vendedor_id    STRING,
  data_pedido    DATE   COMMENT 'Data do pedido via coalesce(try_to_date ISO, try_to_date dd/MM/yyyy): nenhum formato fica para tras',
  canal          STRING,
  status         STRING COMMENT 'Status original da origem (Cancelado, Entregue, Faturado, Em separacao)',
  valor_total    DECIMAL(18,2) COMMENT 'Valor bruto do pedido como veio da origem, tipado',
  cancelado      BOOLEAN COMMENT 'DERIVADO: true quando status = Cancelado (vieram 957 assim)',
  valor_liquido  DECIMAL(18,2) COMMENT 'ZERO quando cancelado; valor_total caso contrario. Cancelado tem que bater 0 (constraint)',
  ano            INT COMMENT 'Ano extraido de data_pedido',
  mes            INT COMMENT 'Mes extraido de data_pedido',
  _processado_em TIMESTAMP,
  _linhas_origem LONG
)
USING DELTA
COMMENT 'Pedidos limpos: data em um formato, valor tipado, cancelado e valor_liquido explicitos.';

INSERT INTO lakehouse_rotaperfume.silver.pedidos (
  pedido_id, cliente_id, vendedor_id, data_pedido, canal, status, valor_total,
  cancelado, valor_liquido, ano, mes, _processado_em, _linhas_origem
)
WITH base AS (
  SELECT
    pedido_id, cliente_id, vendedor_id, canal, status,
    coalesce(try_to_date(data_pedido), try_to_date(data_pedido, 'dd/MM/yyyy')) AS data_pedido,
    CAST(valor_total AS DECIMAL(18,2)) AS valor_total
  FROM lakehouse_rotaperfume.bronze.pedidos
)
SELECT
  pedido_id, cliente_id, vendedor_id, data_pedido, canal, status, valor_total,
  (status = 'Cancelado') AS cancelado,
  CASE WHEN status = 'Cancelado' THEN 0.00 ELSE valor_total END AS valor_liquido,
  year(data_pedido) AS ano,
  month(data_pedido) AS mes,
  current_timestamp() AS _processado_em,
  1 AS _linhas_origem
FROM base;

ALTER TABLE lakehouse_rotaperfume.silver.pedidos ADD CONSTRAINT data_pedido_obrigatoria CHECK (data_pedido IS NOT NULL);
-- ATENCAO: nao usar valor_liquido >= 0. 135 pedidos legitimos tem saldo negativo
-- por conter item devolvido. A regra certa so obriga cancelado a ter valor ZERO.
ALTER TABLE lakehouse_rotaperfume.silver.pedidos ADD CONSTRAINT cancelado_zera_valor CHECK (NOT cancelado OR valor_liquido = 0);