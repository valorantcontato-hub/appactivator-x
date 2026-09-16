import { CheckCircle2, CircleAlert, Clock, Loader2, Circle } from "lucide-react";
import type { ActivationPhase, ActivationProgress } from "@/types";
import { ACTIVATION_STEPS } from "@/services/steps";
import { formatDuration } from "@/utils/format";

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
    <section className="rounded-2xl border border-border/70 bg-surface/70 p-4 backdrop-blur-xl">
      <div className="flex items-center justify-between text-xs">
        <div className="flex items-center gap-2">
          <StatusIcon phase={phase} />
          <span className="font-medium text-foreground">
            {phase === "idle"
              ? "Pronto para iniciar"
              : phase === "success"
                ? "Ativação concluída"
                : phase === "error"
                  ? "Processo interrompido"
                  : progress.status}
          </span>
        </div>
        <div className="flex items-center gap-3 text-muted-foreground">
          {running && (
            <span className="flex items-center gap-1">
              <Clock className="h-3 w-3" />
              restam ~{formatDuration(progress.etaSeconds)}
            </span>
          )}
          <span className="font-mono text-foreground">{percent}%</span>
        </div>
      </div>

      <div className="mt-3 h-2 overflow-hidden rounded-full bg-surface-2">
        <div
          className="h-full rounded-full transition-all duration-500 ease-out"
          style={{
            width: `${percent}%`,
            background:
              phase === "error" ? "var(--color-destructive)" : "var(--gradient-accent)",
          }}
        />
      </div>

      <ol className="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        {ACTIVATION_STEPS.map((step, index) => {
          const done = phase === "success" || index < progress.stepIndex + (running ? 0 : 0);
          const isCurrent = running && index === progress.stepIndex;
          const completed = phase === "success" || (percent > 0 && index < progress.stepIndex);
          return (
            <li
              key={step.id}
              className={`flex items-center gap-2 rounded-lg border px-3 py-2 text-xs transition-all duration-300 ${
                completed || done
                  ? "border-success/30 bg-success/5 text-foreground"
                  : isCurrent
                    ? "border-primary/40 bg-primary/5 text-foreground"
                    : "border-border/60 text-muted-foreground"
              }`}
            >
              {completed ? (
                <CheckCircle2 className="h-3.5 w-3.5 text-success" />
              ) : isCurrent ? (
                <Loader2 className="h-3.5 w-3.5 animate-spin text-primary" />
              ) : (
                <Circle className="h-3.5 w-3.5 opacity-40" />
              )}
              {step.label}
            </li>
          );
        })}
      </ol>
    </section>
  );
}

function StatusIcon({ phase }: { phase: ActivationPhase }) {
  if (phase === "success") return <CheckCircle2 className="h-4 w-4 text-success" />;
  if (phase === "error") return <CircleAlert className="h-4 w-4 text-destructive" />;
  if (phase === "running") return <Loader2 className="h-4 w-4 animate-spin text-primary" />;
  return <Circle className="h-4 w-4 text-muted-foreground" />;
}
