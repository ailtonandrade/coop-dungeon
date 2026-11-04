# Gera e publica uma versão nova do Corrumpted (chamado por lancar_release.bat).
# Tudo no seu PC: exporta com o seu Godot (sem o modo construtor, o editor de missões e os
# editores, que ficam de fora pelo filtro de exportação), compacta e publica no repositório
# PÚBLICO de downloads ($releaseRepo), que é onde os jogos instalados procuram versão nova.
# O código continua no repositório do projeto ($sourceRepo).
$ErrorActionPreference = "Stop"
$sourceRepo = "ailtonandrade/coop-dungeon"
$releaseRepo = "ailtonandrade/corrumpted"
$configDir = Join-Path $env:APPDATA "Corrumpted"
$godotFile = Join-Path $configDir "godot_path.txt"

function Falha($texto) {
    Write-Host ""
    Write-Host "  *** $texto ***" -ForegroundColor Red
    exit 1
}

# Programas de fora (git, gh, Godot) escrevem avisos no canal de erro mesmo quando dá certo; no
# PowerShell do Windows, com "Stop", isso derruba o script. Então: roda com "Continue" e decide
# só pelo código de saída.
function Rodar([string]$exe, [string[]]$argumentos, [string]$log = "") {
    $antes = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($log) { & $exe @argumentos *> $log } else { & $exe @argumentos 2>&1 | ForEach-Object { "$_" } | Write-Host }
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $antes
    }
}

# Só o código de saída, sem mostrar nada (para perguntas: "existe?", "está logado?").
function Testar([string]$exe, [string[]]$argumentos) {
    $antes = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $exe @argumentos *> $null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $antes
    }
}

# Godot no Windows é programa de janela: chamado direto, não espera terminar. Start-Process
# -Wait espera, e as mensagens vão para o log.
function RodarGodot([string[]]$argumentos, [string]$log) {
    $p = Start-Process -FilePath $godot -ArgumentList $argumentos -Wait -PassThru -NoNewWindow -WorkingDirectory (Get-Location).Path `
        -RedirectStandardOutput $log -RedirectStandardError "$log.erros.txt"
    return $p.ExitCode
}

# (Nome diferente de "git": no PowerShell maiúscula e minúscula são iguais e a função chamaria a si mesma.)
function RodarGit {
    if ((Rodar "git.exe" $args) -ne 0) { Falha "O comando 'git $($args -join ' ')' não deu certo (veja a mensagem acima)." }
}

function RodarGh {
    if ((Rodar "gh.exe" $args) -ne 0) { Falha "O comando 'gh $($args -join ' ')' não deu certo (veja a mensagem acima)." }
}

Write-Host ""
Write-Host "  ==  Gerar e publicar versão nova do Corrumpted  ==" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "project.godot")) { Falha "Rode este arquivo de dentro da pasta tools do projeto." }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { Falha "Git não encontrado. Instale em https://git-scm.com e rode de novo." }
if (-not (Get-Command gh.exe -ErrorAction SilentlyContinue)) {
    Falha "GitHub CLI (gh) não encontrado. Instale em https://cli.github.com, rode 'gh auth login' uma vez e rode este arquivo de novo."
}
if ((Testar "gh.exe" @("auth", "status")) -ne 0) { Falha "O GitHub CLI não está logado. Abra um terminal, rode 'gh auth login' e depois rode este arquivo de novo." }

# Godot: o caminho fica guardado depois da primeira vez.
$godot = ""
if (Test-Path $godotFile) { $godot = (Get-Content $godotFile -Raw).Trim() }
if (-not $godot -or -not (Test-Path $godot)) {
    $achado = Get-Command "Godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($achado) { $godot = $achado.Source }
}
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Host "  Onde está o Godot 4.7 (o .exe que você abre o projeto)?"
    Write-Host "  Dica: arraste o arquivo para esta janela e aperte Enter."
    $godot = (Read-Host "  Caminho do Godot").Trim().Trim('"')
    if (-not (Test-Path $godot)) { Falha "Não achei o Godot em: $godot" }
}
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Set-Content -Path $godotFile -Value $godot -Encoding UTF8
# A versão "console" do Godot (mesma pasta) mostra os erros e espera certinho; usa se tiver.
$console = Get-ChildItem -Path (Split-Path $godot) -Filter "*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($console) { $godot = $console.FullName }
Write-Host "  Godot: $godot"

Write-Host "  Pegando o que tem de novo no GitHub..."
RodarGit pull --ff-only --quiet

$projeto = Get-Content "project.godot" -Raw -Encoding UTF8
$atual = "0.0.0"
if ($projeto -match 'config/version="([^"]+)"') { $atual = $Matches[1] }
$partes = $atual.Split(".")
while ($partes.Count -lt 3) { $partes += "0" }
$sugestao = "{0}.{1}.{2}" -f $partes[0], $partes[1], ([int]$partes[2] + 1)

$antes = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$mudancas = (& git.exe status --short 2>$null)
$ErrorActionPreference = $antes
if ($mudancas) {
    Write-Host ""
    Write-Host "  Estas mudanças ainda não foram enviadas e vão junto nesta versão:" -ForegroundColor Yellow
    $mudancas | ForEach-Object { Write-Host "    $_" }
}

Write-Host ""
Write-Host "  Versão atual: $atual"
$nova = Read-Host "  Número da versão nova (Enter = $sugestao)"
if ([string]::IsNullOrWhiteSpace($nova)) { $nova = $sugestao }
$nova = $nova.Trim().TrimStart("v")
if ($nova -notmatch '^\d+\.\d+\.\d+$') { Falha "Use o formato 1.2.3 (só números e pontos)." }
if ((Testar "gh.exe" @("release", "view", "v$nova", "--repo", $releaseRepo)) -eq 0) { Falha "A versão $nova já foi publicada. Escolha outro número." }

$novidades = Read-Host "  O que mudou nesta versão? (uma linha, opcional)"
if ([string]::IsNullOrWhiteSpace($novidades)) { $novidades = "Versão $nova" }

Write-Host ""
Write-Host "  Vai gerar e publicar a versão $nova : $novidades" -ForegroundColor Cyan
$ok = Read-Host "  Confirma? (S/n)"
if ($ok -match '^[nN]') { Write-Host "  Cancelado. Nada foi enviado."; exit 0 }

# Número da versão no projeto (o jogo mostra e compara com o do GitHub).
if ($projeto -match 'config/version="[^"]*"') {
    $projeto = $projeto -replace 'config/version="[^"]*"', "config/version=`"$nova`""
} else {
    $projeto = $projeto -replace '(config/name="[^"]*")', "`$1`nconfig/version=`"$nova`""
}
[System.IO.File]::WriteAllText((Resolve-Path "project.godot").Path, $projeto, (New-Object System.Text.UTF8Encoding($false)))

# Exportar (Windows, Linux e Web).
Write-Host ""
Write-Host "  Exportando com o Godot (pode levar uns minutos)..."
$build = Join-Path (Get-Location) "build"
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Force -Path "$build\windows", "$build\linux", "$build\web" | Out-Null
RodarGodot @("--headless", "--path", '"."', "--import") "$build\importar.log" | Out-Null
$alvos = @(
    @{ preset = "Windows"; saida = "$build\windows\Corrumpted.exe"; zip = "Windows" },
    @{ preset = "Linux"; saida = "$build\linux\Corrumpted.x86_64"; zip = "Linux" },
    @{ preset = "Web"; saida = "$build\web\index.html"; zip = "Web" }
)
$zips = @()
foreach ($alvo in $alvos) {
    Write-Host "    $($alvo.preset)..."
    RodarGodot @("--headless", "--path", '"."', "--export-release", $alvo.preset, "`"$($alvo.saida)`"") "$build\exportar_$($alvo.zip).log" | Out-Null
    if (-not (Test-Path $alvo.saida)) {
        Falha "Não deu para exportar $($alvo.preset). Veja build\exportar_$($alvo.zip).log. (Faltam os modelos de exportação? No Godot: Editor > Gerenciar modelos de exportação > Baixar e instalar.)"
    }
    $zip = "$build\Corrumpted-v$nova-$($alvo.zip).zip"
    Compress-Archive -Path "$(Split-Path $alvo.saida)\*" -DestinationPath $zip -Force
    $zips += $zip
}

