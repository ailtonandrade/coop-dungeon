# Jogar online com amigos de fora da sua rede

## Quem abre o mundo (host)

1. Crie ou abra um mundo **Aberto** ou **Privado** (Offline não aceita ninguém de fora).
2. Na primeira vez, o Windows pergunta sobre o Firewall: clique em **Permitir** (redes
   privadas e públicas).
3. Aperte **Start/Esc**: o menu de pausa diz como ficou o acesso pela internet:
   - **"Aberto pela internet"**: o roteador abriu a porta sozinho (UPnP). Clique em
     **Copiar código do mundo** e mande o código (ex.: `K7Q2-9XM`) para o amigo.
   - **"O roteador não abriu a porta sozinho"**: ligue o **UPnP** nas configurações do
     roteador (costuma ficar em "Avançado" ou "NAT") e abra o mundo de novo; ou libere a porta
     **7777 UDP** para o seu PC ("redirecionamento de porta"). Depois disso o código funciona.
   - **"Seu provedor usa CGNAT"**: o provedor divide o mesmo IP entre vários clientes e nenhuma
     porta abre de fora. Saídas: pedir IP público (ou "IP fixo/válido") ao provedor, ou usar uma
     VPN de jogo (abaixo).
   O topo direito da tela mostra o código enquanto você joga.

## Quem entra

1. Mesma versão do jogo que o host (o mesmo .zip/instalador).
2. **Buscar mundos** > digite o **código do mundo** (ou o IP) > **Entrar**.
3. Dentro, aperte **Start** (ou Enter) para o herói aparecer.

## VPN de jogo (funciona até com CGNAT)

Todos instalam a mesma, entram na mesma rede da VPN, e quem entra usa o **IP da VPN** do host
no campo do código:
- **Radmin VPN** (grátis, Windows, a mais simples: cria uma "rede" com nome e senha).
- **ZeroTier** ou **Tailscale** (grátis, Windows/Mac/Linux).

## No futuro

Na Steam e no Xbox, os servidores de passagem deles conectam todo mundo sem porta e sem VPN
(convite pela lista de amigos). Isso entra quando o jogo for para essas lojas (a rede do jogo
já está separada para trocar o "cano" por baixo).
