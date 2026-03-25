#Requires -Version 5.1
<#
.SYNOPSIS
    Módulo de funciones de análisis de disco
.DESCRIPTION
    Funciones para escanear, analizar y obtener información del disco.
#>

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

function Get-DriveInfo {
    param([string]$DriveLetter = "C")
    try {
        $drive = Get-PSDrive $DriveLetter -ErrorAction Stop
        return [PSCustomObject]@{
            Letter = $DriveLetter
            TotalGB = [math]::Round($drive.Used / 1GB + $drive.Free / 1GB, 2)
            UsedGB = [math]::Round($drive.Used / 1GB, 2)
            FreeGB = [math]::Round($drive.Free / 1GB, 2)
            PercentUsed = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 1)
            PercentFree = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
        }
    } catch {
        return $null
    }
}

function Get-CleanableCategories {
    param(
        [string[]]$ExcludePatterns = @(
            "Windows", "Program Files", "Program Files (x86)", "ProgramData",
            "`$Recycle.Bin", "System Volume Information", "Recovery"
        )
    )
    
    $PathsToAnalyze = @{
        "Archivos Temporales de Usuario" = @{ Path = "$env:TEMP"; MinAgeDays = 7; SafeForAuto = $true }
        "Archivos Temporales de Windows" = @{ Path = "$env:SystemRoot\Temp"; MinAgeDays = 7; SafeForAuto = $true }
        "Prefetch" = @{ Path = "$env:SystemRoot\Prefetch"; MinAgeDays = 30; SafeForAuto = $true }
        "Caché Windows Update" = @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; MinAgeDays = 0; SafeForAuto = $true }
        "Papelera de Reciclaje" = @{ Path = "C:\`$Recycle.Bin"; MinAgeDays = 0; SafeForAuto = $true }
        "Logs de Windows" = @{ Path = "$env:SystemRoot\Logs"; MinAgeDays = 7; SafeForAuto = $true }
        "Reportes WER" = @{ Path = "$env:ProgramData\Microsoft\Windows\WER"; MinAgeDays = 7; SafeForAuto = $true }
        "Carpeta Downloads" = @{ Path = "$env:USERPROFILE\Downloads"; MinAgeDays = 30; SafeForAuto = $false }
    }
    
    $BrowserCache = @{
        "Chrome Cache" = @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; MinAgeDays = 0; SafeForAuto = $true }
        "Chrome Code Cache" = @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"; MinAgeDays = 0; SafeForAuto = $true }
        "Chrome GPUCache" = @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"; MinAgeDays = 0; SafeForAuto = $true }
        "Firefox Cache" = @{ Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"; MinAgeDays = 0; SafeForAuto = $true }
        "Edge Cache" = @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; MinAgeDays = 0; SafeForAuto = $true }
        "Edge Code Cache" = @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"; MinAgeDays = 0; SafeForAuto = $true }
    }
    
    $allCategories = @()
    $id = 1
    
    foreach ($cat in $PathsToAnalyze.GetEnumerator()) {
        $totalSize = 0
        if ($cat.Value.Path -like "*`$Recycle.Bin*") {
            $recycleBinPaths = Get-ChildItem -Path "C:\`$Recycle.Bin" -Directory -ErrorAction SilentlyContinue
            foreach ($rbPath in $recycleBinPaths) {
                $totalSize += Get-FolderSize -Path $rbPath.FullName
            }
        } else {
            $totalSize = Get-FolderSize -Path $cat.Value.Path
        }
        
        $allCategories += [PSCustomObject]@{
            Id = $id++
            Name = $cat.Key
            Paths = @($cat.Value.Path)
            TamanioBytes = $totalSize
            TamanioFormateado = Format-FileSize -Bytes $totalSize
            MinAgeDays = $cat.Value.MinAgeDays
            SafeForAuto = $cat.Value.SafeForAuto
        }
    }
    
    foreach ($browser in $BrowserCache.GetEnumerator()) {
        $totalSize = 0
        if ($browser.Value.Path -like "*Firefox*") {
            if (Test-Path $browser.Value.Path) {
                $profiles = Get-ChildItem -Path $browser.Value.Path -Directory -ErrorAction SilentlyContinue
                foreach ($profile in $profiles) {
                    $cachePath = Join-Path $profile.FullName "cache2"
                    $totalSize += Get-FolderSize -Path $cachePath
                }
            }
        } else {
            $totalSize = Get-FolderSize -Path $browser.Value.Path
        }
        
        $allCategories += [PSCustomObject]@{
            Id = $id++
            Name = $browser.Key
            Paths = @($browser.Value.Path)
            TamanioBytes = $totalSize
            TamanioFormateado = Format-FileSize -Bytes $totalSize
            MinAgeDays = $browser.Value.MinAgeDays
            SafeForAuto = $browser.Value.SafeForAuto
        }
    }
    
    return $allCategories
}

function Get-TopFolders {
    param(
        [int]$TopCount = 20,
        [string]$RootPath = "C:\",
        [string[]]$ExcludePatterns = @(
            "Windows", "Program Files", "Program Files (x86)", "ProgramData",
            "`$Recycle.Bin", "System Volume Information", "Recovery"
        )
    )
    
    $topFolders = @()
    $rootFolders = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Name -notin $ExcludePatterns }
    
    foreach ($folder in $rootFolders) {
        $size = Get-FolderSize -Path $folder.FullName
        if ($size -gt 0) {
            $topFolders += [PSCustomObject]@{
                Carpeta = $folder.FullName
                Nombre = $folder.Name
                TamanioBytes = $size
                TamanioFormateado = Format-FileSize -Bytes $size
            }
        }
    }
    
    return $topFolders | Sort-Object TamanioBytes -Descending | Select-Object -First $TopCount
}

function Get-LargeFiles {
    param(
        [int]$ThresholdMB = 100,
        [string[]]$SearchPaths = @(
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\Desktop",
            "$env:USERPROFILE\Documents",
            "$env:TEMP"
        )
    )
    
    $largeFiles = @()
    
    foreach ($searchPath in $SearchPaths) {
        if (Test-Path $searchPath) {
            try {
                $files = Get-ChildItem -Path $searchPath -File -Recurse -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Length -ge ($ThresholdMB * 1MB) }
                
                foreach ($file in $files) {
                    $largeFiles += [PSCustomObject]@{
                        Archivo = $file.FullName
                        Nombre = $file.Name
                        TamanioBytes = $file.Length
                        TamanioFormateado = Format-FileSize -Bytes $file.Length
                        UltimaModificacion = $file.LastWriteTime
                    }
                }
            } catch {}
        }
    }
    
    return $largeFiles | Sort-Object TamanioBytes -Descending
}

Export-ModuleMember -Function @(
    'Format-FileSize',
    'Get-FolderSize',
    'Get-DriveInfo',
    'Get-CleanableCategories',
    'Get-TopFolders',
    'Get-LargeFiles'
)