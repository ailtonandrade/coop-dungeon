@echo off
rem Dois cliques: gera e publica uma versao nova do Corrumpted.
rem Sobe o numero da versao, exporta Windows, Linux e Web com o seu Godot (sem o modo
rem construtor, o editor de missoes e os editores), manda o codigo e publica os .zip no
rem repositorio PUBLICO de downloads (ailtonandrade/corrumpted). Os jogos instalados avisam
rem que tem versao nova e atualizam sozinhos.
rem Precisa: Git, GitHub CLI (gh, logado com "gh auth login"), Godot 4.7 com os modelos de
rem exportacao instalados (Editor > Gerenciar modelos de exportacao).
chcp 65001 >nul
cd /d "%~dp0.."
title Publicar versao do Corrumpted
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lancar_release.ps1"
echo.
pause
