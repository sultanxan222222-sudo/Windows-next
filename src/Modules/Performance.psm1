Set-StrictMode -Version Latest

function Get-WnPerformanceAssessment {
    [CmdletBinding()]
    param()

    $findings = New-Object 'System.Collections.Generic.List[object]'
    $memory = @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $totalBytes = 0.0
    foreach ($item in $memory) {
        if ($item.Capacity) { $totalBytes += [double]$item.Capacity }
    }
    $totalGb = [math]::Round($totalBytes / 1GB, 1)

    if ($memory.Count -eq 1) {
        $findings.Add([pscustomobject]@{
            Area = 'ОЗУ'
            Status = 'Резерв улучшения'
            Detail = 'Установлен один модуль памяти. Второй совместимый модуль может включить двухканальный режим; сначала проверить точную модель, частоту и поддержку платы.'
            Priority = 1
        })
    } elseif ($memory.Count -ge 2) {
        $findings.Add([pscustomobject]@{
            Area = 'ОЗУ'
            Status = 'Проверить режим'
            Detail = ('Обнаружено модулей: {0}. Фактический режим каналов отдельно не подтверждён.' -f $memory.Count)
            Priority = 2
        })
    } else {
        $findings.Add([pscustomobject]@{
            Area = 'ОЗУ'
            Status = 'Нет данных'
            Detail = 'Windows не вернула сведения о модулях памяти.'
            Priority = 3
        })
    }

    try {
        $systemDrive = $env:SystemDrive.TrimEnd(':')
        $volume = Get-Volume -DriveLetter $systemDrive -ErrorAction Stop
        $freeGb = [math]::Round(([double]$volume.SizeRemaining / 1GB), 1)
        $freePct = if ([double]$volume.Size -gt 0) { [math]::Round(100 * [double]$volume.SizeRemaining / [double]$volume.Size, 1) } else { 0 }
        $status = if ($freePct -lt 10) { 'Внимание' } elseif ($freePct -lt 20) { 'Запас небольшой' } else { 'Норма' }
        $findings.Add([pscustomobject]@{
            Area = 'Системный диск'
            Status = $status
            Detail = ('Свободно {0} ГБ ({1}%). Для SSD желательно сохранять свободное место; ничего автоматически не удаляется.' -f $freeGb, $freePct)
            Priority = if ($freePct -lt 10) { 1 } else { 2 }
        })
    } catch {
        $findings.Add([pscustomobject]@{ Area='Системный диск'; Status='Нет данных'; Detail='Не удалось безопасно прочитать свободное место системного тома.'; Priority=3 })
    }

    $startupCount = 0
    foreach ($keyPath in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )) {
        try {
            $props = Get-ItemProperty -LiteralPath $keyPath -ErrorAction Stop
            foreach ($prop in $props.PSObject.Properties) {
                if ($prop.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') -and
                    -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) { $startupCount++ }
            }
        } catch { }
    }
    $findings.Add([pscustomobject]@{
        Area = 'Автозагрузка'
        Status = 'Только обзор'
        Detail = ('Записей автозапуска в основных Run-разделах: {0}. Ничего не отключено; список требует проверки издателя и назначения.' -f $startupCount)
        Priority = 2
    })

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $build = [int]$os.BuildNumber
        $status = if ($build -lt 22621) { 'Устаревшая сборка' } else { 'Проверить поддержку' }
        $findings.Add([pscustomobject]@{
            Area = 'Windows'
            Status = $status
            Detail = ('Текущая сборка Windows: {0}. Оценка поддержки выполняется отдельно; обновление ОС не запускается.' -f $build)
            Priority = 1
        })
    }

    [pscustomobject]@{
        GeneratedAt = (Get-Date).ToString('o')
        Mode = 'ReadOnly'
        TotalMemoryGB = $totalGb
        StartupRunEntryCount = $startupCount
        Findings = @($findings | Sort-Object Priority, Area)
        ChangesMade = $false
    }
}

Export-ModuleMember -Function Get-WnPerformanceAssessment
