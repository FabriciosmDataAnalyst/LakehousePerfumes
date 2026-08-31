-- vendedores: alimenta o filtro de vendedor na tela. Uma linha por vendedor
-- com o total de contatos dele na fila da semana (para o Select mostrar quantos
-- tem cada um).

SELECT vendedor, COUNT(*) AS contatos
FROM lakehouse_rotaperfume.gold.fila_semanal
GROUP BY vendedor
ORDER BY vendedor;