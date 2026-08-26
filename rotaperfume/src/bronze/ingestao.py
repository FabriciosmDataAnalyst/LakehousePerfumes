# Databricks notebook source
# COMMAND ----------

# Ingestion da camada bronze.
# Le os 10 CSVs do Volume (raw) e grava {catalog}.bronze.{tabela} em Delta.
# REGRA DA BRONZE: nenhuma limpeza, nenhuma conversao de tipo. Tudo entra como
# texto de proposito (sem inferSchema). A unica coisa adicionada e metadado
# tecnico: _ingerido_em e _arquivo_origem.

import pyspark.sql.functions as F
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

# COMMAND ----------

CATALOG = dbutils.widgets.get("catalog")
VOLUME = f"/Volumes/{CATALOG}/bronze/raw"
BRONZE = f"{CATALOG}.bronze"

ERPS = ["produtos", "pedidos", "itens_pedido", "pagamentos", "estoque"]
CRMS = ["clientes", "vendedores", "carteira", "oportunidades", "visitas"]

print(f"Catalogo : {CATALOG}")
print(f"Volume   : {VOLUME}")

# COMMAND ----------

def _ingestao(sistema: str, tabela: str):
    arquivo = f"{VOLUME}/{sistema}/{tabela}.csv"
    # CRLF e header. Sem multiLine, sem inferSchema: tudo string, de proposito.
    df = spark.read.csv(arquivo, header=True)

    # O leitor de arquivo do Databricks pode criar _rescued_data sozinho; descarta.
    if "_rescued_data" in df.columns:
        df = df.select(*[c for c in df.columns if c != "_rescued_data"])

    df = df.withColumn("_ingerido_em", F.current_timestamp()).withColumn("_arquivo_origem", F.lit(f"{tabela}.csv"))

    df.write.mode("overwrite").saveAsTable(f"{BRONZE}.{tabela}")
    spark.sql(f"COMMENT ON TABLE {BRONZE}.{tabela} IS 'Dados brutos do sistema {sistema} ({tabela}.csv)'")
    return df.count()

# COMMAND ----------

resultados = {}
for sistema, tabelas in (("erp", ERPS), ("crm", CRMS)):
    for tabela in tabelas:
        resultados[tabela] = _ingestao(sistema, tabela)

# COMMAND ----------

# Conferencia interna: as linhas da tabela batem com as linhas do arquivo
# registradas no controle do prompt anterior (ja sem header)?
ctrl = spark.sql(f"SELECT arquivo, linhas FROM {BRONZE}._raw_arquivos").collect()
esperado = {r["arquivo"]: r["linhas"] for r in ctrl}

print("Tabela            | na_tabela | no_arquivo | bate")
falhas = []
for tabela, linhas in resultados.items():
    no_arquivo = esperado.get(tabela)
    bate = linhas == no_arquivo
    print(f"{tabela:16s} | {linhas:9d} | {no_arquivo:10d} | {str(bate):5s}")
    if not bate:
        falhas.append(tabela)

total = sum(resultados.values())
print(f"Total bronze: {total} linhas")

if falhas:
    raise RuntimeError(f"Divergencia de contagem na bronze para: {falhas}. Confira o leitor de CSV (multiLine/separador).")
if total != 313551:
    raise RuntimeError(f"Total inesperado na bronze: {total} (esperado 313551)")

print("Bronze OK: 10 tabelas criadas, contagens conferidas contra _raw_arquivos.")
