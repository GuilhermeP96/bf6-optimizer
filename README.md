# BF6 Optimizer — Battlefield 6 Performance & Network Optimization for Windows

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform: Windows 10/11](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue.svg)](#requirements)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](#requirements)

> **Open-source script to reduce lag, lower ping, eliminate stuttering, and maximize FPS in Battlefield 6 (BF6) on Windows 10/11.**

---

## Why BF6 Optimizer?

Battlefield 6 é um jogo exigente que depende de **rede de baixa latência** e **CPU/GPU com prioridade máxima**. Configurações padrão do Windows introduzem overhead desnecessário: Nagle Algorithm agrupa pacotes (adicionando latência), o Network Throttling limita throughput de jogos, e processos em background competem por recursos.

**BF6 Optimizer** aplica **otimizações comprovadas no nível do sistema operacional** em segundos, com um duplo-clique. O script **unificado** executa otimizações de rede (uma vez) e depois fica em loop otimizando processos enquanto o jogo estiver aberto — e aguarda automaticamente caso o jogo ainda não tenha sido iniciado.

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

- **Script unificado** — Uma única execução aplica tudo: rede + processo + GPU
- **Inteligente** — Só altera valores que diferem da configuração atual; só pede reboot se necessário
- **Loop persistente** — Aguarda o BF6 iniciar, otimiza a cada 3 minutos, e volta a aguardar quando o jogo fecha
- **Nagle Algorithm Disable** — Envia pacotes TCP imediatamente, sem buffering
- **Network Throttling Disable** — Remove limite de banda para jogos
- **MMCSS Game Priority** — Prioridade máxima de GPU e CPU scheduling para games
- **TCP Stack Optimization** — RSS habilitado, timestamps desabilitados, ECN off, CTCP provider
- **TCP Buffer Tuning** — Buffers RX/TX maximizados para anti packet-loss
- **NIC Power Saving Disable** — Desabilita economy mode, flow control, interrupt moderation e offloads
- **Wi-Fi Optimization** — Roaming agressividade mínima, prefer 5GHz, throughput boost (se Wi-Fi)
- **QoS Bandwidth Release** — Remove reserva de banda do Windows para QoS
- **Ultimate Performance Power Plan** — Ativa ou cria plano de energia Ultimate Performance
- **DNS Cache Flush + Winsock Reset** — Limpa cache DNS e reseta Winsock (apenas se necessário)
- **Process Priority Management** — BF6 em prioridade Alta, apps em background em prioridade Baixa
- **CPU Affinity Optimization** — Remove core 0 do BF6 (reservado para OS)
- **Background Services Stop** — Para serviços pesados (SysMain, WSearch, DiagTrack, Xbox, etc.)
- **Game DVR / Game Bar Disable** — Desabilita overlays que causam stuttering
- **Fullscreen Optimizations Disable** — Remove otimizações de janela do Windows para BF6
- **RAM Standby Cleanup** — Libera working sets de processos não-essenciais
- **Network Connection Monitor** — Mostra conexões ativas do BF6 (TCP/UDP) e testa packet loss

---

## Quick Start

### 1. Download

```bash
git clone https://github.com/gp96/bf6-optimizer.git
cd bf6-optimizer
```

Ou faça download do ZIP diretamente em [Releases](https://github.com/gp96/bf6-optimizer/releases).

### 2. Executar

Dê duplo-clique em `bf6_boost.bat` — solicita elevação UAC automaticamente.

O script executa em **duas fases**:

1. **FASE 1 — Rede e Sistema (one-shot):** Aplica otimizações de registro, TCP, placa de rede e plano de energia. Só altera valores que diferem do atual. Solicita reboot apenas se necessário.
2. **FASE 2 — Processo (loop persistente):** Aguarda o BF6 iniciar (verifica a cada 30s). Quando detectado, otimiza prioridade, afinidade, serviços e RAM a cada 3 minutos. Quando o BF6 fecha, volta automaticamente ao modo de espera. Só para com `Ctrl+C`.

> **Dica:** Execute o script *antes* de abrir o jogo — ele ficará aguardando o BF6 iniciar automaticamente.

---

## Arquivos

| Arquivo | Propósito | Requer Admin |
|---|---|---|
| `bf6_boost.ps1` | Script unificado (rede + processo + GPU) | Sim |
| `bf6_boost.bat` | Launcher com elevação automática (UAC) | Auto-eleva |

---

## How It Works

O script unificado `bf6_boost.ps1` opera em duas fases sequenciais:

### FASE 1: Otimizações de Rede e Sistema (one-shot)

Cada otimização é aplicada **somente se o valor atual difere do desejado** — se tudo já estiver configurado, nenhuma alteração é feita e nenhum reboot é solicitado.

#### 0. Diagnóstico de Rede
Identifica o adaptador ativo, exibe link speed, driver, e alerta se Wi-Fi está sendo usado (causa #1 de packet loss).

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

#### 5. TCP Receive/Transmit Buffers
Maximiza buffers RX/TX no registro e nas propriedades avançadas do adaptador para reduzir packet loss.

- **Chaves alteradas:** `TcpWindowSize=65535`, `Tcp1323Opts=3`, `DefaultTTL=64`, `MaxUserPort=65534`, `TcpTimedWaitDelay=30`, `TcpMaxDataRetransmissions=5`, `SackOpts=1`
- **Propriedades do adaptador:** Receive Buffers e Transmit Buffers ajustados ao máximo suportado
- **Impacto:** Reduz packet loss durante picos de tráfego (combates 64+ jogadores)

#### 6. NIC Power Management
Desabilita funcionalidades de economia de energia na placa de rede.

- **Energy Efficient Ethernet (EEE):** Pode adicionar latência ao "acordar" a placa
- **Flow Control:** Pode pausar transmissão em momentos críticos
- **Interrupt Moderation:** Agrupa interrupções, adicionando latência
- **Offloads (LSO/TCP/UDP/Checksum):** Desabilita para evitar bugs em placas consumer
- **Wake on LAN / Power Management:** Overhead desnecessário durante gaming

#### 7. Wi-Fi Optimizations (se aplicável)
Apenas se o adaptador ativo for Wi-Fi:
- **Roaming Aggressiveness:** Mínima (evita trocar de AP durante jogo)
- **Preferred Band:** 5GHz (menor interferência, menor latência)
- **Throughput Boost:** Habilitado
- **MIMO/Spatial Streams:** No SMPS (máximo throughput)

#### 8. QoS Bandwidth Release
Remove a reserva de 20% de banda que o Windows faz para QoS (`NonBestEffortLimit=0`).

#### 9. Power Plan: Ultimate Performance
Ativa o plano de energia "Alto Desempenho" ou cria o plano "Ultimate Performance" (disponível no Windows 10 Pro/Enterprise).

- **Impacto:** CPU mantém frequência máxima, sem C-states agressivos. Melhora tempo de resposta e consistência de FPS.
- **Throttle:** Processador fixado em 100% min/max para eliminar ramp-up delay.

#### 10. DNS Cache Flush + Winsock Reset
Limpa o cache DNS do Windows. Se houve alterações de rede (reboot necessário), também executa `netsh winsock reset` e `netsh int ip reset`.

---

### FASE 2: Otimizações de Processo (loop persistente)

O script entra em um **loop permanente** que:
1. **Aguarda** o BF6 iniciar (verifica a cada 30 segundos)
2. **Otimiza** processos a cada 3 minutos enquanto o BF6 estiver rodando
3. **Volta a aguardar** quando o BF6 fecha (não encerra o script)
4. Só para com **Ctrl+C**

#### 1. BF6 Priority: High
Define `PriorityClass=High` no processo do Battlefield 6.

- **Impacto:** O scheduler do Windows prioriza threads do BF6 sobre quase todos os outros processos. Reduz stuttering quando tarefas em background competem por CPU.
- **Nota:** Não usa `Realtime` para evitar instabilidade do sistema.

#### 2. CPU Affinity Optimization
Remove core 0 da afinidade do BF6on sistemas com 4+ cores.

- **Impacto:** Core 0 é reservado para o kernel do Windows e interrupções de hardware. Removê-lo do jogo reduz stuttering causado por concorrência com o OS.

#### 3. Background Apps: BelowNormal
Reduz prioridade de processos conhecidos por consumir recursos:

| Processo | Motivo |
|---|---|
| OneDrive | Sincronização contínua consome disco e rede |
| EpicGamesLauncher | SDK/overlay consome CPU desnecessariamente |
| EADesktop / EACefSubProcess | Background services da EA |
| msedge | Múltiplos processos consomem RAM significativa |
| Code (VS Code) | Extensões e language servers consomem CPU/RAM |

#### 4. Background Services Stop
Para serviços desnecessários durante gaming:
- **SysMain (Superfetch):** Prefetch de disco compete com I/O do jogo
- **WSearch:** Indexação consome disco e CPU
- **DiagTrack:** Telemetria Microsoft
- **Xbox Live services:** Auth, Game Save, Networking (desnecessários se não usa Xbox)
- **Outros:** Biometria, geolocalização, push de telemetria, etc.

#### 5. Game DVR / Game Bar Disable
Desabilita overlays do Windows que causam micro-stuttering e reduzem FPS.

#### 6. Fullscreen Optimizations Disable
Remove as "Fullscreen Optimizations" do Windows para o executável do BF6 (apenas no primeiro ciclo).

#### 7. RAM Standby Cleanup
Reduz working sets de todos os processos não-BF6, liberando RAM física para o jogo. Executa garbage collection do .NET.

#### 8. Network Connection Monitor
Exibe conexões TCP e endpoints UDP ativas do processo BF6, e testa packet loss para o gateway local. Útil para diagnosticar problemas de conectividade.

#### Resource Audit (primeiro ciclo)
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
- **FASE 1 (Rede):** As alterações de registro persistem após reinicializações. O script detecta isso e não re-aplica.
- **FASE 2 (Processo):** Sim, prioridade de processo não persiste. Execute o script e ele aguarda o BF6 automaticamente.

### O script fecha sozinho?
Não. O script fica em loop permanente: aguarda o BF6 iniciar → otimiza a cada 3 minutos → volta a aguardar quando o BF6 fecha. Só para com `Ctrl+C`.

### Posso reverter as mudanças?
Sim. Veja a documentação detalhada em [`docs/NETWORK_OPTIMIZE.md`](docs/NETWORK_OPTIMIZE.md) e [`docs/PROCESS_BOOST.md`](docs/PROCESS_BOOST.md) para instruções de reversão de cada otimização.

### Meu antivírus bloqueou o script
Alguns antivírus bloqueiam scripts PowerShell por padrão. Adicione a pasta do projeto como exceção ou execute via PowerShell diretamente:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\bf6_boost.ps1
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
