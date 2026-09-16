import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { ShieldCheck, Gamepad2, HardDrive } from "lucide-react";
import { WindowShell } from "@/components/WindowShell";
import { KeyField } from "@/components/KeyField";
import { LogConsole } from "@/components/LogConsole";
import { ProgressPanel } from "@/components/ProgressPanel";
import { ResultBanner } from "@/components/ResultBanner";
import { useActivation } from "@/hooks/useActivation";
import { useSteamDetection } from "@/hooks/useSteamDetection";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Nexus Activate — Ativação automática de jogos Steam" },
      {
        name: "description",
        content:
          "Ative seu jogo na Steam com um único clique: detecção automática de AppID, logs em tempo real e progresso detalhado.",
      },
      { property: "og:title", content: "Nexus Activate — Ativação automática de jogos Steam" },
      {
        property: "og:description",
        content:
          "Insira sua key, clique em Ativar e acompanhe todo o processo pela interface. Sem terminal, sem etapas manuais.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

function Index() {
  const [key, setKey] = useState("");
  const { phase, logs, progress, result, activate, cancel, reset } = useActivation();
  const { info } = useSteamDetection();

  return (
    <WindowShell>
      <div className="space-y-5">
        <section className="rounded-2xl border border-border/70 bg-surface/70 p-6 backdrop-blur-xl duration-500 animate-in fade-in slide-in-from-bottom-2">
          <div className="mb-6 flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground">
            <Badge
              icon={<HardDrive className="h-3 w-3" />}
              tone={info?.found ? "ok" : "warn"}
              label={info?.found ? "Steam detectada" : "Steam não localizada"}
            />
            <Badge
              icon={<ShieldCheck className="h-3 w-3" />}
              tone="ok"
              label="Processo 100% interno"
            />
            <Badge
              icon={<Gamepad2 className="h-3 w-3" />}
              tone="neutral"
              label="AppID automático"
            />
          </div>

          <h1 className="font-display text-2xl font-semibold tracking-tight text-foreground">
            Ativação em um clique
          </h1>
          <p className="mb-6 mt-1 max-w-xl text-sm text-muted-foreground">
            Insira sua key de ativação. O aplicativo executa todas as etapas automaticamente,
            identifica o AppID do jogo e aplica as correções necessárias.
          </p>

          <KeyField
            value={key}
            onChange={setKey}
            onSubmit={() => activate(key)}
            onCancel={cancel}
            phase={phase}
          />
        </section>

        {result && <ResultBanner result={result} onReset={reset} />}

        <ProgressPanel phase={phase} progress={progress} />
        <LogConsole logs={logs} running={phase === "running"} />
      </div>
    </WindowShell>
  );
}

function Badge({
  icon,
  label,
  tone,
}: {
  icon: React.ReactNode;
  label: string;
  tone: "ok" | "warn" | "neutral";
}) {
  const toneClass =
    tone === "ok"
      ? "border-success/30 bg-success/10 text-success"
      : tone === "warn"
        ? "border-warning/30 bg-warning/10 text-warning"
        : "border-border bg-surface-2 text-muted-foreground";
  return (
    <span
      className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-medium ${toneClass}`}
    >
      {icon}
      {label}
    </span>
  );
}
