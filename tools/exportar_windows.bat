@echo off
rem Exporta o Corrumpted para Windows e, se o Inno Setup estiver instalado, gera o instalador.
rem Uso: dê dois cliques, ou rode no cmd dentro da pasta do projeto: tools\exportar_windows.bat
rem Precisa: Godot 4.7 com os modelos de exportação instalados (Editor > Gerenciar modelos de exportação).
rem Se o godot.exe não estiver no PATH, ajuste a linha GODOT abaixo para o caminho dele.

setlocal
set GODOT=godot
cd /d "%~dp0.."
if not exist "..\export\windows" mkdir "..\export\windows"

echo Exportando o jogo...
"%GODOT%" --headless --export-release "Windows" "..\export\windows\Corrumpted.exe"
if errorlevel 1 (
	echo Falhou. Confira o caminho do Godot e os modelos de exportação.
	pause
	exit /b 1
)
echo Jogo exportado em ..\export\windows

set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist %ISCC% (
	echo Gerando o instalador...
	%ISCC% "installer\corrumpted.iss"
	echo Instalador em ..\export\instalador\Corrumpted-Setup.exe
) else (
	echo Inno Setup não encontrado: o jogo exportado já roda direto pelo Corrumpted.exe.
	echo Para gerar o instalador, instale o Inno Setup 6 e rode este arquivo de novo.
)
pause
