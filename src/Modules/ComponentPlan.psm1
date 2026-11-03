Set-StrictMode -Version Latest

function Get-WnComponentPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Audit,
        [Parameter(Mandatory)][string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw ('Component manifest not found: {0}' -f $ManifestPath)
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($manifest.schemaVersion -ne 2) {
        throw ('Unsupported component manifest schema: {0}' -f $manifest.schemaVersion)
    }

    $warnings = @()
    $osBuild = ''
    $osRelease = ''
    if ($null -ne $Audit.OperatingSystem) {
        $osBuild = [string]$Audit.OperatingSystem.BuildNumber
        if ($Audit.OperatingSystem.PSObject.Properties.Name -contains 'DisplayVersion') {
            $osRelease = [string]$Audit.OperatingSystem.DisplayVersion
        }
    }
    if ($osRelease -eq '21H2' -or $osBuild -eq '22000') {
        $warnings += 'Windows 11 Pro/Home 21H2 ended servicing on 2023-10-10 and no longer receives security updates. Do not attempt an unattended feature upgrade on this unsupported CPU.'
    }

    $planned = @()
    foreach ($component in @($manifest.components)) {
        $collection = @()
        switch ([string]$component.inventoryClass) {
            'Graphics'       { $collection = @($Audit.Graphics) }
            'NetworkDevices' { $collection = @($Audit.NetworkDevices) }
            default           { $collection = @() }
        }

        $device = $null
        $expectedPrefix = [string]$component.expectedHardwareIdPrefix
        foreach ($candidate in $collection) {
            $candidateIds = @()
            if ($candidate.PSObject.Properties.Name -contains 'InstanceId') {
                $candidateIds += [string]$candidate.InstanceId
            }
            if ($candidate.PSObject.Properties.Name -contains 'HardwareIds') {
                $candidateIds += @($candidate.HardwareIds | ForEach-Object { [string]$_ })
            }

            foreach ($candidateId in $candidateIds) {
                if (-not [string]::IsNullOrWhiteSpace($candidateId) -and
                    $candidateId.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $device = $candidate
                    break
                }
            }
            if ($null -ne $device) { break }
        }

        $detected = ($null -ne $device)
        $installedVersion = $null
        if ($detected -and $device.PSObject.Properties.Name -contains 'DriverVersion') {
            $installedVersion = [string]$device.DriverVersion
        }

        $decision = 'NOT_DETECTED'
        $reason = 'The expected hardware ID was not found in the live inventory.'
        if ($detected) {
            $decision = 'KEEP_CURRENT'
            $reason = [string]$component.blockReason
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = 'No package has passed the complete compatibility and recovery review.'
            }
        }

        # This planner is intentionally read-only. An approval flag cannot enable
        # installation until a separately reviewed execution engine is released.
        $planned += [pscustomobject]@{
            Id                    = [string]$component.id
            DisplayName           = [string]$component.displayName
            Detected              = $detected
            InstalledDriverVersion = $installedVersion
            Decision              = $decision
            AutomaticInstall      = $false
            Reason                = $reason
        }
    }

    [pscustomobject]@{
        ManifestVersion          = $manifest.schemaVersion
        InstallationEnabled      = $false
        Summary                  = 'READ_ONLY — no component is authorized for automatic installation.'
        Warnings                 = @($warnings)
        Components               = @($planned)
    }
}

Export-ModuleMember -Function Get-WnComponentPlan
