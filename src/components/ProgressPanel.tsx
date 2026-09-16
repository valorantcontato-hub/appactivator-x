import { CheckCircle2, CircleAlert, Loader2, Circle } from "lucide-react";
import type { ActivationPhase, ActivationProgress } from "@/types";

export function ProgressPanel({
  phase,
  progress,
}: {
  phase: ActivationPhase;
  progress: ActivationProgress;
}) {
  const running = phase === "running";
  const percent = phase === "success" ? 100 : progress.percent;

  return (
    <section className="rounded-xl border border-border/70 bg-surface/70 px-4 py-3 backdrop-blur-xl">
      <div className="flex items-center justify-between gap-3 text-xs">
        <div className="flex min-w-0 items-center gap-2">
          <StatusIcon phase={phase} />
          <span className="truncate font-medium text-foreground">
            {phase === "idle"
              ? "Pronto para iniciar"
              : phase === "success"
                ? "Ativação concluída"
                : phase === "error"
                  ? "Processo interrompido"
                  : progress.status}
          </span>
        </div>
        <span className="shrink-0 font-mono text-muted-foreground">{percent}%</span>
      </div>

      <div className="mt-2.5 h-1.5 overflow-hidden rounded-full bg-surface-2">
        <div
          className="h-full rounded-full transition-all duration-500 ease-out"
          style={{
            width: `${percent}%`,
            background:
              phase === "error" ? "var(--color-destructive)" : "var(--gradient-accent)",
          }}
        />
      </div>
    </section>
  );
}

function StatusIcon({ phase }: { phase: ActivationPhase }) {
  if (phase === "success") return <CheckCircle2 className="h-4 w-4 text-success" />;
  if (phase === "error") return <CircleAlert className="h-4 w-4 text-destructive" />;
  if (phase === "running") return <Loader2 className="h-4 w-4 animate-spin text-primary" />;
  return <Circle className="h-4 w-4 text-muted-foreground" />;
}
