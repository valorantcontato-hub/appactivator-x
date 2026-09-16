# Game Key Activator

Quero criar um aplicativo desktop para Windows que posteriormente será transformado em um único arquivo .exe portátil.

O projeto deve ser desenvolvido em React + TypeScript, com arquitetura preparada para futura integração com Tauri, mantendo frontend e backend separados.

IMPORTANTE:

Interface extremamente profissional e moderna.

Visual semelhante a launchers premium.

Tema escuro.

Design clean.

Animações suaves.

Responsivo.

Estrutura pronta para virar um único executável Windows.

Não utilizar PowerShell visível ao usuário.

Nenhuma janela de terminal deve aparecer.

Todo o fluxo deve ocorrer dentro da interface.

FUNCIONAMENTO:

O usuário terá apenas um campo para inserir sua key.

Fluxo:

Usuário insere a key.

Clica em "Ativar".

O aplicativo inicia o processo de ativação.

O sistema executa internamente o Script 1.

Após finalizar, identifica automaticamente o AppID do jogo ativado.

Executa automaticamente o Script 2 utilizando o AppID identificado.

Exibe resultado final ao usuário.

O objetivo é que o usuário NÃO precise:

Abrir PowerShell.

Inserir AppID manualmente.

Executar múltiplas etapas.

Baixar arquivos adicionais.

Tudo deve ocorrer através de um único botão.

TELA PRINCIPAL:

Logo no topo.

Campo:

"Insira sua key"

Botão:

"ATIVAR"

Abaixo:

Console visual de logs em tempo real.

Exemplo:

[✓] Verificando Steam
[✓] Steam encontrada
[✓] Iniciando ativação
[✓] Ativação concluída
[✓] Identificando AppID
[✓] AppID encontrado
[✓] Aplicando correções
[✓] Processo finalizado

Também exibir:

Barra de progresso.

Status atual.

Tempo estimado.

Indicador visual de sucesso ou falha.

TELA DE CONFIGURAÇÕES:

Diretório da Steam detectado automaticamente.

Possibilidade de alterar manualmente.

Opção para reescanear instalação da Steam.

Exibir versão do aplicativo.

TRATAMENTO DE ERROS:

Exemplos:

Steam não encontrada.

Key inválida.

Falha de conexão.

AppID não identificado.

Processo interrompido.

Cada erro deve possuir mensagem amigável para o usuário.

ARQUITETURA:

Preparar desde já:

src/
├─ pages
├─ components
├─ hooks
├─ services
├─ utils
├─ types

Criar camada de serviços para:

Ativação de key.

Detecção de Steam.

Detecção de AppID.

Execução dos processos.

Logs.

IMPORTANTE:

O projeto deve ser criado pensando que posteriormente um agente Devin irá:

Implementar toda a lógica nativa do Windows.

Integrar os scripts existentes.

Empacotar tudo em um único executável .exe.

Portanto o frontend já deve estar totalmente preparado para essa integração futura.

O resultado deve parecer um software comercial profissional e não uma ferramenta improvisada.

Depois que o Lovable gerar a interface, você passa o repositório para o Devin e pede para ele implementar a lógica nativa e gerar o .exe único.

This project was built with [Lovable](https://lovable.dev).

**Live app**: https://appactivator-x.lovable.app

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/ee7d38e3-5b49-4f7e-9f5a-abd725647adb).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
