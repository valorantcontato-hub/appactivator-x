import type { ActivationStep } from "@/types";

export const ACTIVATION_STEPS: ActivationStep[] = [
  { id: "steam-check", label: "Verificando Steam", weight: 10 },
  { id: "key-validate", label: "Validando key", weight: 12 },
  { id: "script-one", label: "Executando ativação", weight: 33 },
  { id: "appid-detect", label: "Identificando AppID", weight: 15 },
  { id: "script-two", label: "Aplicando correções", weight: 25 },
  { id: "finalize", label: "Finalizando", weight: 5 },
];

export const TOTAL_WEIGHT = ACTIVATION_STEPS.reduce((sum, s) => sum + s.weight, 0);
