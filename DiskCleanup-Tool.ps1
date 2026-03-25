#Requires -Version 5.1
<#
.SYNOPSIS
    Disk Cleanup Tool v2.0 — Herramienta unificada de limpieza de disco
.DESCRIPTION
    Script principal con UX avanzada y 3 niveles de experiencia:
    - Básico: Limpieza rápida automática
    - Intermedio: Resumen visual con opciones
    - Avanzado: Control total y comandos
.PARAMETER Mode
    Modo de usuario: 1=Básico, 2=Intermedio, 3=Avanzado
.PARAMETER Auto
    Ejecuta limpieza automática (solo categorías seguras)
.PARAMETER Silent
    Modo silencioso para scripting (sin interacción)
.EXAMPLE
    .\DiskCleanup-Tool.ps1
    .\DiskCleanup-Tool.ps1 -Mode 3
    .\DiskCleanup-Tool.ps1 -Auto
    .\DiskCleanup-Tool.ps1 -Auto -Silent
#>

param(
    [ValidateRange(1,3)][int]$Mode,
    [switch]$Auto,
    [switch]$Silent
)

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Importar módulos
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $ScriptDir "Modules"

try {
    Import-Module (Join-Path $ModulesPath "DiskAnalysis.psm1") -Force
    Import-Module (Join-Path $ModulesPath "DiskCleanup.psm1") -Force
    Import-Module (Join-Path $ModulesPath "UI-Advanced.psm1") -Force
    Import-Module (Join-Path $ModulesPath "Config.psm1") -Force
} catch {
    Write-Host "Error cargando módulos: $_" -ForegroundColor Red
    exit 1
}

# Crear directorios necesarios
$config = Load-Config
$directories = @($config.LogPath, $config.ReportPath, (Split-Path (Get-ConfigPath) -Parent))
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES AUXILIARES
# ═══════════════════════════════════════════════════════════════════════════════

function Get-DiskSummary {
    $driveInfo = Get-DriveInfo
    $categories = Get-CleanableCategories
    $totalCleanable = ($categories | Measure-Object -Property TamanioBytes -Sum).Sum
    $totalCleanableFormatted = Format-FileSize -Bytes $totalCleanable
    
    return @{
        DriveInfo = $driveInfo
        Categories = $categories
        TotalCleanable = $totalCleanable
        TotalCleanableFormatted = $totalCleanableFormatted
    }
}

function Execute-AutoCleanup {
    param([switch]$Silent)
    
    if (-not $Silent) {
        Write-Host "  🔄 Ejecutando limpieza automática..." -ForegroundColor Yellow
    }
    
    $summary = Get-DiskSummary
    $beforeGB = $summary.DriveInfo.FreeGB
    
    Rotate-Logs -LogPath $config.LogPath
    
    $result = Clean-MultipleCategories -Categories $summary.Categories -OnlySafe -LogPath $config.LogPath
    
    $afterDrive = Get-DriveInfo
    $afterGB = $afterDrive.FreeGB
    $freedGB = [math]::Round($afterGB - $beforeGB, 2)
    
    Update-LastRun
    Add-TotalCleaned -BytesCleaned $result.TotalFreedBytes
    
    if (-not $Silent) {
        Show-CleanupSummary -BeforeSize "$beforeGB GB" -AfterSize "$afterGB GB" -FreedSize "$freedGB GB"
    }
    
    Write-Log -Message "LIMPIEZA AUTOMÁTICA COMPLETADA - Liberado: $freedGB GB" -LogPath $config.LogPath
    
    return $result
}