# Código do projeto: grava a versão e manda (com a tag, para saber de onde saiu cada versão).
Write-Host ""
Write-Host "  Gravando a versão no projeto e enviando o código..."
RodarGit add -A
RodarGit commit --quiet -m "Versão ${nova}: $novidades"
RodarGit tag -a "v$nova" -m $novidades
RodarGit push --quiet origin HEAD
RodarGit push --quiet origin "v$nova"

# Repositório público de downloads: cria na primeira vez (com o README de como jogar).
if ((Testar "gh.exe" @("repo", "view", $releaseRepo)) -ne 0) {
    Write-Host "  Criando o repositório público $releaseRepo ..."
    RodarGh repo create $releaseRepo --public --description "Corrumpted: baixe aqui a versão mais nova do jogo" --add-readme
    Start-Sleep -Seconds 3
}
$readme = Join-Path (Get-Location) "tools\release_readme.md"
if (Test-Path $readme) {
    $conteudo = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($readme))
    $antes = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $sha = (& gh.exe api "repos/$releaseRepo/contents/README.md" --jq ".sha" 2>$null)
    $ErrorActionPreference = $antes
    $campos = @("-X", "PUT", "repos/$releaseRepo/contents/README.md", "-f", "message=Como jogar (versão $nova)", "-f", "content=$conteudo")
    if ($sha) { $campos += @("-f", "sha=$sha") }
    Testar "gh.exe" $campos | Out-Null
}

Write-Host "  Publicando a versão $nova em $releaseRepo ..."
$notas = "$novidades`n`n**Como jogar**`n- **Windows:** baixe ``Corrumpted-v$nova-Windows.zip``, extraia e abra ``Corrumpted.exe`` (se o Windows avisar ""aplicativo desconhecido"": Mais informações > Executar assim mesmo).`n- **Linux:** baixe o ``-Linux.zip``, extraia e rode ``./Corrumpted.x86_64``.`n- **Web:** o ``-Web.zip`` é para hospedar (itch.io, por exemplo).`n`nJá tem o jogo? Abra: ele avisa que tem versão nova e atualiza sozinho."
RodarGh release create "v$nova" @zips --repo $releaseRepo --title "Corrumpted v$nova" --notes $notas --latest

Write-Host ""
Write-Host "  Pronto! A versão $nova está publicada:" -ForegroundColor Green
Write-Host "    https://github.com/$releaseRepo/releases/latest"
Write-Host "  Os jogos instalados avisam sozinhos que tem versão nova."
Start-Process "https://github.com/$releaseRepo/releases/latest"
