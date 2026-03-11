# ============================================================================
# BF6 - Otimizacoes Adicionais (Execute como Administrador)
# Prioridade de processo e afinidade de CPU
# ============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " BF6 Otimizacao de Processo em Tempo Real" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Verificar se BF6 esta rodando ---
$bf6 = Get-Process -Name "bf6" -ErrorAction SilentlyContinue
if (-not $bf6) {
    Write-Host "BF6 nao esta rodando. Inicie o jogo primeiro." -ForegroundColor Red
    pause
    exit
}

Write-Host "BF6 encontrado (PID: $($bf6.Id), RAM: $([math]::Round($bf6.WorkingSet64/1GB,1)) GB)" -ForegroundColor Green

# --- 1. Prioridade Alta para BF6 ---
Write-Host "`n[1/4] Setando prioridade Alta para BF6..." -ForegroundColor Yellow
$bf6.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
Write-Host "  OK: PriorityClass = High" -ForegroundColor Green

# --- 2. Baixar prioridade de processos concorrentes (exceto sistema) ---
Write-Host "`n[2/4] Baixando prioridade de apps em background..." -ForegroundColor Yellow
$lowPriority = @("EpicGamesLauncher", "EACefSubProcess", "EADesktop", "EABackgroundService", "EAEgsProxy", "msedge", "Code")
foreach ($name in $lowPriority) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        try {
            $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
            Write-Host "  OK: $name (PID $($p.Id)) = BelowNormal" -ForegroundColor Green
        } catch {
            Write-Host "  SKIP: $name (PID $($p.Id)) - sem permissao" -ForegroundColor DarkGray
        }
    }
}

# --- 3. Info de rede do BF6 ---
Write-Host "`n[3/4] Conexoes de rede do BF6:" -ForegroundColor Yellow
Get-NetTCPConnection -OwningProcess $bf6.Id -ErrorAction SilentlyContinue | Select-Object LocalPort, RemoteAddress, RemotePort, State | Format-Table -AutoSize
Get-NetUDPEndpoint -OwningProcess $bf6.Id -ErrorAction SilentlyContinue | Select-Object LocalPort, LocalAddress | Format-Table -AutoSize

# --- 4. Sugestao de encerramento ---
Write-Host "[4/4] Processos que voce pode considerar FECHAR para liberar recursos:" -ForegroundColor Yellow
$suggest = @(
    @{Name="EpicGamesLauncher"; Reason="Epic Games Launcher (desnecessario durante jogo)"},

    @{Name="msedge"; Reason="Microsoft Edge (consome RAM)"},
    @{Name="Code"; Reason="VS Code (consome RAM e CPU)"}
)
foreach ($s in $suggest) {
    $p = Get-Process -Name $s.Name -ErrorAction SilentlyContinue
    if ($p) {
        $totalRAM = ($p | Measure-Object WorkingSet64 -Sum).Sum / 1MB
        Write-Host ("  - {0}: {1:N0} MB RAM - {2}" -f $s.Name, $totalRAM, $s.Reason) -ForegroundColor DarkYellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Otimizacoes de processo aplicadas!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
pause
