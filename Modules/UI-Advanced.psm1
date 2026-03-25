#Requires -Version 5.1
<#
.SYNOPSIS
    Módulo de UI avanzada con 3 niveles de experiencia
.DESCRIPTION
    Sistema de interfaz de usuario con niveles básico, intermedio y avanzado.
#>

# Configuración de colores
$Script:Colors = @{
    Primary = "Cyan"
    Secondary = "Yellow"
    Success = "Green"
    Warning = "Yellow"
    Danger = "Red"
    Info = "Gray"
    Highlight = "White"
    Dim = "DarkGray"
}

function Show-Header {
    param(
        [string]$Title = "DISK CLEANUP TOOL",
        [string]$Version = "v2.0",
        [string]$Mode = ""
    )
    
    $modeLabel = if ($Mode) { "  [$Mode]" } else { "" }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor $Script:Colors.Primary
    Write-Host "║  💾 $Title $Version$modeLabel" -ForegroundColor $Script:Colors.Primary
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor $Script:Colors.Primary
    Write-Host ""
}

function Show-DriveStatus {
    param(
        [PSCustomObject]$DriveInfo
    )
    
    $statusIcon = if ($DriveInfo.PercentUsed -gt 80) { "⚠️" } elseif ($DriveInfo.PercentUsed -gt 60) { "⚡" } else { "✅" }
    $barColor = if ($DriveInfo.PercentUsed -gt 80) { $Script:Colors.Danger } elseif ($DriveInfo.PercentUsed -gt 60) { $Script:Colors.Warning } else { $Script:Colors.Success }
    
    $barLength = 40
    $filledLength = [math]::Floor($barLength * $DriveInfo.PercentUsed / 100)
    $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
    
    Write-Host "  💾 Disco $($DriveInfo.Letter): $($DriveInfo.TotalGB) GB" -ForegroundColor $Script:Colors.Highlight
    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor $Script:Colors.Dim
    Write-Host "  │ [$bar] $statusIcon $($DriveInfo.PercentUsed)% usado" -ForegroundColor $barColor
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor $Script:Colors.Dim
    Write-Host "     Usado: $($DriveInfo.UsedGB) GB  │  Libre: $($DriveInfo.FreeGB) GB ($($DriveInfo.PercentFree)%)" -ForegroundColor $Script:Colors.Info
    Write-Host ""
}

function Show-MenuBasic {
    param(
        [PSCustomObject]$DriveInfo,
        [string]$TotalCleanable
    )
    
    Show-Header -Mode "Básico"
    Show-DriveStatus -DriveInfo $DriveInfo
    
    Write-Host "  🧹 LIMPIAR AHORA" -ForegroundColor $Script:Colors.Success
    Write-Host "     Elimina archivos seguros automáticamente" -ForegroundColor $Script:Colors.Info
    Write-Host "     Estimado: ~$TotalCleanable" -ForegroundColor $Script:Colors.Secondary
    Write-Host ""
    Write-Host "  📊 VER ANÁLISIS" -ForegroundColor $Script:Colors.Primary
    Write-Host "     Muestra qué ocupa espacio en tu disco" -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  ⚙️ MÁS OPCIONES" -ForegroundColor $Script:Colors.Secondary
    Write-Host "     Cambiar a modo Intermedio o Avanzado" -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  ❌ SALIR" -ForegroundColor $Script:Colors.Danger
    Write-Host ""
    
    $validOptions = @("L", "V", "M", "S", "Q")
    do {
        Write-Host "  Selección [L/V/M/S/Q]: " -NoNewline -ForegroundColor $Script:Colors.Highlight
        $selection = (Read-Host).ToUpper()
    } while ($selection -notin $validOptions)
    
    return $selection
}

