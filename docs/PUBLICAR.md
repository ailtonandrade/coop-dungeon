# Exportar, instalar e publicar

## PC (Windows): .exe e instalador

1. No Godot 4.7: **Editor > Gerenciar modelos de exportação > Baixar e instalar** (uma vez só).
2. Dê dois cliques em `tools/exportar_windows.bat` (ou **Projeto > Exportar > Windows > Exportar projeto**).
   Sai em `..\export\windows\` (fora da pasta do projeto): `Corrumpted.exe` + `Corrumpted.pck`.
   Os dois arquivos juntos já são o jogo: dá para zipar e mandar para um amigo.
3. Instalador (opcional): instale o **Inno Setup 6** (gratuito) e rode o `.bat` de novo. Ele gera
   `..\export\instalador\Corrumpted-Setup.exe` (atalho no menu e na área de trabalho, desinstalador).
   A configuração fica em `installer/corrumpted.iss`.

O editor de mapa, as ferramentas, os testes e a documentação ficam fora da exportação.

**Steam:** não precisa de instalador; envia-se a pasta exportada pelo Steamworks.
**Microsoft Store (PC) e Xbox:** usam o pacote do Xbox (abaixo), que serve para os dois.

## Xbox: como funciona de verdade

- O **modo desenvolvedor** que se ativa num Series S/X comum (app Dev Mode Activation) roda só
  apps **UWP**. O Godot 4 não exporta para UWP (o Godot 3 exportava), então um jogo em Godot 4
  não roda nesse modo.
- Jogo de verdade no Xbox (e na Microsoft Store) é feito com o **GDK** e empacotado como
  **MSIXVC** (ferramenta `makepkg` do GDK). Para isso:
  1. Cadastrar o jogo no **ID@Xbox** (programa gratuito da Microsoft para estúdios independentes;
     pedem uma apresentação do jogo).
  2. Aprovado, você recebe o GDK e o caminho para um kit de desenvolvimento (confirme com eles se o
     seu Series S serve como kit; o modo dev comum não roda jogos do GDK).
  3. O Godot não exporta para console sozinho: o port vem da **W4 Games** (empresa dos criadores do
     Godot, pago) ou de um estúdio de port. Ele gera o build do GDK; o `makepkg` gera o `.msixvc`.
  4. O mesmo pacote do GDK serve para a Microsoft Store no PC (com cross save pela conta Xbox).
- Até lá, o código já está separado para isso: plataforma só em `platform/`, controles por slot,
  pausa ao desconectar controle prevista, save atrás do SaveService.

## Testar no Series S hoje: versão Web no Edge do Xbox

O Xbox tem o navegador Edge (o mesmo motor do Chrome), e a versão Web do jogo roda nele.
É para sentir o jogo na TV com o controle; o desempenho é menor que o do jogo nativo e,
no navegador, só existe o co-op de sofá (sem online).

1. Exporte: **Projeto > Exportar > Web > Exportar projeto** (sai em `..\export\web\`).
2. Coloque num endereço que o Xbox alcance. O jeito mais fácil:
   - **itch.io:** crie uma página de jogo como rascunho (privada), envie um .zip da pasta `web`
     marcando "This file will be played in the browser" e abra o link no Edge do Xbox.
   - **Ou na rede de casa:** no PC, dentro de `export\web`, rode `python -m http.server 8000` e
     abra `http://IP-DO-PC:8000` no Edge do Xbox (o PC e o Xbox na mesma rede).
3. No Edge do Xbox, use tela cheia. Se o controle mexer um cursor em vez do herói, me avise para
   ajustarmos a página do jogo para o navegador do console.
