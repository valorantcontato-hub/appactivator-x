import { useCallback, useRef, useState } from "react";
import type {
  ActivationPhase,
  ActivationProgress,
  ActivationResult,
  LogEntry,
  LogLevel,
} from "@/types";
import { getBackend } from "@/services";
import { ACTIVATION_STEPS } from "@/services/steps";
import { createError } from "@/utils/errors";

const INITIAL_PROGRESS: ActivationProgress = {
  step: "steam-check",
  stepIndex: 0,
  totalSteps: ACTIVATION_STEPS.length,
  percent: 0,
  status: "Aguardando",
  etaSeconds: 0,
};

export function useActivation() {
  const [phase, setPhase] = useState<ActivationPhase>("idle");
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [progress, setProgress] = useState<ActivationProgress>(INITIAL_PROGRESS);
  const [result, setResult] = useState<ActivationResult | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const pushLog = useCallback((level: LogLevel, message: string) => {
    setLogs((prev) => [
      ...prev,
      {
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        timestamp: Date.now(),
        level,
        message,
      },
    ]);
  }, []);

  const reset = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setPhase("idle");
    setLogs([]);
    setProgress(INITIAL_PROGRESS);
    setResult(null);
  }, []);

  const cancel = useCallback(() => {
    abortRef.current?.abort();
  }, []);

  const activate = useCallback(
    async (key: string) => {
      if (phase === "running") return;
      const controller = new AbortController();
      abortRef.current = controller;

      setPhase("running");
      setLogs([]);
      setResult(null);
      setProgress({ ...INITIAL_PROGRESS, status: "Iniciando" });
      pushLog("info", "Iniciando processo de ativação");

      const backend = getBackend();
      let res: ActivationResult;
      try {
        res = await backend.activate(
          key,
          {
            onLog: (entry) => setLogs((prev) => [...prev, entry]),
            onProgress: (p) => setProgress(p),
          },
          controller.signal,
        );
      } catch {
        res = { ok: false, error: createError("UNKNOWN") };
      }

      setResult(res);
      setPhase(res.ok ? "success" : "error");
      if (res.ok) {
        setProgress((p) => ({ ...p, percent: 100, status: "Concluído", etaSeconds: 0 }));
      }
      abortRef.current = null;
    },
    [phase, pushLog],
  );

  return { phase, logs, progress, result, activate, cancel, reset };
}
