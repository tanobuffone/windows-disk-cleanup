#Requires -Version 5.1
<#
.SYNOPSIS
    Script de mantenimiento diario automático para disco C:
.DESCRIPTION
    Ejecuta limpieza automática de categorías seguras.
    Diseñado para ejecutarse como tarea programada.
    NO elimina archivos del usuario sin confirmación.
.PARAMETER LogPath
    Carpeta donde guardar los logs
.PARAMETER AlertThresholdPercent
    Porcentaje de espacio libre que activa alerta (default: 10)
.EXAMPLE
    .\Maintenance.ps1
    .\Maintenance.ps1 -AlertThresholdPercent 15
#>

param(
    [string]$LogPath = "C:\DiskCleanup\Logs",
    [int]$AlertThresholdPercent = 10
)

# CONFIGURACIÓN
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Crear carpetas
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $LogPath "maintenance-$timestamp.txt"

# FUNCIONES AUXILIARES
function Format-FileSize {
    param([long]$Bytes)
    switch ($Bytes) {
        { $_ -ge 1TB } { "{0:N2} TB" -f ($_ / 1TB); break }
        { $_ -ge 1GB } { "{0:N2} GB" -f ($_ / 1GB); break }
        { $_ -ge 1MB } { "{0:N2} MB" -f ($_ / 1MB); break }
        { $_ -ge 1KB } { "{0:N2} KB" -f ($_ / 1KB); break }
        default { "{0} Bytes" -f $_ }
    }
}

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [long]($size ?? 0)
    } catch { return 0 }
}

function Write-Log {
    param([string]$Message)
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $logEntry
}

function Clean-Safe {
    param(
        [string]$Path,
        [string]$Description,
        [int]$MinAgeDays = 0
    )
    
    if (-not (Test-Path $Path)) { return 0 }
    
    try {
        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($MinAgeDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$MinAgeDays)
            $items = $items | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        }
        
        $totalSize = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $totalSize = [long]($totalSize ?? 0)
        
        if ($totalSize -eq 0) { return 0 }
        
        $deletedSize = 0
        
        foreach ($item in $items) {
            try {
                $itemSize = if ($item.PSIsContainer) { 0 } else { $item.Length }
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedSize += $itemSize
            } catch {
                # Ignorar archivos en uso
            }
        }
        
        Write-Log "LIMPIADO: $Description - $(Format-FileSize -Bytes $deletedSize) liberados"
        return $deletedSize
        
    } catch {
        Write-Log "ERROR: $Description - $_"
        return 0
    }
}

# ROTACIÓN DE LOGS (mantener solo 30 días)
function Rotate-Logs {
    $cutoffDate = (Get-Date).AddDays(-30)
    $oldLogs = Get-ChildItem -Path $LogPath -Filter "*.txt" -ErrorAction SilentlyContinue | 
               Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($log in $oldLogs) {
        Remove-Item -Path $log.FullName -Force -ErrorAction SilentlyContinue
    }
    
    if ($oldLogs.Count -gt 0) {
        Write-Log "ROTACIÓN: Eliminados $($oldLogs.Count) logs antiguos"
    }
}

# INICIO
Write-Log "=== INICIO MANTENIMIENTO DIARIO ==="

# Info del disco
$drive = Get-PSDrive C
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$totalGB = [math]::Round($drive.Used / 1GB + $drive.Free / 1GB, 2)
$usedPercent = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 1)
$freePercent = 100 - $usedPercent

Write-Log "Disco: $totalGB GB total, $freeGB GB libre ($freePercent%)"

# ROTAR LOGS
Rotate-Logs

# CATEGORÍAS DE LIMPIEZA SEGURA
$cleanupTasks = @(
    @{
        Name = "Temporales usuario (>7 días)"
        Path = "$env:TEMP"
        MinAgeDays = 7
    },
    @{
        Name = "Temporales Windows (>7 días)"
        Path = "$env:SystemRoot\Temp"
        MinAgeDays = 7
    },
    @{
        Name = "Caché Chrome"
        Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        MinAgeDays = 0
    },
    @{
        Name = "Caché Chrome Code"
        Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        MinAgeDays = 0
    },
    @{
        Name = "Caché Chrome GPU"
        Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
        MinAgeDays = 0
    },
    @{
        Name = "Caché Edge"
        Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        MinAgeDays = 0
    },
    @{
        Name = "Caché Edge Code"
        Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        MinAgeDays = 0
    },
    @{
        Name = "Caché Firefox"
        Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
        MinAgeDays = 0
    },
    @{
        Name = "Papelera de reciclaje"
        Path = "C:\`$Recycle.Bin"
        MinAgeDays = 0
    },
    @{
        Name = "Logs Windows (>7 días)"
        Path = "$env:SystemRoot\Logs"
        MinAgeDays = 7
    },
    @{
        Name = "CrashDumps (>7 días)"
        Path = "$env:LOCALAPPDATA\CrashDumps"
        MinAgeDays = 7
    },
    @{
        Name = "Caché Windows Update"
        Path = "$env:SystemRoot\SoftwareDistribution\Download"
        MinAgeDays = 0
    },
    @{
        Name = "WER Reportes (>7 días)"
        Path = "$env:ProgramData\Microsoft\Windows\WER"
        MinAgeDays = 7
    },
    @{
        Name = "Prefetch (>30 días)"
        Path = "$env:SystemRoot\Prefetch"
        MinAgeDays = 30
    }
)

# EJECUTAR LIMPIEZA
$totalFreed = 0

foreach ($task in $cleanupTasks) {
    $freed = Clean-Safe -Path $task.Path -Description $task.Name -MinAgeDays $task.MinAgeDays
    $totalFreed += $freed
}

# RESUMEN
Write-Log "Total liberado: $(Format-FileSize -Bytes $totalFreed)"

# VERIFICAR ALERTA DE ESPACIO
$driveAfter = Get-PSDrive C
$freePercentAfter = [math]::Round(($driveAfter.Free / ($driveAfter.Used + $driveAfter.Free)) * 100, 1)

if ($freePercentAfter -lt $AlertThresholdPercent) {
    $alertMsg = "ALERTA: Espacio libre crítico: $freePercentAfter% (umbral: $AlertThresholdPercent%)"
    Write-Log $alertMsg
    
    # Intentar escribir evento en Windows Event Log
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("DiskCleanupTool")) {
            New-EventLog -LogName Application -Source "DiskCleanupTool" -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source "DiskCleanupTool" -EventId 1001 -EntryType Warning -Message $alertMsg -ErrorAction SilentlyContinue
    } catch {
        # Ignorar si no se puede escribir al Event Log
    }
}

# REPORTE FINAL
$freeGBAfter = [math]::Round($driveAfter.Free / 1GB, 2)
Write-Log "Espacio libre final: $freeGBAfter GB ($freePercentAfter%)"
Write-Log "=== FIN MANTENIMIENTO DIARIO ==="

# CREAR REPORTE RESUMIDO
$reportPath = Join-Path $LogPath "maintenance-summary-$(Get-Date -Format 'yyyy-MM-dd').txt"
$reportContent = @"
=== REPORTE MANTENIMIENTO DIARIO ===
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Espacio libre inicial: $freeGB GB ($freePercent%)
Espacio liberado: $(Format-FileSize -Bytes $totalFreed)
Espacio libre final: $freeGBAfter GB ($freePercentAfter%)
Estado: $(if ($freePercentAfter -lt $AlertThresholdPercent) { "⚠️ CRÍTICO" } else { "✅ OK" })
=====================================
"@

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8 -Force