@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM Setup-ScheduledTask.bat
REM Configura la tarea programada para mantenimiento diario de disco
REM REQUIERE ejecución como Administrador
REM ═══════════════════════════════════════════════════════════════════════════════

title Configurar Tarea Programada - Disk Cleanup Tool
color 0A

echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║     CONFIGURADOR DE TAREA PROGRAMADA - Disk Cleanup Tool      ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM Verificar permisos de administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    color 0C
    echo [ERROR] Este script requiere permisos de Administrador.
    echo.
    echo Por favor, haz clic derecho en este archivo y selecciona
    echo "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

echo [OK] Ejecutando como Administrador
echo.

REM Definir rutas
set "SCRIPT_DIR=%~dp0"
set "MAINTENANCE_SCRIPT=%SCRIPT_DIR%Maintenance.ps1"
set "TASK_NAME=DailyDiskMaintenance"

REM Verificar que existe el script de mantenimiento
if not exist "%MAINTENANCE_SCRIPT%" (
    color 0C
    echo [ERROR] No se encuentra Maintenance.ps1 en: %SCRIPT_DIR%
    echo.
    pause
    exit /b 1
)

echo [OK] Script encontrado: %MAINTENANCE_SCRIPT%
echo.

REM Configurar política de ejecución de PowerShell
echo [1/4] Configurando política de ejecución de PowerShell...
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" 2>nul
echo [OK] Política configurada
echo.

REM Crear carpeta de trabajo
echo [2/4] Creando estructura de carpetas...
if not exist "C:\DiskCleanup" mkdir "C:\DiskCleanup"
if not exist "C:\DiskCleanup\Logs" mkdir "C:\DiskCleanup\Logs"
if not exist "C:\DiskCleanup\Reports" mkdir "C:\DiskCleanup\Reports"
echo [OK] Carpetas creadas en C:\DiskCleanup
echo.

REM Verificar si la tarea ya existe
echo [3/4] Verificando tarea existente...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %errorLevel% equ 0 (
    echo [AVISO] La tarea "%TASK_NAME%" ya existe.
    echo.
    set /p "REPLACE=¿Deseas reemplazarla? (S/N): "
    if /i "%REPLACE%" neq "S" (
        echo Operación cancelada.
        pause
        exit /b 0
    )
    echo Eliminando tarea anterior...
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)
echo.

REM Crear la tarea programada
echo [4/4] Creando tarea programada...
echo.
echo Configuración:
echo   - Nombre: %TASK_NAME%
echo   - Frecuencia: Diaria
echo   - Hora: 03:00 AM
echo   - Script: %MAINTENANCE_SCRIPT%
echo.

schtasks /create ^
    /tn "%TASK_NAME%" ^
    /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%MAINTENANCE_SCRIPT%\"" ^
    /sc daily ^
    /st 03:00 ^
    /ru SYSTEM ^
    /rl HIGHEST ^
    /f

if %errorLevel% equ 0 (
    echo.
    color 0A
    echo ╔════════════════════════════════════════════════════════════════╗
    echo ║                    ✅ CONFIGURACIÓN EXITOSA                   ║
    echo ╚════════════════════════════════════════════════════════════════╝
    echo.
    echo La tarea programada se ha creado correctamente.
    echo.
    echo Detalles:
    echo   • Nombre: %TASK_NAME%
    echo   • Se ejecutará todos los días a las 3:00 AM
    echo   • Ejecutará: %MAINTENANCE_SCRIPT%
    echo   • Los logs se guardan en: C:\DiskCleanup\Logs\
    echo.
    echo Para verificar la tarea, ejecuta:
    echo   schtasks /query /tn "%TASK_NAME%"
    echo.
    echo Para ejecutar manualmente ahora:
    echo   schtasks /run /tn "%TASK_NAME%"
    echo.
    
    set /p "RUN_NOW=¿Deseas ejecutar el mantenimiento ahora? (S/N): "
    if /i "%RUN_NOW%" equ "S" (
        echo.
        echo Ejecutando mantenimiento...
        powershell -ExecutionPolicy Bypass -File "%MAINTENANCE_SCRIPT%"
        echo.
        echo Mantenimiento completado. Revisa los logs en C:\DiskCleanup\Logs\
    )
) else (
    echo.
    color 0C
    echo ╔════════════════════════════════════════════════════════════════╗
    echo ║                      ❌ ERROR AL CREAR TAREA                  ║
    echo ╚════════════════════════════════════════════════════════════════╝
    echo.
    echo No se pudo crear la tarea programada.
    echo Verifica que tengas permisos de administrador.
    echo.
)

echo.
echo Presiona cualquier tecla para salir...
pause >nul