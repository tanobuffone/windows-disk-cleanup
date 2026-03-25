#Requires -Version 5.1
<#
.SYNOPSIS
    Analiza el uso de espacio en disco C: y genera reportes detallados.
.DESCRIPTION
    Escanea el disco C: identificando carpetas que más espacio ocupan,
    archivos grandes, y categorías de archivos limpiables.
.PARAMETER TopFolders
    Número de carpetas principales a mostrar (default: 20)
.PARAMETER LargeFileThresholdMB
    Umbral en MB para considerar archivo grande (default: 100)
.PARAMETER OutputPath
    Carpeta donde guardar los reportes
.EXAMPLE
    .\Analyze-Disk.ps1
    .\Analyze-Disk.ps1 -TopFolders 30 -LargeFileThresholdMB 200
#>

param(
    [int]$TopFolders = 20,
    [int]$LargeFileThresholdMB = 100,
    [string]$OutputPath = "C:\DiskCleanup\Reports"
)

# CONFIGURACIÓN
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Rutas a analizar
$PathsToAnalyze = @{
    "Archivos Temporales de Usuario" = "$env:TEMP"
    "Archivos Temporales de Windows" = "$env:SystemRoot\Temp"
    "Prefetch" = "$env:SystemRoot\Prefetch"
    "Caché Windows Update" = "$env:SystemRoot\SoftwareDistribution\Download"
    "Papelera de Reciclaje" = "`$Recycle.Bin"
    "Logs de Windows" = "$env:SystemRoot\Logs"
    "Reportes WER" = "$env:ProgramData\Microsoft\Windows\WER"
    "Carpeta Downloads" = "$env:USERPROFILE\Downloads"
}

# Caché de navegadores
$BrowserCache = @{
    "Chrome Cache" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    "Chrome Code Cache" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
    "Chrome GPUCache" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
    "Firefox Cache" = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    "Edge Cache" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    "Edge Code Cache" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
}

# Carpetas del sistema a excluir del escaneo profundo
$ExcludePatterns = @(
    "Windows", "Program Files", "Program Files (x86)", "ProgramData",
    "`$Recycle.Bin", "System Volume Information", "Recovery"
)

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

function Get-DriveInfo {
    $drive = Get-PSDrive C
    return [PSCustomObject]@{
        TotalGB = [math]::Round($drive.Used / 1GB + $drive.Free / 1GB, 2)
        UsedGB = [math]::Round($drive.Used / 1GB, 2)
        FreeGB = [math]::Round($drive.Free / 1GB, 2)
        PercentUsed = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 1)
        PercentFree = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
    }
}

# ANÁLISIS PRINCIPAL
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           ANÁLISIS DE DISCO C: - Disk Cleanup Tool            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# 1. Información del disco
Write-Host "📊 INFORMACIÓN DEL DISCO" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$driveInfo = Get-DriveInfo
Write-Host "  Espacio Total:   $($driveInfo.TotalGB) GB" -ForegroundColor White
Write-Host "  Espacio Usado:   $($driveInfo.UsedGB) GB ($($driveInfo.PercentUsed)%)" -ForegroundColor Red
Write-Host "  Espacio Libre:   $($driveInfo.FreeGB) GB ($($driveInfo.PercentFree)%)" -ForegroundColor Green

$barLength = 50
$filledLength = [math]::Floor($barLength * $driveInfo.PercentUsed / 100)
$bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
Write-Host ""
Write-Host "  [$bar]" -ForegroundColor $(if ($driveInfo.PercentUsed -gt 80) { "Red" } elseif ($driveInfo.PercentUsed -gt 60) { "Yellow" } else { "Green" })
Write-Host ""

# 2. Categorías limpiables
Write-Host "🧹 CATEGORÍAS LIMPIABLES" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$cleanableCategories = @()

foreach ($category in $PathsToAnalyze.GetEnumerator()) {
    Write-Host "  Escaneando: $($category.Key)..." -NoNewline -ForegroundColor Gray
    
    if ($category.Value -like "*`$Recycle.Bin*") {
        $recycleBinPaths = Get-ChildItem -Path "C:\`$Recycle.Bin" -Directory -ErrorAction SilentlyContinue
        $totalSize = 0
        foreach ($rbPath in $recycleBinPaths) {
            $totalSize += Get-FolderSize -Path $rbPath.FullName
        }
    } else {
        $totalSize = Get-FolderSize -Path $category.Value
    }
    
    $sizeFormatted = Format-FileSize -Bytes $totalSize
    Write-Host " $sizeFormatted" -ForegroundColor Green
    
    if ($totalSize -gt 0) {
        $cleanableCategories += [PSCustomObject]@{
            Categoria = $category.Key
            Ruta = $category.Value
            TamanioBytes = $totalSize
            TamanioFormateado = $sizeFormatted
        }
    }
}

