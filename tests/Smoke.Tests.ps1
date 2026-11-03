BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Inventory.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Report.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\ComponentPlan.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Maintenance.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Performance.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Startup.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Components.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\DriverUpdates.psm1') -Force
}

Describe 'Windows Next source validation' {
    It 'parses every PowerShell source file without syntax errors' {
        $sourceFiles = @(
            Get-ChildItem -Path (Join-Path $script:ProjectRoot 'src') -Recurse -File |
                Where-Object { $_.Extension -in @('.ps1', '.psm1') }
        )

        $sourceFiles.Count | Should -BeGreaterThan 0
        foreach ($file in $sourceFiles) {
            $tokens = $null
            $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            )
            $parseErrors | Should -BeNullOrEmpty -Because $file.FullName
        }
    }

    It 'exposes the maintenance task engine' {
        (Get-Command Invoke-WnMaintenanceAction -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command Test-WnAdministrator -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It 'uses the maintenance center as the product entry point' {
        $app = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\WindowsNext.ps1') -Raw
        $app | Should -Match 'Windows Next — центр обслуживания'
        $app | Should -Match 'RepairWindows'
        $app | Should -Match 'ExportDrivers'
        $app | Should -Match 'Update-WnVolumePicker'
        $app | Should -Match 'OptimizeVolume'
    }

    It 'exposes the read-only inventory and component planner' {
        (Get-Command Get-WnAudit -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command Get-WnComponentPlan -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It 'provides a read-only performance assessment without changing settings' {
        $assessment = Get-WnPerformanceAssessment
        $assessment.Mode | Should -Be 'ReadOnly'
        $assessment.ChangesMade | Should -BeFalse
        $assessment.Findings.Count | Should -BeGreaterThan 0
        ($assessment.Findings | Where-Object { $_.Area -eq 'Автозагрузка' }).Count | Should -Be 1
    }

    It 'shows performance assessment in the main dashboard' {
        $app = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\\WindowsNext.ps1') -Raw
        $app | Should -Match 'Get-WnPerformanceAssessment'
        $app | Should -Match 'ОЦЕНКА ПРОИЗВОДИТЕЛЬНОСТИ'
    }

    It 'exports JSON and TXT reports from a supplied fixture' {
        $fixture = [pscustomobject]@{
            SchemaVersion = '1.1'
            ToolVersion = 'test'
            CollectionMode = 'ReadOnly'
            CollectedAtUtc = '2026-01-01T00:00:00Z'
            OperatingSystem = [pscustomobject]@{
                Caption = 'Test Windows'
                Version = '10.0'
                BuildNumber = '99999'
                Architecture = '64-bit'
            }
            System = [pscustomobject]@{
                Manufacturer = 'Test'
                Model = 'Fixture'
                MemoryGB = 8
                SystemType = 'x64-based PC'
            }
            Processor = [pscustomobject]@{
                Name = 'Test CPU'
                NumberOfCores = 2
                NumberOfLogicalProcessors = 4
                MaxClockSpeedMHz = 2500
            }
            Graphics = @()
            Storage = @()
            Memory = [pscustomobject]@{ Modules = @(); Arrays = @() }
            NetworkDevices = @()
            ActivePowerPlan = 'Test plan'
            SecureBoot = 'Unknown'
        }

        $target = Join-Path $TestDrive 'reports'
        $result = Export-WnAuditReport -Audit $fixture -OutputDirectory $target

        Test-Path -LiteralPath $result.JsonPath | Should -BeTrue
        Test-Path -LiteralPath $result.TextPath | Should -BeTrue
        (Get-Content -LiteralPath $result.JsonPath -Raw) | Should -Match '"ToolVersion"'
        (Get-Content -LiteralPath $result.TextPath -Raw) | Should -Match 'WINDOWS NEXT'
    }

    It 'never authorizes unapproved hardware packages for automatic installation' {
        $manifestPath = Join-Path $TestDrive 'components.json'
        @{
            schemaVersion = 2
            components = @(
                @{
                    id = 'test-gpu'
                    displayName = 'Test GPU'
                    inventoryClass = 'Graphics'
                    expectedHardwareIdPrefix = 'PCI\VEN_1234&DEV_5678'
                    approvalStatus = 'blocked'
                    packages = @()
                    blockReason = 'Not approved for this test.'
                }
            )
        } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

        $audit = [pscustomobject]@{
            OperatingSystem = [pscustomobject]@{
                DisplayVersion = '21H2'
                BuildNumber = '22000'
            }
            Graphics = @(
                [pscustomobject]@{
                    Name = 'Test GPU'
                    InstanceId = 'PCI\VEN_1234&DEV_5678&SUBSYS_00000000\1'
                    HardwareIds = @('PCI\VEN_1234&DEV_5678&SUBSYS_00000000')
                    DriverVersion = '1.0.0.0'
                }
            )
            NetworkDevices = @()
        }

        $plan = Get-WnComponentPlan -Audit $audit -ManifestPath $manifestPath
        $plan.InstallationEnabled | Should -BeFalse
        $plan.Warnings[0] | Should -Match 'ended servicing'
        $plan.Components[0].Decision | Should -Be 'KEEP_CURRENT'
        $plan.Components[0].AutomaticInstall | Should -BeFalse
    }

    It 'backs up and restores a user startup entry without overwriting an existing value' {
        $backupDirectory = Join-Path $TestDrive 'startup-backups'
        $valueName = 'WindowsNext-Pester-' + [guid]::NewGuid().ToString('N')
        $originalValue = '"C:\Windows\System32\notepad.exe" --windows-next-test'
        $registryPath = 'Software\Microsoft\Windows\CurrentVersion\Run'
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($registryPath)
        try {
            $key.SetValue($valueName, $originalValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            $entry = @(Get-WnStartupEntries | Where-Object { $_.Name -eq $valueName })
            $entry.Count | Should -Be 1
            $entry[0].CanDisable | Should -BeTrue

            $disabled = Disable-WnStartupEntry -Entry $entry[0] -BackupDirectory $backupDirectory
            $disabled.Disabled | Should -BeTrue
            $key.GetValueNames() | Should -Not -Contain $valueName
            Test-Path -LiteralPath $disabled.BackupFile | Should -BeTrue

            $restored = Restore-WnStartupEntry -BackupFile $disabled.BackupFile -BackupDirectory $backupDirectory
            $restored.Restored | Should -BeTrue
            $key.GetValue($valueName, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) | Should -Be $originalValue
            $key.GetValueKind($valueName) | Should -Be ([Microsoft.Win32.RegistryValueKind]::ExpandString)
        }
        finally {
            $key.DeleteValue($valueName, $false)
            $key.Dispose()
        }
    }

    It 'refuses to disable machine-wide startup entries' {
        $entry = [pscustomobject]@{
            Name = 'ProtectedMachineEntry'
            Command = 'example.exe'
            RegistryPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
            CanDisable = $false
        }
        { Disable-WnStartupEntry -Entry $entry -BackupDirectory (Join-Path $TestDrive 'blocked') } | Should -Throw
    }


    It 'reports Visual C++ x86 and x64 runtime status without changing the system' {
        $status = @(Get-WnVCRuntimeStatus)
        $status.Count | Should -Be 2
        ($status | Where-Object { $_.Architecture -eq 'x86' }).Count | Should -Be 1
        ($status | Where-Object { $_.Architecture -eq 'x64' }).Count | Should -Be 1
        ($status | Where-Object { $_.RegistryPath -notmatch '^HKLM:' }).Count | Should -Be 0
    }

    It 'uses Microsoft-owned HTTPS endpoints for Visual C++ runtime packages' {
        $module = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\Modules\Components.psm1') -Raw
        $module | Should -Match 'https://aka\.ms/vc14/vc_redist\.x64\.exe'
        $module | Should -Match 'https://aka\.ms/vc14/vc_redist\.x86\.exe'
        $module | Should -Match 'Get-AuthenticodeSignature'
        $module | Should -Match 'Microsoft Corporation'
    }


    It 'accepts only an exact hardware ID with a newer Windows Update driver date' {
        $deviceId = 'PCI\VEN_8086&DEV_0416&SUBSYS_07811025&REV_06'
        Test-WnDriverCandidateApplicability -DeviceHardwareIds @($deviceId,'PCI\VEN_8086&DEV_0416') -UpdateHardwareId $deviceId -CurrentDriverDate ([datetime]'2015-08-04') -UpdateDriverDate ([datetime]'2020-01-01') | Should -BeTrue
    }

    It 'rejects compatible or partial hardware IDs instead of treating them as exact matches' {
        $deviceId = 'PCI\VEN_8086&DEV_0416&SUBSYS_07811025&REV_06'
        Test-WnDriverCandidateApplicability -DeviceHardwareIds @($deviceId) -UpdateHardwareId 'PCI\VEN_8086&DEV_0416' -CurrentDriverDate ([datetime]'2015-08-04') -UpdateDriverDate ([datetime]'2020-01-01') | Should -BeFalse
    }

    It 'rejects Windows Update drivers with an equal or older driver date' {
        $deviceId = 'PCI\VEN_10DE&DEV_0FE4&SUBSYS_07811025'
        Test-WnDriverCandidateApplicability -DeviceHardwareIds @($deviceId) -UpdateHardwareId $deviceId -CurrentDriverDate ([datetime]'2016-12-29') -UpdateDriverDate ([datetime]'2016-12-29') | Should -BeFalse
        Test-WnDriverCandidateApplicability -DeviceHardwareIds @($deviceId) -UpdateHardwareId $deviceId -CurrentDriverDate ([datetime]'2016-12-29') -UpdateDriverDate ([datetime]'2014-01-01') | Should -BeFalse
    }

    It 'verifies the resulting driver date and Device Manager status after installation' {
        $module = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\Modules\DriverUpdates.psm1') -Raw
        $module | Should -Match 'NewerThanPreviousDriver'
        $module | Should -Match 'DeviceManagerStatusOK'
        $module | Should -Match 'ConfigManagerErrorCode'
        $module | Should -Match 'DriverSignaturePresent'
        $module | Should -Match '\$session\.CreateUpdateDownloader\(\)'
        $module | Should -Match '\$session\.CreateUpdateInstaller\(\)'
    }

    It 'restricts automated driver discovery to Windows Update driver entries' {
        $module = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\Modules\DriverUpdates.psm1') -Raw
        $module | Should -Match "IsInstalled=0 and Type='Driver' and IsHidden=0"
        $module | Should -Match 'IncludePotentiallySupersededUpdates'
        $module | Should -Match 'Install-WnWindowsUpdateDriver'
        $maintenance = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\Modules\Maintenance.psm1') -Raw
        $maintenance | Should -Match 'At least 2 GB of free space'
    }


    It 'enables only the built-in NetFx3 optional feature without forcing a reboot' {
        $module = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\Modules\Components.psm1') -Raw
        $module | Should -Match '/Enable-Feature'
        $module | Should -Match '/FeatureName:NetFx3'
        $module | Should -Match '/NoRestart'
        $module | Should -Match 'Get-WindowsOptionalFeature'
        $module | Should -Match 'NetFx3 state after operation'
    }


    It 'does not recurse into Temp subfolders or junctions during cleanup' {
        $module = Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'src\Modules\Maintenance.psm1') -Raw
        $module | Should -Match 'Get-ChildItem -LiteralPath \$tempRoot -File -Force'
        $module | Should -Not -Match 'Get-ChildItem -LiteralPath \$tempRoot -File -Recurse'
    }

}
