import { useState } from 'react';
import {
  useAnalyticsQuery,
  Alert,
  AlertTitle,
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
  Input,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@databricks/appkit-ui/react';
import { sql } from '@databricks/appkit-ui/js';
import { asNum, fmtChance, fmtInt, fmtPct, fmtReais } from '../../lib/format';
import type { ComentariosPorCliente } from './SemanaPage';

const STATUS_LABEL: Record<string, string> = {
  vendeu: 'Vendeu',
  vai_pensar: 'Vai pensar',
  sem_interesse: 'Sem interesse',
  nao_atendeu: 'Não atendeu',
};

const STATUS_VARIANT: Record<string, 'default' | 'secondary' | 'destructive' | 'outline'> = {
  vendeu: 'default',
  vai_pensar: 'secondary',
  sem_interesse: 'outline',
  nao_atendeu: 'outline',
};

const STATUS_ORDER = ['vendeu', 'vai_pensar', 'sem_interesse', 'nao_atendeu'] as const;

interface Props {
  vendedor: string;
  recarga: number;
  comentarios: ComentariosPorCliente;
  onComentario: (clienteId: string, texto: string) => void;
  onGravado: () => void;
}

export function SemanaConteudo({ vendedor, recarga, comentarios, onComentario, onGravado }: Props) {
  const [gravando, setGravando] = useState<string | null>(null);
  const [erroGravacao, setErroGravacao] = useState<string | null>(null);

  const kpis = useAnalyticsQuery('kpis_semana');
  const fila = useAnalyticsQuery('fila', { vendedor: sql.string(vendedor), recarga: sql.number(recarga) });

  const kpiRow = kpis.data?.[0];

  async function gravar(clienteId: number, vendedorNome: string, status: string, referencia: string) {
    const chave = `${clienteId}:${status}`;
    setGravando(chave);
    setErroGravacao(null);
    try {
      const resp = await fetch('/api/retorno', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          // Number(): o warehouse devolve o id como STRING mesmo tipado number
          cliente_id: Number(clienteId),
          vendedor: vendedorNome,
          status,
          comentario: comentarios[String(clienteId)] ?? '',
          referencia,
        }),
      });
      if (!resp.ok) {
        const detail = (await resp.json().catch(() => null)) as { error?: string } | null;
        throw new Error(detail?.error ?? `HTTP ${resp.status}`);
      }
      onGravado();
    } catch (err) {
      console.error('[semana] falha ao gravar retorno:', err);
      setErroGravacao(
        'Não foi possível registrar o retorno da ligação. ' +
          (err instanceof Error ? err.message : String(err)),
      );
    } finally {
      setGravando(null);
    }
  }

  return (
    <div className="space-y-8">
      {erroGravacao && (
        <Alert variant="destructive">
          <AlertTitle>Falha ao registrar o retorno</AlertTitle>
          <p className="text-sm">{erroGravacao} Tente novamente.</p>
        </Alert>
      )}

      {kpis.loading && (
        <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <Card key={`kpi-sk-${i}`} className="shadow-sm">
              <CardHeader className="pb-2">
                <Skeleton className="h-3 w-24" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-9 w-32" />
                <Skeleton className="h-3 w-40 mt-3" />
              </CardContent>
            </Card>
          ))}
        </section>
      )}

      {kpis.error && (
        <Alert variant="destructive">
          <AlertTitle>Falha ao carregar os indicadores da semana</AlertTitle>
          <p className="text-sm">{kpis.error}</p>
        </Alert>
      )}

      {!kpis.loading && !kpis.error && kpiRow && (
        <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          <Card className="shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Contatos da semana
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold tabular-nums text-foreground">
                {fmtInt(kpiRow.contatos)}
              </div>
              <div className="mt-2 text-sm text-muted-foreground">
                {fmtInt(kpiRow.vendedores)} vendedores na fila
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-sm ring-1 ring-primary/20">
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between gap-2">
                <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Receita esperada
                </CardTitle>
                <Badge variant="outline" className="font-normal">Estimativa</Badge>
              </div>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold tabular-nums text-primary">
                {fmtReais(kpiRow.receita_esperada)}
              </div>
              <div className="mt-2 text-sm text-muted-foreground">
                Soma de score × ticket — potencial da fila, não receita realizada.
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Conversão prevista
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold tabular-nums text-foreground">
                {asNum(kpiRow.contatos) > 0
                  ? fmtPct(asNum(kpiRow.acertos_top200) / asNum(kpiRow.contatos))
                  : '0%'}
              </div>
              <div className="mt-2 text-sm text-muted-foreground">
                Taxa base: {fmtPct(kpiRow.taxa_base)} (comprar em 7 dias)
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-sm">
            <CardHeader className="pb-2">
              <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Já trabalhados
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold tabular-nums text-foreground">
                {fmtInt(kpiRow.retornos)}
              </div>
              <div className="mt-2 text-sm text-muted-foreground">
                <span className="font-medium text-foreground">{fmtInt(kpiRow.viraram_pedido)}</span>{' '}
                viraram pedido
              </div>
            </CardContent>
          </Card>
        </section>
      )}

      {!kpis.loading && !kpis.error && !kpiRow && (
        <Empty>
          <EmptyHeader>
            <EmptyTitle>Sem fila na semana</EmptyTitle>
            <EmptyDescription>
              A fila dos 200 ainda não foi gerada para esta semana.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {fila.loading && (
        <Card className="shadow-sm">
          <CardContent className="space-y-3 py-6">
            {[0, 1, 2, 3, 4, 5].map((i) => (
              <Skeleton key={`row-sk-${i}`} className="h-10 w-full" />
            ))}
          </CardContent>
        </Card>
      )}

      {fila.error && (
        <Alert variant="destructive">
          <AlertTitle>Falha ao carregar a fila</AlertTitle>
          <p className="text-sm">{fila.error}</p>
        </Alert>
      )}

      {!fila.loading && !fila.error && fila.data && fila.data.length === 0 && (
        <Empty>
          <EmptyHeader>
            <EmptyTitle>Nenhum contato para este vendedor</EmptyTitle>
            <EmptyDescription>
              A fila é global e prioriza o maior score, não distribui cota por
              vendedor. Quem tem a carteira mais quente recebe mais contatos — e
              está certo assim.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {!fila.loading && !fila.error && fila.data && fila.data.length > 0 && (
        <Card className="shadow-sm">
          <CardHeader className="border-b">
            <CardTitle>Fila da semana</CardTitle>
          </CardHeader>
          <CardContent className="overflow-x-auto p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-14">Ordem</TableHead>
                  <TableHead>Cliente</TableHead>
                  <TableHead className="hidden md:table-cell">Vendedor</TableHead>
                  <TableHead className="text-right">Chance</TableHead>
                  <TableHead className="hidden lg:table-cell">Motivo</TableHead>
                  <TableHead className="hidden lg:table-cell max-w-[16rem]">Sugestão</TableHead>
                  <TableHead className="min-w-[16rem]">Como foi a ligação</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {fila.data.map((r) => {
                  const clienteId = String(r.cliente_id);
                  const temRetorno = !!r.ultimo_status;
                  const comentario = comentarios[clienteId] ?? '';

                  return (
                    <TableRow key={`${r.vendedor}-${r.cliente_id}`} className="hover:bg-muted/40">
                      <TableCell className="text-muted-foreground tabular-nums">
                        {fmtInt(r.ordem)}
                      </TableCell>
                      <TableCell>
                        <div className="font-medium text-foreground">{r.razao_social}</div>
                        <div className="text-xs text-muted-foreground">
                          {r.cidade}/{r.uf} · {fmtReais(r.ticket_medio)}
                        </div>
                      </TableCell>
                      <TableCell className="hidden md:table-cell text-muted-foreground">
                        {r.vendedor}
                      </TableCell>
                      <TableCell className="text-right">
                        <Badge
                          variant={Number(r.score) >= 0.7 ? 'default' : 'secondary'}
                          className="font-semibold tabular-nums"
                        >
                          {fmtChance(r.score)}
                        </Badge>
                      </TableCell>
                      <TableCell className="hidden lg:table-cell max-w-md text-sm text-muted-foreground">
                        {r.motivo}
                      </TableCell>
                      <TableCell className="hidden lg:table-cell max-w-xs text-sm text-muted-foreground">
                        {r.sugestao}
                      </TableCell>
                      <TableCell className="min-w-[16rem]">
                        {temRetorno ? (
                          <div className="space-y-1.5">
                            <Badge variant={STATUS_VARIANT[r.ultimo_status] ?? 'secondary'}>
                              {STATUS_LABEL[r.ultimo_status] ?? r.ultimo_status}
                            </Badge>
                            {r.ultimo_comentario && (
                              <div className="text-xs text-muted-foreground break-words">
                                {r.ultimo_comentario}
                              </div>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-2">
                            <Input
                              placeholder="Comentário (opcional)"
                              value={comentario}
                              maxLength={500}
                              onChange={(e) => onComentario(clienteId, e.target.value)}
                            />
                            <div className="flex flex-wrap gap-1.5">
                              {STATUS_ORDER.map((status) => (
                                <Button
                                  key={status}
                                  size="sm"
                                  variant={status === 'vendeu' ? 'default' : 'outline'}
                                  disabled={gravando !== null}
                                  onClick={() => {
                                    void gravar(asNum(r.cliente_id), r.vendedor, status, r._referencia);
                                  }}
                                >
                                  {gravando === `${clienteId}:${status}` ? 'Gravando…' : STATUS_LABEL[status]}
                                </Button>
                              ))}
                            </div>
                          </div>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}