-- Gold.retorno_ligacao -- o CAMINHO DE VOLTA: o que aconteceu depois da ligacao.
--
-- Ate aqui toda a gold nasceu do pipeline. Esta tabela e a EXCECAO: o dado
-- nasce no campo, na mao do time. Por isso ela usa CREATE TABLE IF NOT EXISTS
-- e NUNCA CREATE OR REPLACE: o redeploy nao pode apagar o que o vendedor
-- respondeu. Nao ha INSERT aqui -- quem grava e o sistema de CRM depois que a
-- ligacao acontece.
--
-- O Genie (space da direcao) le o COMMENT desta tabela e de cada coluna para
-- saber o que e status, o que e comentario e o que e a referencia da semana.
-- Metadado faltando e BUG (a auditoria_de_metadado quebra o job).

CREATE TABLE IF NOT EXISTS lakehouse_rotaperfume.gold.retorno_ligacao (
  cliente_id      INT         COMMENT 'Id do cliente que recebeu a ligacao (usa a mesma chave da fila_semanal e do score_propensao)',
  vendedor        STRING      COMMENT 'Nome do vendedor que fez a ligacao',
  status          STRING      COMMENT 'Resultado registrado apos a ligacao: vendeu, vai_pensar, sem_interesse ou nao_atendeu',
  comentario      STRING      COMMENT 'Texto livre do vendedor sobre a conversa',
  registrado_em   TIMESTAMP   COMMENT 'Quando o registro foi gravado no sistema',
  registrado_por  STRING      COMMENT 'E-mail de quem estava logado quando registrou o retorno',
  _referencia     DATE        COMMENT 'Data da fila de origem (a coluna _referencia de fila_semanal) -- uma linha por semana, para saber de qual fila cada retorno veio'
)
USING DELTA
COMMENT 'O que aconteceu depois da ligacao da fila da semana: status (vendeu, vai_pensar, sem_interesse, nao_atendeu), comentario do vendedor e de quem registrou. Nasce VAZIA; o time registra a mao, o pipeline nunca escreve aqui.';