import type { AppError, AppErrorCode } from "@/types";

const MESSAGES: Record<AppErrorCode, { message: string; hint: string }> = {
  STEAM_NOT_FOUND: {
    message: "Não encontramos a Steam neste computador.",
    hint: "Abra as Configurações e informe manualmente a pasta onde a Steam está instalada.",
  },
  INVALID_KEY: {
    message: "Esta key não é válida ou já foi utilizada.",
    hint: "Confira se digitou corretamente, sem espaços extras.",
  },
  NETWORK_FAILURE: {
    message: "Não foi possível conectar ao servidor de ativação.",
    hint: "Verifique sua internet ou desative temporariamente VPN/firewall e tente novamente.",
  },
  APPID_NOT_FOUND: {
    message: "A ativação terminou, mas não foi possível identificar o jogo.",
    hint: "Reinicie a Steam e execute a ativação novamente.",
  },
  PROCESS_ABORTED: {
    message: "O processo foi interrompido antes de terminar.",
    hint: "Nada foi alterado. Você pode iniciar novamente quando quiser.",
  },
  SCRIPT_FAILED: {
    message: "Uma etapa da ativação falhou.",
    hint: "Feche a Steam e execute o aplicativo como administrador.",
  },
  UNKNOWN: {
    message: "Ocorreu um erro inesperado.",
    hint: "Tente novamente. Se persistir, copie os logs e envie ao suporte.",
  },
};

export function createError(code: AppErrorCode): AppError {
  const entry = MESSAGES[code] ?? MESSAGES.UNKNOWN;
  return { code, message: entry.message, hint: entry.hint };
}

export function toAppError(err: unknown): AppError {
  if (err && typeof err === "object" && "code" in err) {
    const code = (err as { code: string }).code as AppErrorCode;
    if (code in MESSAGES) return createError(code);
  }
  return createError("UNKNOWN");
}
