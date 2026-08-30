import { createBrowserRouter, RouterProvider, NavLink, Outlet } from 'react-router';
import { useState } from 'react';
import {
  Button,
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '@databricks/appkit-ui/react';
import { Menu, BarChart3 } from 'lucide-react';
import { SemanaPage } from './pages/semana/SemanaPage';
import { PerguntarPage } from './pages/perguntar/PerguntarPage';
import { AcompanhamentoPage } from './pages/acompanhamento/AcompanhamentoPage';

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
    isActive
      ? 'bg-primary text-primary-foreground'
      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
  }`;

const mobileNavLinkClass = ({ isActive }: { isActive: boolean }) =>
  `block w-full text-left px-3 py-2 rounded-md text-sm font-medium transition-colors ${
    isActive
      ? 'bg-primary text-primary-foreground'
      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
  }`;

type NavLinkClassFn = (props: { isActive: boolean }) => string;

function NavLinks({ className, linkClass, onClick }: { className?: string; linkClass: NavLinkClassFn; onClick?: () => void }) {
  return (
    <nav className={className}>
      <NavLink to="/" end className={linkClass} onClick={onClick}>
        A semana
      </NavLink>
      <NavLink to="/acompanhamento" className={linkClass} onClick={onClick}>
        Acompanhamento
      </NavLink>
      <NavLink to="/perguntar" className={linkClass} onClick={onClick}>
        Perguntar
      </NavLink>
    </nav>
  );
}

function Layout() {
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background flex flex-col">
      <header className="sticky top-0 z-20 border-b bg-background/80 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="mx-auto flex max-w-7xl items-center gap-4 px-4 py-3 md:px-6">
          <div className="flex items-center gap-2">
            <span className="inline-flex h-8 w-8 items-center justify-center rounded-md bg-primary/10 text-primary">
              <BarChart3 className="h-4 w-4" />
            </span>
            <div className="leading-tight">
              <h1 className="text-base font-semibold text-foreground">
                Rota do Perfume
              </h1>
              <p className="text-xs text-muted-foreground">Direção comercial</p>
            </div>
          </div>
          {/* Desktop nav — hidden below md breakpoint */}
          <NavLinks className="ml-auto hidden md:flex gap-1" linkClass={navLinkClass} />
          {/* Mobile nav — visible below md breakpoint */}
          <div className="ml-auto md:hidden">
            <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
              <Button variant="ghost" size="icon" onClick={() => setMobileNavOpen(true)}>
                <Menu className="h-5 w-5" />
                <span className="sr-only">Abrir navegação</span>
              </Button>
              <SheetContent side="left">
                <SheetHeader>
                  <SheetTitle>Rota do Perfume · Direção</SheetTitle>
                </SheetHeader>
                <NavLinks
                  className="flex flex-col gap-1 pt-2"
                  linkClass={mobileNavLinkClass}
                  onClick={() => setMobileNavOpen(false)}
                />
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </header>

      <main className="flex-1">
        <div className="mx-auto w-full max-w-7xl px-4 py-6 md:px-6 md:py-8">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { path: '/', element: <SemanaPage /> },
      { path: '/acompanhamento', element: <AcompanhamentoPage /> },
      { path: '/perguntar', element: <PerguntarPage /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}