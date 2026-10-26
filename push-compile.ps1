# ========================================
# 🔥 URIEL XITER - Auto Push & Compile
# ========================================
# Clique 2x para enviar código e compilar no GitHub
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  🔥 URIEL XITER - Auto Compile" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Caminho do projeto
$projectPath = "/home/kaikedev/main"

# Navegar para o diretório do script
Set-Location -Path "\\wsl.localhost\Ubuntu\home\kaikedev\main"

# Verificar mudanças
Write-Host "📂 Verificando mudanças..." -ForegroundColor White
$status = wsl bash -c "cd $projectPath && git status --porcelain"

if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "✓ Nenhuma mudança detectada!" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Quer forçar recompilação? (S/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -eq "S" -or $response -eq "s") {
        Write-Host ""
        Write-Host "🔄 Forçando recompilação..." -ForegroundColor White
        wsl bash -c "cd $projectPath && git commit --allow-empty -m 'trigger: recompilar' && git push"
    } else {
        Write-Host ""
        Write-Host "❌ Cancelado!" -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit
    }
} else {
    Write-Host "✓ Mudanças detectadas!" -ForegroundColor Green
    Write-Host ""
    
    # Mostrar arquivos modificados
    Write-Host "📝 Arquivos modificados:" -ForegroundColor Cyan
    wsl bash -c "cd $projectPath && git status --short"
    Write-Host ""
    
    # Pedir mensagem de commit
    Write-Host "💬 Mensagem do commit (ou Enter para 'update'): " -NoNewline -ForegroundColor Yellow
    $commitMsg = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($commitMsg)) {
        $commitMsg = "update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }
    
    Write-Host ""
    Write-Host "📤 Enviando para GitHub..." -ForegroundColor White
    
    # Git add, commit, pull, push
    $gitCommand = "cd $projectPath && git add . && git commit -m '$commitMsg' && git pull --rebase && git push"
    $result = wsl bash -c $gitCommand 2>&1
    
    if ($LASTEXITCODE -eq 0 -or $result -match "up-to-date" -or $result -match "Everything up-to-date") {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  ✅ ENVIADO COM SUCESSO!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔗 Acompanhe a compilação em:" -ForegroundColor Cyan
        Write-Host "   https://github.com/kakaka1234567890000ka-lab/main/actions" -ForegroundColor White
        Write-Host ""
        Write-Host "📦 Quando terminar (✅), baixe o IPA nos Artifacts!" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  ❌ ERRO AO ENVIAR!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host $result -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
