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

## Scripts incluídos no repositório

Os dois scripts PowerShell reais já estão em `native/scripts/` e devem ser
**embarcados como recursos do binário** (nenhum download em runtime):

| Arquivo | Equivalente online | Função |
| --- | --- | --- |
| `native/scripts/script1-ativacao.ps1` | `irm keyssteam.com/install \| iex` | Ativação da key (instala payload OST, DLLs, etc.) |
| `native/scripts/script2-correcao-download.ps1` | `irm keyssteam.com/internet \| iex` | Correção de download do jogo ativado |

### Adaptações necessárias nos scripts

1. **Script 1** — executar oculto (`CREATE_NO_WINDOW`), passando a key informada pelo
   usuário como entrada (o script lê a key via prompt; a camada nativa deve alimentá-la
   via stdin ou adaptar para um parâmetro `-Key`).
2. **Script 2** — já foi adaptado para modo **não interativo**: aceita `-AppId <appid>`
   como parâmetro (o `param()` está na primeira linha). Sem `-AppId`, ele usa o primeiro
   jogo resgatado da conta. O entry point original interativo (banner ASCII, `Read-Host`,
   loop "corrigir outro jogo?") foi substituído por um fluxo direto com `exit 0/1`.
3. Ambos escrevem em stdout/stderr — a camada nativa deve capturar a saída linha a linha
   e reemitir como eventos `activation://log`, mapeando o andamento para
   `activation://progress`.

## Fluxo que a camada nativa deve executar

1. Localizar a Steam (registro do Windows + caminhos padrão + `libraryfolders.vdf`).
2. Validar a key no servidor de ativação.
3. Executar o **Script 1** (PowerShell oculto: `CREATE_NO_WINDOW`, sem console).
4. Detectar o **AppID** do jogo ativado a partir do resultado do Script 1 / `steamapps`
   (o Script 2 também expõe helpers como `Get-ShadowKeysAppIds` e `Get-RecentPlayedAppIds`
   que podem ser reutilizados para essa detecção).
5. Executar o **Script 2** passando `-AppId <appid detectado>`.
6. Finalizar, limpar temporários e retornar `{ ok: true, appId, gameName }`.

Qualquer falha deve retornar `{ ok: false, error: { code, message, hint } }` usando um dos
códigos de `AppErrorCode`: `STEAM_NOT_FOUND`, `INVALID_KEY`, `NETWORK_FAILURE`,
`APPID_NOT_FOUND`, `PROCESS_ABORTED`, `SCRIPT_FAILED`, `UNKNOWN`.
As mensagens amigáveis já existem em `src/utils/errors.ts`.

## Requisitos de empacotamento

- Nenhuma janela de terminal visível (processos criados com `CREATE_NO_WINDOW`).
- Scripts embarcados como recursos do binário (nenhum download em runtime).
- Build final: executável único portátil para Windows x64.

## Prompt sugerido para o agente nativo (Devin)

> Leia `README-INTEGRACAO.md` na raiz. Implemente a camada nativa Tauri com os comandos
> e eventos especificados, embarque os scripts de `native/scripts/` como recursos,
> execute o fluxo de ativação completo (Script 1 → detectar AppID → Script 2) e gere o
> executável único para Windows x64. Não altere nada em `src/`.
