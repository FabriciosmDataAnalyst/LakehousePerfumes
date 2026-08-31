#!/usr/bin/env bash
# Roda UMA tarefa do job rotaperfume_pipeline, sem executar as demais.
# O job completo leva ~3m30; uma tarefa so, ~35s.
# Uso: bash scripts/rodar-tarefa.sh <profile> <task_key>
set -euo pipefail

PROFILE="${1:?Uso: bash scripts/rodar-tarefa.sh <profile> <task_key>}"
TASK="${2:?Uso: bash scripts/rodar-tarefa.sh <profile> <task_key>}"

# O bash do Git for Windows nao herda o PATH do PowerShell: o `databricks`
# fica fora do PATH e o script falha com "databricks: not found". Resolve
# procurando o CLI primeiro no PATH e, no Windows, no caminho do WinGet.
DATABRICKS="$(command -v databricks 2>/dev/null || true)"
if [ -z "${DATABRICKS}" ] && [ -n "${HOME}" ] \
   && [ -x "${HOME}/AppData/Local/Microsoft/WinGet/Links/databricks.exe" ]; then
  DATABRICKS="${HOME}/AppData/Local/Microsoft/WinGet/Links/databricks.exe"
fi
if [ -z "${DATABRICKS}" ]; then
  DATABRICKS="databricks"
fi

# --only roda apenas a tarefa pedida (sem upstream/downstream).
exec "${DATABRICKS}" bundle run rotaperfume_pipeline \
  --target dev --profile "${PROFILE}" --only "${TASK}"