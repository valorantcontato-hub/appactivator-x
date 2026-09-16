export type LogLevel = "info" | "success" | "warn" | "error";

export interface LogEntry {
  id: string;
  timestamp: number;
  level: LogLevel;
  message: string;
}

export type ActivationStepId =
  | "steam-check"
  | "key-validate"
  | "script-one"
  | "appid-detect"
  | "script-two"
  | "finalize";

export interface ActivationStep {
  id: ActivationStepId;
  label: string;
  weight: number;
}

export type ActivationPhase = "idle" | "running" | "success" | "error";

export interface ActivationProgress {
  step: ActivationStepId;
  stepIndex: number;
  totalSteps: number;
  percent: number;
  status: string;
  etaSeconds: number;
}

export interface ActivationResult {
  ok: boolean;
  appId?: string;
  gameName?: string;
  error?: AppError;
}

export type AppErrorCode =
  | "STEAM_NOT_FOUND"
  | "INVALID_KEY"
  | "NETWORK_FAILURE"
  | "APPID_NOT_FOUND"
  | "PROCESS_ABORTED"
  | "SCRIPT_FAILED"
  | "UNKNOWN";

export interface AppError {
  code: AppErrorCode;
  message: string;
  hint?: string;
}

export interface SteamInfo {
  found: boolean;
  path: string | null;
  version?: string;
  libraries?: string[];
}

export interface ActivationEvents {
  onLog: (entry: LogEntry) => void;
  onProgress: (progress: ActivationProgress) => void;
}

export interface ActivationBackend {
  readonly name: "mock" | "tauri";
  detectSteam(): Promise<SteamInfo>;
  setSteamPath(path: string): Promise<SteamInfo>;
  activate(key: string, events: ActivationEvents, signal: AbortSignal): Promise<ActivationResult>;
  getAppVersion(): Promise<string>;
}
