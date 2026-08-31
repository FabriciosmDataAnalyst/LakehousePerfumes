import { useEffect, useState } from 'react';
import { Alert, AlertDescription, AlertTitle, Badge } from '@databricks/appkit-ui/react';
import { GenieChat } from '@databricks/appkit-ui/react';

export function PerguntarPage() {
  const [email, setEmail] = useState<string | null>(null);
  const [erroEmail, setErroEmail] = useState<string | null>(null);

  useEffect(() => {
    let ativo = true;
    fetch('/api/quem-sou')
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json() as Promise<{ email: string | null }>;
      })
      .then((d) => {
        if (ativo) setEmail(d.email);
      })
      .catch((e) => {
        if (ativo) setErroEmail(e instanceof Error ? e.message : String(e));
      });
    return () => {
      ativo = false;
    };
  }, []);

  return (
    <div className="space-y-8">
      <header className="flex items-end justify-between gap-4 flex-wrap">
        <div className="space-y-1">
          <h2 className="text-3xl font-bold tracking-tight text-foreground">
            Perguntar
          </h2>
          <p className="text-sm text-muted-foreground">
            Pergunte em linguagem natural à direção — o agente lê a gold e
            responde com números.
          </p>
        </div>
        <div className="flex items-center gap-2 rounded-md border bg-muted/30 px-3 py-1.5">
          <Badge variant="secondary">Conectado como</Badge>
          {email ? (
            <span className="text-sm font-medium text-foreground">{email}</span>
          ) : erroEmail ? (
            <span className="text-sm text-destructive">{erroEmail}</span>
          ) : (
            <span className="text-sm text-muted-foreground">carregando…</span>
          )}
        </div>
      </header>

      {/* Aviso permanente: resposta gerada por IA e o SQL que a produziu */}
      <Alert>
        <AlertTitle>Resposta gerada por IA</AlertTitle>
        <AlertDescription>
          A resposta abaixo é gerada por IA e traz o SQL que a produziu. Confira
          sempre o número antes de decidir — o agente pode errar.
        </AlertDescription>
      </Alert>

      <div className="h-[min(620px,72vh)] rounded-lg border shadow-sm overflow-hidden">
        <GenieChat alias="default" />
      </div>
    </div>
  );
}