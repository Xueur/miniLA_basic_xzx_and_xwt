@echo off
setlocal
cd /d "%~dp0"
py -3 bin2coe.py software\trace\start.bin
if errorlevel 1 (
    echo Trace image conversion failed.
    exit /b 1
)
echo Trace image is ready.
