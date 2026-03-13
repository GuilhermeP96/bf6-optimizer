@echo off
:: Solicita elevacao de privilegio automaticamente
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo ============================================
echo  BF6 FULL BOOST - Rede + Processo + GPU
echo ============================================
echo.

echo [FASE 1] Aplicando otimizacoes de rede...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\bf6_network_optimize.ps1"

echo.
echo [FASE 2] Aplicando otimizacoes de processo e GPU...
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\bf6_process_boost.ps1"
