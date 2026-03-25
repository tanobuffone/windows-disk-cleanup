#Requires -Version 5.1
<#
.SYNOPSIS
    Herramienta interactiva para limpiar espacio en disco C:
.DESCRIPTION
    Permite seleccionar qué categorías de archivos limpiar de forma interactiva.
    Muestra el espacio estimado antes de cada operación y genera logs.
.PARAMETER Auto
    Ejecuta limpieza automática de categorías seguras sin interacción
.PARAMETER LogPath
    Carpeta donde guardar los logs de limpieza
.EXAMPLE
    .\Clean-Disk.ps1
    .\Clean-Disk.ps1 -Auto
#>

param(
    [switch]$Auto,
    [string]$LogPath = "C:\DiskCleanup\Logs"
)

# CONFIGURACIÓN
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Crear carpetas necesarias
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $LogPath "cleanup-$timestamp.txt"

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
    Write-Host $Message -ForegroundColor Gray
}

function Clean-Folder {
    param(
        [string]$Path,
        [string]$Description,
        [int]$MinAgeDays = 0,
        [switch]$Confirm
    )
    
    if (-not (Test-Path $Path)) {
        Write-Host "  ⚠️ Ruta no existe: $Path" -ForegroundColor Yellow
        return 0
    }
    
    try {
        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($MinAgeDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$MinAgeDays)
            $items = $items | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        }
        
        $totalSize = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $totalSize = [long]($totalSize ?? 0)
        
        if ($totalSize -eq 0) {
            Write-Host "  ✅ $Description - Nada que limpiar" -ForegroundColor Green
            return 0
        }
        
        $sizeFormatted = Format-FileSize -Bytes $totalSize
        Write-Host "  📦 $Description - $sizeFormatted encontrados" -ForegroundColor White
        
        if ($Confirm) {
            $response = Read-Host "  ¿Eliminar? (S/N)"
            if ($response -ne "S" -and $response -ne "s") {
                Write-Log "CANCELADO: $Description ($sizeFormatted)"
                return 0
            }
        }
        
        $deletedCount = 0
        $deletedSize = 0
        
        foreach ($item in $items) {
            try {
                $itemSize = if ($item.PSIsContainer) { 0 } else { $item.Length }
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedCount++
                $deletedSize += $itemSize
            } catch {
                # Ignorar errores de archivos en uso
            }
        }
        
        $deletedFormatted = Format-FileSize -Bytes $deletedSize
        Write-Log "LIMPIADO: $Description - $deletedCount elementos, $deletedFormatted liberados"
        Write-Host "  ✅ Eliminado: $deletedFormatted" -ForegroundColor Green
        
        return $deletedSize
        
    } catch {
        Write-Host "  ❌ Error en $Description: $_" -ForegroundColor Red
        Write-Log "ERROR: $Description - $_"
        return 0
    }
}

# CATEGORÍAS DE LIMPIEZA
$CleanupCategories = @(
    @{
        Id = 1
        Name = "🗑️ Archivos temporales de usuario"
        Paths = @("$env:TEMP")
        MinAgeDays = 7
        SafeForAuto = $true
    },
    @{
        Id = 2
        Name = "🗑️ Archivos temporales de Windows"
        Paths = @("$env:SystemRoot\Temp")
        MinAgeDays = 7
        SafeForAuto = $true
    },
    @{
        Id = 3
        Name = "🌐 Caché de Chrome"
        Paths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
        )
        MinAgeDays = 0
        SafeForAuto = $true
    },
    @{
        Id = 4
        Name = "🌐 Caché de Edge"
        Paths = @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        )
        MinAgeDays = 0
        SafeForAuto = $true
    },
    @{
        Id = 5
        Name = "🌐 Caché de Firefox"
        Paths = @("$env:LOCALAPPDATA\Mozilla\Firefox\Profiles")
        MinAgeDays = 0
        SafeForAuto = $true
    },
    @{
        Id = 6
        Name = "📥 Descargas (>30 días)"
        Paths = @("$env:USERPROFILE\Downloads")
        MinAgeDays = 30
        SafeForAuto = $false
    },
    @{
        Id = 7
        Name = "🗑️ Papelera de reciclaje"
        Paths = @("C:\`$Recycle.Bin")
        MinAgeDays = 0
        SafeForAuto = $true
    },
    @{
        Id = 8
        Name = "📋 Logs antiguos (>7 días)"
        Paths = @(
            "$env:SystemRoot\Logs",
            "$env:LOCALAPPDATA\CrashDumps"
        )
        MinAgeDays = 7
        SafeForAuto = $true
    },
    @{
        Id = 9
        Name = "🔄 Caché Windows Update"
        Paths = @("$env:SystemRoot\SoftwareDistribution\Download")
        MinAgeDays = 0
        SafeForAuto = $true
    },
    @{
        Id = 10
        Name = "📊 Informes de errores (WER)"
        Paths = @("$env:ProgramData\Microsoft\Windows\WER")
        MinAgeDays = 7
        SafeForAuto = $true
    },
    @{
        Id = 11
        Name = "⚡ Prefetch"
        Paths = @("$env:SystemRoot\Prefetch")
        MinAgeDays = 30
        SafeForAuto = $true
    }
)

