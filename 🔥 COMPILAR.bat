@echo off
chcp 65001 >nul
title 🔥 URIEL XITER - Auto Compile

powershell.exe -ExecutionPolicy Bypass -File "%~dp0push-compile.ps1"
