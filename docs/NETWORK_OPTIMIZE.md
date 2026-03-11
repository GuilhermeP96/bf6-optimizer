# Network Optimization — Detailed Documentation

## Overview

`bf6_network_optimize.ps1` applies system-level network and power optimizations to reduce latency and improve stability in online multiplayer games, specifically Battlefield 6.

**Run once** after installing or reinstalling Windows. Most changes persist across reboots.

---

## Optimization Breakdown

### 1. Nagle Algorithm Disable

**What it does:**  
The Nagle Algorithm (RFC 896) buffers small TCP packets and sends them together to reduce overhead. While efficient for bulk transfers, it adds **up to 200ms of delay** per packet in real-time applications like games.

**Registry changes:**
```
HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{GUID}
  TcpAckFrequency = 1   (ACK every packet immediately)
  TCPNoDelay = 1         (Disable Nagle buffering)
```

**Impact:**
- Reduces round-trip time (RTT) by 5-15ms on average
- Eliminates "rubberbanding" caused by packet batching
- Most noticeable on connections with already low base latency (<50ms)

**How to revert:**
```powershell
$nics = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($nic in $nics) {
    Remove-ItemProperty -Path $nic.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $nic.PSPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
}
# Reboot required
```

**Requires reboot:** Yes

---

### 2. Network Throttling Index

**What it does:**  
Windows limits non-multimedia network traffic to ~10 packets per millisecond by default, through the `NetworkThrottlingIndex` value. Setting it to `0xFFFFFFFF` removes this limit. `SystemResponsiveness=0` tells the scheduler to dedicate maximum resources to the foreground application.

**Registry changes:**
```
HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
  NetworkThrottlingIndex = 0xFFFFFFFF  (disabled)
  SystemResponsiveness = 0             (100% foreground priority)
```

**Impact:**
- Removes artificial network bandwidth cap for games
- CPU scheduler favors the game process for I/O and network operations
- Reduces sudden latency spikes during large battles (64+ players)

**How to revert:**
```powershell
$path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $path -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force
Set-ItemProperty -Path $path -Name "SystemResponsiveness" -Value 20 -Type DWord -Force
# Reboot required
```

**Requires reboot:** Yes

---

### 3. MMCSS Game Priority

**What it does:**  
Configures the Multimedia Class Scheduler Service (MMCSS) to recognize a "Games" task class with elevated priority for GPU scheduling, thread priority, and storage I/O.

**Registry changes:**
```
HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games
  GPU Priority = 8           (Scale 0-8, max priority)
  Priority = 6               (Thread priority boost, 1-8)
  Scheduling Category = High (Thread scheduling class)
  SFIO Priority = High       (Storage/File I/O priority)
```

**Impact:**
- GPU commands from the game are processed ahead of other applications
- Thread scheduling favors game threads over background services
- Disk I/O (loading assets, textures) gets higher priority
- Reduces micro-stuttering caused by background processes competing for GPU/disk

**How to revert:**
```powershell
Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Force
# Reboot required
```

**Requires reboot:** Yes

---

### 4. TCP Global Settings

**What it does:**  
Configures the Windows TCP/IP stack via `netsh` for optimal gaming performance.

| Parameter | Value Set | Default | Why |
|---|---|---|---|
| Auto-tuning Level | Normal | Normal | Keeps dynamic window sizing without excessive probing |
| TCP Chimney Offload | Disabled | Enabled | Avoids bugs in consumer NIC firmware that cause packet loss |
| RSS (Receive Side Scaling) | Enabled | Varies | Spreads packet processing across CPU cores — essential for multi-core CPUs |
| TCP Timestamps | Disabled | Enabled | Saves 12 bytes per packet; not needed on modern networks |
| ECN Capability | Disabled | Disabled | Some ISPs/routers mishandle ECN, causing false congestion signals |
| Initial RTO | 2000ms | 3000ms | Faster retransmission on packet loss |
| Congestion Provider | CTCP | CUBIC | Compound TCP has lower latency than CUBIC under light congestion |

**Impact:**
- Overall reduction in TCP overhead and retransmission delay
- RSS distributes load, preventing CPU0 bottleneck on packet processing
- Disabling timestamps saves bandwidth on high-packet-rate connections

**How to revert:**
```powershell
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global chimney=enabled
netsh int tcp set global rss=enabled
netsh int tcp set global timestamps=enabled
netsh int tcp set global ecncapability=disabled
netsh int tcp set global initialRto=3000
netsh int tcp set supplemental internet congestionprovider=default
```

**Requires reboot:** No (takes effect immediately)

---

### 5. NIC Power Management

**What it does:**  
Disables power-saving features on the active network adapter that can introduce latency.

| Feature | Why Disable |
|---|---|
| Energy Efficient Ethernet (EEE/802.3az) | Puts NIC into low-power state between packets; waking up adds 2-10ms latency |
| Flow Control (802.3x) | Can pause packet transmission for up to 33ms during "congestion" |
| Interrupt Moderation | Batches interrupts to reduce CPU usage, but adds 1-5ms per batch |
| Wake on LAN | Unnecessary during gaming, adds minor processing overhead |

**Impact:**
- Eliminates random latency spikes (2-33ms) caused by power saving features
- NIC processes every packet immediately instead of batching
- Most noticeable on Ethernet connections (Wi-Fi has other latency sources)

**How to revert:**
- Re-enable in Device Manager → Network Adapter → Advanced Properties
- Or run: `Enable-NetAdapterPowerManagement -Name "YOUR_ADAPTER_NAME"`

**Requires reboot:** No

---

### 6. Power Plan: Ultimate Performance

**What it does:**  
Activates the "High Performance" or "Ultimate Performance" power plan, which:
- Keeps CPU at maximum frequency (disables SpeedStep/Cool'n'Quiet dynamic scaling)
- Disables aggressive C-state transitions (CPU won't enter deep sleep between frames)
- Maximizes PCI Express link state power

**Impact:**
- Eliminates micro-stutters caused by CPU frequency ramping (takes 1-5ms to ramp up)
- Consistent frame times due to stable CPU frequency
- Uses more power and generates more heat — intended for desktop use during gaming sessions

**How to revert:**
```powershell
# Switch back to Balanced
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
```

**Requires reboot:** No

---

### 7. DNS Cache Flush

**What it does:**  
Clears the Windows DNS resolver cache (`ipconfig /flushdns`).

**Impact:**
- Forces fresh DNS resolution for game servers
- Fixes stale DNS entries that might route to decommissioned servers
- Zero risk; cache rebuilds naturally

**Requires reboot:** No

---

## Safety Notes

- All changes are configuration-level; no system files are modified
- Create a System Restore Point before running: `Checkpoint-Computer -Description "Before BF6 Optimizer"`
- Registry changes can be exported beforehand: `reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" backup_tcp.reg`
