// Formato que a diretoria le: R$ com toLocaleString('pt-BR'), score como
// porcentagem inteira. Ninguem decide ligacao lendo 0.9740085224443632.
//
// ATENCAO medida na pratica: o warehouse devolve NUMERO como STRING no JSON,
// mesmo com o tipo gerado dizendo `number`. Toda funcao deste arquivo passa o
// valor por Number() ANTES de formatar ou somar — senão toLocaleString devolve
// a string intacta e "7" + "12" vira "712".

export function asNum(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

export function fmtReais(v: unknown): string {
  return asNum(v).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  });
}

// score (0..1) -> porcentagem inteira, ex: 0.974 -> "97%"
export function fmtChance(v: unknown): string {
  return `${Math.round(asNum(v) * 100)}%`;
}

// taxa (0..1) -> porcentagem, ex: 0.052 -> "5,2%"
export function fmtPct(v: unknown): string {
  return asNum(v).toLocaleString('pt-BR', {
    style: 'percent',
    maximumFractionDigits: 1,
  });
}

export function fmtInt(v: unknown): string {
  return asNum(v).toLocaleString('pt-BR');
}