import { useState } from 'react';
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
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
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

const TODOS = 'Todos';

export function SemanaPage() {
  const [vendedor, setVendedor] = useState<string>(TODOS);

  const kpis = useAnalyticsQuery('kpis_semana');
  const vendedores = useAnalyticsQuery('vendedores');
  const fila = useAnalyticsQuery('fila', { vendedor: sql.string(vendedor) });

  const kpiRow = kpis.data?.[0];

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      <header>
        <h2 className="text-2xl font-bold text-foreground">A semana</h2>
        <p className="text-sm text-muted-foreground mt-1">
          A fila dos 200 contatos da semana — priorizados pelo score do modelo.
        </p>
      </header>

      {kpis.loading && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Card key={i} className="shadow-lg">
              <CardHeader>
                <Skeleton className="h-4 w-24" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-8 w-32" />
                <Skeleton className="h-4 w-40 mt-2" />
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {kpis.error && (
        <Alert variant="destructive">
          <AlertTitle>Falha ao carregar os indicadores da semana</AlertTitle>
          <p className="text-sm">{kpis.error}</p>
        </Alert>
      )}

      {/* Os quatro cartões, lendo somente a linha única de kpis_semana */}
      {!kpis.loading && !kpis.error && kpiRow && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          <Card className="shadow-lg">
            <CardHeader>
              <CardTitle>Contatos da semana</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-primary">
                {fmtInt(kpiRow.contatos)}
              </div>
              <div className="text-sm text-muted-foreground mt-1">
                {fmtInt(kpiRow.vendedores)} vendedores na fila
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-lg">
            <CardHeader>
              <CardTitle>Receita esperada</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-primary">
                {fmtReais(kpiRow.receita_esperada)}
              </div>
              <div className="text-sm text-muted-foreground mt-1">
                Estimativa: soma de score × ticket — não é receita realizada.
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-lg">
            <CardHeader>
              <CardTitle>Conversão prevista</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-primary">
                {kpiRow.contatos > 0
                  ? fmtPct(asNum(kpiRow.acertos_top200) / asNum(kpiRow.contatos))
                  : '0%'}
              </div>
              <div className="text-sm text-muted-foreground mt-1">
                Taxa base: {fmtPct(kpiRow.taxa_base)} (comprar em 7 dias)
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-lg">
            <CardHeader>
              <CardTitle>Já trabalhados</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold text-primary">
                {fmtInt(kpiRow.retornos)}
              </div>
              <div className="text-sm text-muted-foreground mt-1">
                {fmtInt(kpiRow.viraram_pedido)} viraram pedido
              </div>
            </CardContent>
          </Card>
        </div>
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

      {/* Filtro por vendedor */}
      <div className="max-w-xs">
        <Label htmlFor="filtro-vendedor">Vendedor</Label>
        <Select
          value={vendedor}
          onValueChange={(value) => setVendedor(value ?? TODOS)}
        >
          <SelectTrigger id="filtro-vendedor" className="mt-1">
            <SelectValue placeholder="Todos os vendedores" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={TODOS}>Todos os vendedores</SelectItem>
            {(vendedores.data ?? []).map((v) => (
              <SelectItem key={v.vendedor} value={v.vendedor}>
                {v.vendedor} ({fmtInt(v.contatos)})
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Fila — os quatro estados: carregando, erro, vazio, dado */}
      {fila.loading && (
        <Card className="shadow-lg">
          <CardContent className="space-y-3 py-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-6 w-full" />
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
              vendedor. Quem tem a carteira mais quente recebe mais contatos —
              e está certo assim.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {!fila.loading && !fila.error && fila.data && fila.data.length > 0 && (
        <Card className="shadow-lg">
          <CardContent className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-12">Ordem</TableHead>
                  <TableHead>Cliente</TableHead>
                  <TableHead>Vendedor</TableHead>
                  <TableHead className="text-right">Chance</TableHead>
                  <TableHead>Motivo</TableHead>
                  <TableHead>Sugestão</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {fila.data.map((r) => (
                  <TableRow key={`${r.vendedor}-${r.cliente_id}`}>
                    <TableCell className="text-muted-foreground">{fmtInt(r.ordem)}</TableCell>
                    <TableCell>
                      <div className="font-medium">{r.razao_social}</div>
                      <div className="text-xs text-muted-foreground">
                        {r.cidade}/{r.uf} · {fmtReais(r.ticket_medio)}
                      </div>
                    </TableCell>
                    <TableCell>{r.vendedor}</TableCell>
                    <TableCell className="text-right font-medium">
                      {fmtChance(r.score)}
                    </TableCell>
                    <TableCell className="max-w-md text-sm">{r.motivo}</TableCell>
                    <TableCell className="max-w-xs text-sm">{r.sugestao}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}