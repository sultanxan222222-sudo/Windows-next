Set-StrictMode -Version Latest

function Test-WnAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-WnTaskLog {
    param([Parameter(Mandatory)][string]$Action)
    $directory = Join-Path $env:LOCALAPPDATA 'WindowsNext\Logs'
    [void][System.IO.Directory]::CreateDirectory($directory)
    $path = Join-Path $directory ("WindowsNext-{0}-{1}.log" -f $Action, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Set-Content -LiteralPath $path -Value ('Windows Next task: {0}' -f $Action) -Encoding UTF8
    return $path
}

function Write-WnTaskLog {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $Path -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8
}

function Invoke-WnNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $stdout = Join-Path $env:TEMP ("WindowsNext-{0}.stdout" -f [guid]::NewGuid().ToString('N'))
    $stderr = Join-Path $env:TEMP ("WindowsNext-{0}.stderr" -f [guid]::NewGuid().ToString('N'))
    try {
        Write-WnTaskLog -Path $LogPath -Message ("START {0}: {1}" -f $DisplayName, ($ArgumentList -join ' '))
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (Test-Path -LiteralPath $stdout) {
            Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue | Add-Content -LiteralPath $LogPath -Encoding UTF8
        }
        if (Test-Path -LiteralPath $stderr) {
            Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue | Add-Content -LiteralPath $LogPath -Encoding UTF8
        }
        Write-WnTaskLog -Path $LogPath -Message ("EXIT CODE {0}: {1}" -f $process.ExitCode, $DisplayName)
        return [int]$process.ExitCode
    }
    finally {
        Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-WnTempCleanup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LogPath)

    $tempRoot = Join-Path $env:LOCALAPPDATA 'Temp'
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        Write-WnTaskLog -Path $LogPath -Message 'User Temp directory does not exist; nothing to clean.'
        return [pscustomobject]@{ FilesDeleted = 0; BytesFreed = [long]0; Skipped = 0 }
    }

    $cutoff = (Get-Date).AddDays(-14)
    [long]$bytes = 0
    [int]$deleted = 0
    [int]$skipped = 0

    # The cleanup is deliberately restricted to the current user's LocalAppData\Temp.
    # Files newer than 14 days, reparse points, and inaccessible/in-use files are retained.
    $files = @(Get-ChildItem -LiteralPath $tempRoot -File -Recurse -Force -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        try {
            if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $skipped++
                continue
            }
            $fullName = [IO.Path]::GetFullPath($file.FullName)
            if (-not $fullName.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                $skipped++
                continue
            }
            if ($file.LastWriteTime -gt $cutoff) {
                continue
            }
            $length = [long]$file.Length
            Remove-Item -LiteralPath $fullName -Force -ErrorAction Stop
            $bytes += $length
            $deleted++
        }
        catch {
            $skipped++
            Write-WnTaskLog -Path $LogPath -Message ("Skipped file: {0} — {1}" -f $file.FullName, $_.Exception.Message)
        }
    }

    $result = [pscustomobject]@{
        FilesDeleted = $deleted
        BytesFreed = $bytes
        Skipped = $skipped
    }
    Write-WnTaskLog -Path $LogPath -Message ("Temporary cleanup completed. Files deleted: {0}; MB freed: {1}; skipped: {2}" -f $deleted, [math]::Round($bytes / 1MB, 2), $skipped)
    return $result
}

function Invoke-WnDriverBackup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Destination, [Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-WnAdministrator)) { throw 'Driver backup requires administrator rights.' }
    if ([string]::IsNullOrWhiteSpace($Destination)) { throw 'Backup destination is empty.' }
    [void][IO.Directory]::CreateDirectory($Destination)

    $drivers = @(Export-WindowsDriver -Online -Destination $Destination -ErrorAction Stop)
    if ($drivers.Count -lt 1) { throw 'Windows did not return any third-party driver packages to export.' }

    $index = @($drivers | Select-Object Driver, OriginalFileName, ProviderName, ClassName, Date, Version)
    $index | Export-Csv -LiteralPath (Join-Path $Destination 'WindowsNext-DriverIndex.csv') -NoTypeInformation -Encoding UTF8
    $index | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Destination 'WindowsNext-DriverIndex.json') -Encoding UTF8

    $hashes = New-Object 'System.Collections.Generic.List[object]'
    foreach ($file in @(Get-ChildItem -LiteralPath $Destination -File -Recurse -Force -ErrorAction Stop)) {
        $hashes.Add([pscustomobject]@{
            RelativePath = $file.FullName.Substring($Destination.TrimEnd('\').Length).TrimStart('\')
            Length = $file.Length
            SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        })
    }
    $hashes | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Destination 'SHA256-manifest.json') -Encoding UTF8

    Write-WnTaskLog -Path $LogPath -Message ("Exported driver packages: {0}" -f $drivers.Count)
    Write-WnTaskLog -Path $LogPath -Message ("Backup folder: {0}" -f $Destination)
    return [pscustomobject]@{ PackageCount = $drivers.Count; Destination = $Destination }
}

