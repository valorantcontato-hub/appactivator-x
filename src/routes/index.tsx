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
      <div className="space-y-4">
        <section className="rounded-xl border border-border/70 bg-surface/70 p-4 backdrop-blur-xl duration-500 animate-in fade-in slide-in-from-bottom-2">
          <div className="mb-3 flex items-center justify-between">
            <h1 className="font-display text-base font-semibold tracking-tight text-foreground">
              Ativação em um clique
            </h1>
            <span
              className={`flex items-center gap-1.5 rounded-full border px-2 py-0.5 text-[11px] font-medium ${
                info?.found
                  ? "border-success/30 bg-success/10 text-success"
                  : "border-warning/30 bg-warning/10 text-warning"
              }`}
            >
              <HardDrive className="h-3 w-3" />
              {info?.found ? "Steam detectada" : "Steam não localizada"}
            </span>
          </div>

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