function Show-FullAnalysis {
    $summary = Get-DiskSummary
    
    Show-Header -Title "ANÁLISIS COMPLETO"
    Show-DriveStatus -DriveInfo $summary.DriveInfo
    
    # Categorías limpiables
    Write-Host "  🧹 CATEGORÍAS LIMPIABLES" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $i = 1
    foreach ($cat in ($summary.Categories | Sort-Object TamanioBytes -Descending)) {
        $safeIndicator = if ($cat.SafeForAuto) { "✅" } else { "⚠️" }
        $barWidth = [math]::Min(20, [math]::Floor($cat.TamanioBytes / ($summary.Categories[0].TamanioBytes + 1) * 20))
        $bar = "█" * $barWidth + "░" * (20 - $barWidth)
        
        Write-Host ("  {0,2}. [{1}] {2,-25} {3,10} {4}" -f $i, $bar, $cat.Name, $cat.TamanioFormateado, $safeIndicator) -ForegroundColor White
        $i++
    }
    
    Write-Host ""
    Write-Host "  📦 TOTAL LIMPIABLE: $($summary.TotalCleanableFormatted)" -ForegroundColor Green
    Write-Host ""
    
    # Top carpetas
    Write-Host "  📁 TOP 10 CARPETAS MÁS GRANDES" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $topFolders = Get-TopFolders -TopCount 10
    $i = 1
    foreach ($folder in $topFolders) {
        $barWidth = [math]::Min(20, [math]::Floor($folder.TamanioBytes / ($topFolders[0].TamanioBytes + 1) * 20))
        $bar = "▓" * $barWidth + "░" * (20 - $barWidth)
        
        Write-Host ("  {0,2}. [{1}] {2,10} - {3}" -f $i, $bar, $folder.TamanioFormateado, $folder.Nombre) -ForegroundColor White
        $i++
    }
    
    Write-Host ""
    Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor DarkGray
    if (-not $Silent) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Execute-PersonalizedCleanup {
    $summary = Get-DiskSummary
    
    Show-Header -Title "LIMPIEZA PERSONALIZADA"
    
    Write-Host "  Selecciona las categorías a limpiar:" -ForegroundColor Yellow
    Write-Host "  (números separados por coma, ej: 1,3,5 o rango 1-5)" -ForegroundColor DarkGray
    Write-Host ""
    
    $i = 1
    foreach ($cat in ($summary.Categories | Sort-Object TamanioBytes -Descending)) {
        $safeIndicator = if ($cat.SafeForAuto) { "✅" } else { "⚠️" }
        Write-Host ("  {0,2}. {1,-30} {2,10} {3}" -f $i, $cat.Name, $cat.TamanioFormateado, $safeIndicator) -ForegroundColor White
        $i++
    }
    
    Write-Host ""
    Write-Host "  [A] Seleccionar todos los seguros" -ForegroundColor Green
    Write-Host "  [0] Cancelar" -ForegroundColor Red
    Write-Host ""
    
    $selection = Read-Host "  Selección"
    
    if ($selection -eq "0") { return }
    
    $selectedCategories = @()
    
    if ($selection -eq "A") {
        $selectedCategories = $summary.Categories | Where-Object { $_.SafeForAuto }
    } else {
        # Parsear selección
        $indices = @()
        foreach ($part in $selection -split ",") {
            if ($part -match "(\d+)-(\d+)") {
                $start = [int]$Matches[1]
                $end = [int]$Matches[2]
                $indices += $start..$end
            } elseif ($part -match "\d+") {
                $indices += [int]$part
            }
        }
        
        $sortedCategories = $summary.Categories | Sort-Object TamanioBytes -Descending
        foreach ($idx in $indices) {
            if ($idx -ge 1 -and $idx -le $sortedCategories.Count) {
                $selectedCategories += $sortedCategories[$idx - 1]
            }
        }
    }
    
    if ($selectedCategories.Count -eq 0) {
        Write-Host "  ❌ No se seleccionaron categorías" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "  Categorías seleccionadas:" -ForegroundColor Yellow
    foreach ($cat in $selectedCategories) {
        Write-Host "    • $($cat.Name) - $($cat.TamanioFormateado)" -ForegroundColor White
    }
    
    $totalToClean = ($selectedCategories | Measure-Object -Property TamanioBytes -Sum).Sum
    Write-Host ""
    Write-Host "  📦 Total a limpiar: $(Format-FileSize -Bytes $totalToClean)" -ForegroundColor Green
    Write-Host ""
    
    if (Confirm-Action -Message "¿Proceder con la limpieza?") {
        $beforeGB = (Get-DriveInfo).FreeGB
        
        $result = Clean-MultipleCategories -Categories $selectedCategories -ConfirmEach -LogPath $config.LogPath
        
        $afterGB = (Get-DriveInfo).FreeGB
        $freedGB = [math]::Round($afterGB - $beforeGB, 2)
        
        Update-LastRun
        Add-TotalCleaned -BytesCleaned $result.TotalFreedBytes
        
        Show-CleanupSummary -BeforeSize "$beforeGB GB" -AfterSize "$afterGB GB" -FreedSize "$freedGB GB"
        
        Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# BUCLE PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════

# Modo Auto
if ($Auto) {
    Execute-AutoCleanup -Silent:$Silent
    exit
}

# Modo interactivo
$currentMode = if ($Mode) { $Mode } else { 
    $savedMode = Get-UserMode
    if ($savedMode -eq 2) {
        # Primera ejecución o modo por defecto - preguntar
        Show-ModeSelector
    } else {
        $savedMode
    }
}

Set-UserMode -Mode $currentMode

do {
    Clear-Host
    $summary = Get-DiskSummary
    
    $selection = switch ($currentMode) {
        1 { Show-MenuBasic -DriveInfo $summary.DriveInfo -TotalCleanable $summary.TotalCleanableFormatted }
        2 { Show-MenuIntermediate -DriveInfo $summary.DriveInfo -Categories $summary.Categories }
        3 { Show-MenuAdvanced -DriveInfo $summary.DriveInfo -Categories $summary.Categories }
    }
    
    switch ($selection) {
        # Comunes
        "Q" { break }
        "0" { break }
        "H" { Show-Help -Mode (Get-ModeName -Mode $currentMode) }
        "M" { 
            $newMode = Show-ModeSelector
            Set-UserMode -Mode $newMode
            $currentMode = $newMode
        }
        "R" { continue }
        
        # Básico
        "L" { 
            Execute-AutoCleanup
            Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "V" { Show-FullAnalysis }
        "S" { break }
        
        # Intermedio
        "1" { 
            Execute-AutoCleanup
            Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" { Execute-PersonalizedCleanup }
        "3" { Show-FullAnalysis }
        "4" { 
            Write-Host "  📥 Gestionar descargas - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "5" { 
            Write-Host "  📁 Explorar carpetas - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "6" { 
            Write-Host "  ⚙️ Configuración - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        
        # Avanzado
        "A" { 
            Execute-AutoCleanup
            Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "C" { 
            Write-Host "  🔍 Custom scan - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "E" { 
            Write-Host "  📄 Export report - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "S" { 
            Write-Host "  📅 Schedule task - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "D" { 
            Write-Host "  🔬 Deep scan - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        "X" { 
            Write-Host "  🛠️ Expert mode - Próximamente" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        
        # Selección numérica en modo avanzado
        default {
            if ($selection -match "^\d+$") {
                $num = [int]$selection
                if ($num -ge 1 -and $num -le $summary.Categories.Count) {
                    $selectedCat = $summary.Categories | Where-Object { $_.Id -eq $num }
                    if ($selectedCat) {
                        Write-Host ""
                        Write-Host "  Limpiando: $($selectedCat.Name)" -ForegroundColor Cyan
                        foreach ($path in $selectedCat.Paths) {
                            $result = Clean-Folder -Path $path -Description $selectedCat.Name -MinAgeDays $selectedCat.MinAgeDays -Confirm -LogPath $config.LogPath
                            if ($result.Success) {
                                Write-Host "  ✅ $($result.Message)" -ForegroundColor Green
                            }
                        }
                        Update-LastRun
                        Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor DarkGray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                }
            }
        }
    }
    
} while ($selection -notin @("Q", "0", "S"))

Write-Host ""
Write-Host "  ¡Hasta luego! 👋" -ForegroundColor Cyan
Write-Host ""