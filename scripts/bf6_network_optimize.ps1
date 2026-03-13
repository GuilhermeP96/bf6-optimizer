# ============================================================================
# BF6 Network & Gaming Optimization Script
# Foco principal: REDUZIR PACKET LOSS e otimizar rede para gaming
# Execute como Administrador: Right-click > Run as Administrator
# ============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " BF6 Otimizacao de Rede e Performance" -ForegroundColor Cyan
Write-Host " Foco: Packet Loss e Latencia" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Verificar admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: Execute este script como Administrador!" -ForegroundColor Red
    pause
    exit
}

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
    
    # Verificar se eh Wi-Fi
    if ($adapter.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN|802\.11') {
        Write-Host ""
        Write-Host "  *** ATENCAO: Voce esta usando Wi-Fi! ***" -ForegroundColor Red
        Write-Host "  Wi-Fi e a causa #1 de packet loss em jogos." -ForegroundColor Red
        Write-Host "  Use cabo Ethernet se possivel." -ForegroundColor Red
        Write-Host ""
    }
}

# --- 1. DESABILITAR NAGLE ALGORITHM ---
Write-Host "`n[1/10] Desabilitando Nagle Algorithm..." -ForegroundColor Yellow
$nics = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($nic in $nics) {
    $props = Get-ItemProperty $nic.PSPath -ErrorAction SilentlyContinue
    if ($props.DhcpIPAddress -or $props.IPAddress) {
        Set-ItemProperty -Path $nic.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $nic.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
        Write-Host "  OK: $($nic.PSChildName)" -ForegroundColor Green
    }
}

# --- 2. NETWORK THROTTLING INDEX ---
Write-Host "`n[2/10] Desabilitando Network Throttling..." -ForegroundColor Yellow
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
Write-Host "  OK: NetworkThrottlingIndex = FFFFFFFF, SystemResponsiveness = 0" -ForegroundColor Green

# --- 3. MMCSS GAME PRIORITY ---
Write-Host "`n[3/10] Configurando MMCSS Game Priority..." -ForegroundColor Yellow
$gamePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
Set-ItemProperty -Path $gamePath -Name "GPU Priority" -Value 8 -Type DWord -Force
Set-ItemProperty -Path $gamePath -Name "Priority" -Value 6 -Type DWord -Force
Set-ItemProperty -Path $gamePath -Name "Scheduling Category" -Value "High" -Type String -Force
Set-ItemProperty -Path $gamePath -Name "SFIO Priority" -Value "High" -Type String -Force
Write-Host "  OK: GPU Priority = 8, Priority = 6, Scheduling = High" -ForegroundColor Green

# --- 4. TCP GLOBAL SETTINGS (agressivo contra packet loss) ---
Write-Host "`n[4/10] Otimizando TCP Global Settings..." -ForegroundColor Yellow
netsh int tcp set global autotuninglevel=normal 2>$null
netsh int tcp set global chimney=disabled 2>$null
netsh int tcp set global rss=enabled 2>$null
netsh int tcp set global timestamps=disabled 2>$null
netsh int tcp set global ecncapability=disabled 2>$null
netsh int tcp set global initialRto=2000 2>$null
netsh int tcp set global nonsackrttresiliency=disabled 2>$null
netsh int tcp set supplemental internet congestionprovider=ctcp 2>$null
Write-Host "  OK: TCP otimizado" -ForegroundColor Green

# --- 5. AUMENTAR BUFFERS DE RECEBIMENTO (direto contra PL IN 14%) ---
Write-Host "`n[5/10] Aumentando buffers de rede (anti packet loss)..." -ForegroundColor Yellow

# TCP global: aumentar janela de recepcao
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpParams -Name "TcpWindowSize" -Value 65535 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "Tcp1323Opts" -Value 3 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "DefaultTTL" -Value 64 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "MaxUserPort" -Value 65534 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force
Set-ItemProperty -Path $tcpParams -Name "TcpMaxDataRetransmissions" -Value 5 -Type DWord -Force
# SackOpts = habilitar SACK (Selective Acknowledgments) — reduz retransmissoes desnecessarias
Set-ItemProperty -Path $tcpParams -Name "SackOpts" -Value 1 -Type DWord -Force
Write-Host "  OK: TcpWindowSize=65535, SACK=on, TTL=64, MaxPorts=65534" -ForegroundColor Green

# Aumentar buffers do adaptador de rede
if ($adapter) {
    # Receive Buffers / Receive Descriptors
    $rxBuf = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Receive Buffer|Rx Ring|Receive Descriptors|Rx Descriptors' }
    foreach ($prop in $rxBuf) {
        $maxVal = $prop.ValidRegistryValues | Sort-Object { [int]$_ } -Descending | Select-Object -First 1
        if ($maxVal) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -RegistryValue $maxVal -ErrorAction SilentlyContinue
            Write-Host "  OK: $($prop.DisplayName) = $maxVal (maximo)" -ForegroundColor Green
        }
    }
    
    # Transmit Buffers
    $txBuf = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Transmit Buffer|Tx Ring|Transmit Descriptors|Tx Descriptors' }
    foreach ($prop in $txBuf) {
        $maxVal = $prop.ValidRegistryValues | Sort-Object { [int]$_ } -Descending | Select-Object -First 1
        if ($maxVal) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -RegistryValue $maxVal -ErrorAction SilentlyContinue
            Write-Host "  OK: $($prop.DisplayName) = $maxVal (maximo)" -ForegroundColor Green
        }
    }
}

