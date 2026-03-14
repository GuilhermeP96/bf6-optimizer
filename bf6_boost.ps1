# ============================================================================
# BF6 FULL BOOST - Rede + Processo + GPU (Script Unificado)
# FASE 1: Otimizacoes de rede e sistema (one-shot, so altera se necessario)
# FASE 2: Otimizacao de processo em loop a cada 3 min enquanto BF6 roda
# Execute como Administrador: Right-click > Run as Administrator
# ============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " BF6 FULL BOOST - Rede + Processo + GPU" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Verificar admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: Execute este script como Administrador!" -ForegroundColor Red
    pause
    exit
}

# ============================================================================
# HELPERS
# ============================================================================

$script:rebootNeeded = $false

# Seta registro somente se valor atual for diferente
function Set-RegIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord",
        [switch]$RebootRequired
    )
    $current = $null
    try { $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name } catch {}
    if ($current -eq $Value) { return $false }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    if ($RebootRequired) { $script:rebootNeeded = $true }
    return $true
}

# Seta propriedade avancada do adaptador somente se diferente
function Set-AdapterPropIfDifferent {
    param(
        [string]$AdapterName,
        $Prop,
        [string]$DesiredDisplayValue = $null,
        [string]$DesiredRegistryValue = $null,
        [switch]$RebootRequired
    )
    if ($DesiredRegistryValue) {
        if ($Prop.RegistryValue -eq $DesiredRegistryValue) { return $false }
        Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $Prop.DisplayName -RegistryValue $DesiredRegistryValue -ErrorAction SilentlyContinue
    } elseif ($DesiredDisplayValue) {
        if ($Prop.DisplayValue -eq $DesiredDisplayValue) { return $false }
        Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $Prop.DisplayName -DisplayValue $DesiredDisplayValue -ErrorAction SilentlyContinue
    }
    if ($RebootRequired) { $script:rebootNeeded = $true }
    return $true
}

# ============================================================================
# FASE 1 - OTIMIZACOES DE REDE E SISTEMA (one-shot)
# ============================================================================
Write-Host "`n########################################" -ForegroundColor Magenta
Write-Host " FASE 1: Otimizacao de Rede e Sistema" -ForegroundColor Magenta
Write-Host "########################################" -ForegroundColor Magenta

# --- 0. DIAGNOSTICO INICIAL ---
Write-Host "`n[0/10] Diagnostico de rede atual..." -ForegroundColor Yellow
$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if ($adapter) {
    $stats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction SilentlyContinue
    Write-Host "  Adaptador: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Cyan
    Write-Host "  Link Speed: $($adapter.LinkSpeed)" -ForegroundColor Cyan
    Write-Host "  Driver: $($adapter.DriverVersion)" -ForegroundColor Cyan
    if ($stats) {
        Write-Host "  Pacotes recebidos com erro: $($stats.ReceivedUnicastPackets) total / $($stats.InboundDiscardedPackets) descartados" -ForegroundColor Cyan
    }
    
    if ($adapter.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN|802\.11') {
        Write-Host ""
        Write-Host "  *** ATENCAO: Voce esta usando Wi-Fi! ***" -ForegroundColor Red
        Write-Host "  Wi-Fi e a causa #1 de packet loss em jogos." -ForegroundColor Red
        Write-Host "  Use cabo Ethernet se possivel." -ForegroundColor Red
        Write-Host ""
    }
}

# --- 1. DESABILITAR NAGLE ALGORITHM ---
Write-Host "`n[1/10] Verificando Nagle Algorithm..." -ForegroundColor Yellow
$nics = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$nagleChanged = $false
foreach ($nic in $nics) {
    $props = Get-ItemProperty $nic.PSPath -ErrorAction SilentlyContinue
    if ($props.DhcpIPAddress -or $props.IPAddress) {
        $c1 = Set-RegIfDifferent -Path $nic.PSPath -Name "TcpAckFrequency" -Value 1 -RebootRequired
        $c2 = Set-RegIfDifferent -Path $nic.PSPath -Name "TCPNoDelay" -Value 1 -RebootRequired
        if ($c1 -or $c2) {
            Write-Host "  ALTERADO: $($nic.PSChildName)" -ForegroundColor Green
            $nagleChanged = $true
        }
    }
}
if (-not $nagleChanged) { Write-Host "  OK: Nagle ja otimizado" -ForegroundColor DarkGray }