foreach ($browser in $BrowserCache.GetEnumerator()) {
    Write-Host "  Escaneando: $($browser.Key)..." -NoNewline -ForegroundColor Gray
    
    $totalSize = 0
    if ($browser.Value -like "*Firefox*") {
        if (Test-Path $browser.Value) {
            $profiles = Get-ChildItem -Path $browser.Value -Directory -ErrorAction SilentlyContinue
            foreach ($profile in $profiles) {
                $cachePath = Join-Path $profile.FullName "cache2"
                $totalSize += Get-FolderSize -Path $cachePath
            }
        }
    } else {
        $totalSize = Get-FolderSize -Path $browser.Value
    }
    
    $sizeFormatted = Format-FileSize -Bytes $totalSize
    Write-Host " $sizeFormatted" -ForegroundColor Green
    
    if ($totalSize -gt 0) {
        $cleanableCategories += [PSCustomObject]@{
            Categoria = $browser.Key
            Ruta = $browser.Value
            TamanioBytes = $totalSize
            TamanioFormateado = $sizeFormatted
        }
    }
}

Write-Host ""

# 3. Top carpetas por tamaño
Write-Host "📁 TOP $TopFolders CARPETAS MÁS GRANDES (raíz C:\)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$topFolders = @()
$rootFolders = Get-ChildItem -Path "C:\" -Directory -ErrorAction SilentlyContinue | 
               Where-Object { $_.Name -notin $ExcludePatterns }

foreach ($folder in $rootFolders) {
    Write-Host "  Analizando $($folder.Name)..." -NoNewline -ForegroundColor Gray
    $size = Get-FolderSize -Path $folder.FullName
    Write-Host " $(Format-FileSize -Bytes $size)" -ForegroundColor Green
    
    if ($size -gt 0) {
        $topFolders += [PSCustomObject]@{
            Carpeta = $folder.FullName
            Nombre = $folder.Name
            TamanioBytes = $size
            TamanioFormateado = Format-FileSize -Bytes $size
        }
    }
}

$topFolders = $topFolders | Sort-Object TamanioBytes -Descending | Select-Object -First $TopFolders

$i = 1
foreach ($folder in $topFolders) {
    $barWidth = [math]::Min(30, [math]::Floor($folder.TamanioBytes / $topFolders[0].TamanioBytes * 30))
    $bar = "▓" * $barWidth + "░" * (30 - $barWidth)
    Write-Host ("  {0,2}. [{1}] {2} - {3}" -f $i, $bar, $folder.TamanioFormateado, $folder.Nombre) -ForegroundColor White
    $i++
}

Write-Host ""

# 4. Archivos grandes
Write-Host "📦 ARCHIVOS GRANDES (>$LargeFileThresholdMB MB)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$largeFiles = @()
$searchPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:TEMP"
)

foreach ($searchPath in $searchPaths) {
    if (Test-Path $searchPath) {
        Write-Host "  Buscando en: $(Split-Path $searchPath -Leaf)..." -NoNewline -ForegroundColor Gray
        
        try {
            $files = Get-ChildItem -Path $searchPath -File -Recurse -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Length -ge ($LargeFileThresholdMB * 1MB) }
            
            foreach ($file in $files) {
                $largeFiles += [PSCustomObject]@{
                    Archivo = $file.FullName
                    Nombre = $file.Name
                    TamanioBytes = $file.Length
                    TamanioFormateado = Format-FileSize -Bytes $file.Length
                    UltimaModificacion = $file.LastWriteTime
                }
            }
            Write-Host " $($files.Count) encontrados" -ForegroundColor Green
        } catch {
            Write-Host " error" -ForegroundColor Red
        }
    }
}

