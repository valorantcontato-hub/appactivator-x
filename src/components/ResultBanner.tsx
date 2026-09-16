import { CheckCircle2, CircleAlert, RotateCcw } from "lucide-react";
import type { ActivationResult } from "@/types";

export function ResultBanner({
  result,
  onReset,
}: {
  result: ActivationResult;
  onReset: () => void;
}) {
  const ok = result.ok;
  return (
    <section
      className={`flex flex-col gap-3 rounded-2xl border p-4 duration-500 animate-in fade-in slide-in-from-bottom-2 sm:flex-row sm:items-center sm:justify-between ${
        ok ? "border-success/40 bg-success/10" : "border-destructive/40 bg-destructive/10"
      }`}
    >
      <div className="flex items-start gap-3">
        {ok ? (
          <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-success" />
        ) : (
          <CircleAlert className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />
        )}
        <div>
          <p className="font-display text-sm font-semibold text-foreground">
            {ok ? "Ativação concluída com sucesso" : result.error?.message}
          </p>
          <p className="mt-0.5 text-xs text-muted-foreground">
            {ok ? (
              <>
                {result.gameName} · AppID{" "}
                <span className="font-mono text-foreground">{result.appId}</span>
              </>
            ) : (
              result.error?.hint
            )}
          </p>
        </div>
      </div>
      <button
        type="button"
        onClick={onReset}
        className="flex items-center justify-center gap-2 rounded-lg border border-border bg-surface-2 px-4 py-2 text-xs font-medium text-foreground transition-colors hover:bg-secondary"
      >
        <RotateCcw className="h-3.5 w-3.5" />
        {ok ? "Nova ativação" : "Tentar novamente"}
      </button>
    </section>
  );
}