function Show-MenuIntermediate {
    param(
        [PSCustomObject]$DriveInfo,
        [PSCustomObject[]]$Categories
    )
    
    Show-Header -Mode "Intermedio"
    Show-DriveStatus -DriveInfo $DriveInfo
    
    Write-Host "  📊 RESUMEN RÁPIDO" -ForegroundColor $Script:Colors.Secondary
    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor $Script:Colors.Dim
    Write-Host "  │ CATEGORÍA              TAMAÑO      SEGURIDAD           │" -ForegroundColor $Script:Colors.Highlight
    Write-Host "  ├─────────────────────────────────────────────────────────┤" -ForegroundColor $Script:Colors.Dim
    
    foreach ($cat in ($Categories | Sort-Object TamanioBytes -Descending | Select-Object -First 8)) {
        $safeIndicator = if ($cat.SafeForAuto) { "✅ Seguro" } else { "⚠️ Revisar" }
        $safeColor = if ($cat.SafeForAuto) { $Script:Colors.Success } else { $Script:Colors.Warning }
        Write-Host ("  │ {0,-22} {1,10}  {2,-15} │" -f $cat.Name, $cat.TamanioFormateado, $safeIndicator) -ForegroundColor $Script:Colors.Info
    }
    
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor $Script:Colors.Dim
    Write-Host ""
    Write-Host "  [1] 🧹 Limpieza rápida (solo seguros)" -ForegroundColor $Script:Colors.Success
    Write-Host "  [2] 🧹 Limpieza personalizada" -ForegroundColor $Script:Colors.Primary
    Write-Host "  [3] 📊 Análisis detallado + reporte" -ForegroundColor $Script:Colors.Primary
    Write-Host "  [4] 📥 Gestionar descargas" -ForegroundColor $Script:Colors.Secondary
    Write-Host "  [5] 📁 Explorar carpetas grandes" -ForegroundColor $Script:Colors.Secondary
    Write-Host "  [6] ⚙️ Configuración" -ForegroundColor $Script:Colors.Secondary
    Write-Host "  [H] Ayuda  [M] Cambiar modo" -ForegroundColor $Script:Colors.Info
    Write-Host "  [0] ❌ Salir" -ForegroundColor $Script:Colors.Danger
    Write-Host ""
    
    $validOptions = @("1", "2", "3", "4", "5", "6", "H", "M", "0", "Q")
    do {
        Write-Host "  Selección: " -NoNewline -ForegroundColor $Script:Colors.Highlight
        $selection = (Read-Host).ToUpper()
    } while ($selection -notin $validOptions)
    
    return $selection
}

function Show-MenuAdvanced {
    param(
        [PSCustomObject]$DriveInfo,
        [PSCustomObject[]]$Categories
    )
    
    Show-Header -Mode "Avanzado"
    Show-DriveStatus -DriveInfo $DriveInfo
    
    Write-Host "  📊 ANÁLISIS COMPLETO" -ForegroundColor $Script:Colors.Secondary
    Write-Host "  ┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor $Script:Colors.Dim
    Write-Host "  │  #  CATEGORÍA                TAMAÑO      EDAD   SEGURIDAD          │" -ForegroundColor $Script:Colors.Highlight
    Write-Host "  ├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor $Script:Colors.Dim
    
    foreach ($cat in $Categories) {
        $ageLabel = if ($cat.MinAgeDays -gt 0) { "$($cat.MinAgeDays)d+" } else { "Any " }
        $safeIndicator = if ($cat.SafeForAuto) { "████████░░" } else { "████░░░░░░" }
        Write-Host ("  │ {0,2}. {1,-24} {2,10}  {3,5}  {4,-16} │" -f $cat.Id, $cat.Name, $cat.TamanioFormateado, $ageLabel, $safeIndicator) -ForegroundColor $Script:Colors.Info
    }
    
    Write-Host "  └─────────────────────────────────────────────────────────────────────┘" -ForegroundColor $Script:Colors.Dim
    Write-Host ""
    Write-Host "  COMANDOS:" -ForegroundColor $Script:Colors.Secondary
    Write-Host "  [1-$($Categories.Count)] Liminar categoría    [A] Limpiar seguros    [C] Custom scan" -ForegroundColor $Script:Colors.Info
    Write-Host "  [E] Export report    [S] Schedule task    [R] Refresh    [D] Deep scan" -ForegroundColor $Script:Colors.Info
    Write-Host "  [X] Expert mode    [H] Help    [M] Cambiar modo    [Q] Quit" -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  Selección: " -NoNewline -ForegroundColor $Script:Colors.Highlight
    $selection = (Read-Host).ToUpper()
    
    return $selection
}

function Show-CleanupSummary {
    param(
        [string]$BeforeSize,
        [string]$AfterSize,
        [string]$FreedSize
    )
    
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════════╗" -ForegroundColor $Script:Colors.Success
    Write-Host "  ║                    ✅ LIMPIEZA COMPLETADA                      ║" -ForegroundColor $Script:Colors.Success
    Write-Host "  ╚════════════════════════════════════════════════════════════════╝" -ForegroundColor $Script:Colors.Success
    Write-Host ""
    Write-Host "  📊 Resultados:" -ForegroundColor $Script:Colors.Secondary
    Write-Host "     Espacio libre antes:  $BeforeSize" -ForegroundColor $Script:Colors.Info
    Write-Host "     Espacio libre después: $AfterSize" -ForegroundColor $Script:Colors.Success
    Write-Host "     Total liberado:       $FreedSize" -ForegroundColor $Script:Colors.Success
    Write-Host ""
}

