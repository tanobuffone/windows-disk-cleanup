#Requires -Version 5.1
<#
.SYNOPSIS
    Módulo de funciones de limpieza de disco
.DESCRIPTION
    Funciones para limpiar archivos temporales, caché y categorías limpiables.
#>

function Write-Log {
    param(
        [string]$Message,
        [string]$LogPath = "C:\DiskCleanup\Logs"
    )
    
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = Join-Path $LogPath "cleanup-$timestamp.txt"
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $logEntry
}

function Clean-Folder {
    param(
        [string]$Path,
        [string]$Description,
        [int]$MinAgeDays = 0,
        [switch]$Confirm,
        [string]$LogPath = "C:\DiskCleanup\Logs"
    )
    
    if (-not (Test-Path $Path)) {
        return @{ Success = $false; FreedBytes = 0; Message = "Ruta no existe" }
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
            return @{ Success = $true; FreedBytes = 0; Message = "Nada que limpiar" }
        }
        
        $sizeFormatted = Format-FileSize -Bytes $totalSize
        
        if ($Confirm) {
            Write-Host "  📦 $Description - $sizeFormatted encontrados" -ForegroundColor White
            $response = Read-Host "  ¿Eliminar? (S/N)"
            if ($response -ne "S" -and $response -ne "s") {
                Write-Log -Message "CANCELADO: $Description ($sizeFormatted)" -LogPath $LogPath
                return @{ Success = $false; FreedBytes = 0; Message = "Cancelado por usuario" }
            }
        }
        
        $deletedSize = 0
        $deletedCount = 0
        
        foreach ($item in $items) {
            try {
                $itemSize = if ($item.PSIsContainer) { 0 } else { $item.Length }
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $deletedCount++
                $deletedSize += $itemSize
            } catch {
                # Ignorar archivos en uso
            }
        }
        
        $deletedFormatted = Format-FileSize -Bytes $deletedSize
        Write-Log -Message "LIMPIADO: $Description - $deletedCount elementos, $deletedFormatted liberados" -LogPath $LogPath
        
        return @{ 
            Success = $true
            FreedBytes = $deletedSize
            FreedFormatted = $deletedFormatted
            ItemsDeleted = $deletedCount
            Message = "Eliminado: $deletedFormatted"
        }
        
    } catch {
        Write-Log -Message "ERROR: $Description - $_" -LogPath $LogPath
        return @{ Success = $false; FreedBytes = 0; Message = "Error: $_" }
    }
}

function Clean-MultipleCategories {
    param(
        [PSCustomObject[]]$Categories,
        [switch]$OnlySafe,
        [switch]$ConfirmEach,
        [string]$LogPath = "C:\DiskCleanup\Logs"
    )
    
    $totalFreed = 0
    $results = @()
    
    foreach ($category in $Categories) {
        if ($OnlySafe -and -not $category.SafeForAuto) {
            continue
        }
        
        foreach ($path in $category.Paths) {
            $result = Clean-Folder -Path $path -Description $category.Name -MinAgeDays $category.MinAgeDays -Confirm:$ConfirmEach -LogPath $LogPath
            $totalFreed += $result.FreedBytes
            $results += @{
                Category = $category.Name
                Result = $result
            }
        }
    }
    
    return @{
        TotalFreedBytes = $totalFreed
        TotalFreedFormatted = Format-FileSize -Bytes $totalFreed
        Results = $results
    }
}

function Rotate-Logs {
    param(
        [string]$LogPath = "C:\DiskCleanup\Logs",
        [int]$KeepDays = 30
    )
    
    if (-not (Test-Path $LogPath)) { return }
    
    $cutoffDate = (Get-Date).AddDays(-$KeepDays)
    $oldLogs = Get-ChildItem -Path $LogPath -Filter "*.txt" -ErrorAction SilentlyContinue | 
               Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($log in $oldLogs) {
        Remove-Item -Path $log.FullName -Force -ErrorAction SilentlyContinue
    }
    
    if ($oldLogs.Count -gt 0) {
        Write-Log -Message "ROTACIÓN: Eliminados $($oldLogs.Count) logs antiguos" -LogPath $LogPath
    }
}

Export-ModuleMember -Function @(
    'Write-Log',
    'Clean-Folder',
    'Clean-MultipleCategories',
    'Rotate-Logs'
)