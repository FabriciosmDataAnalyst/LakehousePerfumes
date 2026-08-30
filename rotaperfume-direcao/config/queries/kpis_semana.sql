-- kpis_semana: os números do topo da tela do diretor, resumidos numa linha.
--   contatos / vendedores = os 200 da fila esta semana
--   receita_esperada      = SUM(score * ticket_medio) a fila — ESTIMATIVA, nunca receita realizada
--   referencia            = quando a fila da semana foi gerada
--   acertos/lift/taxa     = metrica da ULTIMA versao do modelo
--   retornos              = quantas ligacoes o time ja registrou em gold.retorno_ligacao

SELECT
  MAX(f.contatos)            AS contatos,
  MAX(f.vendedores)          AS vendedores,
  MAX(f.receita_esperada)    AS receita_esperada,
  MAX(f.referencia)          AS referencia,
  MAX(m.acertos_top200)      AS acertos_top200,
  MAX(m.lift_top200)         AS lift_top200,
  MAX(m.taxa_base)           AS taxa_base,
  MAX(r.retornos)            AS retornos,
  MAX(r.viraram_pedido)      AS viraram_pedido
FROM (
  SELECT
    COUNT(*)                        AS contatos,
    COUNT(DISTINCT vendedor)        AS vendedores,
    ROUND(SUM(score * ticket_medio), 2) AS receita_esperada,
    CAST(MAX(_gerada_em) AS DATE)   AS referencia
  FROM lakehouse_rotaperfume.gold.fila_semanal
) f
CROSS JOIN (
  SELECT
    acertos_top200,
    lift_top200,
    taxa_base
  FROM (
    SELECT
      acertos_top200,
      lift_top200,
      taxa_base,
      row_number() OVER (ORDER BY versao DESC) AS rn
    FROM lakehouse_rotaperfume.gold.modelo_metricas
  )
  WHERE rn = 1
) m
CROSS JOIN (
  SELECT
    COUNT(*) AS retornos,
    COUNT(CASE WHEN status = 'vendeu' THEN 1 END) AS viraram_pedido
  FROM lakehouse_rotaperfume.gold.retorno_ligacao
) r
LIMIT 1;