# --- 2. NETWORK THROTTLING INDEX ---
Write-Host "`n[2/10] Verificando Network Throttling..." -ForegroundColor Yellow
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
$c1 = Set-RegIfDifferent -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -RebootRequired
$c2 = Set-RegIfDifferent -Path $mmPath -Name "SystemResponsiveness" -Value 0 -RebootRequired
if ($c1 -or $c2) {
    Write-Host "  ALTERADO: NetworkThrottlingIndex / SystemResponsiveness" -ForegroundColor Green
} else {
    Write-Host "  OK: Network Throttling ja otimizado" -ForegroundColor DarkGray
}

# --- 3. MMCSS GAME PRIORITY ---
Write-Host "`n[3/10] Verificando MMCSS Game Priority..." -ForegroundColor Yellow
$gamePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
$c1 = Set-RegIfDifferent -Path $gamePath -Name "GPU Priority" -Value 8 -RebootRequired
$c2 = Set-RegIfDifferent -Path $gamePath -Name "Priority" -Value 6 -RebootRequired
$c3 = Set-RegIfDifferent -Path $gamePath -Name "Scheduling Category" -Value "High" -Type "String" -RebootRequired
$c4 = Set-RegIfDifferent -Path $gamePath -Name "SFIO Priority" -Value "High" -Type "String" -RebootRequired
if ($c1 -or $c2 -or $c3 -or $c4) {
    Write-Host "  ALTERADO: MMCSS Game Priority" -ForegroundColor Green
} else {
    Write-Host "  OK: MMCSS ja otimizado" -ForegroundColor DarkGray
}

# --- 4. TCP GLOBAL SETTINGS ---
Write-Host "`n[4/10] Otimizando TCP Global Settings..." -ForegroundColor Yellow
netsh int tcp set global autotuninglevel=normal 2>$null
netsh int tcp set global chimney=disabled 2>$null
netsh int tcp set global rss=enabled 2>$null
netsh int tcp set global timestamps=disabled 2>$null
netsh int tcp set global ecncapability=disabled 2>$null
netsh int tcp set global initialRto=2000 2>$null
netsh int tcp set global nonsackrttresiliency=disabled 2>$null
netsh int tcp set supplemental internet congestionprovider=ctcp 2>$null
Write-Host "  OK: TCP verificado/otimizado" -ForegroundColor Green

# --- 5. BUFFERS DE RECEBIMENTO ---
Write-Host "`n[5/10] Verificando buffers de rede (anti packet loss)..." -ForegroundColor Yellow
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
$bufChanged = $false
$regEntries = @(
    @{Name="TcpWindowSize"; Value=65535},
    @{Name="Tcp1323Opts"; Value=3},
    @{Name="DefaultTTL"; Value=64},
    @{Name="MaxUserPort"; Value=65534},
    @{Name="TcpTimedWaitDelay"; Value=30},
    @{Name="TcpMaxDataRetransmissions"; Value=5},
    @{Name="SackOpts"; Value=1}
)
foreach ($entry in $regEntries) {
    if (Set-RegIfDifferent -Path $tcpParams -Name $entry.Name -Value $entry.Value -RebootRequired) {
        Write-Host "  ALTERADO: $($entry.Name) = $($entry.Value)" -ForegroundColor Green
        $bufChanged = $true
    }
}
if (-not $bufChanged) { Write-Host "  OK: Buffers TCP ja otimizados" -ForegroundColor DarkGray }

if ($adapter) {
    $rxBuf = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Receive Buffer|Rx Ring|Receive Descriptors|Rx Descriptors' }
    foreach ($prop in $rxBuf) {
        $maxVal = $prop.ValidRegistryValues | Sort-Object { [int]$_ } -Descending | Select-Object -First 1
        if ($maxVal -and $prop.RegistryValue -ne $maxVal) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -RegistryValue $maxVal -ErrorAction SilentlyContinue
            Write-Host "  ALTERADO: $($prop.DisplayName) = $maxVal (maximo)" -ForegroundColor Green
            $script:rebootNeeded = $true
        }
    }
    
    $txBuf = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Transmit Buffer|Tx Ring|Transmit Descriptors|Tx Descriptors' }
    foreach ($prop in $txBuf) {
        $maxVal = $prop.ValidRegistryValues | Sort-Object { [int]$_ } -Descending | Select-Object -First 1
        if ($maxVal -and $prop.RegistryValue -ne $maxVal) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -RegistryValue $maxVal -ErrorAction SilentlyContinue
            Write-Host "  ALTERADO: $($prop.DisplayName) = $maxVal (maximo)" -ForegroundColor Green
            $script:rebootNeeded = $true
        }
    }
}

