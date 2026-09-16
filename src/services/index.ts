import type { ActivationBackend } from "@/types";
import { mockBackend } from "./mockBackend";
import { isTauriAvailable, tauriBackend } from "./tauriBackend";

/** Escolhe automaticamente o backend nativo quando rodando dentro do Tauri. */
export function getBackend(): ActivationBackend {
  return isTauriAvailable() ? tauriBackend : mockBackend;
}

export { ACTIVATION_STEPS, TOTAL_WEIGHT } from "./steps";
export { APP_VERSION } from "./mockBackend";
