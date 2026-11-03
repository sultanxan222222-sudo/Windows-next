Set-StrictMode -Version Latest

function Export-WnAuditReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Audit,
        [psobject]$ComponentPlan,
        [string]$OutputDirectory
    )

    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path $env:LOCALAPPDATA 'WindowsNext\Reports'
    }

    [void][System.IO.Directory]::CreateDirectory($OutputDirectory)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $OutputDirectory "WindowsNext-Audit-$stamp.json"
    $textPath = Join-Path $OutputDirectory "WindowsNext-Audit-$stamp.txt"

    $Audit | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('WINDOWS NEXT — SYSTEM INVENTORY')
    $lines.Add(('Collected (UTC): {0}' -f $Audit.CollectedAtUtc))
    $lines.Add(('Tool version: {0}' -f $Audit.ToolVersion))
    $lines.Add(('Collection mode: {0}' -f $Audit.CollectionMode))
    $lines.Add('')

    $lines.Add('OPERATING SYSTEM')
    if ($null -ne $Audit.OperatingSystem) {
        $lines.Add(('Name: {0}' -f $Audit.OperatingSystem.Caption))
        $lines.Add(('Version / build: {0} / {1}' -f $Audit.OperatingSystem.Version, $Audit.OperatingSystem.BuildNumber))
        $lines.Add(('Architecture: {0}' -f $Audit.OperatingSystem.Architecture))
    }
    else {
        $lines.Add('Not available')
    }

    $lines.Add('')
    $lines.Add('SYSTEM')
    if ($null -ne $Audit.System) {
        $lines.Add(('Manufacturer / model: {0} / {1}' -f $Audit.System.Manufacturer, $Audit.System.Model))
        $lines.Add(('Memory: {0} GB' -f $Audit.System.MemoryGB))
        $lines.Add(('System type: {0}' -f $Audit.System.SystemType))
    }
    else {
        $lines.Add('Not available')
    }

    $lines.Add('')
    $lines.Add('PROCESSOR')
    if ($null -ne $Audit.Processor) {
        $lines.Add(('Name: {0}' -f $Audit.Processor.Name))
        $lines.Add(('Cores / logical processors: {0} / {1}' -f $Audit.Processor.NumberOfCores, $Audit.Processor.NumberOfLogicalProcessors))
        $lines.Add(('Reported max clock: {0} MHz' -f $Audit.Processor.MaxClockSpeedMHz))
    }
    else {
        $lines.Add('Not available')
    }

    $lines.Add('')
    $lines.Add('GRAPHICS ADAPTERS')
    foreach ($gpu in @($Audit.Graphics)) {
        $lines.Add(('Name: {0}' -f $gpu.Name))
        $lines.Add(('Manufacturer: {0}' -f $gpu.Manufacturer))
        $lines.Add(('Driver: {0} | date: {1} | INF: {2}' -f $gpu.DriverVersion, $gpu.DriverDate, $gpu.InfName))
        $lines.Add(('Signed: {0}' -f $gpu.IsSigned))
        $lines.Add(('Instance ID: {0}' -f $gpu.InstanceId))
        $lines.Add(('Hardware IDs: {0}' -f (@($gpu.HardwareIds) -join '; ')))
        $lines.Add(('Inventory source: {0}' -f $gpu.Source))
        $lines.Add('')
    }

    $lines.Add('STORAGE')
    foreach ($disk in @($Audit.Storage)) {
        $lines.Add(('Model: {0} | type: {1} | bus: {2} | size: {3} GB | health: {4} | status: {5}' -f
            $disk.Model, $disk.MediaType, $disk.BusType, $disk.SizeGB, $disk.HealthStatus, $disk.OperationalStatus))
    }

    $lines.Add('')
    $lines.Add('MEMORY MODULES')
    if (($Audit.PSObject.Properties.Name -contains 'Memory') -and $null -ne $Audit.Memory) {
        foreach ($module in @($Audit.Memory.Modules)) {
            $lines.Add(('Manufacturer: {0} | part: {1} | capacity: {2} GB | speed: {3} MHz | configured: {4} MHz | slot: {5}' -f
                $module.Manufacturer, $module.PartNumber, $module.CapacityGB, $module.SpeedMHz,
                $module.ConfiguredClockSpeedMHz, $module.DeviceLocator))
        }
        foreach ($array in @($Audit.Memory.Arrays)) {
            $lines.Add(('Memory array: reported devices {0} | reported max {1} GB' -f
                $array.MemoryDevices, $array.ReportedMaxCapacityGB))
        }
    }
    else {
        $lines.Add('Not available')
    }

    $lines.Add('')
    $lines.Add('NETWORK AND BLUETOOTH DEVICES')
    if ($Audit.PSObject.Properties.Name -contains 'NetworkDevices') {
        foreach ($device in @($Audit.NetworkDevices)) {
            $lines.Add(('Name: {0} | class: {1} | driver: {2} | date: {3} | INF: {4}' -f
                $device.Name, $device.Class, $device.DriverVersion, $device.DriverDate, $device.InfName))
            $lines.Add(('Manufacturer: {0} | signed: {1} | instance ID: {2}' -f
                $device.Manufacturer, $device.IsSigned, $device.InstanceId))
        }
    }
    else {
        $lines.Add('Not available')
    }

    $lines.Add('')
    $lines.Add('COMPONENT INSTALLATION PLAN')
    if ($null -ne $ComponentPlan) {
        $lines.Add([string]$ComponentPlan.Summary)
        foreach ($warning in @($ComponentPlan.Warnings)) {
            $lines.Add(('WARNING: {0}' -f $warning))
        }
        foreach ($component in @($ComponentPlan.Components)) {
            $lines.Add(('{0}: {1} | detected: {2} | installed driver: {3}' -f
                $component.DisplayName, $component.Decision, $component.Detected, $component.InstalledDriverVersion))
            $lines.Add(('Reason: {0}' -f $component.Reason))
        }
    }
    else {
        $lines.Add('No compatibility plan was generated.')
    }
    $lines.Add('No driver package was installed by this diagnostic run.')

    $lines.Add('')
    $lines.Add(('Active power plan: {0}' -f $Audit.ActivePowerPlan))
    $lines.Add(('Secure Boot: {0}' -f $Audit.SecureBoot))
    $lines.Add('')
    $lines.Add('PRIVACY')
    $lines.Add('Serial numbers, product keys, usernames, network addresses, and personal file names are not collected.')
    $lines.Add('')
    $lines.Add('SAFETY')
    $lines.Add('Read-only inventory and compatibility planning. No driver or Windows configuration changes were made.')

    $lines | Set-Content -LiteralPath $textPath -Encoding UTF8

    [pscustomobject]@{
        JsonPath = $jsonPath
        TextPath = $textPath
    }
}

Export-ModuleMember -Function Export-WnAuditReport
