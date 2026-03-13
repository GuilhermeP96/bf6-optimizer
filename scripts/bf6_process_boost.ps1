# ============================================================================
# BF6 - Otimizacao de Processo, GPU e Memoria (Execute como Administrador)
# Foco: reduzir packet loss, liberar CPU/RAM, prioridade maxima para BF6
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

$cpuCount = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
Write-Host "BF6 encontrado (PID: $($bf6.Id), RAM: $([math]::Round($bf6.WorkingSet64/1GB,1)) GB, CPUs: $cpuCount)" -ForegroundColor Green

# --- 1. Prioridade Alta para BF6 ---
Write-Host "`n[1/8] Setando prioridade Alta para BF6..." -ForegroundColor Yellow
$bf6.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
Write-Host "  OK: PriorityClass = High" -ForegroundColor Green

# --- 2. Afinidade de CPU: tirar core 0 do BF6 (core 0 = interrupcoes de rede/SO) ---
Write-Host "`n[2/8] Configurando afinidade de CPU..." -ForegroundColor Yellow
if ($cpuCount -ge 4) {
    # Bitmask: todos os cores EXCETO core 0
    # Ex: 8 cores = 0xFF, sem core 0 = 0xFE
    $allCores = [math]::Pow(2, $cpuCount) - 1
    $withoutCore0 = [int]$allCores -band (-bnot 1)
    $bf6.ProcessorAffinity = [IntPtr]$withoutCore0
    Write-Host "  OK: BF6 usando cores 1-$($cpuCount-1) (core 0 livre para interrupcoes de rede)" -ForegroundColor Green
} else {
    Write-Host "  SKIP: Poucos cores ($cpuCount), mantendo todos" -ForegroundColor DarkGray
}

# --- 3. Baixar prioridade de processos concorrentes ---
Write-Host "`n[3/8] Baixando prioridade de apps em background..." -ForegroundColor Yellow
$lowPriority = @(
    "EpicGamesLauncher", "EACefSubProcess", "EADesktop", "EABackgroundService", "EAEgsProxy",
    "msedge", "chrome", "firefox", "Code",
    "steam", "steamwebhelper", "steamservice",
    "Discord", "DiscordPTB", "DiscordCanary",
    "Spotify", "SpotifyWebHelper",
    "OneDrive", "Teams", "Slack",
    "SearchApp", "SearchHost", "StartMenuExperienceHost",
    "PhoneExperienceHost", "YourPhone", "GameBar", "GameBarPresenceWriter",
    "NVIDIA Share", "nvcontainer", "NVDisplay.Container",
    "RtkAudUService64", "RtkAudUService"
)
$lowered = 0
foreach ($name in $lowPriority) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        try {
            $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
            $lowered++
            Write-Host "  OK: $name (PID $($p.Id)) = BelowNormal" -ForegroundColor Green
        } catch {
            # Silencioso para processos protegidos
        }
    }
}
Write-Host "  Total: $lowered processos rebaixados" -ForegroundColor Green

# --- 4. Parar servicos pesados que competem por CPU/disco/rede ---
Write-Host "`n[4/8] Parando servicos desnecessarios durante jogo..." -ForegroundColor Yellow
$servicesToStop = @(
    @{Name="SysMain"; Desc="Superfetch (prefetch de disco)"},
    @{Name="WSearch"; Desc="Windows Search (indexacao)"},
    @{Name="DiagTrack"; Desc="Telemetria Microsoft"},
    @{Name="dmwappushservice"; Desc="Push de telemetria"},
    @{Name="WbioSrvc"; Desc="Biometria Windows Hello"},
    @{Name="TabletInputService"; Desc="Servico de teclado touch"},
    @{Name="wisvc"; Desc="Windows Insider Service"},
    @{Name="MapsBroker"; Desc="Mapas offline"},
    @{Name="lfsvc"; Desc="Geolocalizacao"},
    @{Name="XblAuthManager"; Desc="Xbox Live Auth"},
    @{Name="XblGameSave"; Desc="Xbox Game Save"},
    @{Name="XboxNetApiSvc"; Desc="Xbox Networking"}
)
foreach ($svc in $servicesToStop) {
    $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq 'Running') {
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        Write-Host "  OK: $($svc.Name) parado ($($svc.Desc))" -ForegroundColor Green
    }
}

