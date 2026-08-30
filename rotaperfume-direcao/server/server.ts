import { createApp, analytics, genie, server } from '@databricks/appkit';

createApp({
  plugins: [
    analytics(),
    genie(),
    server(),
  ],
  onPluginsReady(appkit) {
    // /api/quem-sou: quem esta logado. O proxy do app injeta o e-mail no header
    // x-forwarded-email; devolvemos ele para a tela "Perguntar" mostrar quem sou.
    appkit.server.extend((app) => {
      app.get('/api/quem-sou', (_req, res) => {
        const email = _req.headers['x-forwarded-email'];
        res.json({ email: Array.isArray(email) ? email[0] : (email ?? null) });
      });
    });
  },
}).catch(console.error);
