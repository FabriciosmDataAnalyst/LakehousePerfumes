-- Gold.auditoria-de-metadado -- modo do fechamento: metadado faltando e BUG.
--
-- Metadado NAO e documentacao para humano ler: e o que o agente (Genie) le
-- para decidir qual coluna usar. Uma coluna chamada `vl_liq` sem COMMENT e uma
-- coluna que o agente vai errar. A partir desta entrega existe um agente lendo
-- cada comentario para decidir qual coluna usar.
--
-- Esta tarefa consulta information_schema e QUEBRA (raise_error) se:
--   1) ha tabela ou view da gold sem COMMENT
--   2) ha coluna sem COMMENT em fato_vendas ou nas 6 views de negocio
--      (receita_mensal, ranking_marcas, margem_por_categoria,
--       clientes_em_risco, efeito_lancamento, ruptura_por_marca)
-- Ao final imprime um relatorio de cobertura de metadado por objeto, SEM
-- quebrar -- serve para a conversa com quem vai consumir a gold.
--
-- Mesmo padrao dos testes (08-testes.sql): raise_error no ELSE do CASE.

-- ---------- auditoria_1 ----------
-- Todo objeto da gold (tabela ou view) tem COMMENT.
SELECT 'auditoria_1' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.information_schema.tables
              WHERE table_schema = 'gold'
                AND (comment IS NULL OR comment = '')) AS STRING) AS objetos_sem_comentario,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.information_schema.tables
                   WHERE table_schema = 'gold'
                     AND (comment IS NULL OR comment = '')) = 0
            THEN 'PASSOU'
            ELSE raise_error('auditoria_1 falhou: existe tabela ou view da gold sem COMMENT') END AS resultado;

-- ---------- auditoria_2 ----------
-- Toda coluna de fato_vendas e das 6 views de negocio tem COMMENT.
SELECT 'auditoria_2' AS nome,
       CAST((SELECT count(*) FROM lakehouse_rotaperfume.information_schema.columns
              WHERE table_schema = 'gold'
                AND (table_name = 'fato_vendas'
                     OR table_name IN ('receita_mensal', 'ranking_marcas',
                                       'margem_por_categoria', 'clientes_em_risco',
                                       'efeito_lancamento', 'ruptura_por_marca'))
                AND (comment IS NULL OR comment = '')) AS STRING) AS colunas_sem_comentario,
       '0' AS esperado,
       CASE WHEN (SELECT count(*) FROM lakehouse_rotaperfume.information_schema.columns
                   WHERE table_schema = 'gold'
                     AND (table_name = 'fato_vendas'
                          OR table_name IN ('receita_mensal', 'ranking_marcas',
                                            'margem_por_categoria', 'clientes_em_risco',
                                            'efeito_lancamento', 'ruptura_por_marca'))
                     AND (comment IS NULL OR comment = '')) = 0
            THEN 'PASSOU'
            ELSE raise_error('auditoria_2 falhou: existe coluna sem COMMENT em fato_vendas ou nas views de negocio') END AS resultado;

-- ---------- relatorio de cobertura ----------
-- Nao quebra: imprime, objeto por objeto, quantas colunas tem e quantas
-- estao comentadas, com o percentual de cobertura.
SELECT c.table_name AS objeto,
       count(*)                                                          AS colunas,
       count(*) FILTER (WHERE c.comment IS NOT NULL AND c.comment <> '') AS comentadas,
       round(100.0
             * count(*) FILTER (WHERE c.comment IS NOT NULL AND c.comment <> '')
             / count(*), 1)                                             AS cobertura_pct
FROM lakehouse_rotaperfume.information_schema.columns c
WHERE c.table_schema = 'gold'
GROUP BY c.table_name
ORDER BY cobertura_pct, c.table_name;