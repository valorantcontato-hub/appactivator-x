import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { WindowShell } from "@/components/WindowShell";
import { KeyField } from "@/components/KeyField";
import { ProgressPanel } from "@/components/ProgressPanel";
import { ResultBanner } from "@/components/ResultBanner";
import { useActivation } from "@/hooks/useActivation";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "MOGG — Ministry of Games & Gifts" },
      {
        name: "description",
        content:
          "Ative seu jogo com um único clique: detecção automática de AppID e progresso em tempo real.",
      },
      { property: "og:title", content: "MOGG — Ministry of Games & Gifts" },
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

  const lastLog = logs.length > 0 ? logs[logs.length - 1] : undefined;

  return (
    <WindowShell>
      <div className="space-y-4">
        <section className="rounded-xl border border-border/70 bg-surface/70 p-4 backdrop-blur-xl duration-500 animate-in fade-in slide-in-from-bottom-2">
          <KeyField
            value={key}
            onChange={setKey}
            onSubmit={() => activate(key)}
            onCancel={cancel}
            phase={phase}
          />
        </section>

        {result && <ResultBanner result={result} onReset={reset} />}

        <ProgressPanel phase={phase} progress={progress} message={lastLog?.message} />
      </div>
    </WindowShell>
  );
}
