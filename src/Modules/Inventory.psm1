Set-StrictMode -Version Latest

function Get-WnSafeCim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClassName,
        [string]$Filter
    )
    try {
        if ([string]::IsNullOrWhiteSpace($Filter)) {
            return @(Get-CimInstance -ClassName $ClassName -ErrorAction Stop)
        }
        return @(Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

function Get-WnDisplayDevices {
    [CmdletBinding()]
    param()

    $signedDrivers = @(Get-WnSafeCim -ClassName 'Win32_PnPSignedDriver' -Filter "DeviceClass = 'DISPLAY'")
    $items = @()

    foreach ($driver in $signedDrivers) {
        $hardwareIds = @()
        $instanceId = [string]$driver.DeviceID

        if (-not [string]::IsNullOrWhiteSpace($instanceId) -and
            (Get-Command -Name Get-PnpDeviceProperty -ErrorAction SilentlyContinue)) {
            try {
                $property = Get-PnpDeviceProperty -InstanceId $instanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop
                if ($null -ne $property.Data) {
                    $hardwareIds = @($property.Data | ForEach-Object { [string]$_ })
                }
            }
            catch {
                # Do not substitute guessed hardware identifiers.
            }
        }

        $driverDate = $null
        try {
            if ($null -ne $driver.DriverDate) {
                $driverDate = ([datetime]$driver.DriverDate).ToString('yyyy-MM-dd')
            }
        }
        catch {
            $driverDate = $null
        }

        $items += [pscustomobject]@{
            Name          = [string]$driver.DeviceName
            Manufacturer  = [string]$driver.Manufacturer
            InstanceId    = $instanceId
            HardwareIds   = $hardwareIds
            DriverVersion = [string]$driver.DriverVersion
            DriverDate    = $driverDate
            InfName       = [string]$driver.InfName
            IsSigned      = $driver.IsSigned
            Source        = 'Win32_PnPSignedDriver'
        }
    }

    if ($items.Count -eq 0) {
        foreach ($controller in @(Get-WnSafeCim -ClassName 'Win32_VideoController')) {
            $instanceId = [string]$controller.PNPDeviceID
            $fallbackIds = @()
            if (-not [string]::IsNullOrWhiteSpace($instanceId)) {
                $fallbackIds = @($instanceId)
            }
            $items += [pscustomobject]@{
                Name          = [string]$controller.Name
                Manufacturer  = [string]$controller.AdapterCompatibility
                InstanceId    = $instanceId
                HardwareIds   = $fallbackIds
                DriverVersion = [string]$controller.DriverVersion
                DriverDate    = $null
                InfName       = $null
                IsSigned      = $null
                Source        = 'Win32_VideoController fallback'
            }
        }
    }

    return @($items)
}

function Get-WnStorageDevices {
    [CmdletBinding()]
    param()

    $items = @()
    if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        try {
            foreach ($disk in @(Get-PhysicalDisk -ErrorAction Stop)) {
                $sizeGb = $null
                if ($disk.Size) {
                    $sizeGb = [math]::Round(([double]$disk.Size / 1GB), 1)
                }
                $items += [pscustomobject]@{
                    Model             = [string]$disk.FriendlyName
                    MediaType         = [string]$disk.MediaType
                    BusType           = [string]$disk.BusType
                    SizeGB            = $sizeGb
                    HealthStatus      = [string]$disk.HealthStatus
                    OperationalStatus = (@($disk.OperationalStatus) -join ', ')
                    Source            = 'Get-PhysicalDisk'
                }
            }
        }
        catch {
            # Fall back to read-only CIM inventory.
        }
    }

    if ($items.Count -eq 0) {
        foreach ($disk in @(Get-WnSafeCim -ClassName 'Win32_DiskDrive')) {
            $sizeGb = $null
            if ($disk.Size) {
                $sizeGb = [math]::Round(([double]$disk.Size / 1GB), 1)
            }
            $items += [pscustomobject]@{
                Model             = [string]$disk.Model
                MediaType         = [string]$disk.MediaType
                BusType           = [string]$disk.InterfaceType
                SizeGB            = $sizeGb
                HealthStatus      = [string]$disk.Status
                OperationalStatus = $null
                Source            = 'Win32_DiskDrive'
            }
        }
    }

    return @($items)
}

function Get-WnMemoryInventory {
    [CmdletBinding()]
    param()

    $modules = @()
    foreach ($module in @(Get-WnSafeCim -ClassName 'Win32_PhysicalMemory')) {
        $capacityGb = $null
        if ($module.Capacity) {
            $capacityGb = [math]::Round(([double]$module.Capacity / 1GB), 2)
        }
        $modules += [pscustomobject]@{
            Manufacturer         = [string]$module.Manufacturer
            PartNumber            = ([string]$module.PartNumber).Trim()
            CapacityGB            = $capacityGb
            SpeedMHz               = $module.Speed
            ConfiguredClockSpeedMHz = $module.ConfiguredClockSpeed
            DeviceLocator          = [string]$module.DeviceLocator
            BankLabel              = [string]$module.BankLabel
            MemoryType             = $module.SMBIOSMemoryType
        }
    }

    $arrays = @(Get-WnSafeCim -ClassName 'Win32_PhysicalMemoryArray')
    $arrayInfo = @()
    foreach ($array in $arrays) {
        $maximumGb = $null
        # Win32_PhysicalMemoryArray.MaxCapacity is reported in kilobytes.
        if ($array.MaxCapacity) {
            $maximumGb = [math]::Round(([double]$array.MaxCapacity / 1MB), 1)
        }
        $arrayInfo += [pscustomobject]@{
            MemoryDevices       = $array.MemoryDevices
            ReportedMaxCapacityGB = $maximumGb
            Location            = $array.Location
            Use                 = $array.Use
        }
    }

    [pscustomobject]@{
        Modules = @($modules)
        Arrays  = @($arrayInfo)
    }
}

function Get-WnNetworkDevices {
    [CmdletBinding()]
    param()

    $items = @()
    $drivers = @(Get-WnSafeCim -ClassName 'Win32_PnPSignedDriver')
    foreach ($driver in $drivers) {
        $class = [string]$driver.DeviceClass
        if ($class -notin @('NET', 'BLUETOOTH')) {
            continue
        }

        $name = [string]$driver.DeviceName
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $driverDate = $null
        if ($null -ne $driver.DriverDate) {
            try { $driverDate = ([datetime]$driver.DriverDate).ToString('yyyy-MM-dd') } catch { $driverDate = $null }
        }

        $items += [pscustomobject]@{
            Name          = $name
            Class         = $class
            Manufacturer  = [string]$driver.Manufacturer
            InstanceId    = [string]$driver.DeviceID
            DriverVersion = [string]$driver.DriverVersion
            DriverDate    = $driverDate
            InfName       = [string]$driver.InfName
            IsSigned      = $driver.IsSigned
        }
    }

    return @($items)
}

function Get-WnActivePowerPlan {
    [CmdletBinding()]
    param()

    $powerCfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
    if (-not (Test-Path -LiteralPath $powerCfg)) {
        return $null
    }
    try {
        $output = & $powerCfg /getactivescheme 2>$null
        if ($LASTEXITCODE -eq 0) {
            return (($output | Out-String).Trim())
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-WnAudit {
    [CmdletBinding()]
    param()

    $os = @(Get-WnSafeCim -ClassName 'Win32_OperatingSystem') | Select-Object -First 1
    $computer = @(Get-WnSafeCim -ClassName 'Win32_ComputerSystem') | Select-Object -First 1
    $processors = @(Get-WnSafeCim -ClassName 'Win32_Processor')
    $cpu = $processors | Select-Object -First 1

    $memoryGb = $null
    if ($null -ne $computer -and $computer.TotalPhysicalMemory) {
        $memoryGb = [math]::Round(([double]$computer.TotalPhysicalMemory / 1GB), 2)
    }

    $secureBoot = 'Unknown'
    if (Get-Command -Name Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
        try {
            $secureBoot = [string](Confirm-SecureBootUEFI -ErrorAction Stop)
        }
        catch {
            $secureBoot = 'Unavailable on this system or access was denied'
        }
    }

    $osInfo = $null
    if ($null -ne $os) {
        $installDate = $null
        $displayVersion = $null
        if ($os.InstallDate) {
            try { $installDate = ([datetime]$os.InstallDate).ToString('yyyy-MM-dd') } catch { $installDate = $null }
        }
        try {
            $currentVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction Stop
            $displayVersion = [string]$currentVersion.DisplayVersion
        }
        catch {
            $displayVersion = $null
        }
        $osInfo = [pscustomobject]@{
            Caption        = [string]$os.Caption
            Version        = [string]$os.Version
            DisplayVersion = $displayVersion
            BuildNumber    = [string]$os.BuildNumber
            Architecture   = [string]$os.OSArchitecture
            InstallDate    = $installDate
        }
    }

    $systemInfo = $null
    if ($null -ne $computer) {
        $systemInfo = [pscustomobject]@{
            Manufacturer = [string]$computer.Manufacturer
            Model        = [string]$computer.Model
            SystemType   = [string]$computer.SystemType
            MemoryGB     = $memoryGb
        }
    }

    $cpuInfo = $null
    if ($null -ne $cpu) {
        $cpuInfo = [pscustomobject]@{
            Name                     = [string]$cpu.Name
            Manufacturer             = [string]$cpu.Manufacturer
            NumberOfCores             = $cpu.NumberOfCores
            NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockSpeedMHz          = $cpu.MaxClockSpeed
        }
    }

    [pscustomobject]@{
        SchemaVersion   = '1.1'
        ToolVersion     = '0.2.0'
        CollectedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        CollectionMode  = 'ReadOnly'
        OperatingSystem = $osInfo
        System          = $systemInfo
        Processor       = $cpuInfo
        Graphics        = @(Get-WnDisplayDevices)
        Storage         = @(Get-WnStorageDevices)
        Memory          = Get-WnMemoryInventory
        NetworkDevices  = @(Get-WnNetworkDevices)
        ActivePowerPlan = Get-WnActivePowerPlan
        SecureBoot      = $secureBoot
        Privacy         = [pscustomobject]@{
            SerialNumbersCollected     = $false
            ProductKeysCollected       = $false
            UsernamesCollected         = $false
            NetworkAddressesCollected  = $false
            PersonalFileNamesCollected = $false
        }
        Notes = @(
            'This inventory reads system metadata only.',
            'It does not install, remove, or modify drivers or Windows settings.',
            'Hardware profiles are planning hints and never authorize driver installation.'
        )
    }
}

Export-ModuleMember -Function Get-WnAudit
