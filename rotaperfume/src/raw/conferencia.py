# Databricks notebook source
# COMMAND ----------

# Conferencia de chegada da camada raw.
# Confere que os 10 arquivos esperados chegaram ao Volume, grava uma tabela de
# controle em bronze._raw_arquivos e falha se faltar arquivo ou vier vazio.

import pyspark.sql.functions as F
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

# COMMAND ----------

CATALOG = dbutils.widgets.get("catalog")
VOLUME = f"/Volumes/{CATALOG}/bronze/raw"
CTRL_TABLE = f"{CATALOG}.bronze._raw_arquivos"

ERPS = ["produtos", "pedidos", "itens_pedido", "pagamentos", "estoque"]
CRMS = ["clientes", "vendedores", "carteira", "oportunidades", "visitas"]

print(f"Catalogo : {CATALOG}")
print(f"Volume   : {VOLUME}")

# COMMAND ----------

# COMMAND ----------

def _listar(prefixo: str):
    # LIST e nativo do Unity Catalog e funciona em qualquer compute (incl. serverless).
    try:
        rows = spark.sql(f"LIST '{prefixo}'").collect()
        return [(r["name"], r["size"]) for r in rows]
    except Exception as exc:
        raise RuntimeError(f"Falha ao listar {prefixo}: {exc}") from exc

def _linhas(arquivo: str):
    # Conta linhas de dado de um CSV no Volume. Sem inferSchema: basta contar e
    # evita quebra por coluna com tipos mistos em arquivos grandes.
    try:
        df = spark.read.csv(arquivo, header=True)
        return df.count()
    except Exception as exc:
        raise RuntimeError(f"Falha ao ler {arquivo}: {exc}") from exc

# COMMAND ----------

registros = []

for sistema, nomes in (("erp", ERPS), ("crm", CRMS)):
    prefixo = f"/Volumes/{CATALOG}/bronze/raw/{sistema}"
    arquivos_no_volume = {nome.rsplit(".", 1)[0] for nome, _ in _listar(prefixo)}
    for nome in nomes:
        arquivo = f"{prefixo}/{nome}.csv"
        if nome not in arquivos_no_volume:
            raise RuntimeError(f"Faltou o arquivo: {arquivo}")
        linhas = _linhas(arquivo)
        if linhas == 0:
            raise RuntimeError(f"Arquivo vazio: {arquivo}")
        info = next(i for i in _listar(prefixo) if i[0].rsplit(".", 1)[0] == nome)
        registros.append((sistema, nome, info[1], linhas))

# COMMAND ----------

ctrl = spark.createDataFrame(
    registros,
    schema="sistema STRING, arquivo STRING, bytes LONG, linhas LONG",
).withColumn("conferido_em", F.current_timestamp())

# COMMAND ----------

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.bronze")
spark.sql(f"""
CREATE OR REPLACE TABLE {CTRL_TABLE} (
  sistema      STRING COMMENT 'Sistema de origem (erp|crm)',
  arquivo      STRING COMMENT 'Nome do arquivo (sem extensao)',
  bytes        LONG   COMMENT 'Tamanho em bytes no Volume',
  linhas       LONG   COMMENT 'Quantidade de linhas de dado',
  conferido_em TIMESTAMP COMMENT 'Quando a conferencia rodou'
)
USING DELTA
COMMENT 'Controle de chegada dos arquivos raw no Volume'
""")

ctrl.write.mode("overwrite").saveAsTable(CTRL_TABLE)

# COMMAND ----------

print("Conferencia de chegada concluida:")
ctrl.orderBy(F.col("linhas").desc()).show(truncate=False)

total = ctrl.agg(
    F.count(F.lit(1)).alias("arquivos"),
    F.sum("linhas").alias("linhas_de_dado"),
    F.round(F.sum("bytes") / 1024 / 1024, 1).alias("mb"),
).collect()[0]
print(f"Total: {total['arquivos']} arquivos, {total['linhas_de_dado']} linhas, {total['mb']} MB")