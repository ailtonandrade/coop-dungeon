# Lança uma versão nova do Corrumpted (chamado por lancar_release.bat).
$ErrorActionPreference = "Stop"
$repo = "ailtonandrade/coop-dungeon"

function Falha($texto) {
    Write-Host ""
    Write-Host "  *** $texto ***" -ForegroundColor Red
    exit 1
}

# (Nome diferente de "git": no PowerShell maiúscula e minúscula são iguais e a função chamaria a si mesma.)
function RodarGit {
    & git.exe @args
    if ($LASTEXITCODE -ne 0) { Falha "O comando 'git $($args -join ' ')' não deu certo (veja a mensagem acima)." }
}

Write-Host ""
Write-Host "  ==  Lançar versão nova do Corrumpted  ==" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { Falha "Git não encontrado. Instale em https://git-scm.com e rode de novo." }
if (-not (Test-Path "project.godot")) { Falha "Rode este arquivo de dentro da pasta tools do projeto." }

Write-Host "  Pegando o que tem de novo no GitHub..."
RodarGit pull --ff-only --quiet

$projeto = Get-Content "project.godot" -Raw -Encoding UTF8
$atual = "0.0.0"
if ($projeto -match 'config/version="([^"]+)"') { $atual = $Matches[1] }
$partes = $atual.Split(".")
while ($partes.Count -lt 3) { $partes += "0" }
$sugestao = "{0}.{1}.{2}" -f $partes[0], $partes[1], ([int]$partes[2] + 1)

$mudancas = (& git.exe status --short)
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
if ((& git.exe tag --list "v$nova")) { Falha "A versão $nova já existe. Escolha outro número." }

$novidades = Read-Host "  O que mudou nesta versão? (uma linha, opcional)"
if ([string]::IsNullOrWhiteSpace($novidades)) { $novidades = "Versão $nova" }

Write-Host ""
Write-Host "  Vai lançar a versão $nova : $novidades" -ForegroundColor Cyan
$ok = Read-Host "  Confirma? (S/n)"
if ($ok -match '^[nN]') { Write-Host "  Cancelado. Nada foi enviado."; exit 0 }

if ($projeto -match 'config/version="[^"]*"') {
    $projeto = $projeto -replace 'config/version="[^"]*"', "config/version=`"$nova`""
} else {
    $projeto = $projeto -replace '(config/name="[^"]*")', "`$1`nconfig/version=`"$nova`""
}
[System.IO.File]::WriteAllText((Resolve-Path "project.godot").Path, $projeto, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "  Gravando e enviando..."
RodarGit add -A
RodarGit commit --quiet -m "Versão ${nova}: $novidades"
RodarGit tag -a "v$nova" -m $novidades
RodarGit push --quiet origin HEAD
RodarGit push --quiet origin "v$nova"

Write-Host ""
Write-Host "  Pronto! A versão $nova foi enviada." -ForegroundColor Green
Write-Host "  O GitHub está montando os arquivos (uns 5 minutos):"
Write-Host "    https://github.com/$repo/actions"
Write-Host "  Depois ela aparece aqui, e os jogos dos jogadores avisam sozinhos:"
Write-Host "    https://github.com/$repo/releases"
Start-Process "https://github.com/$repo/actions"
