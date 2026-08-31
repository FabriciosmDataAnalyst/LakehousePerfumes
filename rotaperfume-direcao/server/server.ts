import { createApp, analytics, genie, getExecutionContext, server } from '@databricks/appkit';
import { z } from 'zod';

// O contrato do retorno: e esse enum que impede a tabela de ter "vendeu",
// "Vendeu" e "vendido". Nada chega ao banco sem passar por aqui.
const retornoSchema = z.object({
  cliente_id: z.coerce.number().int('cliente_id deve ser um inteiro'),
  vendedor: z.string().min(1, 'vendedor nao pode ser vazio'),
  status: z.enum(['vendeu', 'vai_pensar', 'sem_interesse', 'nao_atendeu']),
  comentario: z.string().max(500, 'comentario tem no maximo 500 caracteres').optional(),
  referencia: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'referencia deve estar em aaaa-mm-dd'),
});

createApp({
  plugins: [
    analytics(),
    genie(),
    server(),
  ],
  // Cache de leitura desligado: sao 200 linhas e todas mudam quando alguem
  // clica em um botao de retorno. O cache guardaria o numero de antes e a tela
  // mentiria. A recarga em React (key no filho) resolve o resto.
  cache: { enabled: false },
  onPluginsReady(appkit) {
    appkit.server.extend((app) => {
      // /api/quem-sou: quem esta logado. O proxy do app injeta o e-mail no header
      // x-forwarded-email; devolvemos ele para a tela "Perguntar" mostrar quem sou.
      app.get('/api/quem-sou', (_req, res) => {
        const email = _req.headers['x-forwarded-email'];
        res.json({ email: Array.isArray(email) ? email[0] : (email ?? null) });
      });

      // /api/retorno: a UNICA rota que escreve. Valida com Zod ANTES de tocar no
      // banco (corpo invalido = 400 sem consultar o warehouse). O INSERT usa o
      // Statement Execution com TODOS os valores como parameters — nunca
      // concatenados na string do SQL.
      app.post('/api/retorno', async (req, res) => {
        const parsed = retornoSchema.safeParse(req.body);
        if (!parsed.success) {
          res.status(400).json({
            error: 'Dados invalidos. Verifique cliente, vendedor, status e referencia.',
            detail: parsed.error.flatten(),
          });
          return;
        }

        let registradoPor: string | null = null;
        const header = req.headers['x-forwarded-email'];
        const email = Array.isArray(header) ? header[0] : header;
        if (email) {
          registradoPor = email;
        } else if (process.env.NODE_ENV === 'development') {
          registradoPor = 'dev.local@rotaperfume';
        } else {
          res.status(400).json({ error: 'Usuario nao identificado (x-forwarded-email ausente).' });
          return;
        }

        try {
          const ctx = getExecutionContext();
          const warehouseId = await ctx.warehouseId;
          if (!warehouseId) {
            res.status(500).json({ error: 'Warehouse nao configurado para este contexto.' });
            return;
          }

          const data = parsed.data;
          const statement = await ctx.client.statementExecution.executeStatement({
            warehouse_id: warehouseId,
            statement: `
              INSERT INTO lakehouse_rotaperfume.gold.retorno_ligacao
                (cliente_id, vendedor, status, comentario, registrado_em, registrado_por, _referencia)
              VALUES
                (:cliente_id, :vendedor, :status,
                 COALESCE(NULLIF(:comentario, ''), NULL),
                 current_timestamp(), :registrado_por, DATE(:referencia))
            `,
            parameters: [
              { name: 'cliente_id', value: String(data.cliente_id), type: 'INT' },
              { name: 'vendedor', value: data.vendedor, type: 'STRING' },
              { name: 'status', value: data.status, type: 'STRING' },
              { name: 'comentario', value: data.comentario ?? '', type: 'STRING' },
              { name: 'registrado_por', value: registradoPor, type: 'STRING' },
              { name: 'referencia', value: data.referencia, type: 'DATE' },
            ],
            wait_timeout: '30s',
            on_wait_timeout: 'CONTINUE',
          });

          if (statement.status?.state !== 'SUCCEEDED') {
            throw new Error(
              `Statement terminou em ${statement.status?.state ?? 'desconhecido'}: ${statement.status?.error?.message ?? 'sem detalhe'}`,
            );
          }

          res.status(201).json({ ok: true });
        } catch (err) {
          console.error('[api/retorno] falha ao registrar:', err);
          res.status(500).json({
            error: 'Nao foi possivel registrar o retorno da ligacao.',
            detail: err instanceof Error ? err.message : String(err),
          });
        }
      });
    });
  },
}).catch(console.error);