# ENCABEZADO
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           LIMPIEZA DE DISCO C: - Disk Cleanup Tool            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Info del disco antes
$drive = Get-PSDrive C
$freeBeforeGB = [math]::Round($drive.Free / 1GB, 2)
Write-Host "  💾 Espacio libre antes: $freeBeforeGB GB" -ForegroundColor White
Write-Host "  📝 Log: $logFile" -ForegroundColor Gray
Write-Host ""

Write-Log "=== INICIO DE LIMPIEZA ==="
Write-Log "Espacio libre inicial: $freeBeforeGB GB"

# MODO AUTOMÁTICO
if ($Auto) {
    Write-Host "🔄 MODO AUTOMÁTICO - Limpiando categorías seguras..." -ForegroundColor Yellow
    Write-Host ""
    
    $totalFreed = 0
    
    foreach ($category in $CleanupCategories) {
        if ($category.SafeForAuto) {
            Write-Host "  Procesando: $($category.Name)" -ForegroundColor Cyan
            
            foreach ($path in $category.Paths) {
                $freed = Clean-Folder -Path $path -Description $category.Name -MinAgeDays $category.MinAgeDays
                $totalFreed += $freed
            }
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "✅ LIMPIEZA AUTOMÁTICA COMPLETADA" -ForegroundColor Green
    Write-Host "   Espacio liberado: $(Format-FileSize -Bytes $totalFreed)" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Log "=== FIN DE LIMPIEZA AUTOMÁTICA - Liberado: $(Format-FileSize -Bytes $totalFreed) ==="
    exit
}

# MODO INTERACTIVO
do {
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "📋 MENÚ DE LIMPIEZA" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($category in $CleanupCategories) {
        $totalSize = 0
        foreach ($path in $category.Paths) {
            $totalSize += Get-FolderSize -Path $path
        }
        $sizeFormatted = Format-FileSize -Bytes $totalSize
        
        if ($totalSize -gt 0) {
            Write-Host ("  {0,2}. {1,-40} [{2}]" -f $category.Id, $category.Name, $sizeFormatted) -ForegroundColor White
        } else {
            Write-Host ("  {0,2}. {1,-40} [Vacío]" -f $category.Id, $category.Name) -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "  99. 🧹 Limpiar TODO lo anterior (con confirmación)" -ForegroundColor Yellow
    Write-Host "  0.  ❌ Salir" -ForegroundColor Red
    Write-Host ""
    
    $selection = Read-Host "Selecciona una opción (número)"
    
    if ($selection -eq "0") {
        break
    }
    
    if ($selection -eq "99") {
        Write-Host ""
        Write-Host "⚠️ ATENCIÓN: Se eliminarán archivos de TODAS las categorías" -ForegroundColor Yellow
        Write-Host "   excepto descargas recientes." -ForegroundColor Yellow
        $confirm = Read-Host "¿Continuar? (S/N)"
        
        if ($confirm -eq "S" -or $confirm -eq "s") {
            $totalFreed = 0
            foreach ($category in $CleanupCategories) {
                if ($category.SafeForAuto) {
                    foreach ($path in $category.Paths) {
                        $freed = Clean-Folder -Path $path -Description $category.Name -MinAgeDays $category.MinAgeDays
                        $totalFreed += $freed
                    }
                }
            }
            Write-Host ""
            Write-Host "  ✅ Total liberado: $(Format-FileSize -Bytes $totalFreed)" -ForegroundColor Green
            Write-Log "LIMPIEZA COMPLETA: $(Format-FileSize -Bytes $totalFreed) liberados"
        }
        continue
    }
    
    # Buscar categoría seleccionada
    $selectedCategory = $CleanupCategories | Where-Object { $_.Id -eq $selection }
    
    if ($selectedCategory) {
        Write-Host ""
        Write-Host "  Procesando: $($selectedCategory.Name)" -ForegroundColor Cyan
        
        foreach ($path in $selectedCategory.Paths) {
            Clean-Folder -Path $path -Description $selectedCategory.Name -MinAgeDays $selectedCategory.MinAgeDays -Confirm
        }
    } else {
        Write-Host "  ❌ Opción no válida" -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "Presiona Enter para continuar"
    
} while ($true)

# RESUMEN FINAL
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$driveAfter = Get-PSDrive C
$freeAfterGB = [math]::Round($driveAfter.Free / 1GB, 2)
$freedGB = [math]::Round($freeAfterGB - $freeBeforeGB, 2)

Write-Host "📊 RESUMEN DE LIMPIEZA" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Espacio libre antes:  $freeBeforeGB GB" -ForegroundColor White
Write-Host "  Espacio libre después: $freeAfterGB GB" -ForegroundColor Green
Write-Host "  Total liberado:       $freedGB GB" -ForegroundColor Green
Write-Host ""
Write-Host "  📝 Log guardado en: $logFile" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Log "=== FIN DE LIMPIEZA - Liberado: $freedGB GB ==="