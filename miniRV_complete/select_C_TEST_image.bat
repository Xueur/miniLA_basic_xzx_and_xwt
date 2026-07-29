@echo off
setlocal
cd /d "%~dp0"

set "TEST_ID=%~1"
if not defined TEST_ID (
    echo 0=UART  1=formatIO  2=sort  3=DDR  4=CoreMark
    set /p "TEST_ID=Select test number: "
)
if not defined TEST_ID (
    echo No test selected.
    pause
    exit /b 2
)

set "PYTHON_CMD="
where py >nul 2>nul && set "PYTHON_CMD=py -3"
if not defined PYTHON_CMD (
    where python >nul 2>nul && set "PYTHON_CMD=python"
)
if not defined PYTHON_CMD (
    echo Python 3 was not found.
    pause
    exit /b 1
)

%PYTHON_CMD% tools\select_c_test_image.py %TEST_ID%
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo The active program image is ready.
echo Now run build_C_TEST_50MHz_bitstream_and_reports.bat.
pause
