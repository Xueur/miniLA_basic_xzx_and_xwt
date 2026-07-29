@echo off
setlocal
cd /d "%~dp0"

set "VIVADO_CMD="
for /f "delims=" %%V in ('where vivado.bat 2^>nul') do (
    if not defined VIVADO_CMD set "VIVADO_CMD=%%V"
)
if not defined VIVADO_CMD if exist "C:\Xilinx\Vivado\2023.2\bin\vivado.bat" set "VIVADO_CMD=C:\Xilinx\Vivado\2023.2\bin\vivado.bat"
if not defined VIVADO_CMD if exist "D:\Xilinx\Vivado\2023.2\bin\vivado.bat" set "VIVADO_CMD=D:\Xilinx\Vivado\2023.2\bin\vivado.bat"
if not defined VIVADO_CMD if exist "C:\AMD\Vivado\2023.2\bin\vivado.bat" set "VIVADO_CMD=C:\AMD\Vivado\2023.2\bin\vivado.bat"
if not defined VIVADO_CMD if exist "D:\AMD\Vivado\2023.2\bin\vivado.bat" set "VIVADO_CMD=D:\AMD\Vivado\2023.2\bin\vivado.bat"

if not defined VIVADO_CMD (
    echo Vivado 2023.2 was not found.
    pause
    exit /b 1
)

set "XPR=%~dp0vivado_coremark_board_50MHz\miniRV_coremark_board_50MHz.xpr"
if not exist "%XPR%" (
    call "%VIVADO_CMD%" -mode batch -notrace -source create_coremark_board_project.tcl
    if errorlevel 1 (
        echo Project creation failed.
        pause
        exit /b 1
    )
)

call "%VIVADO_CMD%" -mode batch -notrace -source build_coremark_board_bitstream.tcl
if errorlevel 1 (
    echo Build or timing validation failed.
    echo Check reports\coremark_board_50MHz and the messages above.
    pause
    exit /b 1
)

echo.
echo CoreMark 50 MHz timing passed. The bitstream and reports are ready.
echo Bitstream: output\miniRV_coremark_board_50MHz.bit
echo Timing:   reports\coremark_board_50MHz\timing_summary_PASS.rpt
echo.
start "" "%XPR%"
pause
exit /b 0
