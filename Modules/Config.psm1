#Requires -Version 5.1
<#
.SYNOPSIS
    Módulo de gestión de configuración
.DESCRIPTION
    Funciones para cargar, guardar y gestionar la configuración persistente.
#>

$Script:DefaultConfig = @{
    UserMode = 2  # 1=Básico, 2=Intermedio, 3=Avanzado
    LogPath = "C:\DiskCleanup\Logs"
    ReportPath = "C:\DiskCleanup\Reports"
    AlertThresholdPercent = 10
    AutoConfirmSafe = $false
    ShowBanner = $true
    Theme = "Default"
    LastRun = $null
    TotalCleanedGB = 0
}

function Get-ConfigPath {
    param([string]$BasePath = "C:\DiskCleanup")
    
    $configDir = Join-Path $BasePath "Config"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    return Join-Path $configDir "settings.json"
}

function Load-Config {
    param([string]$ConfigPath = "")
    
    if (-not $ConfigPath) {
        $ConfigPath = Get-ConfigPath
    }
    
    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            # Merge con defaults para nuevas propiedades
            foreach ($key in $Script:DefaultConfig.Keys) {
                if (-not ($config.PSObject.Properties.Name -contains $key)) {
                    $config | Add-Member -NotePropertyName $key -NotePropertyValue $Script:DefaultConfig[$key]
                }
            }
            return $config
        } catch {
            return [PSCustomObject]$Script:DefaultConfig
        }
    }
    
    return [PSCustomObject]$Script:DefaultConfig
}

function Save-Config {
    param(
        [PSCustomObject]$Config,
        [string]$ConfigPath = ""
    )
    
    if (-not $ConfigPath) {
        $ConfigPath = Get-ConfigPath
    }
    
    try {
        $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
        return $true
    } catch {
        return $false
    }
}

function Update-ConfigValue {
    param(
        [string]$Key,
        $Value,
        [string]$ConfigPath = ""
    )
    
    $config = Load-Config -ConfigPath $ConfigPath
    
    if ($config.PSObject.Properties.Name -contains $Key) {
        $config.$Key = $Value
    } else {
        $config | Add-Member -NotePropertyName $Key -NotePropertyValue $Value
    }
    
    return Save-Config -Config $config -ConfigPath $ConfigPath
}

function Get-UserMode {
    param([string]$ConfigPath = "")
    
    $config = Load-Config -ConfigPath $ConfigPath
    return $config.UserMode
}

function Set-UserMode {
    param(
        [int]$Mode,
        [string]$ConfigPath = ""
    )
    
    if ($Mode -lt 1 -or $Mode -gt 3) {
        return $false
    }
    
    return Update-ConfigValue -Key "UserMode" -Value $Mode -ConfigPath $ConfigPath
}

function Update-LastRun {
    param([string]$ConfigPath = "")
    
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Update-ConfigValue -Key "LastRun" -Value $now -ConfigPath $ConfigPath
}

function Add-TotalCleaned {
    param(
        [long]$BytesCleaned,
        [string]$ConfigPath = ""
    )
    
    $config = Load-Config -ConfigPath $ConfigPath
    $currentGB = [double]$config.TotalCleanedGB
    $newGB = $currentGB + ($BytesCleaned / 1GB)
    
    Update-ConfigValue -Key "TotalCleanedGB" -Value ([math]::Round($newGB, 2)) -ConfigPath $ConfigPath
}

function Get-ModeName {
    param([int]$Mode)
    
    switch ($Mode) {
        1 { return "Básico" }
        2 { return "Intermedio" }
        3 { return "Avanzado" }
        default { return "Desconocido" }
    }
}

Export-ModuleMember -Function @(
    'Get-ConfigPath',
    'Load-Config',
    'Save-Config',
    'Update-ConfigValue',
    'Get-UserMode',
    'Set-UserMode',
    'Update-LastRun',
    'Add-TotalCleaned',
    'Get-ModeName'
)