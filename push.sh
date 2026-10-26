#!/bin/bash
# ========================================
# 🔥 URIEL XITER - Auto Push & Compile
# ========================================

clear
echo ""
echo "========================================"
echo "  🔥 URIEL XITER - Auto Compile"
echo "========================================"
echo ""

cd /home/kaikedev/main || exit

# Verificar mudanças
echo "📂 Verificando mudanças..."
git status --short
echo ""

# Pedir mensagem
read -p "💬 Mensagem do commit (ou Enter para 'update'): " msg
if [ -z "$msg" ]; then
    msg="update: $(date '+%Y-%m-%d %H:%M')"
fi

echo ""
echo "📤 Enviando para GitHub..."
echo ""

# Git add, commit, pull, push
git add .
git commit -m "$msg"
git pull --rebase
git push

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "  ✅ ENVIADO COM SUCESSO!"
    echo "========================================"
    echo ""
    echo "🔗 Acompanhe a compilação em:"
    echo "   https://github.com/kakaka1234567890000ka-lab/main/actions"
    echo ""
    echo "📦 Quando terminar (✅), baixe o IPA nos Artifacts!"
else
    echo ""
    echo "========================================"
    echo "  ❌ ERRO AO ENVIAR!"
    echo "========================================"
fi

echo ""
read -p "Pressione Enter para sair..."
