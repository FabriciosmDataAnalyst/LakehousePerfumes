import {
  useAnalyticsQuery,
  Alert,
  AlertTitle,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@databricks/appkit-ui/react';
import { BarChart } from '@databricks/appkit-ui/react';
import { sql } from '@databricks/appkit-ui/js';
import { asNum, fmtInt, fmtPct } from '../../lib/format';

export function AcompanhamentoPage() {
  const acompanhamento = useAnalyticsQuery('acompanhamento', {
    vendedor: sql.string('Todos'),
  });

  const linhas = acompanhamento.data ?? [];
  const trabalhados = linhas.reduce((acc, r) => acc + asNum(r.trabalhados), 0);
  const viraramPedido = linhas.reduce((acc, r) => acc + asNum(r.vendeu), 0);
  const naFila = linhas.reduce((acc, r) => acc + asNum(r.na_fila), 0);
  const taxaConversao = trabalhados > 0 ? viraramPedido / trabalhados : 0;

  // O grafico recebe so as duas series que interessam (trabalhados e vendeu);
  // se passassemos a query inteira, o inferidor de campos plotaria tambem
  // na_fila/vai_pensar/... e o grafico ficaria poluido.
  const dadosGrafico = linhas.map((r) => ({
    vendedor: r.vendedor,
    trabalhados: asNum(r.trabalhados),
    vendeu: asNum(r.vendeu),
  }));

  return (
    <div className="space-y-8">
      <header className="space-y-1">
        <h2 className="text-3xl font-bold tracking-tight text-foreground">
          Acompanhamento
        </h2>
        <p className="text-sm text-muted-foreground">
          O que o time registrou depois das ligações — por vendedor.
        </p>
      </header>

      {acompanhamento.loading && (
        <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <Card key={`sk-${i}`} className="shadow-sm">
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

      {acompanhamento.error && (
        <Alert variant="destructive">
          <AlertTitle>Falha ao carregar o acompanhamento</AlertTitle>
          <p className="text-sm">{acompanhamento.error}</p>
        </Alert>
      )}

      {!acompanhamento.loading && !acompanhamento.error && trabalhados === 0 && (
        <Empty>
          <EmptyHeader>
            <EmptyTitle>Nenhum retorno registrado ainda</EmptyTitle>
            <EmptyDescription>
              Assim que o time marcar o desfecho de uma ligação, o número
              aparece aqui — e vira dado de treino da semana que vem. Zero
              não é erro.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {!acompanhamento.loading && !acompanhamento.error && trabalhados > 0 && (
        <>
          <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
            <Card className="shadow-sm">
              <CardHeader className="pb-2">
                <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Na fila
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold tabular-nums text-foreground">
                  {fmtInt(naFila)}
                </div>
                <div className="mt-2 text-sm text-muted-foreground">
                  contatos atribuídos a vendedores
                </div>
              </CardContent>
            </Card>
            <Card className="shadow-sm">
              <CardHeader className="pb-2">
                <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Trabalhados
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold tabular-nums text-foreground">
                  {fmtInt(trabalhados)}
                </div>
                <div className="mt-2 text-sm text-muted-foreground">
                  ligações com retorno registrado
                </div>
              </CardContent>
            </Card>
            <Card className="shadow-sm">
              <CardHeader className="pb-2">
                <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Viraram pedido
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold tabular-nums text-foreground">
                  {fmtInt(viraramPedido)}
                </div>
                <div className="mt-2 text-sm text-muted-foreground">
                  status &ldquo;vendeu&rdquo; da fila
                </div>
              </CardContent>
            </Card>
            <Card className="shadow-sm">
              <CardHeader className="pb-2">
                <CardTitle className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Conversão
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold tabular-nums text-primary">
                  {fmtPct(taxaConversao)}
                </div>
                <div className="mt-2 text-sm text-muted-foreground">
                  viraram pedido ÷ trabalhados
                </div>
              </CardContent>
            </Card>
          </section>

          <Card className="shadow-sm">
            <CardHeader className="border-b">
              <CardTitle>Ligações por vendedor</CardTitle>
            </CardHeader>
            <CardContent className="h-80 pt-4">
              <BarChart data={dadosGrafico} />
            </CardContent>
          </Card>

          <Card className="shadow-sm">
            <CardHeader className="border-b">
              <CardTitle>Detalhe por vendedor</CardTitle>
            </CardHeader>
            <CardContent className="overflow-x-auto p-0">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Vendedor</TableHead>
                    <TableHead className="text-right">Na fila</TableHead>
                    <TableHead className="text-right">Trabalhados</TableHead>
                    <TableHead className="text-right">Vendeu</TableHead>
                    <TableHead className="text-right hidden sm:table-cell">Vai pensar</TableHead>
                    <TableHead className="text-right hidden md:table-cell">Sem interesse</TableHead>
                    <TableHead className="text-right hidden md:table-cell">Não atendeu</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {linhas.map((r) => (
                    <TableRow key={r.vendedor} className="hover:bg-muted/40">
                      <TableCell className="font-medium">{r.vendedor}</TableCell>
                      <TableCell className="text-right tabular-nums">{fmtInt(r.na_fila)}</TableCell>
                      <TableCell className="text-right tabular-nums">{fmtInt(r.trabalhados)}</TableCell>
                      <TableCell className="text-right tabular-nums font-medium text-primary">
                        {fmtInt(r.vendeu)}
                      </TableCell>
                      <TableCell className="text-right tabular-nums hidden sm:table-cell">
                        {fmtInt(r.vai_pensar)}
                      </TableCell>
                      <TableCell className="text-right tabular-nums hidden md:table-cell">
                        {fmtInt(r.sem_interesse)}
                      </TableCell>
                      <TableCell className="text-right tabular-nums hidden md:table-cell">
                        {fmtInt(r.nao_atendeu)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}