#!/usr/bin/env python3
"""Roda um arquivo .sql no warehouse, UMA instrucao por vez.

O `databricks experimental aitools tools query` nao aceita multiplas instrucoes
na mesma chamada (nao divide no ';', e multi-statement e rejeitado). Este
script divide o arquivo em instrucoes e executa cada uma via stdin, parando na
primeira que falhar.

Uso: python scripts/run_sql.py <profile> <arquivo.sql>
"""

import json
import subprocess
import sys

WAREHOUSE = "39b53a84b2a3e763"


def limpar(sql: str) -> str:
    """Remove comentarios de linha (--) fora de literais de string."""
    saida: list[str] = []
    em_string = False
    i = 0
    n = len(sql)
    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if ch == "'":
            em_string = not em_string
            saida.append(ch)
            i += 1
            continue
        if ch == "-" and nxt == "-" and not em_string:
            while i < n and sql[i] != "\n":
                i += 1
            continue
        saida.append(ch)
        i += 1
    return "".join(saida)


def dividir(sql: str) -> list[str]:
    """Divide no ';' de topo, respeitando literais entre aspas simples."""
    sql = limpar(sql)
    instrucoes: list[str] = []
    atual: list[str] = []
    em_string = False
    for ch in sql:
        if ch == "'":
            em_string = not em_string
        if ch == ";" and not em_string:
            texto = "".join(atual).strip()
            if texto:
                instrucoes.append(texto)
            atual = []
        else:
            atual.append(ch)
    resto = "".join(atual).strip()
    if resto:
        instrucoes.append(resto)
    return instrucoes


def executar(profile: str, sql: str) -> None:
    proc = subprocess.run(
        [
            "databricks",
            "experimental",
            "aitools",
            "tools",
            "query",
            "--warehouse",
            WAREHOUSE,
            "--profile",
            profile,
            "--output",
            "json",
        ],
        input=sql.encode("utf-8"),
        capture_output=True,
    )
    stdout = proc.stdout.decode("utf-8", errors="replace").strip()
    stderr = proc.stderr.decode("utf-8", errors="replace").strip()

    def _achar_erro(val):
        if isinstance(val, dict):
            if val.get("error"):
                return val["error"]
            for v in val.values():
                found = _achar_erro(v)
                if found:
                    return found
        elif isinstance(val, list):
            for v in val:
                found = _achar_erro(v)
                if found:
                    return found
        return None

    erro = None
    if stdout:
        try:
            dados = json.loads(stdout)
        except json.JSONDecodeError:
            dados = None
        if dados is not None:
            # o engine pode devolver o erro como lista OU como objeto; procura
            # recursivo pega os dois (antes o formato objeto passava batido e o
            # script "rodava OK" com a tabela sem nascer).
            erro = _achar_erro(dados)
        elif "error" in stdout.lower() or "Error" in stdout:
            erro = stdout
    if not erro and proc.returncode != 0 and not stdout:
        erro = stderr

    if erro:
        print(erro, file=sys.stderr)
        sys.exit(1)
    if stdout:
        print(stdout)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("Uso: python scripts/run_sql.py <profile> <arquivo.sql>")
    profile, arquivo = sys.argv[1:]

    with open(arquivo, encoding="utf-8") as f:
        sql = f.read()

    instrucoes = dividir(sql)
    if not instrucoes:
        sys.exit("Nenhuma instrucao no arquivo.")

    for i, instr in enumerate(instrucoes, 1):
        primeiro = " ".join(instr.split())[:80]
        print(f"==> [{i}/{len(instrucoes)}] {primeiro} ...")
        executar(profile, instr)

    print(f"==> OK: {len(instrucoes)} instrucoes executadas.")


if __name__ == "__main__":
    main()