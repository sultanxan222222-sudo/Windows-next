BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Inventory.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\Report.psm1') -Force
    Import-Module (Join-Path $script:ProjectRoot 'src\Modules\ComponentPlan.psm1') -Force
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

    It 'exposes the read-only inventory and component planner' {
        (Get-Command Get-WnAudit -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command Get-WnComponentPlan -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
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
}
