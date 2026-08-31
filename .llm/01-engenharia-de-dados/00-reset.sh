#!/usr/bin/env bash
# Setup 00 · APAGA TUDO do bundle e devolve o ambiente ao zero.
#
# Versão corrigida para o layout do repositório: bundle em rotaperfume/ na
# RAIZ do repo (nao em aulas/aula-02-engenharia-de-dados/rotaperfume/).
#
# Existe por um motivo só: os seis prompts precisam funcionar a partir do nada.
# Se você não consegue apagar, você não consegue provar que reconstrói.
#
# Uso:  bash 00-reset.sh <profile> [--apagar]
#       Sem --apagar ele só MOSTRA o que faria. A flag se chama --apagar, e não
#       --sim, de propósito: ninguém confunde "apagar" com "simular".
#
# O que apaga:
#   1. o deployment do bundle no workspace (jobs, dashboards, Genie space,
#      modelo registrado no Unity Catalog via MLflow)
#   2. o catálogo lakehouse_rotaperfume INTEIRO, com bronze, silver, gold, ml
#   3. NAO apaga rotaperfume/src/ml/ (esta gitignored, mas é o codigo do
#      professor que voce nao quer perder). Para isso, comente a linha final.
set -euo pipefail

PROFILE="${1:?uso: bash 00-reset.sh <profile> [--apagar]}"
CONFIRMA="${2:-}"
CATALOGO="${CATALOGO:-lakehouse_rotaperfume}"

# Layout deste repo: bundle na RAIZ, nao em aulas/.
RAIZ_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE="$RAIZ_REPO/rotaperfume"

echo "profile:   $PROFILE"
echo "catálogo:  $CATALOGO  (DROP ... CASCADE)"
echo "bundle:    $BUNDLE"
echo

if [ "$CONFIRMA" != "--apagar" ]; then
  echo "Simulação. Nada foi apagado."
  echo "Para apagar de verdade:  bash 00-reset.sh $PROFILE --apagar"
  exit 0
fi

# 1. o que o bundle criou, o bundle desfaz
if [ -f "$BUNDLE/databricks.yml" ]; then
  echo "→ destruindo o deployment do bundle em $BUNDLE..."
  (cd "$BUNDLE" && databricks bundle destroy --target dev --auto-approve --profile "$PROFILE") || true
else
  echo "!! $BUNDLE/databricks.yml nao encontrado — pulando bundle destroy."
  echo "   Se o deployment existe no workspace, destrua manualmente:"
  echo "     cd $BUNDLE && databricks bundle destroy --target dev --auto-approve --profile $PROFILE"
fi

# 2. o que sobrou do catalogo — inclusive o que o noites anteriores criaram
echo "→ dropando o catálogo $CATALOGO..."
echo "DROP CATALOG IF EXISTS $CATALOGO CASCADE" \
  | databricks experimental aitools tools query --profile "$PROFILE" || true

echo
echo "Catalogo dropado. Para reconstruir:"
echo "  1. cd rotaperfume"
echo "  2. bash scripts/criar-catalogo.sh $PROFILE"
echo "  3. databricks bundle validate --target dev --profile $PROFILE"
echo "  4. databricks bundle deploy   --target dev --profile $PROFILE"
echo "  5. bash scripts/subir-raw.sh  $PROFILE"
echo "  6. databricks bundle run rotaperfume_pipeline --target dev --profile $PROFILE --only raw_conferencia"
echo "  7. ... e os outros 14 tasks, na ordem do .llm/01-engenharia-de-dados/"
