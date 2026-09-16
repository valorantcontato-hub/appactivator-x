# Prompt para o Devin — Implementação Nativa (Tauri + Windows .exe)

## Contexto

Este projeto é o frontend completo de um ativador de keys Steam. A interface já está
100% pronta em React + TypeScript (TanStack Start). Sua tarefa é **apenas** implementar a
camada nativa em Tauri (Rust) e gerar o executável único — **não altere nada em `src/`**.

## O que já existe

- **Frontend completo** em `src/` — telas, componentes, hooks, serviços, tipos.
- **Camada de serviços abstraída** — `src/services/index.ts` escolhe automaticamente
  entre `tauriBackend` (quando `window.__TAURI__` existe) e `mockBackend` (navegador).
- **Dois scripts PowerShell reais** em `native/scripts/`:
  - `script1-ativacao.ps1` — equivalente a `irm keyssteam.com/install | iex` (ativação da key).
  - `script2-correcao-download.ps1` — equivalente a `irm keyssteam.com/internet | iex` (correção de download).
- **Guia de integração** em `README-INTEGRACAO.md` — comandos Tauri, eventos, fluxo, códigos de erro.

## O que você deve implementar

### 1. Projeto Tauri

- Criar a estrutura Tauri na raiz do projeto (`src-tauri/` ou `tauri/`).
- Configurar o frontend como dev server/build (Vite, porta 8080).
- Janela: 576×620 aprox., sem barra de título nativa visível OU com barra de título customizada
  (decorations: false no Tauri config para usar a barra já implementada em `WindowShell.tsx`).
- Tema escuro já está no CSS — não mexa.

### 2. Comandos Tauri (Rust → frontend)

Implemente exatamente estes 5 comandos, conforme `README-INTEGRACAO.md`:

| Comando | Args | Retorno |
| --- | --- | --- |
| `detect_steam` | — | `{ path: string, found: boolean, steamId?: string }` |
| `set_steam_path` | `{ path: string }` | `{ path: string, found: boolean }` |
| `start_activation` | `{ key: string }` | `{ ok: boolean, appId?: string, gameName?: string, error?: { code, message, hint } }` |
| `cancel_activation` | — | `void` |
| `get_app_version` | — | `string` (ex: "1.0.0") |

### 3. Eventos Tauri (Rust → frontend)

Emita durante `start_activation`:

| Evento | Payload |
| --- | --- |
| `activation://log` | `{ id: string, timestamp: number, level: "info"\|"success"\|"warn"\|"error", message: string }` |
| `activation://progress` | `{ step: string, stepIndex: number, totalSteps: number, percent: number, status: string, etaSeconds: number }` |

IDs de etapa (`step`): `steam-check`, `key-validate`, `script-one`, `appid-detect`,
`script-two`, `finalize` (ver `src/services/steps.ts` para os pesos/ordem).

### 4. Execução dos scripts

- **Embarcar** os dois `.ps1` de `native/scripts/` como recursos do binário (Tauri resources).
  Nenhum download em runtime.
- **Script 1** (`script1-ativacao.ps1`):
  - Executar via PowerShell oculto — **sem janela de terminal visível**.
  - Usar `CREATE_NO_WINDOW` (Windows API) ou `-WindowStyle Hidden -NoProfile`.
  - O script lê a key via `Read-Host` — alimentar a key via **stdin** (pipe) ou adaptar
    para aceitar `-Key <key>` como parâmetro (adicionar `param([string]$Key)` na primeira linha).
  - Capturar stdout/stderr linha a linha e reemitir como `activation://log`.
- **Script 2** (`script2-correcao-download.ps1`):
  - Já adaptado para modo não interativo: aceita `-AppId <appid>` como parâmetro.
  - Executar também oculto, capturando saída.
- **Detecção do AppID**: após o Script 1, detectar o AppID do jogo ativado:
  - Ler `steamapps/*.manifest` ou `libraryfolders.vdf` no diretório da Steam.
  - Ou reutilizar helpers do Script 2 (`Get-ShadowKeysAppIds`, `Get-RecentPlayedAppIds`).
  - O AppID detectado é passado para o Script 2 via `-AppId`.

### 5. Fluxo completo (`start_activation`)

```
detect_steam → se não encontrado, retornar erro STEAM_NOT_FOUND
validar key  → se inválida, retornar erro INVALID_KEY
executar Script 1 (oculto, key via stdin) → emitir logs + progress
detectar AppID → se não encontrado, retornar erro APPID_NOT_FOUND
executar Script 2 (oculto, -AppId <detectado>) → emitir logs + progress
finalizar → retornar { ok: true, appId, gameName }
```

### 6. Tratamento de erros

Códigos de erro (já mapeados no frontend em `src/utils/errors.ts`):

| Código | Quando |
| --- | --- |
| `STEAM_NOT_FOUND` | Steam não instalada ou não encontrada |
| `INVALID_KEY` | Key rejeitada pelo servidor de ativação |
| `NETWORK_FAILURE` | Falha de conexão durante ativação |
| `APPID_NOT_FOUND` | AppID não pôde ser detectado após Script 1 |
| `PROCESS_ABORTED` | Usuário cancelou ou processo foi interrompido |
| `SCRIPT_FAILED` | Script 1 ou 2 terminou com código de erro |
| `UNKNOWN` | Qualquer outro erro |

Retornar sempre `{ ok: false, error: { code, message, hint } }` com mensagem em pt-BR.

### 7. Empacotamento

- Build final: **executável único portátil** para Windows x64.
- Nenhuma janela de terminal em nenhum momento do fluxo.
- Scripts embarcados no binário.
- WebView2 (já incluído pelo Tauri).

## Não alterar

- Nada em `src/` — toda a interface, tipos, serviços e hooks já estão prontos.
- O `README-INTEGRACAO.md` já documenta o contrato completo.

## Resumo

```
Leia README-INTEGRACAO.md e DEVIN-PROMPT.md na raiz.
Implemente a camada nativa Tauri (Rust) com os 5 comandos e 2 eventos especificados.
Embarque os scripts de native/scripts/ como recursos.
Execute o fluxo: Script 1 → detectar AppID → Script 2 → resultado.
Gere o executável único para Windows x64.
Não altere nada em src/.
```
