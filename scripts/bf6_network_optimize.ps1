# ============================================================================
# BF6 Network & Gaming Optimization Script
# Execute como Administrador: Right-click > Run as Administrator
# ============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " BF6 Otimizacao de Rede e Performance" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Verificar admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: Execute este script como Administrador!" -ForegroundColor Red
    pause
    exit
}

# --- 1. DESABILITAR NAGLE ALGORITHM ---
Write-Host "`n[1/7] Desabilitando Nagle Algorithm..." -ForegroundColor Yellow
$nics = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($nic in $nics) {
    $props = Get-ItemProperty $nic.PSPath -ErrorAction SilentlyContinue
    if ($props.DhcpIPAddress -or $props.IPAddress) {
        Set-ItemProperty -Path $nic.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $nic.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
        Write-Host "  OK: $($nic.PSChildName) (IP: $($props.DhcpIPAddress)$($props.IPAddress))" -ForegroundColor Green
    }
}

# --- 2. NETWORK THROTTLING INDEX ---
Write-Host "`n[2/7] Desabilitando Network Throttling..." -ForegroundColor Yellow
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
# 0xFFFFFFFF = desabilitar throttling completamente
Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
# 0 = dar 100% de prioridade para multimedia/gaming
Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
Write-Host "  OK: NetworkThrottlingIndex = FFFFFFFF (disabled)" -ForegroundColor Green
Write-Host "  OK: SystemResponsiveness = 0 (max gaming priority)" -ForegroundColor Green

# --- 3. MMCSS GAME PRIORITY ---
Write-Host "`n[3/7] Configurando MMCSS Game Priority..." -ForegroundColor Yellow
$gamePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (-not (Test-Path $gamePath)) {
    New-Item -Path $gamePath -Force | Out-Null
}
Set-ItemProperty -Path $gamePath -Name "GPU Priority" -Value 8 -Type DWord -Force
Set-ItemProperty -Path $gamePath -Name "Priority" -Value 6 -Type DWord -Force
Set-ItemProperty -Path $gamePath -Name "Scheduling Category" -Value "High" -Type String -Force
Set-ItemProperty -Path $gamePath -Name "SFIO Priority" -Value "High" -Type String -Force
Write-Host "  OK: GPU Priority = 8, Priority = 6, Scheduling = High" -ForegroundColor Green

# --- 4. TCP GLOBAL SETTINGS ---
Write-Host "`n[4/7] Otimizando TCP Global Settings..." -ForegroundColor Yellow
netsh int tcp set global autotuninglevel=normal 2>$null
netsh int tcp set global chimney=disabled 2>$null
netsh int tcp set global rss=enabled 2>$null
netsh int tcp set global timestamps=disabled 2>$null
netsh int tcp set global ecncapability=disabled 2>$null
netsh int tcp set global initialRto=2000 2>$null
netsh int tcp set supplemental internet congestionprovider=ctcp 2>$null
Write-Host "  OK: TCP otimizado (autotuning=normal, chimney=off, rss=on, timestamps=off, ecn=off)" -ForegroundColor Green

# --- 5. DESABILITAR POWER SAVING NA PLACA DE REDE ---
Write-Host "`n[5/7] Desabilitando Power Saving na placa de rede..." -ForegroundColor Yellow
$adapter = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if ($adapter) {
    # Desabilitar Energy Efficient Ethernet se disponivel
    $eee = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Energy Efficient|Green Ethernet|EEE' }
    foreach ($prop in $eee) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    # Desabilitar Flow Control
    $fc = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Flow Control' }
    foreach ($prop in $fc) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    # Desabilitar Interrupt Moderation
    $im = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Interrupt Moderation' }
    foreach ($prop in $im) {
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        Write-Host "  OK: $($prop.DisplayName) = Disabled" -ForegroundColor Green
    }
    
    # Desabilitar Wake on LAN (evita wake indesejado e overhead)
    Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
    Write-Host "  OK: Power Management desabilitado em $($adapter.Name)" -ForegroundColor Green
} else {
    Write-Host "  AVISO: Nenhum adaptador ativo encontrado" -ForegroundColor Red
}

# --- 6. PLANO DE ENERGIA ALTO DESEMPENHO ---
Write-Host "`n[6/7] Ativando plano de energia Alto Desempenho..." -ForegroundColor Yellow
$highPerf = powercfg /list | Select-String "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
if ($highPerf) {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    Write-Host "  OK: Plano 'Alto Desempenho' ativado" -ForegroundColor Green
} else {
    # Tentar criar o plano Ultimate Performance
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
    if ($LASTEXITCODE -eq 0) {
        $ultimateGuid = (powercfg /list | Select-String "Ultimate" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1
        if ($ultimateGuid) {
            powercfg /setactive $ultimateGuid
            Write-Host "  OK: Plano 'Ultimate Performance' criado e ativado" -ForegroundColor Green
        }
    } else {
        Write-Host "  AVISO: Alto Desempenho nao disponivel, mantendo atual" -ForegroundColor Red
    }
}

# --- 7. FLUSH DNS ---
Write-Host "`n[7/7] Limpando cache DNS..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null
Write-Host "  OK: Cache DNS limpo" -ForegroundColor Green

# --- RESUMO ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " OTIMIZACOES APLICADAS COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Alteracoes que requerem REINICIALIZACAO:" -ForegroundColor Yellow
Write-Host "  - Nagle Algorithm (TcpAckFrequency + TCPNoDelay)"
Write-Host "  - Network Throttling Index"
Write-Host "  - MMCSS Game Priority"
Write-Host ""
Write-Host "Reinicie o PC para aplicar todas as mudancas." -ForegroundColor Yellow
Write-Host ""
pause
