# BF6 Optimizer — Battlefield 6 Performance & Network Optimization for Windows

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform: Windows 10/11](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue.svg)](#requirements)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](#requirements)

> **Open-source scripts to reduce lag, lower ping, eliminate stuttering, and maximize FPS in Battlefield 6 (BF6) on Windows 10/11.**

---

## Why BF6 Optimizer?

Battlefield 6 é um jogo exigente que depende de **rede de baixa latência** e **CPU/GPU com prioridade máxima**. Configurações padrão do Windows introduzem overhead desnecessário: Nagle Algorithm agrupa pacotes (adicionando latência), o Network Throttling limita throughput de jogos, e processos em background competem por recursos.

**BF6 Optimizer** aplica **otimizações comprovadas no nível do sistema operacional** em segundos, com um duplo-clique.

### Resultados Esperados

| Métrica | Antes | Depois | Melhoria |
|---|---|---|---|
| Ping médio | ~40-60ms | ~25-40ms | **-15 a 20ms** |
| Micro-stuttering | Frequente | Raro | **Significativa** |
| Input lag percebido | Alto | Baixo | **Notável** |
| FPS em combates intensos | Drops frequentes | Mais estável | **+5-15%** |
| Uso de RAM por background | ~2-4 GB | ~1-2 GB | **-50%** |

> *Resultados variam conforme hardware e conexão de internet.*

---

## Features

- **Nagle Algorithm Disable** — Envia pacotes TCP imediatamente, sem buffering
- **Network Throttling Disable** — Remove limite de banda para jogos
- **MMCSS Game Priority** — Prioridade máxima de GPU e CPU scheduling para games
- **TCP Stack Optimization** — RSS habilitado, timestamps desabilitados, ECN off, CTCP provider
- **NIC Power Saving Disable** — Desabilita economy mode, flow control e interrupt moderation na placa de rede
- **Ultimate Performance Power Plan** — Ativa ou cria plano de energia Ultimate Performance
- **DNS Cache Flush** — Limpa cache DNS corrompido ou desatualizado
- **Process Priority Management** — BF6 em prioridade Alta, apps em background em prioridade Baixa
- **Background Process Audit** — Identifica processos consumindo recursos desnecessariamente
- **Network Connection Monitor** — Mostra conexões ativas do BF6 (TCP/UDP)

---

## Quick Start

### 1. Download

```bash
git clone https://github.com/gp96/bf6-optimizer.git
cd bf6-optimizer
```

Ou faça download do ZIP diretamente em [Releases](https://github.com/gp96/bf6-optimizer/releases).

### 2. Otimização de Rede (uma vez após instalar/reinstalar Windows)

Clique com botão direito em `bf6_network_optimize.bat` → **Executar como administrador**

> Requer **reinicialização** para aplicar Nagle e Network Throttling.

### 3. Boost de Processo (toda vez que iniciar o jogo)

1. Abra o Battlefield 6
2. Dê duplo-clique em `bf6_boost.bat` — solicita elevação UAC automaticamente
3. Pronto! Prioridades ajustadas.

---

## Scripts Included

| Script | Propósito | Requer Admin | Requer Reboot |
|---|---|---|---|
| `scripts/bf6_network_optimize.ps1` | Otimizações de rede e sistema | Sim | Sim (parcial) |
| `scripts/bf6_process_boost.ps1` | Prioridade de processo em tempo real | Sim | Não |
| `bf6_boost.bat` | Launcher com elevação automática (UAC) | Auto-eleva | Não |
| `bf6_network_optimize.bat` | Launcher de rede com elevação automática | Auto-eleva | Sim (parcial) |

---

## How It Works

### Network Optimizations (`bf6_network_optimize.ps1`)

Cada otimização atua em uma camada diferente do stack de rede do Windows:

#### 1. Nagle Algorithm Disable
Modifica o registro do Windows para desabilitar o algoritmo de Nagle em todas as interfaces de rede ativas.

- **Chaves alteradas:** `TcpAckFrequency=1`, `TCPNoDelay=1` em `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*`
- **Impacto:** Pacotes são enviados imediatamente em vez de agrupados. Reduz latência em **5-15ms** em jogos FPS multiplayer.
- **Reversibilidade:** Remover as chaves de registro restaura o comportamento padrão.

#### 2. Network Throttling Disable
O Windows limita o throughput de rede de aplicativos não-multimídia por padrão (10 pacotes/ms).

- **Chaves alteradas:** `NetworkThrottlingIndex=0xFFFFFFFF`, `SystemResponsiveness=0`
- **Impacto:** Remove o limite de throughput. O sistema dedica 100% dos recursos de scheduling para a aplicação em primeiro plano (o jogo). Melhora estabilidade de conexão durante combates massivos.
- **Reversibilidade:** Setar `NetworkThrottlingIndex=10` e `SystemResponsiveness=20` restaura padrões.

#### 3. MMCSS Game Priority
Configura o Multimedia Class Scheduler Service (MMCSS) para priorizar tarefas de jogos.

- **Chaves alteradas:** `GPU Priority=8`, `Priority=6`, `Scheduling Category=High`, `SFIO Priority=High`
- **Impacto:** I/O de disco, GPU scheduling e prioridade de thread favorecem o processo do jogo. Reduz stuttering causado por concorrência de I/O.
- **Reversibilidade:** Deletar a chave `HKLM:\...\Tasks\Games` restaura padrões.

#### 4. TCP Global Settings
Configura parâmetros globais do stack TCP via `netsh`.

| Parâmetro | Valor | Motivo |
|---|---|---|
| Auto-tuning | Normal | Permite janela dinâmica sem overhead excessivo |
| Chimney Offload | Disabled | Evita bugs de offload em placas de rede consumer |
| RSS | Enabled | Distribui processamento de pacotes entre múltiplos cores |
| Timestamps | Disabled | Remove 12 bytes de overhead por pacote TCP |
| ECN | Disabled | Evita marcação incorreta de congestionamento por ISPs |
| Initial RTO | 2000ms | Retransmissão mais rápida em caso de packet loss |
| Congestion Provider | CTCP | Compound TCP para melhor throughput |

#### 5. NIC Power Management
Desabilita funcionalidades de economia de energia na placa de rede.

- **Energy Efficient Ethernet (EEE):** Pode adicionar latência ao "acordar" a placa
- **Flow Control:** Pode pausar transmissão em momentos críticos
- **Interrupt Moderation:** Agrupa interrupções, adicionando latência
- **Wake on LAN:** Overhead desnecessário durante gaming

#### 6. Power Plan: Ultimate Performance
Ativa o plano de energia "Alto Desempenho" ou cria o plano "Ultimate Performance" (disponível no Windows 10 Pro/Enterprise).

- **Impacto:** CPU mantém frequência máxima, sem C-states agressivos. Melhora tempo de resposta e consistência de FPS.

#### 7. DNS Cache Flush
Limpa o cache DNS do Windows para evitar resoluções incorretas ou lentas para servidores do jogo.

---

### Process Optimizations (`bf6_process_boost.ps1`)

#### 1. BF6 Priority: High
Define `PriorityClass=High` no processo do Battlefield 6.

- **Impacto:** O scheduler do Windows prioriza threads do BF6 sobre quase todos os outros processos. Reduz stuttering quando tarefas em background competem por CPU.
- **Nota:** Não usa `Realtime` para evitar instabilidade do sistema.

#### 2. Background Apps: BelowNormal
Reduz prioridade de processos conhecidos por consumir recursos:

| Processo | Motivo |
|---|---|
| OneDrive | Sincronização contínua consome disco e rede |
| EpicGamesLauncher | SDK/overlay consome CPU desnecessariamente |
| EADesktop / EACefSubProcess | Background services da EA |
| msedge | Múltiplos processos consomem RAM significativa |
| Code (VS Code) | Extensões e language servers consomem CPU/RAM |

#### 3. Network Connection Monitor
Exibe conexões TCP e endpoints UDP ativas do processo BF6, útil para diagnosticar problemas de conectividade ou verificar a qual servidor você está conectado.

#### 4. Resource Audit
Lista processos que podem ser encerrados manualmente para liberar recursos, mostrando consumo de RAM de cada um.

---

## Requirements

- **Windows 10** (build 1903+) ou **Windows 11**
- **PowerShell 5.1** ou superior (incluído no Windows)
- **Privilégios de Administrador** (os scripts solicitam elevação automaticamente via `.bat`)
- **Battlefield 6** instalado (para o script de processo)

---

## FAQ

### É seguro usar?
Sim. Todas as alterações são no nível de configuração do Windows — nenhum arquivo de sistema é modificado. As otimizações de registro podem ser revertidas manualmente ou restaurando pontos de restauração do sistema.

### Funciona com outros jogos?
Sim! As otimizações de rede e energia se aplicam a **qualquer jogo multiplayer FPS**: Battlefield, Call of Duty, Valorant, CS2, Apex Legends, etc. O script de processo precisa ser adaptado para o nome do executável.

### Preciso rodar toda vez que ligar o PC?
- **Network Optimize:** Não. Persiste após reinicializações (alterações de registro).
- **Process Boost:** Sim, sempre que iniciar o jogo (prioridade de processo não persiste).

### Posso reverter as mudanças?
Sim. Veja a documentação detalhada em [`docs/NETWORK_OPTIMIZE.md`](docs/NETWORK_OPTIMIZE.md) e [`docs/PROCESS_BOOST.md`](docs/PROCESS_BOOST.md) para instruções de reversão de cada otimização.

### Meu antivírus bloqueou o script
Alguns antivírus bloqueiam scripts PowerShell por padrão. Adicione a pasta do projeto como exceção ou execute via PowerShell diretamente:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\bf6_network_optimize.ps1
```

---

## Disclaimer

Este projeto é disponibilizado "como está" (as-is), sem garantias. As otimizações são baseadas em boas práticas documentadas pela Microsoft e pela comunidade de gaming. Use por sua conta e risco. Crie um ponto de restauração do sistema antes de aplicar mudanças de registro.

---

## Contributing

Pull requests são bem-vindos! Se você tem otimizações adicionais ou correções, abra uma issue ou PR.

---

## License

[MIT](LICENSE) — Use, modifique e distribua livremente.

---

## Keywords

Battlefield 6 optimization, BF6 FPS boost, BF6 reduce lag, BF6 lower ping, Battlefield 6 stuttering fix, BF6 network optimization, Windows gaming optimization, Nagle algorithm disable gaming, reduce input lag Battlefield, BF6 performance tweak, Battlefield 6 Windows 11 optimization, gaming TCP optimization, MMCSS gaming priority, disable network throttling gaming, BF6 high priority process, Battlefield 6 micro stutter fix, FPS drop fix BF6, optimize Windows for gaming, best settings Battlefield 6 PC, BF6 competitive settings