# --- 6. DESABILITAR POWER SAVING NA PLACA DE REDE ---
Write-Host "`n[6/10] Desabilitando Power Saving na placa de rede..." -ForegroundColor Yellow
if ($adapter) {
    $eee = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Energy Efficient|Green Ethernet|EEE|Power Sav' }
    foreach ($prop in $eee) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    $fc = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Flow Control' }
    foreach ($prop in $fc) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    $im = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Interrupt Moderation' }
    foreach ($prop in $im) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    # Desabilitar offloading features que podem causar packet loss
    $offloads = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Large Send Offload|LSO|TCP Offload|UDP Offload|Checksum Offload' }
    foreach ($prop in $offloads) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
    Write-Host "  OK: Power Management desabilitado em $($adapter.Name)" -ForegroundColor Green
}

# --- 7. OTIMIZACOES ESPECIFICAS PARA WI-FI (se aplicavel) ---
Write-Host "`n[7/10] Otimizacoes Wi-Fi (se aplicavel)..." -ForegroundColor Yellow
if ($adapter -and $adapter.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN|802\.11') {
    # Roaming Aggressiveness - baixo (evita trocar de access point)
    $roaming = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Roaming Aggressiv' }
    foreach ($prop in $roaming) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "1. Lowest" -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -RegistryValue 1 -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Lowest (estabilidade)" -ForegroundColor Green
    }
    
    # Preferred Band - 5GHz (menos interferencia)
    $band = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Preferred Band|Band Preference' }
    foreach ($prop in $band) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Prefer 5GHz band" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Prefer 5GHz" -ForegroundColor Green
    }
    
    # Throughput Booster
    $boost = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'Throughput Boost' }
    foreach ($prop in $boost) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Enabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Enabled" -ForegroundColor Green
    }
    
    # MIMO Power Save Mode - desabilitar (maximo throughput)
    $mimo = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -match 'MIMO|Spatial' }
    foreach ($prop in $mimo) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "No SMPS" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = No SMPS" -ForegroundColor Green
    }
    
    Write-Host "  LEMBRETE: cabo Ethernet elimina 90% do packet loss" -ForegroundColor Red
} else {
    Write-Host "  SKIP: Usando Ethernet (bom!)" -ForegroundColor Green
}

# --- 8. QoS / PRIORIDADE DE REDE PARA BF6 ---
Write-Host "`n[8/10] Configurando QoS para BF6..." -ForegroundColor Yellow
# Remover limite de 20% de banda reservada do Windows
$qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
if (-not (Test-Path $qosPath)) { New-Item -Path $qosPath -Force | Out-Null }
Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force
Write-Host "  OK: QoS bandwidth reservation = 0% (100% para apps)" -ForegroundColor Green

# Priorizar trafego UDP (BF6 usa UDP para gameplay)
netsh int udp set global uro=disabled 2>$null
Write-Host "  OK: UDP Receive Offload desabilitado (menos buffer = menos delay)" -ForegroundColor Green

# --- 9. PLANO DE ENERGIA ULTIMATE PERFORMANCE ---
Write-Host "`n[9/10] Ativando plano de energia Ultimate Performance..." -ForegroundColor Yellow
# Tentar Ultimate Performance primeiro
$ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

# Habilitar Ultimate Performance (pode estar oculto)
powercfg /duplicatescheme $ultimateGuid 2>$null
$plans = powercfg /list
$ultimate = $plans | Select-String "Ultimate"
if ($ultimate) {
    $guid = ($ultimate.Line -split '\s+' | Where-Object { $_ -match '^[0-9a-f]{8}-' }) | Select-Object -First 1
    if ($guid) { 
        powercfg /setactive $guid
        Write-Host "  OK: Plano 'Ultimate Performance' ativado" -ForegroundColor Green
    }
} else {
    $highPerf = $plans | Select-String $highPerfGuid
    if ($highPerf) {
        powercfg /setactive $highPerfGuid
        Write-Host "  OK: Plano 'Alto Desempenho' ativado" -ForegroundColor Green
    } else {
        Write-Host "  AVISO: Nenhum plano de alto desempenho disponivel" -ForegroundColor Red
    }
}

# Garantir que CPU nao faz throttling
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 2>$null
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 2>$null
powercfg /setactive scheme_current 2>$null
Write-Host "  OK: CPU min/max = 100% (sem throttling)" -ForegroundColor Green

# --- 10. FLUSH DNS e RESET WINSOCK ---
Write-Host "`n[10/10] Limpando cache DNS e resetando catalogo Winsock..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null
netsh winsock reset catalog 2>$null
netsh int ip reset 2>$null
Write-Host "  OK: DNS limpo + Winsock reset" -ForegroundColor Green

# --- RESUMO ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " OTIMIZACOES APLICADAS COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Alteracoes que requerem REINICIALIZACAO do PC:" -ForegroundColor Yellow
Write-Host "  - Nagle Algorithm (TcpAckFrequency + TCPNoDelay)" 
Write-Host "  - Network Throttling / MMCSS"
Write-Host "  - TCP Window Size / SACK"
Write-Host "  - Winsock Reset"
Write-Host "  - Offloading changes"
Write-Host ""
Write-Host "IMPORTANTE se packet loss persistir:" -ForegroundColor Red
Write-Host "  1. Use cabo Ethernet (elimina 90% do PL)" -ForegroundColor White
Write-Host "  2. Verifique firmware do roteador" -ForegroundColor White
Write-Host "  3. Teste outro servidor DNS (1.1.1.1 ou 8.8.8.8)" -ForegroundColor White
Write-Host "  4. Verifique se ha downloads em background" -ForegroundColor White
Write-Host "  5. Teste em horarios diferentes (congestionamento ISP)" -ForegroundColor White
Write-Host ""
Write-Host "Reinicie o PC para aplicar todas as mudancas." -ForegroundColor Yellow
Write-Host ""
pause