# --- 5. Desabilitar Game DVR e Game Bar (causa stuttering e packet loss indireto) ---
Write-Host "`n[5/8] Desabilitando Game DVR / Game Bar..." -ForegroundColor Yellow
$gameDVRPaths = @(
    "HKCU:\System\GameConfigStore",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
)
# GameDVR_Enabled = 0
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
# Desabilitar Game Bar
$gameBarPath = "HKCU:\SOFTWARE\Microsoft\GameBar"
if (-not (Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force | Out-Null }
Set-ItemProperty -Path $gameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $gameBarPath -Name "AutoGameModeEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "  OK: Game DVR e Game Bar desabilitados" -ForegroundColor Green

# --- 6. Desabilitar Fullscreen Optimizations para BF6 ---
Write-Host "`n[6/8] Desabilitando Fullscreen Optimizations..." -ForegroundColor Yellow
$bf6Path = $bf6.Path
if ($bf6Path) {
    $layersPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $layersPath)) { New-Item -Path $layersPath -Force | Out-Null }
    Set-ItemProperty -Path $layersPath -Name $bf6Path -Value "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type String -Force
    Write-Host "  OK: Fullscreen Optimizations off para $bf6Path" -ForegroundColor Green
}

# --- 7. Limpar RAM standby (libera memoria em standby para o jogo) ---
Write-Host "`n[7/8] Limpando memoria standby..." -ForegroundColor Yellow
# Limpar working sets de processos idle
$totalFreed = 0
Get-Process | Where-Object { $_.Id -ne $bf6.Id -and $_.Id -ne 0 -and $_.Id -ne 4 } | ForEach-Object {
    try {
        $before = $_.WorkingSet64
        [System.Diagnostics.Process]::GetProcessById($_.Id).MinWorkingSet = [IntPtr]::new(204800)
        $after = (Get-Process -Id $_.Id -ErrorAction SilentlyContinue).WorkingSet64
        if ($after -and $before -gt $after) { $totalFreed += ($before - $after) }
    } catch {}
}
Write-Host ("  OK: ~{0:N0} MB liberados de working sets" -f ($totalFreed / 1MB)) -ForegroundColor Green

# Forcar garbage collection .NET
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# --- 8. Info de rede do BF6 + diagnostico ---
Write-Host "`n[8/8] Diagnostico de conexao BF6:" -ForegroundColor Yellow
$tcpConns = Get-NetTCPConnection -OwningProcess $bf6.Id -ErrorAction SilentlyContinue
$udpConns = Get-NetUDPEndpoint -OwningProcess $bf6.Id -ErrorAction SilentlyContinue
if ($tcpConns) {
    $tcpConns | Select-Object LocalPort, RemoteAddress, RemotePort, State | Format-Table -AutoSize
}
if ($udpConns) {
    Write-Host "  Portas UDP:" -ForegroundColor Cyan
    $udpConns | Select-Object LocalPort, LocalAddress | Format-Table -AutoSize
}

# Verificar perda de pacotes com ping rapido ao gateway
$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
if ($gateway) {
    Write-Host "  Testando packet loss para gateway ($gateway)..." -ForegroundColor Cyan
    $pingResult = Test-Connection -ComputerName $gateway -Count 10 -ErrorAction SilentlyContinue
    if ($pingResult) {
        $lost = 10 - $pingResult.Count
        $avgMs = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
        $color = if ($lost -gt 0) { "Red" } else { "Green" }
        Write-Host ("  Gateway: {0:N0}ms avg, {1}/10 pacotes perdidos" -f $avgMs, $lost) -ForegroundColor $color
        if ($lost -gt 0) {
            Write-Host "  ALERTA: Packet loss detectado na sua rede local!" -ForegroundColor Red
            Write-Host "  Verifique: cabo Ethernet, Wi-Fi, roteador, firmware" -ForegroundColor Red
        }
    }
}

# --- Processos que sugerimos fechar ---
Write-Host "`nProcessos que voce pode considerar FECHAR para liberar recursos:" -ForegroundColor Yellow
$suggest = @(
    @{Name="EpicGamesLauncher"; Reason="Epic Games Launcher (desnecessario durante jogo)"},
    @{Name="msedge"; Reason="Microsoft Edge (consome RAM)"},
    @{Name="chrome"; Reason="Google Chrome (consome muita RAM)"},
    @{Name="Code"; Reason="VS Code (consome RAM e CPU)"},
    @{Name="Discord"; Reason="Discord (usa rede e CPU)"},
    @{Name="Spotify"; Reason="Spotify (streaming consome banda)"},
    @{Name="steam"; Reason="Steam (downloads em background)"},
    @{Name="OneDrive"; Reason="OneDrive (sync consome rede)"}
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
