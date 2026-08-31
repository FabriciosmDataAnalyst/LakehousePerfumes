-- acompanhamento: por vendedor, quantos clientes tem na fila (na_fila) e quantos
-- retornos ja foram registrados (trabalhados), com a contagem de cada status.
-- Parametro :vendedor — 'Todos' nao filtra.

-- @param vendedor STRING = Todos
WITH fila AS (
  SELECT
    vendedor,
    COUNT(*) AS na_fila
  FROM lakehouse_rotaperfume.gold.fila_semanal
  GROUP BY vendedor
),
retorno AS (
  SELECT
    vendedor,
    COUNT(*) AS trabalhados,
    COUNT(CASE WHEN status = 'vendeu' THEN 1 END) AS vendeu,
    COUNT(CASE WHEN status = 'vai_pensar' THEN 1 END) AS vai_pensar,
    COUNT(CASE WHEN status = 'sem_interesse' THEN 1 END) AS sem_interesse,
    COUNT(CASE WHEN status = 'nao_atendeu' THEN 1 END) AS nao_atendeu
  FROM lakehouse_rotaperfume.gold.retorno_ligacao
  GROUP BY vendedor
)
SELECT
  f.vendedor,
  f.na_fila,
  COALESCE(r.trabalhados, 0) AS trabalhados,
  COALESCE(r.vendeu, 0)      AS vendeu,
  COALESCE(r.vai_pensar, 0)  AS vai_pensar,
  COALESCE(r.sem_interesse, 0) AS sem_interesse,
  COALESCE(r.nao_atendeu, 0) AS nao_atendeu
FROM fila f
LEFT JOIN retorno r ON r.vendedor = f.vendedor
WHERE :vendedor = 'Todos' OR f.vendedor = :vendedor
ORDER BY f.na_fila DESC, f.vendedor;