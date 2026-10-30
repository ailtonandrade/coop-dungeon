# Jogar online com amigos de fora da sua rede

## Quem abre o mundo (host)

1. Crie ou abra um mundo **Aberto** ou **Privado** (Offline é só o sofá: não aceita ninguém
   pela rede). Para só entrar quem você quiser, ponha uma **senha** ao criar o mundo, ou na
   pausa (aba Jogo > Senha do mundo; vazio = sem senha). Vale para a rede local e a internet.
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
2. **Buscar mundos** > digite o **código do mundo** (ou o IP) e, se o mundo tiver, a **senha**
   > **Entrar**. Na lista da rede local, mundos com senha aparecem marcados.
3. Dentro, aperte **Start** (ou Enter) e escolha o personagem (ou crie um, até 5 por PC).

## Chat do mundo

Todo mundo da sala vê. **Enter** abre (teclado), digita e Enter manda; no controle, o
**direcional para baixo** abre as mensagens rápidas ("Bora!", "Cuidado!", "Preciso de cura!"...).
O chat mostra também quem entrou, quem saiu e quem subiu de nível. As mensagens somem sozinhas
depois de um tempo e voltam ao abrir. Quem o host mutou para todos (aba Voz) fica mudo também no
chat; o host limita o tamanho e a frequência das mensagens.

## Voz

Com o microfone ligado (Configurações > Voz), a sala se ouve; a voz fica mais baixa quando os
heróis estão longe (opcional). Na pausa, aba Voz: volume e mudo de cada pessoa só para você;
o host pode mutar alguém para todos. Detalhes em [`SOM.md`](SOM.md).

## VPN de jogo (funciona até com CGNAT)

Todos instalam a mesma, entram na mesma rede da VPN, e quem entra usa o **IP da VPN** do host
no campo do código:
- **Radmin VPN** (grátis, Windows, a mais simples: cria uma "rede" com nome e senha).
- **ZeroTier** ou **Tailscale** (grátis, Windows/Mac/Linux).

## No futuro

Na Steam e no Xbox, os servidores de passagem deles conectam todo mundo sem porta e sem VPN
(convite pela lista de amigos). Isso entra quando o jogo for para essas lojas (a rede do jogo
já está separada para trocar o "cano" por baixo).
