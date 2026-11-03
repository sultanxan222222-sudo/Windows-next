Set-StrictMode -Version Latest

$script:WnUserRunSubKey = 'Software\Microsoft\Windows\CurrentVersion\Run'
$script:WnUserRunPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

function Get-WnStartupEntries {
    [CmdletBinding()]
    param()

    $entries = New-Object 'System.Collections.Generic.List[object]'
    $sources = @(
        [pscustomobject]@{ Scope='Текущий пользователь'; Root=[Microsoft.Win32.Registry]::CurrentUser; SubKey=$script:WnUserRunSubKey; CanDisable=$true },
        [pscustomobject]@{ Scope='Все пользователи'; Root=[Microsoft.Win32.Registry]::LocalMachine; SubKey='Software\Microsoft\Windows\CurrentVersion\Run'; CanDisable=$false },
        [pscustomobject]@{ Scope='Все пользователи (32-bit)'; Root=[Microsoft.Win32.Registry]::LocalMachine; SubKey='Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; CanDisable=$false }
    )

    foreach ($source in $sources) {
        $key = $null
        try {
            $key = $source.Root.OpenSubKey($source.SubKey, $false)
            if ($null -eq $key) { continue }
            foreach ($name in $key.GetValueNames()) {
                try {
                    $kind = $key.GetValueKind($name)
                    if ($kind -notin @([Microsoft.Win32.RegistryValueKind]::String, [Microsoft.Win32.RegistryValueKind]::ExpandString)) { continue }
                    $value = [string]$key.GetValue($name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    $identity = '{0}|{1}|{2}' -f $source.Root.Name, $source.SubKey, $name
                    $sha = [System.Security.Cryptography.SHA256]::Create()
                    try {
                        $id = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)))).Replace('-', '').Substring(0,16)
                    } finally { $sha.Dispose() }
                    $entries.Add([pscustomobject]@{
                        Id = $id
                        Name = [string]$name
                        Command = $value
                        Scope = $source.Scope
                        RegistryPath = if ($source.Root -eq [Microsoft.Win32.Registry]::CurrentUser) { $script:WnUserRunPath } else { 'HKLM:\' + $source.SubKey }
                        ValueKind = [string]$kind
                        CanDisable = [bool]$source.CanDisable
                        Status = if ($source.CanDisable) { 'Можно отключить с резервной копией' } else { 'Только просмотр — системная запись' }
                    })
                } catch { }
            }
        } catch { }
        finally { if ($null -ne $key) { $key.Dispose() } }
    }

    return @($entries | Sort-Object Scope, Name)
}

function Disable-WnStartupEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Entry,
        [Parameter(Mandatory)][string]$BackupDirectory
    )

    if (-not $Entry.CanDisable -or [string]$Entry.RegistryPath -ne $script:WnUserRunPath) {
        throw 'Отключать разрешено только записи автозапуска текущего пользователя.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$Entry.Name)) { throw 'Имя записи автозапуска пустое.' }
    if ([string]::IsNullOrWhiteSpace($BackupDirectory)) { throw 'Не задана папка резервных копий.' }

    [void][IO.Directory]::CreateDirectory($BackupDirectory)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:WnUserRunSubKey, $true)
    if ($null -eq $key) { throw 'Раздел автозагрузки текущего пользователя не найден.' }
    $backupFile = Join-Path $BackupDirectory ('{0}.json' -f [guid]::NewGuid().ToString('N'))
    try {
        if (-not ($key.GetValueNames() -contains [string]$Entry.Name)) {
            throw 'Запись уже изменилась или была удалена. Обновите список автозагрузки.'
        }
        $kind = $key.GetValueKind([string]$Entry.Name)
        if ($kind -notin @([Microsoft.Win32.RegistryValueKind]::String, [Microsoft.Win32.RegistryValueKind]::ExpandString)) {
            throw 'Тип этой записи не поддерживается безопасным резервированием.'
        }
        $currentValue = [string]$key.GetValue([string]$Entry.Name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($currentValue -cne [string]$Entry.Command -or [string]$kind -ne [string]$Entry.ValueKind) {
            throw 'Команда записи изменилась после просмотра. Обновите список и проверьте её ещё раз.'
        }

        $backup = [pscustomobject]@{
            SchemaVersion = 1
            Product = 'Windows Next'
            CreatedAtUtc = [DateTime]::UtcNow.ToString('o')
            RegistryPath = $script:WnUserRunPath
            Name = [string]$Entry.Name
            Value = $currentValue
            ValueKind = [string]$kind
        }
        $temporary = $backupFile + '.tmp'
        $backup | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporary -Encoding UTF8
        Move-Item -LiteralPath $temporary -Destination $backupFile -ErrorAction Stop

        try {
            $key.DeleteValue([string]$Entry.Name, $false)
        } catch {
            Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
            throw
        }
    } finally { $key.Dispose() }

    [pscustomobject]@{ Name=[string]$Entry.Name; BackupFile=$backupFile; Disabled=$true }
}

