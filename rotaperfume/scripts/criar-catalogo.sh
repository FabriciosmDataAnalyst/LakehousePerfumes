#!/usr/bin/env bash
# Cria o catalogo do Unity Catalog via SQL.
#
# POR QUE NAO ESTA NO BUNDLE: no Free Edition o Default Storage esta ligado e,
# nessa configuracao, a API do Unity Catalog RECUSA criar catalogo - ela exige um
# MANAGED LOCATION que a conta gratuita nao tem:
#   Error: Metastore storage root URL does not exist.
#          Default Storage is enabled in your account. (400 INVALID_STATE)
# O comando SQL abaixo funciona. Por isso o catalogo e criado por script e o
# restante do catalogo (schemas, volumes) vive no bundle em resources/catalogo.yml.
#
# Uso: bash scripts/criar-catalogo.sh <profile>
set -euo pipefail

PROFILE="${1:?Uso: bash scripts/criar-catalogo.sh <profile>}"
CATALOG="lakehouse_rotaperfume"
WAREHOUSE="39b53a84b2a3e763"

echo "==> Criando catalogo ${CATALOG} via SQL (profile=${PROFILE})"
echo "CREATE CATALOG IF NOT EXISTS ${CATALOG};" | \
  databricks experimental aitools tools query \
    --profile "${PROFILE}" \
    --warehouse "${WAREHOUSE}" \
    --output json

echo "==> Catalogo pronto."