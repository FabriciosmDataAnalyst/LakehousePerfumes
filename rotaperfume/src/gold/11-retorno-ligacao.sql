-- Gold · retorno_ligacao — o caminho de volta
--
-- REGRA FUNDAMENTAL: CREATE TABLE IF NOT EXISTS, NUNCA CREATE OR REPLACE.
-- Esta é a ÚNICA tabela do projeto cujo dado não vem do pipeline — vem do time
-- de vendas (o que aconteceu depois da ligação). Um redeploy não pode apagar
-- o que o vendedor respondeu.
--
-- A tarefa roda depois de gold_marts, independente de testes. Se a tabela já
-- existe e tem dados, a tarefa passa sem tocar neles.

CREATE TABLE IF NOT EXISTS lakehouse_rotaperfume.gold.retorno_ligacao (
  cliente_id      INT        COMMENT 'Identificador do cliente, o mesmo de gold.dim_cliente e gold.fila_semanal.',
  vendedor        STRING     COMMENT 'Nome do vendedor que realizou o contato, exatamente como em gold.fila_semanal.',
  status          STRING     COMMENT 'Resultado do contato: vendeu | vai_pensar | sem_interesse | nao_atendeu.',
  comentario      STRING     COMMENT 'Texto livre do vendedor com observacoes sobre o contato.',
  registrado_em   TIMESTAMP  COMMENT 'Quando o retorno foi registrado. Para o estado atual do cliente, use o registro mais recente por este campo.',
  registrado_por  STRING     COMMENT 'E-mail de quem estava logado no momento do registro.',
  _referencia     DATE       COMMENT 'A semana da fila que gerou o contato (data de corte de gold.fila_semanal).'
)
USING DELTA
COMMENT 'Registro do que aconteceu depois de cada ligacao da fila semanal. Dado inserido pelo time de vendas, nao pelo pipeline. Comeca vazia: zero linhas e o estado correto no inicio da semana. Um cliente pode ter mais de um retorno; para o estado atual use o mais recente por registrado_em.';
