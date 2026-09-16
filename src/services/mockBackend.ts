import type {
  ActivationBackend,
  ActivationEvents,
  ActivationResult,
  LogEntry,
  LogLevel,
  SteamInfo,
} from "@/types";
import { ACTIVATION_STEPS, TOTAL_WEIGHT } from "./steps";
import { createError } from "@/utils/errors";
import { isKeyFormatValid } from "@/utils/validation";

export const APP_VERSION = "1.0.0";

let steamState: SteamInfo = {
  found: true,
  path: "C:\\Program Files (x86)\\Steam",
  version: "1758.03.42",
  libraries: ["C:\\Program Files (x86)\\Steam\\steamapps", "D:\\SteamLibrary\\steamapps"],
};

function makeLog(level: LogLevel, message: string): LogEntry {
  return {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    timestamp: Date.now(),
    level,
    message,
  };
}

function wait(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) return reject(createError("PROCESS_ABORTED"));
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    function onAbort() {
      clearTimeout(timer);
      reject(createError("PROCESS_ABORTED"));
    }
    signal.addEventListener("abort", onAbort, { once: true });
  });
}

const CATALOG = [
  { appId: "1091500", name: "Cyberpunk 2077" },
  { appId: "1245620", name: "Elden Ring" },
  { appId: "271590", name: "Grand Theft Auto V" },
  { appId: "1174180", name: "Red Dead Redemption 2" },
];

/**
 * Backend simulado usado no navegador/preview.
 * A implementação nativa (Tauri) substitui esta classe sem mudar a interface.
 */
export const mockBackend: ActivationBackend = {
  name: "mock",

  async detectSteam() {
    await new Promise((r) => setTimeout(r, 600));
    return steamState;
  },

  async setSteamPath(path: string) {
    await new Promise((r) => setTimeout(r, 300));
    steamState = { ...steamState, found: Boolean(path), path: path || null };
    return steamState;
  },

  async getAppVersion() {
    return APP_VERSION;
  },

  async activate(
    key: string,
    events: ActivationEvents,
    signal: AbortSignal,
  ): Promise<ActivationResult> {
    const started = Date.now();
    let done = 0;
    let appId: string | undefined;
    let gameName: string | undefined;

    const emit = (level: LogLevel, message: string) => events.onLog(makeLog(level, message));

    const advance = (index: number, status: string) => {
      const step = ACTIVATION_STEPS[index]!;
      done += step.weight;
      const percent = Math.min(100, Math.round((done / TOTAL_WEIGHT) * 100));
      const elapsed = (Date.now() - started) / 1000;
      const eta = percent > 0 ? (elapsed / percent) * (100 - percent) : 20;
      events.onProgress({
        step: step.id,
        stepIndex: index,
        totalSteps: ACTIVATION_STEPS.length,
        percent,
        status,
        etaSeconds: eta,
      });
    };

    try {
      emit("info", "Verificando instalação da Steam...");
      await wait(900, signal);
      if (!steamState.found || !steamState.path) throw createError("STEAM_NOT_FOUND");
      emit("success", `Steam encontrada em ${steamState.path}`);
      advance(0, "Steam verificada");

      emit("info", "Validando key de ativação...");
      await wait(1100, signal);
      if (!isKeyFormatValid(key)) throw createError("INVALID_KEY");
      emit("success", "Key validada com sucesso");
      advance(1, "Key válida");

      emit("info", "Iniciando ativação (etapa 1 de 2)...");
      await wait(1600, signal);
      emit("info", "Preparando arquivos da Steam...");
      await wait(1400, signal);
      emit("success", "Ativação concluída");
      advance(2, "Ativação concluída");

      emit("info", "Identificando AppID do jogo ativado...");
      await wait(1200, signal);
      const picked = CATALOG[Math.floor(Math.random() * CATALOG.length)];
      appId = picked.appId;
      gameName = picked.name;
      emit("success", `AppID encontrado: ${appId} — ${gameName}`);
      advance(3, "AppID identificado");

      emit("info", `Aplicando correções para o AppID ${appId} (etapa 2 de 2)...`);
      await wait(1800, signal);
      emit("success", "Correções aplicadas");
      advance(4, "Correções aplicadas");

      emit("info", "Finalizando e limpando arquivos temporários...");
      await wait(700, signal);
      emit("success", "Processo finalizado");
      advance(5, "Concluído");

      return { ok: true, appId, gameName };
    } catch (err) {
      const error = (err as { code?: string })?.code
        ? (err as ReturnType<typeof createError>)
        : createError("UNKNOWN");
      emit("error", error.message);
      return { ok: false, error };
    }
  },
};