$largeFiles = $largeFiles | Sort-Object TamanioBytes -Descending
if ($largeFiles.Count -gt 0) {
    $i = 1
    foreach ($file in $largeFiles | Select-Object -First 20) {
        Write-Host ("  {0,2}. {1} - {2}" -f $i, $file.TamanioFormateado, $file.Nombre) -ForegroundColor White
        Write-Host ("      Ruta: {0}" -f $file.Archivo) -ForegroundColor DarkGray
        Write-Host ("      Modificado: {0}" -f $file.UltimaModificacion.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
        $i++
    }
} else {
    Write-Host "  No se encontraron archivos grandes." -ForegroundColor Green
}

Write-Host ""

# GENERAR REPORTE HTML
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$htmlPath = Join-Path $OutputPath "disk-analysis-$timestamp.html"
$csvPath = Join-Path $OutputPath "cleanable-categories-$timestamp.csv"

$cleanableCategories | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# Generar HTML (versión simplificada)
$html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Análisis de Disco C: - $timestamp</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #00d4ff; text-align: center; margin-bottom: 30px; }
        h2 { color: #00d4ff; margin: 20px 0 10px 0; border-bottom: 1px solid #333; padding-bottom: 5px; }
        .card { background: #16213e; border-radius: 10px; padding: 20px; margin-bottom: 20px; }
        .drive-info { display: flex; justify-content: space-around; flex-wrap: wrap; gap: 20px; }
        .drive-stat { text-align: center; padding: 15px; background: #0f3460; border-radius: 8px; min-width: 150px; }
        .drive-stat .value { font-size: 2em; font-weight: bold; color: #00d4ff; }
        .drive-stat .label { font-size: 0.9em; color: #888; }
        .progress-bar { background: #333; border-radius: 10px; height: 30px; overflow: hidden; margin: 20px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #00d4ff, #0099ff); }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #333; }
        th { background: #0f3460; color: #00d4ff; }
        .cleanable { color: #00ff88; }
        .danger { color: #ff4444; }
        .footer { text-align: center; margin-top: 30px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Análisis de Disco C:</h1>
        <p style="text-align: center; color: #888; margin-bottom: 30px;">Generado: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</p>
        
        <div class="card">
            <h2>💾 Información del Disco</h2>
            <div class="drive-info">
                <div class="drive-stat">
                    <div class="value">$($driveInfo.TotalGB)</div>
                    <div class="label">GB Total</div>
                </div>
                <div class="drive-stat">
                    <div class="value danger">$($driveInfo.UsedGB)</div>
                    <div class="label">GB Usado ($($driveInfo.PercentUsed)%)</div>
                </div>
                <div class="drive-stat">
                    <div class="value $(if($driveInfo.PercentFree -lt 20){'danger'}else{'cleanable'})">$($driveInfo.FreeGB)</div>
                    <div class="label">GB Libre ($($driveInfo.PercentFree)%)</div>
                </div>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: $($driveInfo.PercentUsed)%"></div>
            </div>
        </div>
        
        <div class="card">
            <h2>🧹 Categorías Limpiables</h2>
            <table>
                <thead><tr><th>Categoría</th><th>Tamaño</th></tr></thead>
                <tbody>
"@

foreach ($cat in ($cleanableCategories | Sort-Object TamanioBytes -Descending)) {
    $html += "<tr><td>$($cat.Categoria)</td><td class='cleanable'>$($cat.TamanioFormateado)</td></tr>`n"
}

$html += @"
                </tbody>
            </table>
            <p style="margin-top: 15px; color: #00ff88;"><strong>Total limpiable: $(Format-FileSize -Bytes ($cleanableCategories | Measure-Object -Property TamanioBytes -Sum).Sum)</strong></p>
        </div>
        
        <div class="card">
            <h2>📁 Top $TopFolders Carpetas</h2>
            <table>
                <thead><tr><th>#</th><th>Carpeta</th><th>Tamaño</th></tr></thead>
                <tbody>
"@

$i = 1
foreach ($folder in $topFolders) {
    $html += "<tr><td>$i</td><td>$($folder.Carpeta)</td><td>$($folder.TamanioFormateado)</td></tr>`n"
    $i++
}

$html += @"
                </tbody>
            </table>
        </div>
        
        <div class="card">
            <h2>📦 Archivos Grandes (>$LargeFileThresholdMB MB)</h2>
            <table>
                <thead><tr><th>Archivo</th><th>Tamaño</th><th>Modificado</th></tr></thead>
                <tbody>
"@

foreach ($file in ($largeFiles | Select-Object -First 20)) {
    $html += "<tr><td>$($file.Nombre)<br><small>$($file.Archivo)</small></td><td>$($file.TamanioFormateado)</td><td>$($file.UltimaModificacion.ToString('dd/MM/yyyy HH:mm'))</td></tr>`n"
}

$html += @"
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>Generado por Disk Cleanup Tool | Para limpiar, ejecuta: .\Clean-Disk.ps1</p>
        </div>
    </div>
</body>
</html>
"@

$html | Out-File -FilePath $htmlPath -Encoding UTF8

# RESUMEN FINAL
$totalCleanable = Format-FileSize -Bytes ($cleanableCategories | Measure-Object -Property TamanioBytes -Sum).Sum

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 RESUMEN" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Espacio total limpiable estimado: " -NoNewline -ForegroundColor White
Write-Host "$totalCleanable" -ForegroundColor Green
Write-Host ""
Write-Host "  📄 Reporte HTML: $htmlPath" -ForegroundColor Gray
Write-Host "  📄 CSV categorías: $csvPath" -ForegroundColor Gray
Write-Host ""
Write-Host "  💡 Para liberar espacio, ejecuta: " -NoNewline -ForegroundColor White
Write-Host ".\Clean-Disk.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$openReport = Read-Host "¿Abrir reporte HTML? (S/N)"
if ($openReport -eq "S" -or $openReport -eq "s") {
    Start-Process $htmlPath
}