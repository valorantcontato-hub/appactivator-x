# Guia de integração nativa (Tauri / Windows)

O frontend já está completo. Para transformar o projeto em um `.exe` portátil único,
basta implementar a camada nativa e os comandos abaixo — **nenhuma tela precisa ser alterada**.

## Seleção automática de backend

`src/services/index.ts` → `getBackend()` retorna:

- `tauriBackend` quando `window.__TAURI__` existe (build nativo);
- `mockBackend` (simulação) no navegador.

A interface contratada está em `src/types/index.ts` → `ActivationBackend`.

## Comandos Tauri esperados

| Comando | Args | Retorno |
| --- | --- | --- |
| `detect_steam` | — | `SteamInfo` |
| `set_steam_path` | `{ path: string }` | `SteamInfo` |
| `start_activation` | `{ key: string }` | `ActivationResult` |
| `cancel_activation` | — | `void` |
| `get_app_version` | — | `string` |

## Eventos emitidos durante a ativação

| Evento | Payload |
| --- | --- |
| `activation://log` | `LogEntry` — `{ id, timestamp, level: "info"\|"success"\|"warn"\|"error", message }` |
| `activation://progress` | `ActivationProgress` — `{ step, stepIndex, totalSteps, percent, status, etaSeconds }` |

Os IDs de etapa (`ActivationStepId`) são: `steam-check`, `key-validate`, `script-one`,
`appid-detect`, `script-two`, `finalize` (ver `src/services/steps.ts`).

## Fluxo que a camada nativa deve executar

1. Localizar a Steam (registro do Windows + caminhos padrão + `libraryfolders.vdf`).
2. Validar a key no servidor de ativação.
3. Executar o **Script 1** (PowerShell oculto: `CREATE_NO_WINDOW`, sem console).
4. Detectar o **AppID** do jogo ativado a partir do resultado do Script 1 / `steamapps`.
5. Executar o **Script 2** passando o AppID detectado.
6. Finalizar, limpar temporários e retornar `{ ok: true, appId, gameName }`.

Qualquer falha deve retornar `{ ok: false, error: { code, message, hint } }` usando um dos
códigos de `AppErrorCode`: `STEAM_NOT_FOUND`, `INVALID_KEY`, `NETWORK_FAILURE`,
`APPID_NOT_FOUND`, `PROCESS_ABORTED`, `SCRIPT_FAILED`, `UNKNOWN`.
As mensagens amigáveis já existem em `src/utils/errors.ts`.

## Requisitos de empacotamento

- Nenhuma janela de terminal visível (processos criados com `CREATE_NO_WINDOW`).
- Scripts embarcados como recursos do binário (nenhum download em runtime).
- Build final: executável único portátil para Windows x64.
