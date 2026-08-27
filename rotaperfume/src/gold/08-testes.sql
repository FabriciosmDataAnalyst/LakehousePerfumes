-- Gold.testes -- os 9 testes de qualidade que interrompem o job quando falham.
-- Cada teste e um SELECT que, numa condicao de FALHA, levanta excecao com
-- raise_error() dentro de um CASE WHEN ... THEN 'PASSOU' ELSE raise_error(...).
-- raise_error retorna tipo NOTHING: por isso ele sempre fica no ELSE do CASE.
-- Se qualquer teste falhar, a tarefa testes quebra e o job para - o dashboard
-- fica com o dado de ontem, nunca com o dado errado de hoje.

-- teste_1: receita da gold = receita da silver = R$ 102.303.828,05 (tol 0,01)
-- O teste que mais importa: limpeza NAO pode mudar o faturamento.
WITH calc AS (
  SELECT
    (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas) AS gold,
    (SELECT round(sum(i.quantidade * i.preco_praticado), 2)
       FROM lakehouse_rotaperfume.silver.itens_pedido i
       JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = i.pedido_id
      WHERE NOT p.cancelado) AS silver,
    102303828.05 AS esperado
)
SELECT 'teste_1' AS nome,
       CAST(calc.gold AS STRING)  AS calculado,
       CAST(calc.esperado AS STRING) AS esperado,
       CASE WHEN abs(calc.gold - calc.silver) <= 0.01
             AND abs(calc.gold - calc.esperado) <= 0.01 THEN 'PASSOU'
            ELSE raise_error('teste_1 falhou: receita da gold diferente da silver') END AS resultado
FROM calc;

-- teste_2: CNPJ unico na silver.clientes (0 duplicados)
SELECT 'teste_2' AS nome,
       CAST((SELECT count(*) FROM (
              SELECT cnpj FROM lakehouse_rotaperfume.silver.clientes
              GROUP BY cnpj HAVING count(*) > 1
            ) d) AS STRING) AS duplicados,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM (
                   SELECT cnpj FROM lakehouse_rotaperfume.silver.clientes
                   GROUP BY cnpj HAVING count(*) > 1
                 ) d) = 0 THEN 'PASSOU'
            ELSE raise_error('teste_2 falhou: existe CNPJ duplicado na silver.clientes') END AS resultado;

-- teste_3: nenhuma data_pedido nula na silver.pedidos
SELECT 'teste_3' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.silver.pedidos WHERE data_pedido IS NULL) AS STRING) AS nulos,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.silver.pedidos WHERE data_pedido IS NULL) = 0
            THEN 'PASSOU'
            ELSE raise_error('teste_3 falhou: existe data_pedido nula na silver.pedidos') END AS resultado;

-- teste_4: receita negativa so onde devolucao = true
SELECT 'teste_4' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas
              WHERE receita < 0 AND NOT devolucao) AS STRING) AS negativos_sem_devolucao,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas
                   WHERE receita < 0 AND NOT devolucao) = 0 THEN 'PASSOU'
            ELSE raise_error('teste_4 falhou: existe receita negativa sem devolucao no fato') END AS resultado;

-- teste_5: volume da gold.fato_vendas entre 140.000 e 250.000 linhas
SELECT 'teste_5' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas) AS STRING) AS linhas,
       '[140000, 250000]' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas) BETWEEN 140000 AND 250000
            THEN 'PASSOU'
            ELSE raise_error('teste_5 falhou: volume do fato fora de 140000..250000') END AS resultado;

-- teste_6: nenhum pedido_id na gold que nao exista na silver.pedidos
SELECT 'teste_6' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f
              LEFT JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = f.pedido_id
             WHERE p.pedido_id IS NULL) AS STRING) AS orfaos,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f
                   LEFT JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = f.pedido_id
                  WHERE p.pedido_id IS NULL) = 0 THEN 'PASSOU'
            ELSE raise_error('teste_6 falhou: existe pedido_id orfao no fato') END AS resultado;

-- teste_7: nenhum cliente_id na gold que nao exista na silver.clientes
SELECT 'teste_7' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f
              LEFT JOIN lakehouse_rotaperfume.silver.clientes c ON c.cliente_id = f.cliente_id
             WHERE c.cliente_id IS NULL) AS STRING) AS orfaos,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f
                   LEFT JOIN lakehouse_rotaperfume.silver.clientes c ON c.cliente_id = f.cliente_id
                  WHERE c.cliente_id IS NULL) = 0 THEN 'PASSOU'
            ELSE raise_error('teste_7 falhou: existe cliente_id orfao no fato') END AS resultado;

-- teste_8: mart_produto_performance soma o mesmo que fato_vendas (conformidade)
WITH calc AS (
  SELECT
    (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas) AS fato,
    (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.mart_produto_performance) AS mart
)
SELECT 'teste_8' AS nome,
       CAST(calc.fato AS STRING)  AS fato,
       CAST(calc.mart AS STRING)  AS mart,
       CASE WHEN abs(calc.fato - calc.mart) <= 0.01 THEN 'PASSOU'
            ELSE raise_error('teste_8 falhou: mart_produto_performance soma diferente do fato') END AS resultado
FROM calc;

-- teste_9: todo CNPJ com exatamente 14 digitos na silver.clientes
SELECT 'teste_9' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.silver.clientes WHERE length(cnpj) <> 14) AS STRING) AS invalidos,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.silver.clientes WHERE length(cnpj) <> 14) = 0
            THEN 'PASSOU'
            ELSE raise_error('teste_9 falhou: existe CNPJ sem 14 digitos') END AS resultado;