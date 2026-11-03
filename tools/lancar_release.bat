@echo off
rem Dois cliques: lanca uma versao nova do Corrumpted no GitHub.
rem Sobe o numero da versao, grava no projeto, faz o commit, cria a tag e manda tudo.
rem O GitHub exporta Windows, Linux e Web e publica em Releases; os jogos dos jogadores
rem avisam que tem versao nova e atualizam sozinhos.
rem Precisa: Git instalado e este projeto ligado ao GitHub (o mesmo que voce usa para dar push).
chcp 65001 >nul
cd /d "%~dp0.."
title Lancar versao do Corrumpted
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lancar_release.ps1"
echo.
pause
