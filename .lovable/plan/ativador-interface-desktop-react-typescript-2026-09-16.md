# Ativador — Interface desktop (React + TypeScript)

Aplicativo de ativação com visual de launcher premium, tema escuro, pronto para ser empacotado depois como executável único do Windows via Tauri.

## Importante antes de começar

Aqui construímos a interface completa e a camada de serviços. A execução real dos scripts no Windows (Script 1, detecção de AppID, Script 2) só funciona depois que a parte nativa for implementada. Para que você já consiga ver e testar tudo, os serviços virão com uma simulação realista (logs, progresso, erros) que é trocada pela implementação nativa sem alterar nenhuma tela.

## Telas

**Principal**
- Logo no topo, janela com moldura escura e barra superior discreta.
- Campo "Insira sua key" com validação de formato e botão "ATIVAR" (estados: normal, carregando, sucesso, erro).
- Console de logs em tempo real, com marcadores `[✓]`, `[!]`, `[x]`, rolagem automática e opção de copiar.
- Barra de progresso por etapa, status atual, tempo estimado e indicador final de sucesso/falha.
- AppID identificado exibido em destaque quando encontrado.

**Configurações**
- Diretório da Steam detectado automaticamente, com campo para alterar manualmente.
- Botão "Reescanear instalação da Steam".
- Versão do aplicativo e informações do sistema.

## Fluxo de ativação (um único botão)

1. Verifica Steam
2. Valida a key
3. Executa Script 1
4. Identifica o AppID
5. Executa Script 2 com o AppID
6. Aplica correções e finaliza

Cada etapa emite logs e atualiza progresso. Qualquer falha interrompe o fluxo com mensagem amigável: Steam não encontrada, key inválida, falha de conexão, AppID não identificado, processo interrompido.

## Visual

Tema escuro profundo, acento em ciano/azul elétrico, tipografia técnica para o console e geométrica para títulos, cantos suaves, brilho sutil nos elementos ativos, animações de entrada e transição discretas. Layout responsivo, pensado para janela de desktop.

## Estrutura técnica

```text
src/
├─ routes/        (tela principal e configurações)
├─ components/    (console de logs, barra de progresso, campo de key, shell da janela, cards)
├─ hooks/         (useActivation, useSteamDetection, useLogs)
├─ services/      (activation, steam, appid, process, logger — interface única + adaptador mock/nativo)
├─ utils/         (formatação de tempo, validação de key, classificação de erros)
└─ types/         (LogEntry, ActivationStep, ActivationResult, SteamInfo, AppError)
```

- Serviços expostos por uma interface `ActivationBackend`; um adaptador escolhe entre `mock` (navegador) e `tauri` (invoke) por detecção de ambiente. O agente que fizer a parte nativa só implementa o adaptador Tauri.
- Eventos de log/progresso em streaming (callback/EventEmitter), compatível com `listen()` do Tauri.
- Códigos de erro tipados com mensagens amigáveis centralizadas.
- Nenhum terminal visível: toda saída chega pelo console visual da interface.
- Um `README-INTEGRACAO.md` descrevendo os comandos nativos esperados, seus parâmetros e eventos.

## Fora do escopo desta etapa

Configuração do Tauri, compilação do `.exe` e execução real de PowerShell — feitos na etapa nativa seguinte.
