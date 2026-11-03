Set-StrictMode -Version Latest

function Test-WnDriverCandidateApplicability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$DeviceHardwareIds,
        [Parameter(Mandatory)][string]$UpdateHardwareId,
        [Parameter(Mandatory)][datetime]$CurrentDriverDate,
        [Parameter(Mandatory)][datetime]$UpdateDriverDate
    )

    if ([string]::IsNullOrWhiteSpace($UpdateHardwareId)) { return $false }
    if ($UpdateDriverDate -le $CurrentDriverDate) { return $false }
    foreach ($hardwareId in $DeviceHardwareIds) {
        if ([string]::Equals([string]$hardwareId, $UpdateHardwareId, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-WnRawWindowsUpdateDriverCandidates {
    [CmdletBinding()]
    param()

    if (-not [Environment]::Is64BitOperatingSystem) { throw 'The driver update manager requires 64-bit Windows.' }

    $devices = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.PNPDeviceID) -and @($_.HardwareID).Count -gt 0 })
    $signedDrivers = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop)

    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $searcher.Online = $true
    $searcher.IncludePotentiallySupersededUpdates = $false

    # Use the update service already configured by Windows (Windows Update or the
    # organization's managed source). Search only driver updates; never software/OS updates.
    $searchResult = $searcher.Search("IsInstalled=0 and Type='Driver' and IsHidden=0")
    if ([int]$searchResult.ResultCode -ne 2) {
        throw ('Windows Update driver search did not complete successfully (result code {0}). No driver was selected.' -f $searchResult.ResultCode)
    }

    $candidates = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt [int]$searchResult.Updates.Count; $i++) {
        $update = $searchResult.Updates.Item($i)
        try {
            $hardwareId = [string]$update.DriverHardwareID
            if ([string]::IsNullOrWhiteSpace($hardwareId)) { continue }

            $updateDate = [datetime]$update.DriverVerDate
            if ($updateDate -lt [datetime]'2000-01-01') { continue }

            $matchingDevices = New-Object 'System.Collections.Generic.List[object]'
            $allNewer = $true
            foreach ($device in $devices) {
                $hardwareIds = @($device.HardwareID | ForEach-Object { [string]$_ })
                if (-not ($hardwareIds | Where-Object { [string]::Equals($_, $hardwareId, [StringComparison]::OrdinalIgnoreCase) })) { continue }

                $current = @($signedDrivers | Where-Object { [string]::Equals([string]$_.DeviceID, [string]$device.PNPDeviceID, [StringComparison]::OrdinalIgnoreCase) } |
                    Sort-Object DriverDate -Descending | Select-Object -First 1)
                if ($current.Count -ne 1 -or $null -eq $current[0].DriverDate) {
                    $allNewer = $false
                    break
                }
                $currentDate = [datetime]$current[0].DriverDate
                if ($updateDate -le $currentDate) {
                    $allNewer = $false
                    break
                }

                $matchingDevices.Add([pscustomobject]@{
                    DeviceId = [string]$device.PNPDeviceID
                    DeviceName = [string]$device.Name
                    CurrentDriverVersion = [string]$current[0].DriverVersion
                    CurrentDriverDate = $currentDate
                })
            }

            if (-not $allNewer -or $matchingDevices.Count -eq 0) { continue }

            $candidates.Add([pscustomobject]@{
                UpdateId = [string]$update.Identity.UpdateID
                RevisionNumber = [int]$update.Identity.RevisionNumber
                Title = [string]$update.Title
                Description = [string]$update.Description
                HardwareId = $hardwareId
                Manufacturer = [string]$update.DriverManufacturer
                Model = [string]$update.DriverModel
                Provider = [string]$update.DriverProvider
                DriverClass = [string]$update.DriverClass
                DriverDate = $updateDate
                MatchedDevices = @($matchingDevices.ToArray())
                Update = $update
            })
        }
        catch {
            # Missing or unreadable metadata is not installable in this application.
            continue
        }
    }

    return $candidates.ToArray()
}