# --- 6. POWER SAVING NA PLACA DE REDE ---
Write-Host "`n[6/10] Verificando Power Saving na placa de rede..." -ForegroundColor Yellow
if ($adapter) {
    $eee = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Energy Efficient|Green Ethernet|EEE|Power Sav' }
    foreach ($prop in $eee) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "Disabled" -RebootRequired) {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Disabled" -ForegroundColor Green
        }
    }
    
    $fc = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Flow Control' }
    foreach ($prop in $fc) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "Disabled" -RebootRequired) {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Disabled" -ForegroundColor Green
        }
    }
    
    $im = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Interrupt Moderation' }
    foreach ($prop in $im) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "Disabled" -RebootRequired) {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Disabled" -ForegroundColor Green
        }
    }
    
    $offloads = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Large Send Offload|LSO|TCP Offload|UDP Offload|Checksum Offload' }
    foreach ($prop in $offloads) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "Disabled" -RebootRequired) {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Disabled" -ForegroundColor Green
        }
    }
    
    Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
    Write-Host "  OK: Power Management verificado em $($adapter.Name)" -ForegroundColor DarkGray
}

# --- 7. OTIMIZACOES WI-FI ---
Write-Host "`n[7/10] Otimizacoes Wi-Fi (se aplicavel)..." -ForegroundColor Yellow
if ($adapter -and $adapter.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN|802\.11') {
    $roaming = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Roaming Aggressiv' }
    foreach ($prop in $roaming) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredRegistryValue "1") {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Lowest (estabilidade)" -ForegroundColor Green
        }
    }
    
    $band = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Preferred Band|Band Preference' }
    foreach ($prop in $band) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "Prefer 5GHz band") {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Prefer 5GHz" -ForegroundColor Green
        }
    }
    
    $boost = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Throughput Boost' }
    foreach ($prop in $boost) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "Enabled") {
            Write-Host "  ALTERADO: $($prop.DisplayName) = Enabled" -ForegroundColor Green
        }
    }
    
    $mimo = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'MIMO|Spatial' }
    foreach ($prop in $mimo) {
        if (Set-AdapterPropIfDifferent -AdapterName $adapter.Name -Prop $prop -DesiredDisplayValue "No SMPS") {
            Write-Host "  ALTERADO: $($prop.DisplayName) = No SMPS" -ForegroundColor Green
        }
    }
    
    Write-Host "  LEMBRETE: cabo Ethernet elimina 90% do packet loss" -ForegroundColor Red
} else {
    Write-Host "  SKIP: Usando Ethernet (bom!)" -ForegroundColor Green
}

# --- 8. QoS ---
Write-Host "`n[8/10] Verificando QoS para BF6..." -ForegroundColor Yellow
$qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
if (-not (Test-Path $qosPath)) { New-Item -Path $qosPath -Force | Out-Null }
if (Set-RegIfDifferent -Path $qosPath -Name "NonBestEffortLimit" -Value 0) {
    Write-Host "  ALTERADO: QoS bandwidth reservation = 0% (100% para apps)" -ForegroundColor Green
} else {
    Write-Host "  OK: QoS ja otimizado" -ForegroundColor DarkGray
}
netsh int udp set global uro=disabled 2>$null

# --- 9. PLANO DE ENERGIA ---
Write-Host "`n[9/10] Verificando plano de energia..." -ForegroundColor Yellow
$ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$activePlan = powercfg /getactivescheme
$powerChanged = $false

if ($activePlan -notmatch "Ultimate") {
    powercfg /duplicatescheme $ultimateGuid 2>$null
    $plans = powercfg /list
    $ultimate = $plans | Select-String "Ultimate"
    if ($ultimate) {
        $guid = ($ultimate.Line -split '\s+' | Where-Object { $_ -match '^[0-9a-f]{8}-' }) | Select-Object -First 1
        if ($guid) { 
            powercfg /setactive $guid
            Write-Host "  ALTERADO: Plano 'Ultimate Performance' ativado" -ForegroundColor Green
            $powerChanged = $true
        }
    } else {
        if ($activePlan -notmatch $highPerfGuid) {
            $plans = powercfg /list
            $highPerf = $plans | Select-String $highPerfGuid
            if ($highPerf) {
                powercfg /setactive $highPerfGuid
                Write-Host "  ALTERADO: Plano 'Alto Desempenho' ativado" -ForegroundColor Green
                $powerChanged = $true
            } else {
                Write-Host "  AVISO: Nenhum plano de alto desempenho disponivel" -ForegroundColor Red
            }
        }
    }
}
if (-not $powerChanged) { Write-Host "  OK: Plano de energia ja otimizado" -ForegroundColor DarkGray }

powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 2>$null
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 2>$null
powercfg /setactive scheme_current 2>$null

# --- 10. FLUSH DNS ---
Write-Host "`n[10/10] Limpando cache DNS..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null
if ($script:rebootNeeded) {
    netsh winsock reset catalog 2>$null
    netsh int ip reset 2>$null
    Write-Host "  OK: DNS limpo + Winsock reset (mudancas de rede aplicadas)" -ForegroundColor Green
} else {
    Write-Host "  OK: DNS limpo" -ForegroundColor DarkGray
}

# --- RESUMO FASE 1 ---
Write-Host "`n========================================" -ForegroundColor Cyan
if ($script:rebootNeeded) {
    Write-Host " FASE 1: REDE OTIMIZADA - REBOOT NECESSARIO" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Valores de rede foram alterados. Reinicie o PC para efeito completo." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "IMPORTANTE se packet loss persistir:" -ForegroundColor Red
    Write-Host "  1. Use cabo Ethernet (elimina 90% do PL)" -ForegroundColor White
    Write-Host "  2. Verifique firmware do roteador" -ForegroundColor White
    Write-Host "  3. Teste outro servidor DNS (1.1.1.1 ou 8.8.8.8)" -ForegroundColor White
    Write-Host "  4. Verifique se ha downloads em background" -ForegroundColor White
    Write-Host "  5. Teste em horarios diferentes (congestionamento ISP)" -ForegroundColor White
} else {
    Write-Host " FASE 1: REDE JA OTIMIZADA - SEM REBOOT" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Todos os valores de rede ja estavam configurados." -ForegroundColor Green
}

# ============================================================================
# FASE 2 - OTIMIZACAO DE PROCESSO EM LOOP (a cada 3 minutos)
# ============================================================================
Write-Host "`n########################################" -ForegroundColor Magenta
Write-Host " FASE 2: Otimizacao de Processo (Loop)" -ForegroundColor Magenta
Write-Host "########################################" -ForegroundColor Magenta

$cpuCount = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