function Show-ProgressBar {
    param(
        [int]$Percent,
        [string]$Label = "",
        [int]$Width = 40
    )
    
    $filledLength = [math]::Floor($Width * $Percent / 100)
    $bar = "█" * $filledLength + "░" * ($Width - $filledLength)
    
    $color = if ($Percent -gt 80) { $Script:Colors.Danger } elseif ($Percent -gt 50) { $Script:Colors.Warning } else { $Script:Colors.Success }
    
    if ($Label) {
        Write-Host "  $Label [$bar] $Percent%" -ForegroundColor $color
    } else {
        Write-Host "  [$bar] $Percent%" -ForegroundColor $color
    }
}

function Show-Help {
    param([string]$Mode = "Basic")
    
    Show-Header -Title "AYUDA"
    
    Write-Host "  📖 MODOS DE USO:" -ForegroundColor $Script:Colors.Secondary
    Write-Host ""
    Write-Host "  🟢 BÁSICO:" -ForegroundColor $Script:Colors.Success
    Write-Host "     Ideal si solo quieres liberar espacio rápido." -ForegroundColor $Script:Colors.Info
    Write-Host "     Opciones limitadas, todo automático." -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  🟡 INTERMEDIO:" -ForegroundColor $Script:Colors.Warning
    Write-Host "     Para usuarios que quieren más control." -ForegroundColor $Script:Colors.Info
    Write-Host "     Resumen visual, limpieza personalizable." -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  🔴 AVANZADO:" -ForegroundColor $Script:Colors.Danger
    Write-Host "     Control total, comandos abreviados." -ForegroundColor $Script:Colors.Info
    Write-Host "     Selección múltiple, exportación, scripting." -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  ⌨️ ATAJOS DE TECLADO:" -ForegroundColor $Script:Colors.Secondary
    Write-Host "     [H] Ayuda    [M] Cambiar modo    [Q] Salir" -ForegroundColor $Script:Colors.Info
    Write-Host "     [R] Refrescar    [0] Volver" -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  Presiona cualquier tecla para continuar..." -ForegroundColor $Script:Colors.Dim
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Confirm-Action {
    param(
        [string]$Message,
        [string]$Warning = "",
        [switch]$ForceConfirm
    )
    
    if ($Warning) {
        Write-Host "  ⚠️ $Warning" -ForegroundColor $Script:Colors.Warning
    }
    
    Write-Host "  $Message (S/N): " -NoNewline -ForegroundColor $Script:Colors.Highlight
    $response = (Read-Host).ToUpper()
    
    return ($response -eq "S" -or $response -eq "Y")
}

function Show-ModeSelector {
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════════╗" -ForegroundColor $Script:Colors.Primary
    Write-Host "  ║              SELECCIONA TU NIVEL DE EXPERIENCIA                ║" -ForegroundColor $Script:Colors.Primary
    Write-Host "  ╚════════════════════════════════════════════════════════════════╝" -ForegroundColor $Script:Colors.Primary
    Write-Host ""
    Write-Host "  🟢 [1] BÁSICO — Solo quiero liberar espacio" -ForegroundColor $Script:Colors.Success
    Write-Host "     Opciones simples, limpieza automática." -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  🟡 [2] INTERMEDIO — Quiero más control" -ForegroundColor $Script:Colors.Warning
    Write-Host "     Resumen visual, personalización." -ForegroundColor $Script:Colors.Info
    Write-Host ""
    Write-Host "  🔴 [3] AVANZADO — Control total" -ForegroundColor $Script:Colors.Danger
    Write-Host "     Comandos avanzados, scripting." -ForegroundColor $Script:Colors.Info
    Write-Host ""
    
    do {
        Write-Host "  Selección [1/2/3]: " -NoNewline -ForegroundColor $Script:Colors.Highlight
        $selection = Read-Host
    } while ($selection -notin @("1", "2", "3"))
    
    return [int]$selection
}

Export-ModuleMember -Function @(
    'Show-Header',
    'Show-DriveStatus',
    'Show-MenuBasic',
    'Show-MenuIntermediate',
    'Show-MenuAdvanced',
    'Show-CleanupSummary',
    'Show-ProgressBar',
    'Show-Help',
    'Confirm-Action',
    'Show-ModeSelector'
)