function Invoke-WnOptimizeVolume {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DriveLetter, [Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-WnAdministrator)) { throw 'Drive optimization requires administrator rights.' }
    if ($DriveLetter -notmatch '^[A-Z]$') { throw 'Invalid drive letter.' }
    $volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop
    if ($volume.DriveType -ne 'Fixed') { throw 'Only a fixed local drive may be optimized.' }
    if (-not (Get-Command Optimize-Volume -ErrorAction SilentlyContinue)) { throw 'Optimize-Volume is not available on this Windows installation.' }

    Write-WnTaskLog -Path $LogPath -Message ("Optimizing fixed volume {0}:; Windows chooses the suitable operation for its media type." -f $DriveLetter)
    Optimize-Volume -DriveLetter $DriveLetter -Verbose -ErrorAction Stop 4>&1 |
        Out-String | Add-Content -LiteralPath $LogPath -Encoding UTF8
    Write-WnTaskLog -Path $LogPath -Message 'Windows volume optimization completed.'
    return [pscustomobject]@{ DriveLetter = $DriveLetter; FileSystem = $volume.FileSystem; DriveType = [string]$volume.DriveType }
}

function Invoke-WnScanVolume {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DriveLetter, [Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-WnAdministrator)) { throw 'Drive scan requires administrator rights.' }
    if ($DriveLetter -notmatch '^[A-Z]$') { throw 'Invalid drive letter.' }
    $volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop
    if ($volume.FileSystem -ne 'NTFS') { throw 'Online scan is only enabled for NTFS volumes in this release.' }
    if (-not (Get-Command Repair-Volume -ErrorAction SilentlyContinue)) { throw 'Repair-Volume is not available on this Windows installation.' }

    Write-WnTaskLog -Path $LogPath -Message ("Running online scan on {0}: without scheduling an offline repair." -f $DriveLetter)
    Repair-Volume -DriveLetter $DriveLetter -Scan -ErrorAction Stop 4>&1 |
        Out-String | Add-Content -LiteralPath $LogPath -Encoding UTF8
    Write-WnTaskLog -Path $LogPath -Message 'Online volume scan completed.'
    return [pscustomobject]@{ DriveLetter = $DriveLetter; FileSystem = $volume.FileSystem }
}

function Invoke-WnWindowsHealthCheck {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-WnAdministrator)) { throw 'Windows component scan requires administrator rights.' }
    $dism = Join-Path $env:SystemRoot 'System32\dism.exe'
    $sfc = Join-Path $env:SystemRoot 'System32\sfc.exe'

    $dismCode = Invoke-WnNativeCommand -FilePath $dism -ArgumentList @('/Online', '/Cleanup-Image', '/ScanHealth') -LogPath $LogPath -DisplayName 'DISM ScanHealth'
    if ($dismCode -ne 0) { throw ("DISM ScanHealth failed with exit code {0}; SFC was not started." -f $dismCode) }

    $sfcCode = Invoke-WnNativeCommand -FilePath $sfc -ArgumentList @('/verifyonly') -LogPath $LogPath -DisplayName 'SFC VerifyOnly'
    if ($sfcCode -ne 0) { throw ("SFC VerifyOnly returned exit code {0}. See the log." -f $sfcCode) }

    Write-WnTaskLog -Path $LogPath -Message 'Windows health checks completed.'
    return [pscustomobject]@{ DISM = 'ScanHealth complete'; SFC = 'VerifyOnly complete' }
}

function Invoke-WnWindowsRepair {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-WnAdministrator)) { throw 'Windows repair requires administrator rights.' }
    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
        throw 'System Restore is not available. Repair was stopped before making changes.'
    }

    # Require a restore point before any repair operation. If System Protection is
    # disabled or Windows refuses the checkpoint, do not proceed.
    Checkpoint-Computer -Description 'Windows Next pre-repair' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-WnTaskLog -Path $LogPath -Message 'System restore point created.'

    $dism = Join-Path $env:SystemRoot 'System32\dism.exe'
    $sfc = Join-Path $env:SystemRoot 'System32\sfc.exe'
    $dismCode = Invoke-WnNativeCommand -FilePath $dism -ArgumentList @('/Online', '/Cleanup-Image', '/RestoreHealth') -LogPath $LogPath -DisplayName 'DISM RestoreHealth'
    if ($dismCode -ne 0) { throw ("DISM RestoreHealth failed with exit code {0}; SFC was not started." -f $dismCode) }

    $sfcCode = Invoke-WnNativeCommand -FilePath $sfc -ArgumentList @('/scannow') -LogPath $LogPath -DisplayName 'SFC Scannow'
    if ($sfcCode -ne 0) { throw ("SFC Scannow returned exit code {0}. See the log." -f $sfcCode) }

    Write-WnTaskLog -Path $LogPath -Message 'Windows repair completed.'
    return [pscustomobject]@{ RestorePointCreated = $true; DISM = 'RestoreHealth complete'; SFC = 'Scannow complete' }
}