while ($true) {
    # Aguardar BF6 iniciar
    $bf6 = Get-Process -Name "bf6" -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 1
    if (-not $bf6) {
        Write-Host "`nAguardando BF6 iniciar... (verificando a cada 30s)" -ForegroundColor Yellow
        Write-Host "(Ctrl+C para parar)" -ForegroundColor DarkGray
        while (-not ($bf6 = Get-Process -Name "bf6" -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 1)) {
            Start-Sleep -Seconds 30
        }
        Write-Host "`nBF6 detectado! Iniciando otimizacao..." -ForegroundColor Green
    }

    $firstRun = $true
    $iteration = 0

    # Loop de otimizacao enquanto BF6 estiver rodando
    while ($true) {
        $iteration++
        $bf6 = Get-Process -Name "bf6" -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 1
        if (-not $bf6) {
            Write-Host "`nBF6 encerrado. Voltando ao modo de espera..." -ForegroundColor Yellow
            break
        }

    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " [$timestamp] Ciclo #$iteration de otimizacao" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "BF6 PID: $($bf6.Id), RAM: $([math]::Round($bf6.WorkingSet64/1GB,1)) GB" -ForegroundColor Green

    # --- 1. Prioridade Alta para BF6 ---
    Write-Host "`n[1/8] Prioridade do BF6..." -ForegroundColor Yellow
    try {
        if ($bf6.PriorityClass -ne [System.Diagnostics.ProcessPriorityClass]::High) {
            $bf6.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
            Write-Host "  ALTERADO: PriorityClass = High" -ForegroundColor Green
        } else {
            Write-Host "  OK: PriorityClass ja High" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  AVISO: Nao foi possivel alterar prioridade" -ForegroundColor DarkYellow
    }

    # --- 2. Afinidade de CPU ---
    Write-Host "`n[2/8] Afinidade de CPU..." -ForegroundColor Yellow
    if ($cpuCount -ge 4) {
        $allCores = [math]::Pow(2, $cpuCount) - 1
        $withoutCore0 = [int]$allCores -band (-bnot 1)
        $desiredAffinity = [IntPtr]$withoutCore0
        try {
            if ($bf6.ProcessorAffinity -ne $desiredAffinity) {
                $bf6.ProcessorAffinity = $desiredAffinity
                Write-Host "  ALTERADO: BF6 usando cores 1-$($cpuCount-1)" -ForegroundColor Green
            } else {
                Write-Host "  OK: Afinidade ja configurada" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  AVISO: Nao foi possivel alterar afinidade" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  SKIP: Poucos cores ($cpuCount), mantendo todos" -ForegroundColor DarkGray
    }

    # --- 3. Baixar prioridade de processos concorrentes ---
    Write-Host "`n[3/8] Prioridade de apps em background..." -ForegroundColor Yellow
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
                if ($p.PriorityClass -ne [System.Diagnostics.ProcessPriorityClass]::BelowNormal) {
                    $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
                    $lowered++
                }
            } catch {}
        }
    }
    if ($lowered -gt 0) {
        Write-Host "  ALTERADO: $lowered processos rebaixados para BelowNormal" -ForegroundColor Green
    } else {
        Write-Host "  OK: Todos ja em BelowNormal ou ausentes" -ForegroundColor DarkGray
    }

    # --- 4. Parar servicos pesados ---
    Write-Host "`n[4/8] Servicos desnecessarios..." -ForegroundColor Yellow
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
    $stopped = 0
    foreach ($svc in $servicesToStop) {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($s -and $s.Status -eq 'Running') {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            Write-Host "  PARADO: $($svc.Name) ($($svc.Desc))" -ForegroundColor Green
            $stopped++
        }
    }
    if ($stopped -eq 0) {
        Write-Host "  OK: Servicos ja parados ou ausentes" -ForegroundColor DarkGray
    }

    # --- 5. Game DVR / Game Bar ---
    Write-Host "`n[5/8] Game DVR / Game Bar..." -ForegroundColor Yellow
    $dvrChanged = $false
    $dvrChanged = (Set-RegIfDifferent -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0) -or $dvrChanged
    $dvrChanged = (Set-RegIfDifferent -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0) -or $dvrChanged
    $gameBarPath = "HKCU:\SOFTWARE\Microsoft\GameBar"
    if (-not (Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force | Out-Null }
    $dvrChanged = (Set-RegIfDifferent -Path $gameBarPath -Name "UseNexusForGameBarEnabled" -Value 0) -or $dvrChanged
    $dvrChanged = (Set-RegIfDifferent -Path $gameBarPath -Name "AutoGameModeEnabled" -Value 0) -or $dvrChanged
    if ($dvrChanged) {
        Write-Host "  ALTERADO: Game DVR / Game Bar desabilitados" -ForegroundColor Green
    } else {
        Write-Host "  OK: Game DVR / Game Bar ja desabilitados" -ForegroundColor DarkGray
    }

    # --- 6. Fullscreen Optimizations (apenas primeira vez) ---
    if ($firstRun) {
        Write-Host "`n[6/8] Fullscreen Optimizations..." -ForegroundColor Yellow
        $bf6Path = $bf6.Path
        if ($bf6Path) {
            $layersPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
            if (-not (Test-Path $layersPath)) { New-Item -Path $layersPath -Force | Out-Null }
            if (Set-RegIfDifferent -Path $layersPath -Name $bf6Path -Value "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" -Type "String") {
                Write-Host "  ALTERADO: Fullscreen Optimizations off para $bf6Path" -ForegroundColor Green
            } else {
                Write-Host "  OK: Fullscreen Optimizations ja desabilitado" -ForegroundColor DarkGray
            }
        }
    }

    # --- 7. Limpar RAM standby ---
    Write-Host "`n[7/8] Limpando memoria standby..." -ForegroundColor Yellow
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
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # --- 8. Diagnostico de conexao BF6 ---
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
            }
        }
    }

    # Sugestoes apenas na primeira rodada
    if ($firstRun) {
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
        $firstRun = $false
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " Ciclo #$iteration concluido. Proximo em 3 minutos..." -ForegroundColor Green
    Write-Host " (Ctrl+C para parar | Volta a aguardar quando BF6 sair)" -ForegroundColor DarkGray
    Write-Host "========================================" -ForegroundColor Cyan

    # Aguardar 3 minutos, verificando a cada 10s se BF6 ainda esta rodando
    $bf6Closed = $false
    for ($i = 0; $i -lt 18; $i++) {
        Start-Sleep -Seconds 10
        if (-not (Get-Process -Name "bf6" -ErrorAction SilentlyContinue)) {
            Write-Host "`nBF6 encerrado. Voltando ao modo de espera..." -ForegroundColor Yellow
            $bf6Closed = $true
            break
        }
    }
    if ($bf6Closed) { break }
    } # fim do loop interno de otimizacao
} # fim do loop externo (aguardar BF6)
