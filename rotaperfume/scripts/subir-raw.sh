#!/usr/bin/env bash
# Sobe os CSVs de dados/ (na raiz do repositorio) para o Volume de raw do
# catalogo, separando por sistema: erp e crm.
#
# Uso: bash scripts/subir-raw.sh <profile>
set -euo pipefail

PROFILE="${1:?Uso: bash scripts/subir-raw.sh <profile>}"
CATALOG="lakehouse_rotaperfume"
# dados/ fica na raiz do repositorio (../.. a partir de scripts/).
RAIZ_DADOS="$(cd "$(dirname "$0")/../.." && pwd)/dados"
DESTINO_BASE="dbfs:/Volumes/${CATALOG}/bronze/raw"

# O comando databricks fs cp EXIGE o esquema dbfs: no destino, mesmo quando o
# destino e um Volume do Unity Catalog.
echo "==> Subindo ERP (profile=${PROFILE})"
databricks fs cp --recursive --overwrite \
  "${RAIZ_DADOS}/erp" "${DESTINO_BASE}/erp" \
  --profile "${PROFILE}"

echo "==> Subindo CRM (profile=${PROFILE})"
databricks fs cp --recursive --overwrite \
  "${RAIZ_DADOS}/crm" "${DESTINO_BASE}/crm" \
  --profile "${PROFILE}"

echo "==> Upload concluido."