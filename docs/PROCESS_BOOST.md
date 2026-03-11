# Process Boost — Detailed Documentation

## Overview

`bf6_process_boost.ps1` applies real-time process optimizations while Battlefield 6 is running. It adjusts CPU scheduling priorities and audits resource usage from background processes.

**Run every time** you start the game. Changes do not persist after the game or PC is restarted.

---

## Optimization Breakdown

### 1. BF6 Process Priority: High

**What it does:**  
Sets `PriorityClass = High` on the BF6 process.

**Windows Priority Classes (ascending):**
| Priority | Value | Use Case |
|---|---|---|
| Idle | 64 | Screen savers, background indexing |
| BelowNormal | 16384 | Low-priority background tasks |
| Normal | 32 | Default for all applications |
| AboveNormal | 32768 | Important but non-critical |
| **High** | **128** | **Real-time processing, games** |
| RealTime | 256 | OS kernel tasks only (dangerous for apps) |

**Impact:**
- The Windows scheduler allocates CPU time slices to BF6 before Normal-priority processes
- When CPU is under load, BF6 threads get priority — prevents FPS drops from background tasks
- Doesn't starve the system (unlike RealTime, which can freeze the OS)

**Why not RealTime?**
RealTime priority can preempt Windows kernel threads (mouse input, disk I/O, network stack), causing system instability, input lag, or crashes. High priority is the safest maximum for games.

**How to revert:**  
Priority resets automatically when the game closes. No manual action needed.

---

### 2. Background Process Priority: BelowNormal

**What it does:**  
Lowers the priority of known resource-heavy background processes to `BelowNormal`.

**Targeted processes:**

| Process Name | Application | Why Lower Priority |
|---|---|---|
| `OneDrive` | OneDrive client | Continuous file sync uses disk I/O and network bandwidth |
| `OneDrive.Sync.Service` | OneDrive sync service | Same as above; separate service process |
| `EpicGamesLauncher` | Epic Games Launcher | Runs overlay SDK and checks for updates; unnecessary during gameplay |
| `EACefSubProcess` | EA CEF (Chromium) | EA app embedded browser — multiple processes, high RAM |
| `EADesktop` | EA Desktop app | Main EA client; can be minimized but still consumes resources |
| `EABackgroundService` | EA Background Service | Telemetry and update checks |
| `EAEgsProxy` | EA-Epic proxy | Bridge between Epic and EA services |
| `msedge` | Microsoft Edge | Multiple renderer processes, each consuming 50-200 MB RAM |
| `Code` | VS Code | Extensions, language servers, and terminal processes |

**Impact:**
- Frees CPU time slices for BF6 when under load
- Combined RAM savings of ~1-3 GB depending on what's running
- These processes continue working normally — just at lower priority when CPU is busy

**How to revert:**  
Priority resets automatically when each process restarts. No manual action needed.

---

### 3. Network Connection Monitor

**What it does:**  
Displays active TCP connections and UDP endpoints owned by the BF6 process.

**Example output:**
```
LocalPort RemoteAddress     RemotePort State
--------- -------------     ---------- -----
49152     159.153.xx.xx     3659       Established
49153     159.153.xx.xx     443        Established

LocalPort LocalAddress
--------- ------------
3659      0.0.0.0
```

**How to use this information:**
- **RemoteAddress** shows which game server you're connected to — you can look up geographic location to verify your matchmaking region
- **Port 3659** is the standard Frostbite engine game port (UDP) — if missing, you have a connectivity issue
- **Multiple Established TCP connections** to EA addresses (159.153.x.x) is normal (game + telemetry + social features)
- If you see connections to unexpected IPs, it could indicate overlay software or proxy interference

---

### 4. Resource Audit

**What it does:**  
Scans for running processes that can be safely closed to free resources, displaying their current RAM usage.

**Suggested processes to close:**
| Process | Typical RAM | Why Close |
|---|---|---|
| EpicGamesLauncher | 200-500 MB | Not needed after game launches (BF6 runs independently) |
| OneDrive | 100-300 MB | File sync competes for disk and network during gameplay |
| msedge | 500-2000 MB | Multiple tabs/renderer processes consume significant RAM |
| Code (VS Code) | 300-1500 MB | Language servers and extensions are CPU/RAM intensive |

**Important:** This step only **suggests** — it does not kill any process automatically. You decide what to close.

---

## Usage Tips

1. **Launch BF6 first**, wait until you reach the main menu
2. Run `bf6_boost.bat` (double-click — auto-elevates with UAC)
3. Review the output for any warnings or suggestions
4. **Alt+Tab back to the game** and enjoy optimized performance

---

## Customization

### Add/remove processes from the low-priority list:

Edit the `$lowPriority` array in `bf6_process_boost.ps1`:

```powershell
# Add Discord and Spotify to the list
$lowPriority = @("OneDrive", "EpicGamesLauncher", "EADesktop", "msedge", "Code", "Discord", "Spotify")
```

### Adapt for other games:

Change the process name in the detection line:

```powershell
# For Valorant:
$bf6 = Get-Process -Name "VALORANT-Win64-Shipping" -ErrorAction SilentlyContinue

# For CS2:
$bf6 = Get-Process -Name "cs2" -ErrorAction SilentlyContinue
```

---

## Safety Notes

- No system files are modified
- No processes are killed automatically
- Priority changes are temporary and reset when processes restart
- High priority (not RealTime) is used to maintain system stability
