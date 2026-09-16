import { Minus, X, Copy } from "lucide-react";
import type { ReactNode } from "react";
import logoMogg from "@/assets/logmog.png.asset.json";

/**
 * Simula o visual final do aplicativo desktop:
 * uma janela do Windows flutuando sobre a área de trabalho.
 * No .exe real (Tauri), a barra de título nativa assume esse papel.
 */
export function WindowShell({ children }: { children: ReactNode }) {
  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#0a0a0c] p-4 text-foreground sm:p-8">
      {/* "Desktop" backdrop */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-48 left-1/3 h-[560px] w-[900px] -translate-x-1/2 rounded-full opacity-15 blur-[140px]"
        style={{ background: "var(--gradient-accent)" }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -bottom-56 right-0 h-[480px] w-[720px] rounded-full opacity-[0.07] blur-[160px]"
        style={{ background: "var(--gradient-accent)" }}
      />

      {/* Janela do aplicativo */}
      <div className="relative flex max-h-[88vh] w-full max-w-md flex-col overflow-hidden rounded-xl border border-white/10 bg-background shadow-[0_40px_120px_-20px_rgba(0,0,0,0.9)] ring-1 ring-black/50">
        {/* Barra de título estilo Windows 11 */}
        <div className="flex h-10 shrink-0 select-none items-center border-b border-border/60 bg-surface/90 pl-3 backdrop-blur-xl">
          <div className="flex min-w-0 flex-1 items-center gap-2.5">
            <img
              src={logoMogg.url}
              alt="MOGG"
              className="h-5 w-5 rounded-full ring-1 ring-white/15"
            />
            <span className="truncate text-xs font-medium text-muted-foreground">
              MOGG <span className="text-muted-foreground/70">— Ministry of Games & Gifts</span>
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
        <div className="relative flex min-h-0 flex-1 flex-col overflow-hidden">
          <div className="relative mx-auto flex w-full flex-1 flex-col px-4 py-4">
            <main className="min-h-0 flex-1 overflow-hidden py-4">{children}</main>
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
