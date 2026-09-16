import { Link, useRouterState } from "@tanstack/react-router";
import { Minus, Settings, Square, X, Home } from "lucide-react";
import type { ReactNode } from "react";
import { Logo } from "./Logo";

export function WindowShell({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="relative min-h-screen overflow-hidden bg-background text-foreground">
      <div
        aria-hidden
        className="pointer-events-none absolute -top-40 left-1/2 h-[520px] w-[820px] -translate-x-1/2 rounded-full opacity-25 blur-[120px]"
        style={{ background: "var(--gradient-accent)" }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.15]"
        style={{
          backgroundImage:
            "linear-gradient(var(--color-border) 1px, transparent 1px), linear-gradient(90deg, var(--color-border) 1px, transparent 1px)",
          backgroundSize: "56px 56px",
          maskImage: "radial-gradient(ellipse at 50% 0%, black, transparent 75%)",
        }}
      />

      <div className="relative mx-auto flex min-h-screen w-full max-w-5xl flex-col px-4 py-6 sm:px-6">
        <header className="flex items-center justify-between rounded-2xl border border-border/70 bg-surface/80 px-4 py-3 backdrop-blur-xl">
          <Logo />

          <div className="flex items-center gap-1">
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
            <div className="ml-2 hidden items-center gap-1 border-l border-border/70 pl-2 sm:flex">
              <WindowDot icon={<Minus className="h-3 w-3" />} label="Minimizar" />
              <WindowDot icon={<Square className="h-2.5 w-2.5" />} label="Maximizar" />
              <WindowDot icon={<X className="h-3 w-3" />} label="Fechar" danger />
            </div>
          </div>
        </header>

        <main className="flex-1 py-6">{children}</main>

        <footer className="flex items-center justify-between border-t border-border/60 pt-3 text-[11px] text-muted-foreground">
          <span>© 2026 Nexus Activate</span>
          <span className="font-mono">Windows x64 · build local</span>
        </footer>
      </div>
    </div>
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

function WindowDot({
  icon,
  label,
  danger = false,
}: {
  icon: ReactNode;
  label: string;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={`flex h-7 w-7 items-center justify-center rounded-md text-muted-foreground transition-colors ${
        danger ? "hover:bg-destructive hover:text-destructive-foreground" : "hover:bg-secondary"
      }`}
    >
      {icon}
    </button>
  );
}
