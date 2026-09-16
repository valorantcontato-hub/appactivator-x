import { useEffect, useRef, useState } from "react";
import { Copy, Terminal, Check } from "lucide-react";
import type { LogEntry } from "@/types";
import { formatClock, logMarker } from "@/utils/format";

const LEVEL_CLASS: Record<LogEntry["level"], string> = {
  info: "text-muted-foreground",
  success: "text-success",
  warn: "text-warning",
  error: "text-destructive",
};

export function LogConsole({ logs, running }: { logs: LogEntry[]; running: boolean }) {
  const endRef = useRef<HTMLDivElement>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [logs]);

  const copy = async () => {
    const text = logs
      .map((l) => `${formatClock(l.timestamp)} ${logMarker(l.level)} ${l.message}`)
      .join("\n");
    await navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };

  return (
    <section className="overflow-hidden rounded-2xl border border-border/70 bg-surface/70 backdrop-blur-xl">
      <header className="flex items-center justify-between border-b border-border/70 px-4 py-3">
        <div className="flex items-center gap-2">
          <Terminal className="h-4 w-4 text-primary" />
          <h2 className="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">
            Console de atividade
          </h2>
          {running && (
            <span className="ml-1 flex h-2 w-2 animate-pulse rounded-full bg-primary" aria-hidden />
          )}
        </div>
        <button
          type="button"
          onClick={copy}
          disabled={logs.length === 0}
          className="flex items-center gap-1.5 rounded-md px-2 py-1 text-[11px] text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground disabled:opacity-40"
        >
          {copied ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
          {copied ? "Copiado" : "Copiar"}
        </button>
      </header>

      <div className="h-64 overflow-y-auto px-4 py-3 font-mono text-[13px] leading-relaxed">
        {logs.length === 0 ? (
          <p className="text-muted-foreground/60">
            Aguardando início do processo. Insira sua key e clique em ATIVAR.
          </p>
        ) : (
          logs.map((log) => (
            <div
              key={log.id}
              className="flex gap-2 duration-300 animate-in fade-in slide-in-from-bottom-1"
            >
              <span className="shrink-0 text-muted-foreground/50">{formatClock(log.timestamp)}</span>
              <span className={`shrink-0 ${LEVEL_CLASS[log.level]}`}>{logMarker(log.level)}</span>
              <span className={log.level === "info" ? "text-foreground/80" : LEVEL_CLASS[log.level]}>
                {log.message}
              </span>
            </div>
          ))
        )}
        <div ref={endRef} />
      </div>
    </section>
  );
}
