# Network Optimization — Detailed Documentation

## Overview

A **FASE 1** do script unificado `bf6_boost.ps1` aplica otimizações de rede e sistema para reduzir latência e melhorar estabilidade em jogos multiplayer online.

**Executa uma vez** — o script detecta automaticamente quais valores já estão configurados e só altera o que for diferente. Solicita reboot apenas se alterações de registro foram feitas. A maioria das mudanças persiste após reinicializações.

---

## Optimization Breakdown

### 0. Network Diagnostics

**What it does:**  
Identifies the active network adapter and displays link speed, driver version, and packet statistics. Alerts if Wi-Fi is being used (primary cause of packet loss in gaming).

---

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

### 5. TCP Receive/Transmit Buffers

**What it does:**  
Maximizes TCP buffer sizes and adapter RX/TX ring buffers for better packet handling under load.

**Registry changes:**
```
HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
  TcpWindowSize = 65535        (Maximum TCP window)
  Tcp1323Opts = 3              (Enable window scaling + timestamps)
  DefaultTTL = 64              (Standard hop limit)
  MaxUserPort = 65534          (Maximum ephemeral ports)
  TcpTimedWaitDelay = 30       (Faster port recycling)
  TcpMaxDataRetransmissions = 5 (Retransmit attempts)
  SackOpts = 1                 (Selective ACK — faster recovery)
```

**Adapter properties:**
- Receive Buffers / Rx Ring Descriptors → set to maximum supported
- Transmit Buffers / Tx Ring Descriptors → set to maximum supported

**Impact:**
- Larger buffers prevent packet loss during burst traffic (64+ player battles)
- Selective ACK enables recovery without retransmitting entire windows
- More ephemeral ports prevent port exhaustion under heavy connection load

**How to revert:**
```powershell
$path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Remove-ItemProperty -Path $path -Name "TcpWindowSize","Tcp1323Opts","DefaultTTL","MaxUserPort","TcpTimedWaitDelay","TcpMaxDataRetransmissions","SackOpts" -ErrorAction SilentlyContinue
# Adapter buffers: reset via Device Manager → NIC → Advanced
```

**Requires reboot:** Yes (registry changes)

---

### 6. NIC Power Management

**What it does:**  
Disables power-saving features on the active network adapter that can introduce latency.

| Feature | Why Disable |
|---|---|
| Energy Efficient Ethernet (EEE/802.3az) | Puts NIC into low-power state between packets; waking up adds 2-10ms latency |
| Flow Control (802.3x) | Can pause packet transmission for up to 33ms during "congestion" |
| Interrupt Moderation | Batches interrupts to reduce CPU usage, but adds 1-5ms per batch |
| Offloads (LSO/TCP/UDP/Checksum) | Offloading to NIC firmware can cause bugs on consumer hardware |
| Wake on LAN / Power Management | Unnecessary during gaming, adds minor processing overhead |

**Impact:**
- Eliminates random latency spikes (2-33ms) caused by power saving features
- NIC processes every packet immediately instead of batching
- Most noticeable on Ethernet connections (Wi-Fi has other latency sources)

**How to revert:**
- Re-enable in Device Manager → Network Adapter → Advanced Properties
- Or run: `Enable-NetAdapterPowerManagement -Name "YOUR_ADAPTER_NAME"`

**Requires reboot:** No

---

### 7. Wi-Fi Optimizations (if applicable)

**What it does:**  
Applies Wi-Fi-specific optimizations only if the active adapter is wireless.

| Setting | Value | Why |
|---|---|---|
| Roaming Aggressiveness | Lowest (1) | Prevents switching access points mid-game — AP transitions cause 100-500ms drops |
| Preferred Band | 5GHz | 5GHz has less interference and lower latency than 2.4GHz |
| Throughput Boost | Enabled | Maximizes data throughput mode |
| MIMO/Spatial Streams | No SMPS | Uses all antenna chains for maximum throughput |

**Impact:**
- Significantly reduces random latency spikes on Wi-Fi
- 5GHz preference can cut average latency by 5-15ms vs 2.4GHz

**Important:** Ethernet cable eliminates ~90% of Wi-Fi-related packet loss. Use cable if at all possible.

**How to revert:**  
Reset in Device Manager → Wi-Fi Adapter → Advanced Properties.

**Requires reboot:** No

---

### 8. QoS Bandwidth Release

**What it does:**  
Windows reserves up to 20% of network bandwidth for QoS (Quality of Service) by default. This setting removes that reservation.

**Registry change:**
```
HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched
  NonBestEffortLimit = 0   (0% reserved, 100% available for apps)
```

Also disables UDP Receive Offload (URO) via `netsh int udp set global uro=disabled`.

**Impact:**
- Full bandwidth available for gaming
- Noticeable on connections under 100 Mbps

**How to revert:**
```powershell
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit"
```

**Requires reboot:** No

---

### 9. Power Plan: Ultimate Performance

**What it does:**  
Activates the "High Performance" or "Ultimate Performance" power plan, which:
- Keeps CPU at maximum frequency (disables SpeedStep/Cool'n'Quiet dynamic scaling)
- Disables aggressive C-state transitions (CPU won't enter deep sleep between frames)
- Maximizes PCI Express link state power
- Sets CPU throttle min/max to 100% (eliminates ramp-up delay)

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

### 10. DNS Cache Flush + Winsock Reset

**What it does:**  
Clears the Windows DNS resolver cache (`ipconfig /flushdns`). If network registry changes were made (reboot needed), also executes `netsh winsock reset` and `netsh int ip reset` to ensure clean state.

**Impact:**
- Forces fresh DNS resolution for game servers
- Fixes stale DNS entries that might route to decommissioned servers
- Winsock reset clears any corrupted network catalog entries
- Zero risk; cache and catalog rebuild naturally

**Requires reboot:** No (Winsock reset takes full effect after reboot, which is already required by other changes)

---

## Smart Change Detection

The script uses helper functions to compare current values before making changes:

- **`Set-RegIfDifferent`**: Reads the current registry value and only writes if it differs. Tracks whether a reboot is needed via the `$script:rebootNeeded` flag.
- **`Set-AdapterPropIfDifferent`**: Compares adapter advanced property values before changing.

This means:
- Running the script multiple times is safe and idempotent
- No reboot is requested unless actual changes were made
- Winsock reset only runs when registry changes require it

---

## Safety Notes

- All changes are configuration-level; no system files are modified
- Create a System Restore Point before running: `Checkpoint-Computer -Description "Before BF6 Optimizer"`
- Registry changes can be exported beforehand: `reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" backup_tcp.reg`
