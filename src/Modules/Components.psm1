Set-StrictMode -Version Latest

function Get-WnVCRuntimeStatus {
    [CmdletBinding()]
    param()

    $items = New-Object 'System.Collections.Generic.List[object]'
    $architectures = @(
        [pscustomobject]@{ Architecture='x86'; RegistryPath='HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86' },
        [pscustomobject]@{ Architecture='x64'; RegistryPath='HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' }
    )
    foreach ($item in $architectures) {
        if ($item.Architecture -eq 'x64' -and -not [Environment]::Is64BitOperatingSystem) { continue }
        $installed = $false
        $version = ''
        try {
            $state = Get-ItemProperty -LiteralPath $item.RegistryPath -ErrorAction Stop
            $installed = ([int]$state.Installed -eq 1)
            $version = [string]$state.Version
            if ($version.StartsWith('v')) { $version = $version.Substring(1) }
        } catch { }
        $items.Add([pscustomobject]@{
            Architecture = $item.Architecture
            Installed = $installed
            Version = $version
            RegistryPath = $item.RegistryPath
        })
    }
    return $items.ToArray()
}

function Test-WnAdministratorForComponents {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-WnComponentLog {
    param([Parameter(Mandatory)][string]$LogPath,[Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $LogPath -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message) -Encoding UTF8
}

function Invoke-WnInstallVCRuntime {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-WnAdministratorForComponents)) { throw 'Установка библиотек Visual C++ требует подтверждения UAC администратора.' }
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Этот пакет рассчитан на 64-разрядную Windows.' }

    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    $downloadDirectory = Join-Path $env:TEMP ('WindowsNext-VCRuntime-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($downloadDirectory)
    $results = New-Object 'System.Collections.Generic.List[object]'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        foreach ($architecture in @('x64','x86')) {
            $url = if ($architecture -eq 'x64') { 'https://aka.ms/vc14/vc_redist.x64.exe' } else { 'https://aka.ms/vc14/vc_redist.x86.exe' }
            $file = Join-Path $downloadDirectory ('vc_redist.{0}.exe' -f $architecture)
            Write-WnComponentLog -LogPath $LogPath -Message ('Загрузка официального Microsoft Visual C++ Runtime: {0}' -f $architecture)
            Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -lt 1MB) {
                throw ('Загруженный установщик {0} отсутствует или имеет подозрительно малый размер.' -f $architecture)
            }

            $signature = Get-AuthenticodeSignature -FilePath $file
            if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
                $null -eq $signature.SignerCertificate -or
                $signature.SignerCertificate.Subject -notmatch '(^|,\s*)CN=Microsoft Corporation(,|$)') {
                throw ('Подпись установщика {0} не подтверждена сертификатом Microsoft Corporation. Установка отменена.' -f $architecture)
            }

            $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
            $fileVersionText = [string](Get-Item -LiteralPath $file).VersionInfo.ProductVersion
            if ([string]::IsNullOrWhiteSpace($fileVersionText)) { $fileVersionText = [string](Get-Item -LiteralPath $file).VersionInfo.FileVersion }
            $targetVersion = [version]($fileVersionText -replace '[^0-9.].*$','')
            $installedState = @(Get-WnVCRuntimeStatus | Where-Object { $_.Architecture -eq $architecture }) | Select-Object -First 1
            $installedVersion = $null
            if ($installedState.Installed -and $installedState.Version -match '^\d+(\.\d+){1,3}$') {
                try { $installedVersion = [version]$installedState.Version } catch { }
            }

            if ($null -ne $installedVersion -and $installedVersion -ge $targetVersion) {
                Write-WnComponentLog -LogPath $LogPath -Message ('{0}: уже установлена версия {1}; загрузка проверена, изменений не требуется. SHA256={2}' -f $architecture,$installedVersion,$hash)
                $results.Add([pscustomobject]@{ Architecture=$architecture; Status='AlreadyCurrent'; Version=[string]$installedVersion; SHA256=$hash; RebootRequired=$false })
                continue
            }

            Write-WnComponentLog -LogPath $LogPath -Message ('Проверена подпись Microsoft; версия пакета {0}; SHA256={1}' -f $targetVersion,$hash)
            $process = Start-Process -FilePath $file -ArgumentList '/install /quiet /norestart' -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -notin @(0,3010)) {
                throw ('Установщик Visual C++ {0} завершился с кодом {1}.' -f $architecture,$process.ExitCode)
            }

            $after = @(Get-WnVCRuntimeStatus | Where-Object { $_.Architecture -eq $architecture }) | Select-Object -First 1
            $afterVersion = $null
            if ($after.Installed -and $after.Version -match '^\d+(\.\d+){1,3}$') {
                try { $afterVersion = [version]$after.Version } catch { }
            }
            if ($null -eq $afterVersion -or $afterVersion -lt $targetVersion) {
                throw ('После установки {0} Windows не подтвердила версию Runtime {1}.' -f $architecture,$targetVersion)
            }

            $reboot = ($process.ExitCode -eq 3010)
            Write-WnComponentLog -LogPath $LogPath -Message ('{0}: успешно установлена версия {1}; перезагрузка требуется: {2}' -f $architecture,$afterVersion,$reboot)
            $results.Add([pscustomobject]@{ Architecture=$architecture; Status='Installed'; Version=[string]$afterVersion; SHA256=$hash; RebootRequired=$reboot })
        }
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
        Remove-Item -LiteralPath $downloadDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    [pscustomobject]@{
        Components = @($results)
        RebootRequired = [bool](@($results | Where-Object { $_.RebootRequired }).Count -gt 0)
    }
}

Export-ModuleMember -Function Get-WnVCRuntimeStatus, Invoke-WnInstallVCRuntime
