# Process Boost — Detailed Documentation

## Overview

A **FASE 2** do script unificado `bf6_boost.ps1` aplica otimizações de processo em tempo real enquanto o Battlefield 6 está rodando. Opera em **loop persistente**: aguarda o BF6 iniciar, otimiza a cada 3 minutos, e volta a aguardar quando o jogo fecha.

**O script nunca encerra sozinho** — só para com `Ctrl+C`.

---

## Comportamento do Loop

```
FASE 1 completa (rede/sistema)
       │
       ▼
┌─► Aguardando BF6 (verifica a cada 30s)
│          │
│          ▼ BF6 detectado
│   ┌─► Ciclo de otimização (8 etapas)
│   │          │
│   │          ▼
│   │   Aguarda 3 minutos (verifica BF6 a cada 10s)
│   │          │
│   │     BF6 rodando? ──Sim──► próximo ciclo ─┘
│   │          │
│   │         Não
│   │          │
└───┘── Volta a aguardar BF6
```

---

## Optimization Breakdown

### 1. BF6 Process Priority: High

**What it does:**  
Sets `PriorityClass = High` on the BF6 process. Only changes if current priority differs.

**Windows Priority Classes (ascending):**
| Priority | Value | Use Case |
|---|---|---|
| Idle | 64 | Screen savers, background indexing |
| BelowNormal | 16384 | Low-priority background tasks |
| Normal | 32 | Default for all applications |
| AboveNormal | 32768 | Important but non-critical |
| **High** | **128** | **Real-time processing, games** |
| RealTime | 256 | OS kernel tasks only (dangerous for apps) |

**Why not RealTime?**
RealTime priority can preempt Windows kernel threads (mouse input, disk I/O, network stack), causing system instability, input lag, or crashes. High priority is the safest maximum for games.

**How to revert:**  
Priority resets automatically when the game closes.

---

### 2. CPU Affinity Optimization

**What it does:**  
On systems with 4+ logical processors, removes core 0 from BF6's CPU affinity mask.

**Impact:**
- Core 0 handles most hardware interrupts (NIC, USB, audio) and kernel scheduling
- Keeping BF6 off core 0 reduces stuttering from interrupt contention
- Only applied if not already configured

**How to revert:**  
Affinity resets automatically when the game closes.

---

### 3. Background Process Priority: BelowNormal

**What it does:**  
Lowers the priority of known resource-heavy background processes to `BelowNormal`. Only changes processes that aren't already at BelowNormal.

**Targeted processes:**

| Process Name | Application | Why Lower Priority |
|---|---|---|
| `EpicGamesLauncher` | Epic Games Launcher | Overlay SDK and update checks |
| `EACefSubProcess` | EA CEF (Chromium) | EA app embedded browser — multiple processes, high RAM |
| `EADesktop` | EA Desktop app | Main EA client |
| `EABackgroundService` | EA Background Service | Telemetry and update checks |
| `msedge` | Microsoft Edge | Multiple renderer processes |
| `chrome` | Google Chrome | Multiple renderer processes |
| `Code` | VS Code | Extensions and language servers |
| `steam` / `steamwebhelper` | Steam | Downloads and overlay |
| `Discord` | Discord | Voice and overlay |
| `Spotify` | Spotify | Streaming consumes bandwidth |
| `OneDrive` | OneDrive | File sync competes for disk and network |
| `nvcontainer` | NVIDIA Container | Telemetry and overlay services |
| And others... | SearchApp, GameBar, Teams, etc. | Various background overhead |

**How to revert:**  
Priority resets automatically when each process restarts.

---

### 4. Background Services Stop

**What it does:**  
Stops Windows services that are unnecessary during gaming. Only stops services that are currently running.

