import { Link, useRouterState } from "@tanstack/react-router";
import { Minus, Settings, X, Home, Copy } from "lucide-react";
import type { ReactNode } from "react";
import { Logo } from "./Logo";

/**
 * Simula o visual final do aplicativo desktop:
 * uma janela do Windows flutuando sobre a área de trabalho.
 * No .exe real (Tauri), a barra de título nativa assume esse papel.
 */
export function WindowShell({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#101014] p-4 text-foreground sm:p-8">
      {/* "Desktop" backdrop */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-48 left-1/3 h-[560px] w-[900px] -translate-x-1/2 rounded-full opacity-20 blur-[140px]"
        style={{ background: "var(--gradient-accent)" }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -bottom-56 right-0 h-[480px] w-[720px] rounded-full opacity-10 blur-[160px]"
        style={{ background: "var(--gradient-accent)" }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.06]"
        style={{
          backgroundImage:
            "linear-gradient(var(--color-border) 1px, transparent 1px), linear-gradient(90deg, var(--color-border) 1px, transparent 1px)",
          backgroundSize: "56px 56px",
        }}
      />

      {/* Janela do aplicativo */}
      <div className="relative flex h-[min(88vh,620px)] w-full max-w-xl flex-col overflow-hidden rounded-xl border border-white/10 bg-background shadow-[0_40px_120px_-20px_rgba(0,0,0,0.85)] ring-1 ring-black/40">
        {/* Barra de título estilo Windows 11 */}
        <div className="flex h-11 shrink-0 select-none items-center border-b border-border/60 bg-surface/90 pl-4 backdrop-blur-xl">
          <div className="flex min-w-0 flex-1 items-center gap-2.5">
            <Logo compact />
            <span className="truncate text-xs font-medium text-muted-foreground">
              Nexus Activate
            </span>
          </div>
          <div className="flex h-full items-stretch">
            <TitleBarButton label="Minimizar">
              <Minus className="h-4 w-4" strokeWidth={1.5} />
            </TitleBarButton>
            <TitleBarButton label="Maximizar">
              <Copy className="h-3.5 w-3.5 rotate-90" strokeWidth={1.5} />
            </TitleBarButton>
            <TitleBarButton label="Fechar" danger>
              <X className="h-4 w-4" strokeWidth={1.5} />
            </TitleBarButton>
          </div>
        </div>

        {/* Conteúdo da janela */}
        <div className="relative flex min-h-0 flex-1 flex-col overflow-y-auto">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 opacity-[0.12]"
            style={{
              backgroundImage:
                "linear-gradient(var(--color-border) 1px, transparent 1px), linear-gradient(90deg, var(--color-border) 1px, transparent 1px)",
              backgroundSize: "56px 56px",
              maskImage: "radial-gradient(ellipse at 50% 0%, black, transparent 75%)",
            }}
          />

          <div className="relative mx-auto flex w-full flex-1 flex-col px-4 py-4">
            <header className="flex items-center justify-between rounded-xl border border-border/70 bg-surface/80 px-3 py-2 backdrop-blur-xl">
              <Logo compact />
              <span className="font-display text-sm font-semibold tracking-tight text-foreground">
                NEXUS<span className="text-primary">ACTIVATE</span>
              </span>

              <nav className="flex items-center gap-1">
                <NavButton to="/" active={pathname === "/"} icon={<Home className="h-4 w-4" />}>
                  Início
                </NavButton>
                <NavButton
                  to="/configuracoes"
                  active={pathname.startsWith("/configuracoes")}
                  icon={<Settings className="h-4 w-4" />}
                >
                  Configurações
                </NavButton>
              </nav>
            </header>

            <main className="min-h-0 flex-1 overflow-y-auto py-4">{children}</main>
          </div>
        </div>
      </div>
    </div>
  );
}

function TitleBarButton({
  label,
  danger = false,
  children,
}: {
  label: string;
  danger?: boolean;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={`flex h-full w-11 items-center justify-center text-muted-foreground transition-colors ${
        danger ? "hover:bg-destructive hover:text-white" : "hover:bg-secondary hover:text-foreground"
      }`}
    >
      {children}
    </button>
  );
}

function NavButton({
  to,
  active,
  icon,
  children,
}: {
  to: string;
  active: boolean;
  icon: ReactNode;
  children: ReactNode;
}) {
  return (
    <Link
      to={to}
      className={`flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition-all duration-200 ${
        active
          ? "bg-secondary text-foreground"
          : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground"
      }`}
    >
      {icon}
      <span className="hidden sm:inline">{children}</span>
    </Link>
  );
}
