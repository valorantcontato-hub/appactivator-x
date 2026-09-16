import type {
  ActivationBackend,
  ActivationEvents,
  ActivationProgress,
  ActivationResult,
  LogEntry,
  SteamInfo,
} from "@/types";
import { toAppError } from "@/utils/errors";

/**
 * Adaptador para a camada nativa (Tauri).
 *
 * A implementação nativa deve expor os comandos:
 *   detect_steam        -> SteamInfo
 *   set_steam_path      -> SteamInfo        (args: { path })
 *   start_activation    -> ActivationResult (args: { key })
 *   cancel_activation   -> void
 *   get_app_version     -> string
 *
 * E emitir os eventos:
 *   activation://log      -> LogEntry
 *   activation://progress -> ActivationProgress
 */

type TauriApi = {
  invoke: <T>(cmd: string, args?: Record<string, unknown>) => Promise<T>;
  listen: <T>(event: string, handler: (e: { payload: T }) => void) => Promise<() => void>;
};

function getTauri(): TauriApi | null {
  const w = globalThis as unknown as { __TAURI__?: { core?: unknown; event?: unknown } };
  const core = w.__TAURI__?.core as { invoke?: TauriApi["invoke"] } | undefined;
  const event = w.__TAURI__?.event as { listen?: TauriApi["listen"] } | undefined;
  if (core?.invoke && event?.listen) {
    return { invoke: core.invoke, listen: event.listen };
  }
  return null;
}

export function isTauriAvailable(): boolean {
  return getTauri() !== null;
}

export const tauriBackend: ActivationBackend = {
  name: "tauri",

  async detectSteam() {
    return getTauri()!.invoke<SteamInfo>("detect_steam");
  },

  async setSteamPath(path: string) {
    return getTauri()!.invoke<SteamInfo>("set_steam_path", { path });
  },

  async getAppVersion() {
    return getTauri()!.invoke<string>("get_app_version");
  },

  async activate(
    key: string,
    events: ActivationEvents,
    signal: AbortSignal,
  ): Promise<ActivationResult> {
    const tauri = getTauri()!;
    const unlisten: Array<() => void> = [];

    unlisten.push(
      await tauri.listen<LogEntry>("activation://log", (e) => events.onLog(e.payload)),
    );
    unlisten.push(
      await tauri.listen<ActivationProgress>("activation://progress", (e) =>
        events.onProgress(e.payload),
      ),
    );

    const onAbort = () => {
      void tauri.invoke("cancel_activation");
    };
    signal.addEventListener("abort", onAbort, { once: true });

    try {
      return await tauri.invoke<ActivationResult>("start_activation", { key });
    } catch (err) {
      return { ok: false, error: toAppError(err) };
    } finally {
      signal.removeEventListener("abort", onAbort);
      unlisten.forEach((fn) => fn());
    }
  },
};
