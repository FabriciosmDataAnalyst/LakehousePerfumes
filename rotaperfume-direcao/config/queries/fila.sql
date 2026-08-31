-- fila: os 200 da semana para a tela do diretor. Traz todas as colunas de
-- leitura humana (motivo, sugestao) e o STATUS do retorno mais recente de cada
-- cliente (LEFT JOIN com a ultima linha de retorno_ligacao por cliente).
--
-- Parametro :vendedor — 'Todos' nao filtra (mostra a fila inteira); qualquer
-- outro valor filtra as linhas daquele vendedor.
-- :recarga >= 0 nao filtra nada (força nova consulta após gravação).

-- @param vendedor STRING = Todos
-- @param recarga INT = 0

WITH ultimo_retorno AS (
  SELECT
    cliente_id,
    status,
    registrado_em,
    comentario,
    row_number() OVER (PARTITION BY cliente_id ORDER BY registrado_em DESC) AS rn
  FROM lakehouse_rotaperfume.gold.retorno_ligacao
  WHERE :recarga >= 0
)
SELECT
  f.vendedor,
  f.ordem,
  f.cliente_id,
  f.razao_social,
  f.cidade,
  f.uf,
  f.score,
  f.faixa,
  f.ticket_medio,
  f.motivo,
  f.sugestao,
  f._referencia,
  r.status AS ultimo_status,
  r.registrado_em AS ultimo_retorno_em,
  r.comentario AS ultimo_comentario
FROM lakehouse_rotaperfume.gold.fila_semanal f
LEFT JOIN ultimo_retorno r
  ON r.cliente_id = f.cliente_id AND r.rn = 1
WHERE :vendedor = 'Todos' OR f.vendedor = :vendedor
ORDER BY f.vendedor, f.ordem;