| Service | Description | Why Stop |
|---|---|---|
| `SysMain` | Superfetch | Prefetch de disco compete com I/O do jogo |
| `WSearch` | Windows Search | Indexação consome disco e CPU |
| `DiagTrack` | Telemetria Microsoft | Envia dados em background |
| `dmwappushservice` | Push de telemetria | Background network activity |
| `WbioSrvc` | Biometria Windows Hello | Desnecessário durante gaming |
| `TabletInputService` | Teclado touch | Desnecessário em desktop |
| `wisvc` | Windows Insider Service | Updates desnecessários |
| `MapsBroker` | Mapas offline | Background I/O desnecessário |
| `lfsvc` | Geolocalização | Background activity desnecessária |
| `XblAuthManager` | Xbox Live Auth | Desnecessário se não usa Xbox |
| `XblGameSave` | Xbox Game Save | Sync desnecessário |
| `XboxNetApiSvc` | Xbox Networking | Network overhead desnecessário |

**How to revert:**  
Services restart automatically on next boot, or manually:
```powershell
Start-Service -Name "SysMain", "WSearch", "DiagTrack"
```

---

### 5. Game DVR / Game Bar Disable

**What it does:**  
Disables Windows Game DVR and Game Bar overlays via registry. Only changes if not already disabled.

- `GameDVR_Enabled = 0`
- `AppCaptureEnabled = 0`
- `UseNexusForGameBarEnabled = 0`
- `AutoGameModeEnabled = 0`

**Impact:**
- Eliminates micro-stuttering caused by Game Bar overlay hooks
- Frees GPU resources used for background recording

**How to revert:**
Enable Game Bar in Settings → Gaming → Game Bar.

---

### 6. Fullscreen Optimizations Disable

**What it does:**  
Sets `DISABLEDXMAXIMIZEDWINDOWEDMODE` compatibility flag for the BF6 executable. Only runs on the first optimization cycle.

**Impact:**
- Prevents Windows from applying DWM composition to the game window
- Can improve input latency and FPS consistency

**How to revert:**
```powershell
$layersPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
Remove-ItemProperty -Path $layersPath -Name "C:\path\to\bf6.exe"
```

---

### 7. RAM Standby Cleanup

**What it does:**  
Reduces the working set of all non-BF6 processes, freeing physical RAM for the game. Also triggers .NET garbage collection.

**Impact:**
- Can free 500MB-2GB+ of RAM depending on background processes
- Freed RAM becomes available for BF6 and the GPU page file
- Does not kill any process — just reduces their cached memory

---

### 8. Network Connection Monitor

**What it does:**  
Displays active TCP connections and UDP endpoints owned by the BF6 process. Also tests packet loss to the default gateway.

**Diagnostics provided:**
- TCP connections: local port, remote address, remote port, state
- UDP endpoints: local port and address
- Gateway ping test: average latency and packet loss (10 packets)

**How to use this information:**
- **Port 3659 (UDP)** is the standard Frostbite engine game port — if missing, you have a connectivity issue
- **Packet loss > 0** to gateway indicates local network problems (Wi-Fi, cable, router)

---

### Resource Audit (first cycle only)

**What it does:**  
Lists processes that can be manually closed to free resources, showing their RAM usage. Runs only on the first optimization cycle.

**Important:** This step only **suggests** — it does not kill any process automatically.

---

## Usage Tips

1. Execute `bf6_boost.bat` — pode ser *antes* de abrir o jogo (ele aguarda automaticamente)
2. O BF6 é detectado e otimizado a cada 3 minutos
3. Quando o BF6 fechar, o script volta a aguardar
4. Use `Ctrl+C` para encerrar o script

---

## Customization

### Add/remove processes from the low-priority list:

Edit the `$lowPriority` array in `bf6_boost.ps1`:

```powershell
$lowPriority = @(
    "EpicGamesLauncher", "EACefSubProcess", "EADesktop",
    "msedge", "chrome", "Code", "Discord", "Spotify"
    # Add your own here
)
```

### Adapt for other games:

Change the process name used for detection:

```powershell
# Search for "bf6" in bf6_boost.ps1 and replace with your game's process name:
# For Valorant: "VALORANT-Win64-Shipping"
# For CS2: "cs2"
# For Apex Legends: "r5apex"
```

---

## Safety Notes

- No system files are modified
- No processes are killed automatically
- Priority changes are temporary and reset when processes restart
- High priority (not RealTime) is used to maintain system stability
- The script never exits on its own — only with Ctrl+C
