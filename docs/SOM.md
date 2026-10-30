# Som

## O que o Godot já traz (e o jogo usa)

- **Barramentos com efeitos** (painel *Áudio*, embaixo no editor): o jogo cria Music, Ambience,
  SFX e UI. O SFX tem um eco leve (Reverb, cara de pátio de chapa) e o Master um limitador
  (HardLimiter), para vários golpes juntos não estourarem. Dá para mexer nos efeitos ali,
  ou acrescentar outros (EQ, Compressor, Distortion, Chorus...).
- **AudioStreamRandomizer:** cada evento sorteia uma das variações, sem repetir a mesma em
  seguida, e varia a afinação um pouco. Por isso 3 golpes parecem 30.
- **Som 3D** (AudioStreamPlayer3D): os efeitos têm posição no mundo; o "ouvido" fica no chão,
  no meio do grupo (câmera de cima) ou na câmera (atrás do herói), virado como a tela.
  Golpe à esquerda soa à esquerda.
- **Música em loop com troca suave** entre menu e mundo. Para trilha que muda com a luta, o
  Godot tem AudioStreamInteractive (troca de faixa por estado) e AudioStreamSynchronized
  (camadas que entram e saem); dá para usar quando houver música de verdade.

O Godot **não** traz sons prontos. Os do jogo vêm de dois lugares:
- **Kenney** (CC0, uso livre): pulo, pouso, moeda, dano e destruição de inimigo, equipar
  (`audio/sfx/kenney_*.ogg`).
- **Sintetizados para o jogo** por `tools/gerar_sons.py` (Python + numpy + ffmpeg): golpes de
  lâmina, impactos, metal, pregos, poção, baú, contêiner, subir de nível, chip, interface,
  grito e "chip queimando" do Corrompido, ambiente de ferro-velho e o tema do menu.

## Trocar ou acrescentar um som

- **Trocar:** ponha o arquivo novo (.ogg ou .wav) em `audio/sfx/` com o mesmo nome do antigo.
- **Mais variações:** acrescente o nome do arquivo na lista `files` do evento em
  `audio/sound_bank.gd`.
- **Evento novo:** uma linha em `SoundBank.EVENTS` (arquivos, volume, variação de afinação,
  barramento) e, no código, `Sound.play("nome", posição)`. Efeitos que todos da sala precisam
  ouvir passam pelos `fx_*` das entidades (rodam em todas as máquinas).
- **Música:** arquivo em `audio/music/` e o nome em `SoundBank.MUSIC`.

Volumes (geral, música/ambiente, efeitos) ficam no menu de pausa e são salvos por máquina.

## Onde achar sons de verdade

- Kenney (kenney.nl): pacotes Impact Sounds, RPG Audio, Sci-fi Sounds, Interface Sounds (CC0).
- Sonniss "GDC Game Audio Bundle" (grátis, uso comercial liberado).
- freesound.org (filtre por CC0).
- Para trilha: encomendar de um compositor, ou bancos com licença comercial.

## Voz (online)

- **Configurações > Voz** (menu ou aba Voz da pausa): microfone deste PC, modo (desligada,
  abre quando fala, ou apertar para falar com **V** / **direcional para cima**), sensibilidade
  com medidor ao vivo (a barra fica verde quando a voz abre), **rádio velho** na própria voz
  (os outros ouvem com o filtro), volume das vozes e **voz mais baixa com a distância** entre os
  heróis.
- **Sofá:** o Godot capta um microfone por vez, então todos do mesmo PC falam pelo mesmo; quem
  está junto já se ouve na sala, e o microfone leva a voz do grupo para quem está online.
- **Aba Voz da pausa:** cada pessoa da sala com volume e "mudo para mim"; o host tem
  "mudo para todos" (o host para de repassar a voz dela e todo mundo vê o microfone cortado).
- No cartão de quem fala aparece um microfone verde; cortado em vermelho se o host mutou.
- Por baixo (audio/voice_chat.gd): 16 mil amostras por segundo em mu-law (1 byte por amostra,
  uns 16 KB/s por pessoa enquanto fala), pacotes de 40 ms, convidados mandam ao host e ele
  repassa; cada voz toca num som 3D preso aos heróis daquele PC. O rádio é um barramento
  (VozRadio) com filtro de faixa, saturação "lo-fi" e um chiado ao abrir.
- Ao publicar: Mac precisa da permissão de microfone no export; no Xbox, a capacidade de
  microfone do GDK e as regras de chat da plataforma (bloqueio, denúncia) entram no port.
