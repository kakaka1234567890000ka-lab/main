@echo off
chcp 65001 >nul
title 🔥 URIEL XITER - Auto Compile
color 0B

echo.
echo ========================================
echo   🔥 URIEL XITER - Auto Compile
echo ========================================
echo.

echo 📂 Verificando mudanças...
wsl bash -c "cd /home/kaikedev/main && git status --short"
echo.

set /p "msg=💬 Mensagem do commit (ou Enter para 'update'): "
if "%msg%"=="" set "msg=update"

echo.
echo 📤 Enviando para GitHub...
echo.

wsl bash -c "cd /home/kaikedev/main && git add . && git commit -m '%msg%' && git pull --rebase && git push"

if %errorlevel%==0 (
    echo.
    echo ========================================
    echo   ✅ ENVIADO COM SUCESSO!
    echo ========================================
    echo.
    echo 🔗 Acompanhe a compilação em:
    echo    https://github.com/kakaka1234567890000ka-lab/main/actions
    echo.
    echo 📦 Quando terminar, baixe o IPA nos Artifacts!
) else (
    echo.
    echo ========================================
    echo   ❌ ERRO AO ENVIAR!
    echo ========================================
)

echo.
pause