function Restore-WnStartupEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BackupFile,
        [Parameter(Mandatory)][string]$BackupDirectory
    )

    $root = [IO.Path]::GetFullPath($BackupDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $fullPath = [IO.Path]::GetFullPath($BackupFile)
    if (-not $fullPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Файл резервной копии должен находиться в штатной папке Windows Next.'
    }
    if ([IO.Path]::GetExtension($fullPath) -ne '.json') { throw 'Ожидался файл резервной копии JSON.' }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw 'Файл резервной копии не найден.' }

    $backup = Get-Content -LiteralPath $fullPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($backup.SchemaVersion -ne 1 -or $backup.Product -ne 'Windows Next' -or [string]$backup.RegistryPath -ne $script:WnUserRunPath) {
        throw 'Файл не является поддерживаемой резервной копией Windows Next.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$backup.Name)) { throw 'В резервной копии отсутствует имя записи.' }
    $kind = [Microsoft.Win32.RegistryValueKind]([Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$backup.ValueKind, $true))
    if ($kind -notin @([Microsoft.Win32.RegistryValueKind]::String, [Microsoft.Win32.RegistryValueKind]::ExpandString)) {
        throw 'Тип значения в резервной копии не поддерживается.'
    }

    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($script:WnUserRunSubKey, $true)
    if ($null -eq $key) { throw 'Не удалось открыть раздел автозагрузки для восстановления.' }
    try {
        if ($key.GetValueNames() -contains [string]$backup.Name) {
            throw 'Запись с таким именем уже существует. Она не перезаписана.'
        }
        $key.SetValue([string]$backup.Name, [string]$backup.Value, $kind)
    } finally { $key.Dispose() }

    $restoredPath = [IO.Path]::ChangeExtension($fullPath, '.restored.json')
    Move-Item -LiteralPath $fullPath -Destination $restoredPath -ErrorAction Stop
    [pscustomobject]@{ Name=[string]$backup.Name; Restored=$true; ArchiveFile=$restoredPath }
}

function Get-WnStartupBackups {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BackupDirectory)

    if (-not (Test-Path -LiteralPath $BackupDirectory -PathType Container)) { return @() }
    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($file in @(Get-ChildItem -LiteralPath $BackupDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        try {
            $data = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($data.SchemaVersion -eq 1 -and $data.Product -eq 'Windows Next' -and [string]$data.RegistryPath -eq $script:WnUserRunPath) {
                $items.Add([pscustomobject]@{ Name=[string]$data.Name; Command=[string]$data.Value; BackupFile=$file.FullName; Status='Отключена — можно восстановить' })
            }
        } catch { }
    }
    return @($items | Sort-Object Name)
}

Export-ModuleMember -Function Get-WnStartupEntries, Disable-WnStartupEntry, Restore-WnStartupEntry, Get-WnStartupBackups