function Get-WnWindowsUpdateDriverCandidates {
    [CmdletBinding()]
    param()

    $raw = @(Get-WnRawWindowsUpdateDriverCandidates)
    $public = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $raw) {
        $deviceNames = @($item.MatchedDevices | ForEach-Object { $_.DeviceName }) -join '; '
        $currentVersions = @($item.MatchedDevices | ForEach-Object { $_.CurrentDriverVersion }) -join '; '
        $public.Add([pscustomobject]@{
            UpdateId = $item.UpdateId
            Title = $item.Title
            Manufacturer = $item.Manufacturer
            Model = $item.Model
            Provider = $item.Provider
            DriverClass = $item.DriverClass
            HardwareId = $item.HardwareId
            DriverDate = $item.DriverDate.ToString('yyyy-MM-dd')
            CurrentDriverVersion = $currentVersions
            MatchedDevices = $deviceNames
            Installable = $true
            Status = 'Точный HWID; дата пакета новее установленного'
        })
    }
    return $public.ToArray()
}

function Write-WnDriverUpdateLog {
    param([Parameter(Mandatory)][string]$LogPath,[Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $LogPath -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message) -Encoding UTF8
}

function Install-WnWindowsUpdateDriver {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][guid]$UpdateId,
        [Parameter(Mandatory)][string]$LogPath
    )

    $raw = @(Get-WnRawWindowsUpdateDriverCandidates)
    $candidate = @($raw | Where-Object { [guid]$_.UpdateId -eq $UpdateId })
    if ($candidate.Count -ne 1) {
        throw 'Этот драйвер больше не проходит проверку Windows Update или не соответствует точному Hardware ID. Установка отменена.'
    }

    $update = $candidate[0].Update
    if (-not [bool]$update.EulaAccepted) {
        $update.AcceptEula()
    }
    if ([bool]$update.InstallationBehavior.CanRequestUserInput) {
        throw 'Этот пакет требует интерактивного ввода. Windows Next не будет запускать такой установщик.'
    }

    Write-WnDriverUpdateLog -LogPath $LogPath -Message ('Подтверждён Windows Update driver: {0}; HWID={1}; Date={2}; UpdateID={3}' -f $candidate[0].Title,$candidate[0].HardwareId,$candidate[0].DriverDate,$candidate[0].UpdateId)

    $collection = New-Object -ComObject Microsoft.Update.UpdateColl
    [void]$collection.Add($update)

    if (-not [bool]$update.IsDownloaded) {
        $downloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
        $downloader.Updates = $collection
        $downloadResult = $downloader.Download()
        if ([int]$downloadResult.ResultCode -ne 2 -or -not [bool]$update.IsDownloaded) {
            throw ('Windows Update download did not complete successfully (result code {0}).' -f $downloadResult.ResultCode)
        }
    }

    $installer = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $installer.Updates = $collection
    $installer.AllowSourcePrompts = $false
    $installer.IsForced = $false
    $installationResult = $installer.Install()
    $resultCode = [int]$installationResult.ResultCode
    if ($resultCode -ne 2) {
        throw ('Windows Update driver install did not complete successfully (result code {0}). Check Device Manager and the restore point.' -f $resultCode)
    }

    $rebootRequired = [bool]$installationResult.RebootRequired
    $deviceIds = @($candidate[0].MatchedDevices | ForEach-Object { $_.DeviceId })
    $verification = New-Object 'System.Collections.Generic.List[object]'
    if (-not $rebootRequired) {
        $after = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop |
            Where-Object { $deviceIds -contains [string]$_.DeviceID })
        foreach ($device in $after) {
            $verification.Add([pscustomobject]@{
                DeviceName = [string]$device.DeviceName
                DriverVersion = [string]$device.DriverVersion
                DriverDate = if ($null -ne $device.DriverDate) { ([datetime]$device.DriverDate).ToString('yyyy-MM-dd') } else { '' }
            })
        }
        if ($verification.Count -eq 0) {
            throw 'The driver installation completed, but Windows did not return the affected device state. Check Device Manager before continuing.'
        }
    }

    Write-WnDriverUpdateLog -LogPath $LogPath -Message ('Windows Update install result: {0}; RebootRequired={1}' -f $resultCode,$rebootRequired)
    [pscustomobject]@{
        Title = [string]$candidate[0].Title
        HardwareId = [string]$candidate[0].HardwareId
        DriverDate = ([datetime]$candidate[0].DriverDate).ToString('yyyy-MM-dd')
        RebootRequired = $rebootRequired
        VerificationPendingUntilRestart = $rebootRequired
        VerifiedDevices = $verification.ToArray()
    }
}

Export-ModuleMember -Function Test-WnDriverCandidateApplicability, Get-WnWindowsUpdateDriverCandidates, Install-WnWindowsUpdateDriver
