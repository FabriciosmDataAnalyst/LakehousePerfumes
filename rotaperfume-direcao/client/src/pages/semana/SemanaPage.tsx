import { useState } from 'react';
import {
  useAnalyticsQuery,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@databricks/appkit-ui/react';
import { fmtInt } from '../../lib/format';
import { SemanaConteudo } from './SemanaConteudo';

const TODOS = 'Todos';

export type ComentariosPorCliente = Record<string, string>;

export function SemanaPage() {
  const [vendedor, setVendedor] = useState<string>(TODOS);
  // Filtro e comentarios vivem no PAI; o filho e REMONTADO com uma key que muda
  // a cada gravacao. Remontar refaz a query — o useAnalyticsQuery nao tem
  // refetch e sem isso a tela mentiria, mostrando o numero de antes.
  const [comentarios, setComentarios] = useState<ComentariosPorCliente>({});
  const [recarga, setRecarga] = useState(0);

  const vendedores = useAnalyticsQuery('vendedores');

  const setComentario = (clienteId: string, texto: string) =>
    setComentarios((prev) => ({ ...prev, [clienteId]: texto }));

  return (
    <div className="space-y-8">
      <header className="space-y-1">
        <h2 className="text-3xl font-bold tracking-tight text-foreground">
          A semana
        </h2>
        <p className="text-sm text-muted-foreground">
          A fila dos 200 contatos da semana — priorizados pelo score do modelo.
        </p>
      </header>

      <section className="flex flex-wrap items-end gap-4 rounded-lg border bg-muted/30 px-4 py-3">
        <div className="min-w-[16rem] flex-1 max-w-xs">
          <Label htmlFor="filtro-vendedor" className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            Vendedor
          </Label>
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
      </section>

      <SemanaConteudo
        key={`${vendedor}|${recarga}`}
        vendedor={vendedor}
        comentarios={comentarios}
        onComentario={setComentario}
        onGravado={() => setRecarga((r) => r + 1)}
      />
    </div>
  );
}