function Invoke-WnCreateRestorePoint {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LogPath)
    if (-not (Test-WnAdministrator)) { throw 'Creating a restore point requires administrator rights.' }
    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) { throw 'System Restore is not available.' }
    Checkpoint-Computer -Description 'Windows Next manual restore point' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-WnTaskLog -Path $LogPath -Message 'Restore point created.'
    return [pscustomobject]@{ RestorePointCreated = $true }
}

function Invoke-WnMaintenanceAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CleanUserTemp', 'ExportDrivers', 'OptimizeVolume', 'ScanVolume', 'CheckWindows', 'RepairWindows', 'CreateRestorePoint', 'InstallVCRuntime', 'CheckDriverUpdates', 'InstallSelectedDriver')]
        [string]$Action,
        [string]$Destination,
        [string]$DriveLetter,
        [string]$SelectionFile
    )

    $logPath = New-WnTaskLog -Action $Action
    Write-WnTaskLog -Path $logPath -Message 'Task started.'
    try {
        $result = switch ($Action) {
            'CleanUserTemp' { Invoke-WnTempCleanup -LogPath $logPath }
            'ExportDrivers' { Invoke-WnDriverBackup -Destination $Destination -LogPath $logPath }
            'OptimizeVolume' { Invoke-WnOptimizeVolume -DriveLetter $DriveLetter -LogPath $logPath }
            'ScanVolume' { Invoke-WnScanVolume -DriveLetter $DriveLetter -LogPath $logPath }
            'CheckWindows' { Invoke-WnWindowsHealthCheck -LogPath $logPath }
            'RepairWindows' { Invoke-WnWindowsRepair -LogPath $logPath }
            'CreateRestorePoint' { Invoke-WnCreateRestorePoint -LogPath $logPath }
            'InstallVCRuntime' { Invoke-WnInstallVCRuntime -LogPath $logPath }
            'CheckDriverUpdates' {
                $candidates = @(Get-WnWindowsUpdateDriverCandidates)
                Write-WnTaskLog -Path $logPath -Message ('Windows Update returned {0} candidates that match an exact Hardware ID and have a newer driver date.' -f $candidates.Count)
                [pscustomobject]@{ CandidateCount=$candidates.Count; Candidates=$candidates }
            }
            'InstallSelectedDriver' {
                if (-not (Test-WnAdministrator)) { throw 'Driver installation requires administrator rights.' }
                if ([string]::IsNullOrWhiteSpace($SelectionFile)) { throw 'Driver selection file is missing.' }

                $selectionRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'WindowsNext\Selections')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
                $selectionPath = [IO.Path]::GetFullPath($SelectionFile)
                if (-not $selectionPath.StartsWith($selectionRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Driver selection file is outside the Windows Next selection folder.' }
                if (-not (Test-Path -LiteralPath $selectionPath -PathType Leaf)) { throw 'Driver selection file was not found.' }

                $selection = Get-Content -LiteralPath $selectionPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $ids = @($selection.UpdateIds | ForEach-Object { [string]$_ })
                if ($ids.Count -ne 1) { throw 'Exactly one driver must be selected per operation. Install, restart if required, and test before choosing the next driver.' }
                $parsedId = [guid]::Empty
                if (-not [guid]::TryParse($ids[0],[ref]$parsedId)) { throw 'The selected Windows Update ID is invalid.' }

                $systemDrive = $env:SystemDrive
                $systemDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $systemDrive) -ErrorAction Stop
                if ($null -eq $systemDisk -or [long]$systemDisk.FreeSpace -lt 2GB) { throw 'At least 2 GB of free space is required on the Windows drive. No driver was changed.' }

                try {
                    $stillAvailable = @(Get-WnWindowsUpdateDriverCandidates | Where-Object { [guid]$_.UpdateId -eq $parsedId })
                    if ($stillAvailable.Count -ne 1) { throw 'The selected driver is no longer applicable. No driver was changed.' }

                    $backupFolder = Join-Path ([Environment]::GetFolderPath('MyDocuments')) ('WindowsNext\DriverBackup\Before-WU-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
                    $backup = Invoke-WnDriverBackup -Destination $backupFolder -LogPath $logPath
                    $restore = Invoke-WnCreateRestorePoint -LogPath $logPath
                    $installed = Install-WnWindowsUpdateDriver -UpdateId $parsedId -LogPath $logPath
                    [pscustomobject]@{
                        BackupPath = $backup.Destination
                        DriverPackageCount = $backup.PackageCount
                        RestorePointCreated = [bool]$restore.RestorePointCreated
                        Installation = $installed
                    }
                }
                finally {
                    Remove-Item -LiteralPath $selectionPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Write-WnTaskLog -Path $logPath -Message 'Task completed successfully.'
        return [pscustomobject]@{ Success = $true; Action = $Action; LogPath = $logPath; Result = $result; Error = $null }
    }
    catch {
        Write-WnTaskLog -Path $logPath -Message ("ERROR: {0}" -f $_.Exception.Message)
        return [pscustomobject]@{ Success = $false; Action = $Action; LogPath = $logPath; Result = $null; Error = $_.Exception.Message }
    }
}

Export-ModuleMember -Function Test-WnAdministrator, Invoke-WnMaintenanceAction
