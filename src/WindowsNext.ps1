#requires -Version 5.1
[CmdletBinding()]
param(
 [ValidateSet('','CleanUserTemp','ExportDrivers','OptimizeVolume','ScanVolume','CheckWindows','RepairWindows','CreateRestorePoint')]
 [string]$Task='',
 [string]$Destination='',
 [string]$DriveLetter='',
 [string]$ResultFile=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:AppRoot=Split-Path -Parent $PSScriptRoot
$script:ReportsPath=Join-Path $env:LOCALAPPDATA 'WindowsNext\Reports'
$script:LogsPath=Join-Path $env:LOCALAPPDATA 'WindowsNext\Logs'
[void][IO.Directory]::CreateDirectory($script:ReportsPath)
[void][IO.Directory]::CreateDirectory($script:LogsPath)
$moduleNames=@('Inventory.psm1','Report.psm1','ComponentPlan.psm1','Maintenance.psm1','Performance.psm1','Startup.psm1')
foreach($name in $moduleNames){
 $path=Join-Path $PSScriptRoot ('Modules\'+$name)
 if (-not (Test-Path -LiteralPath $path -PathType Leaf)){throw ("Не найден модуль: {0}" -f $path)}
 Import-Module $path -Force -ErrorAction Stop
}
if (-not [string]::IsNullOrWhiteSpace($Task)){
 $result=Invoke-WnMaintenanceAction -Action $Task -Destination $Destination -DriveLetter $DriveLetter
 if (-not [string]::IsNullOrWhiteSpace($ResultFile)){
  $parent=Split-Path -Parent $ResultFile
  [void][IO.Directory]::CreateDirectory($parent)
  $result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ResultFile -Encoding UTF8
 }
 if($result.Success){exit 0}else{exit 1}
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:Back=[System.Drawing.Color]::FromArgb(24,29,38)
$script:Panel=[System.Drawing.Color]::FromArgb(34,41,53)
$script:Text=[System.Drawing.Color]::FromArgb(232,236,242)
$script:Muted=[System.Drawing.Color]::FromArgb(161,171,186)
$script:Accent=[System.Drawing.Color]::FromArgb(236,178,52)
$script:ActiveTask=$null

function New-WnButton([string]$Caption,[int]$Width=210){
 $b=New-Object System.Windows.Forms.Button
 $b.Text=$Caption;$b.Width=$Width;$b.Height=42
 $b.Margin=New-Object System.Windows.Forms.Padding(6)
 $b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=$script:Accent
 $b.BackColor=$script:Panel;$b.ForeColor=$script:Text
 $b.Font=New-Object System.Drawing.Font('Segoe UI',9)
 $b.Cursor=[System.Windows.Forms.Cursors]::Hand
 return $b
}
function New-WnTextBox{
 $t=New-Object System.Windows.Forms.TextBox
 $t.Multiline=$true;$t.ReadOnly=$true;$t.ScrollBars='Vertical'
 $t.Dock='Fill';$t.BackColor=[System.Drawing.Color]::FromArgb(17,21,28)
 $t.ForeColor=$script:Text;$t.BorderStyle='FixedSingle'
 $t.Font=New-Object System.Drawing.Font('Consolas',9)
 return $t
}
function Get-WnOverview{
 $audit=Get-WnAudit
 $plan=Get-WnComponentPlan -Audit $audit -ManifestPath (Join-Path $script:AppRoot 'manifest\components.json')
 $lines=New-Object 'System.Collections.Generic.List[string]'
 $lines.Add('WINDOWS NEXT — ЦЕНТР УПРАВЛЕНИЯ')
 $lines.Add(('Проверено: {0}' -f (Get-Date -Format 'dd.MM.yyyy HH:mm:ss')))
 $lines.Add('')
 if($audit.OperatingSystem){$lines.Add(('Windows: {0} | сборка {1} | выпуск {2}' -f $audit.OperatingSystem.Caption,$audit.OperatingSystem.BuildNumber,$audit.OperatingSystem.DisplayVersion))}
 if($audit.System){$lines.Add(('Компьютер: {0} {1} | ОЗУ {2} ГБ' -f $audit.System.Manufacturer,$audit.System.Model,$audit.System.MemoryGB))}
 if($audit.Processor){$lines.Add(('Процессор: {0}' -f $audit.Processor.Name))}
 $lines.Add('');$lines.Add('ВИДЕОАДАПТЕРЫ')
 foreach($x in @($audit.Graphics)){$lines.Add(('{0} | {1} | {2}' -f $x.Name,$x.DriverVersion,$x.DriverDate))}
 $lines.Add('');$lines.Add('НАКОПИТЕЛИ')
 foreach($x in @($audit.Storage)){$lines.Add(('{0} | {1} ГБ | {2} | {3}' -f $x.Model,$x.SizeGB,$x.MediaType,$x.HealthStatus))}
 $lines.Add('');$lines.Add('ОПЕРАТИВНАЯ ПАМЯТЬ')
 foreach($x in @($audit.Memory.Modules)){$lines.Add(('{0} | {1} ГБ | {2} МГц | {3}' -f $x.Manufacturer,$x.CapacityGB,$x.SpeedMHz,$x.PartNumber))}
 $lines.Add('');$lines.Add('СЕТЬ / BLUETOOTH')
 foreach($x in @($audit.NetworkDevices)){$lines.Add(('{0} | {1} | {2}' -f $x.Name,$x.Class,$x.DriverVersion))}
 $performance=Get-WnPerformanceAssessment
 $lines.Add('');$lines.Add('ОЦЕНКА ПРОИЗВОДИТЕЛЬНОСТИ (БЕЗ ИЗМЕНЕНИЙ)')
 foreach($finding in @($performance.Findings)){$lines.Add(('{0} — {1}: {2}' -f $finding.Area,$finding.Status,$finding.Detail))}
 $lines.Add('Режим оценки: только чтение. Настройки Windows не изменялись.')
 $lines.Add('');$lines.Add('СОВМЕСТИМОСТЬ КОМПОНЕНТОВ')
 foreach($w in @($plan.Warnings)){$lines.Add(('ВНИМАНИЕ: {0}' -f $w))}
 foreach($x in @($plan.Components)){$lines.Add(('{0}: {1}' -f $x.DisplayName,$x.Decision))}
 return ($lines -join [Environment]::NewLine)
}
function Update-WnDrivers{
 $audit=Get-WnAudit;$rows=@()
 foreach($x in @($audit.Graphics)){$rows+=[pscustomobject]@{Устройство=$x.Name;Класс='Графика';Версия=$x.DriverVersion;Дата=$x.DriverDate;ID=$x.InstanceId}}
 foreach($x in @($audit.NetworkDevices)){$rows+=[pscustomobject]@{Устройство=$x.Name;Класс=$x.Class;Версия=$x.DriverVersion;Дата=$x.DriverDate;ID=$x.InstanceId}}
 $driverGrid.DataSource=$rows
}
function Update-WnVolumePicker{
 $previous=''
 try{if($volumePicker.SelectedValue){$previous=[string]$volumePicker.SelectedValue}}catch{}
 $items=@()
 try{
  $volumes=@(Get-Volume -ErrorAction Stop|Where-Object{$_.DriveType -eq 'Fixed' -and -not[string]::IsNullOrWhiteSpace([string]$_.DriveLetter)})
  foreach($v in $volumes){
   $letter=[string]$v.DriveLetter
   $free=[math]::Round(([double]$v.SizeRemaining/1GB),1)
   $total=[math]::Round(([double]$v.Size/1GB),1)
   $label=[string]$v.FileSystemLabel
   if([string]::IsNullOrWhiteSpace($label)){$label='Локальный диск'}
   $systemMark=''
   if($letter -eq $env:SystemDrive.TrimEnd(':')){$systemMark=' [Windows]'}
   $display=('{0}: {1}{2} — {3}, свободно {4} из {5} ГБ' -f $letter,$label,$systemMark,$v.FileSystem,$free,$total)
   $items+=[pscustomobject]@{Display=$display;DriveLetter=$letter;FileSystem=[string]$v.FileSystem}
  }
 }catch{}
 $volumePicker.DataSource=$null
 $volumePicker.DisplayMember='Display'
 $volumePicker.ValueMember='DriveLetter'
 $volumePicker.DataSource=$items
 if($items.Count -gt 0){
  $target=$previous
  if([string]::IsNullOrWhiteSpace($target)){$target=$env:SystemDrive.TrimEnd(':')}
  if($items.DriveLetter -contains $target){$volumePicker.SelectedValue=$target}else{$volumePicker.SelectedIndex=0}
 }
}
function Update-WnStartupGrid {
 $backupDirectory=Join-Path $env:LOCALAPPDATA 'WindowsNext\StartupBackup'
 [void][IO.Directory]::CreateDirectory($backupDirectory)
 $table=New-Object System.Data.DataTable
 [void]$table.Columns.Add('Selected',[bool])
 [void]$table.Columns.Add('Name',[string])
 [void]$table.Columns.Add('Command',[string])
 [void]$table.Columns.Add('Scope',[string])
 [void]$table.Columns.Add('Status',[string])
 [void]$table.Columns.Add('CanDisable',[bool])
 [void]$table.Columns.Add('Id',[string])
 [void]$table.Columns.Add('BackupFile',[string])

 foreach($entry in @(Get-WnStartupEntries)){
  [void]$table.Rows.Add($false,[string]$entry.Name,[string]$entry.Command,[string]$entry.Scope,[string]$entry.Status,[bool]$entry.CanDisable,[string]$entry.Id,'')
 }
 foreach($backup in @(Get-WnStartupBackups -BackupDirectory $backupDirectory)){
  [void]$table.Rows.Add($false,[string]$backup.Name,[string]$backup.Command,'Резервная копия',[string]$backup.Status,$false,'',[string]$backup.BackupFile)
 }
 $startupGrid.DataSource=$table
 foreach($column in $startupGrid.Columns){$column.ReadOnly=$true}
 $startupGrid.Columns['Selected'].ReadOnly=$false
 $startupGrid.Columns['Selected'].HeaderText='Выбрать'
 $startupGrid.Columns['Name'].HeaderText='Название'
 $startupGrid.Columns['Command'].HeaderText='Команда запуска'
 $startupGrid.Columns['Scope'].HeaderText='Область'
 $startupGrid.Columns['Status'].HeaderText='Состояние'
 $startupGrid.Columns['CanDisable'].Visible=$false
 $startupGrid.Columns['Id'].Visible=$false
 $startupGrid.Columns['BackupFile'].Visible=$false
}
function Update-WnLogs{
 $files=@(Get-ChildItem -LiteralPath $script:LogsPath -Filter 'WindowsNext-*.log' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 12)
 $out=New-Object 'System.Collections.Generic.List[string]'
 foreach($f in $files){$out.Add(('===== {0} =====' -f $f.Name));foreach($line in @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)){$out.Add([string]$line)};$out.Add('')}
 $logText.Text=$out -join [Environment]::NewLine
}
function Finish-WnTask([object]$Result){
 $script:TaskTimer.Stop()
 if($null -eq $Result){$status.Text='Задача завершилась без отчёта. Откройте журнал.';$script:ActiveTask=$null;return}
 if($Result.Success){
  $status.Text=('Готово: {0}' -f $Result.Action)
  $message='Операция выполнена. Журнал: '+[string]$Result.LogPath
  if($Result.Action -eq 'CleanUserTemp' -and $Result.Result){
   $message=('Удалено файлов: {0}; освобождено: {1} МБ; пропущено: {2}' -f $Result.Result.FilesDeleted,[math]::Round($Result.Result.BytesFreed/1MB,1),$Result.Result.Skipped)
   $message+=[Environment]::NewLine+'Журнал: '+[string]$Result.LogPath
  }
  if($Result.Action -eq 'ExportDrivers' -and $Result.Result){
   $message=('Экспортировано пакетов: {0}' -f $Result.Result.PackageCount)
   $message+=[Environment]::NewLine+'Папка: '+[string]$Result.Result.Destination
   $message+=[Environment]::NewLine+'Журнал: '+[string]$Result.LogPath
  }
  [System.Windows.Forms.MessageBox]::Show($message,'Windows Next','OK','Information')|Out-Null
 }else{
  $status.Text=('Ошибка: {0}' -f $Result.Action)
  $message='Операция остановлена: '+[string]$Result.Error
  $message+=[Environment]::NewLine+'Журнал: '+[string]$Result.LogPath
  [System.Windows.Forms.MessageBox]::Show($message,'Windows Next','OK','Error')|Out-Null
 }
 $script:ActiveTask=$null;Update-WnLogs
}
function Start-WnTask{
 param([string]$Action,[string]$Caption,[string]$Destination='',[string]$Letter='',[switch]$Admin)
 if($null -ne $script:ActiveTask){[System.Windows.Forms.MessageBox]::Show('Уже выполняется другая задача.','Windows Next','OK','Information')|Out-Null;return}
 $resultDir=Join-Path $env:LOCALAPPDATA 'WindowsNext\Results'
 [void][IO.Directory]::CreateDirectory($resultDir)
 $resultFile=Join-Path $resultDir (([guid]::NewGuid().ToString('N'))+'.json')
 $powershell=Join-Path $PSHOME 'powershell.exe'
 $argumentString='-NoLogo -NoProfile -WindowStyle Hidden -File "{0}" -Task {1} -ResultFile "{2}"' -f $PSCommandPath,$Action,$resultFile
 if($Destination){$argumentString+=' -Destination "{0}"' -f $Destination.Replace('"','')}
 if($Letter){$argumentString+=' -DriveLetter {0}' -f $Letter}
 try{
  $start=@{FilePath=$powershell;ArgumentList=$argumentString;PassThru=$true;WindowStyle='Hidden'}
  if($Admin){$start.Verb='RunAs'}
  $proc=Start-Process @start
  $script:ActiveTask=[pscustomobject]@{Process=$proc;ResultFile=$resultFile;Caption=$Caption}
  $status.Text=('Выполняется: {0}' -f $Caption);$script:TaskTimer.Start()
 }catch [System.ComponentModel.Win32Exception]{
  if($_.Exception.NativeErrorCode -eq 1223){$status.Text='Запрос UAC отменён. Изменений не выполнено.'}
  else{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Windows Next','OK','Error')|Out-Null}
 }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Windows Next','OK','Error')|Out-Null}
}

$form=New-Object System.Windows.Forms.Form
$form.Text='Windows Next — центр обслуживания'
$form.Size=New-Object System.Drawing.Size(1120,760);$form.MinimumSize=New-Object System.Drawing.Size(900,620)
$form.StartPosition='CenterScreen';$form.BackColor=$script:Back;$form.ForeColor=$script:Text
$form.Font=New-Object System.Drawing.Font('Segoe UI',9)
$header=New-Object System.Windows.Forms.Panel;$header.Dock='Top';$header.Height=76;$header.BackColor=$script:Panel;$form.Controls.Add($header)
$brand=New-Object System.Windows.Forms.Label;$brand.Text='WINDOWS NEXT';$brand.AutoSize=$true
$brand.Location=New-Object System.Drawing.Point(22,10);$brand.ForeColor=$script:Accent
$brand.Font=New-Object System.Drawing.Font('Segoe UI Semibold',20);$header.Controls.Add($brand)
$tag=New-Object System.Windows.Forms.Label;$tag.Text='Обслуживание • производительность • восстановление';$tag.AutoSize=$true
$tag.Location=New-Object System.Drawing.Point(25,48);$tag.ForeColor=$script:Muted;$header.Controls.Add($tag)
$tabs=New-Object System.Windows.Forms.TabControl;$tabs.Dock='Fill';$tabs.Font=New-Object System.Drawing.Font('Segoe UI',10);$form.Controls.Add($tabs)
$home=New-Object System.Windows.Forms.TabPage;$home.Text='Главная';$home.BackColor=$script:Back
$maint=New-Object System.Windows.Forms.TabPage;$maint.Text='Обслуживание';$maint.BackColor=$script:Back
$drivers=New-Object System.Windows.Forms.TabPage;$drivers.Text='Драйверы';$drivers.BackColor=$script:Back
$logs=New-Object System.Windows.Forms.TabPage;$logs.Text='Журнал';$logs.BackColor=$script:Back
$startup=New-Object System.Windows.Forms.TabPage;$startup.Text='Автозагрузка';$startup.BackColor=$script:Back
[void]$tabs.TabPages.AddRange(@($home,$maint,$drivers,$startup,$logs))

$homePanel=New-Object System.Windows.Forms.Panel;$homePanel.Dock='Fill';$homePanel.Padding=New-Object System.Windows.Forms.Padding(12);$home.Controls.Add($homePanel)
$homeBar=New-Object System.Windows.Forms.FlowLayoutPanel;$homeBar.Dock='Top';$homeBar.Height=54;$homePanel.Controls.Add($homeBar)
$refresh=New-WnButton 'Обновить обзор' 180;$saveReport=New-WnButton 'Сохранить отчёт' 180;$openReports=New-WnButton 'Папка отчётов' 160
$homeBar.Controls.AddRange(@($refresh,$saveReport,$openReports))
$overview=New-WnTextBox;$overview.Dock='Fill';$homePanel.Controls.Add($overview);$homePanel.Controls.SetChildIndex($homeBar,0)

$maintPanel=New-Object System.Windows.Forms.Panel;$maintPanel.Dock='Fill';$maintPanel.Padding=New-Object System.Windows.Forms.Padding(12);$maint.Controls.Add($maintPanel)
$maintBar=New-Object System.Windows.Forms.FlowLayoutPanel;$maintBar.Dock='Top';$maintBar.Height=160;$maintBar.WrapContents=$true;$maintPanel.Controls.Add($maintBar)
$volumeLabel=New-Object System.Windows.Forms.Label
$volumeLabel.Text='Выбери диск:';$volumeLabel.AutoSize=$true;$volumeLabel.Margin=New-Object System.Windows.Forms.Padding(8,14,2,2);$volumeLabel.ForeColor=$script:Text
$volumePicker=New-Object System.Windows.Forms.ComboBox
$volumePicker.Width=430;$volumePicker.Height=32;$volumePicker.DropDownStyle=[System.Windows.Forms.ComboBoxStyle]::DropDownList
$volumePicker.BackColor=$script:Panel;$volumePicker.ForeColor=$script:Text
$refreshVolumes=New-WnButton 'Обновить диски' 160
$clean=New-WnButton 'Очистить временные файлы' 240
$optimize=New-WnButton 'Оптимизировать выбранный диск' 270
$scan=New-WnButton 'Проверить выбранный диск' 210
$check=New-WnButton 'Проверить Windows' 190
$repair=New-WnButton 'Восстановить Windows' 220
$restore=New-WnButton 'Создать точку восстановления' 250
$maintBar.Controls.AddRange(@($volumeLabel,$volumePicker,$refreshVolumes,$clean,$optimize,$scan,$check,$repair,$restore))
$maintInfo=New-WnTextBox;$maintInfo.Dock='Fill';$maintPanel.Controls.Add($maintInfo)
$status=New-Object System.Windows.Forms.Label;$status.Dock='Bottom';$status.Height=30;$status.ForeColor=$script:Muted
$status.Text='Готово к работе. Каждая системная операция требует подтверждения.';$maintPanel.Controls.Add($status);$maintPanel.Controls.SetChildIndex($maintBar,0);$maintPanel.Controls.SetChildIndex($status,1)

$driverPanel=New-Object System.Windows.Forms.Panel;$driverPanel.Dock='Fill';$driverPanel.Padding=New-Object System.Windows.Forms.Padding(12);$drivers.Controls.Add($driverPanel)
$driverBar=New-Object System.Windows.Forms.FlowLayoutPanel;$driverBar.Dock='Top';$driverBar.Height=54;$driverPanel.Controls.Add($driverBar)
$backup=New-WnButton 'Создать резервную копию драйверов' 300;$backupFolder=New-WnButton 'Открыть папку копий' 200
$driverBar.Controls.AddRange(@($backup,$backupFolder))
$driverGrid=New-Object System.Windows.Forms.DataGridView;$driverGrid.Dock='Fill';$driverGrid.ReadOnly=$true
$driverGrid.AllowUserToAddRows=$false;$driverGrid.AllowUserToDeleteRows=$false;$driverGrid.AutoSizeColumnsMode='Fill'
$driverGrid.RowHeadersVisible=$false;$driverGrid.BackgroundColor=[System.Drawing.Color]::FromArgb(17,21,28);$driverPanel.Controls.Add($driverGrid)
$driverNote=New-Object System.Windows.Forms.Label;$driverNote.Dock='Bottom';$driverNote.Height=30
$driverNote.ForeColor=$script:Muted;$driverNote.Text='Показаны установленные версии. Неодобренные обновления не устанавливаются.';$driverPanel.Controls.Add($driverNote);$driverPanel.Controls.SetChildIndex($driverBar,0);$driverPanel.Controls.SetChildIndex($driverNote,1)

$startupPanel=New-Object System.Windows.Forms.Panel;$startupPanel.Dock='Fill';$startupPanel.Padding=New-Object System.Windows.Forms.Padding(12);$startup.Controls.Add($startupPanel)
$startupBar=New-Object System.Windows.Forms.FlowLayoutPanel;$startupBar.Dock='Top';$startupBar.Height=54;$startupPanel.Controls.Add($startupBar)
$startupRefresh=New-WnButton 'Обновить список' 180
$startupDisable=New-WnButton 'Отключить выбранные' 220
$startupRestore=New-WnButton 'Восстановить выбранные' 230
$startupBar.Controls.AddRange(@($startupRefresh,$startupDisable,$startupRestore))
$startupGrid=New-Object System.Windows.Forms.DataGridView;$startupGrid.Dock='Fill';$startupGrid.ReadOnly=$false
$startupGrid.AllowUserToAddRows=$false;$startupGrid.AllowUserToDeleteRows=$false;$startupGrid.AutoSizeColumnsMode='Fill'
$startupGrid.RowHeadersVisible=$false;$startupGrid.SelectionMode='FullRowSelect';$startupGrid.MultiSelect=$false
$startupGrid.BackgroundColor=[System.Drawing.Color]::FromArgb(17,21,28);$startupPanel.Controls.Add($startupGrid)
$startupNote=New-Object System.Windows.Forms.Label;$startupNote.Dock='Bottom';$startupNote.Height=48
$startupNote.ForeColor=$script:Muted
$startupNote.Text='Отключаются только выбранные записи автозагрузки текущего пользователя. Перед удалением создаётся копия; системная автозагрузка доступна только для просмотра.'
$startupPanel.Controls.Add($startupNote);$startupPanel.Controls.SetChildIndex($startupBar,0);$startupPanel.Controls.SetChildIndex($startupNote,1)

$logPanel=New-Object System.Windows.Forms.Panel;$logPanel.Dock='Fill';$logPanel.Padding=New-Object System.Windows.Forms.Padding(12);$logs.Controls.Add($logPanel)
$logBar=New-Object System.Windows.Forms.FlowLayoutPanel;$logBar.Dock='Top';$logBar.Height=48;$logPanel.Controls.Add($logBar)
$logRefresh=New-WnButton 'Обновить журнал' 180;$logFolder=New-WnButton 'Папка журналов' 180;$logBar.Controls.AddRange(@($logRefresh,$logFolder))
$logText=New-WnTextBox;$logText.Dock='Fill';$logPanel.Controls.Add($logText);$logPanel.Controls.SetChildIndex($logBar,0)

$script:TaskTimer=New-Object System.Windows.Forms.Timer;$script:TaskTimer.Interval=1000
$script:TaskTimer.Add_Tick({
 if($null -eq $script:ActiveTask){$script:TaskTimer.Stop();return}
 if(Test-Path -LiteralPath $script:ActiveTask.ResultFile -PathType Leaf){
  try{$result=Get-Content -LiteralPath $script:ActiveTask.ResultFile -Raw|ConvertFrom-Json
   Remove-Item -LiteralPath $script:ActiveTask.ResultFile -Force -ErrorAction SilentlyContinue
   Finish-WnTask -Result $result
  }catch{$status.Text=('Ошибка чтения результата: {0}' -f $_.Exception.Message);$script:TaskTimer.Stop();$script:ActiveTask=$null}
 }elseif($script:ActiveTask.Process.HasExited){
  $status.Text=('Задача завершилась с кодом {0}; файл результата отсутствует.' -f $script:ActiveTask.Process.ExitCode)
  $script:TaskTimer.Stop();$script:ActiveTask=$null
 }
})

$refresh.Add_Click({try{$overview.Text=Get-WnOverview;Update-WnDrivers;Update-WnVolumePicker}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Windows Next','OK','Error')|Out-Null}})
$saveReport.Add_Click({
 try{$audit=Get-WnAudit;$plan=Get-WnComponentPlan -Audit $audit -ManifestPath (Join-Path $script:AppRoot 'manifest\components.json')
  $report=Export-WnAuditReport -Audit $audit -ComponentPlan $plan -OutputDirectory $script:ReportsPath
  [System.Windows.Forms.MessageBox]::Show(('Отчёт сохранён: '+$report.TextPath),'Windows Next','OK','Information')|Out-Null
 }catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Windows Next','OK','Error')|Out-Null}
})
$openReports.Add_Click({Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:ReportsPath)})
$clean.Add_Click({
 $choice=[System.Windows.Forms.MessageBox]::Show('Удалить только файлы в %LOCALAPPDATA%\Temp, которым больше 14 дней? Загрузки, документы и системные папки не затрагиваются.','Очистка','YesNo','Question')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action CleanUserTemp -Caption 'Очистка временных файлов'}
})
$refreshVolumes.Add_Click({Update-WnVolumePicker})
$optimize.Add_Click({
 $letter=[string]$volumePicker.SelectedValue
 if([string]::IsNullOrWhiteSpace($letter)){[System.Windows.Forms.MessageBox]::Show('Сначала выберите локальный диск.','Windows Next','OK','Warning')|Out-Null;return}
 $choice=[System.Windows.Forms.MessageBox]::Show(("Запустить штатную оптимизацию Windows для {0}:? Windows сама выберет операцию для SSD или HDD." -f $letter),'Оптимизация','YesNo','Question')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action OptimizeVolume -Caption ('Оптимизация диска '+$letter+':') -Letter $letter -Admin}
})
$scan.Add_Click({
 $letter=[string]$volumePicker.SelectedValue
 if([string]::IsNullOrWhiteSpace($letter)){[System.Windows.Forms.MessageBox]::Show('Сначала выберите локальный диск.','Windows Next','OK','Warning')|Out-Null;return}
 $choice=[System.Windows.Forms.MessageBox]::Show(("Запустить онлайн-проверку NTFS тома {0}:?" -f $letter),'Проверка диска','YesNo','Question')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action ScanVolume -Caption ('Проверка диска '+$letter+':') -Letter $letter -Admin}
})
$check.Add_Click({
 $choice=[System.Windows.Forms.MessageBox]::Show('Запустить DISM ScanHealth и SFC VerifyOnly? Это проверка без исправления файлов.','Проверка Windows','YesNo','Question')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action CheckWindows -Caption 'Проверка Windows' -Admin}
})
$repair.Add_Click({
 $choice=[System.Windows.Forms.MessageBox]::Show('Сначала будет создана точка восстановления. Если это не удастся, ремонт остановится. Затем DISM RestoreHealth и SFC Scannow могут изменить системные файлы. Продолжить?','Восстановление','YesNo','Warning')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action RepairWindows -Caption 'Восстановление Windows' -Admin}
})
$restore.Add_Click({
 $choice=[System.Windows.Forms.MessageBox]::Show('Создать точку восстановления? Для этого должна быть включена защита системы.','Точка восстановления','YesNo','Question')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action CreateRestorePoint -Caption 'Создание точки восстановления' -Admin}
})
$backup.Add_Click({
 $base=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsNext\DriverBackup'
 $destination=Join-Path $base (Get-Date -Format 'yyyyMMdd-HHmmss')
 $choice=[System.Windows.Forms.MessageBox]::Show(('Экспортировать сторонние драйверы Windows в папку: '+[Environment]::NewLine+$destination+[Environment]::NewLine+'Текущие драйверы не изменяются.'),'Резервная копия','YesNo','Question')
 if($choice -eq [System.Windows.Forms.DialogResult]::Yes){Start-WnTask -Action ExportDrivers -Caption 'Резервное копирование драйверов' -Destination $destination -Admin}
})
$backupFolder.Add_Click({
 $folder=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsNext\DriverBackup'
 [void][IO.Directory]::CreateDirectory($folder);Start-Process explorer.exe -ArgumentList ('"{0}"' -f $folder)
})
$logRefresh.Add_Click({Update-WnLogs})
$logFolder.Add_Click({Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:LogsPath)})
$startupGrid.Add_CurrentCellDirtyStateChanged({
 if($startupGrid.IsCurrentCellDirty){[void]$startupGrid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)}
})
$startupRefresh.Add_Click({try{Update-WnStartupGrid}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Windows Next','OK','Error')|Out-Null}})
$startupDisable.Add_Click({
 $selected=@($startupGrid.Rows|Where-Object{[bool]$_.Cells['Selected'].Value -and [bool]$_.Cells['CanDisable'].Value})
 if($selected.Count -eq 0){[System.Windows.Forms.MessageBox]::Show('Выбери одну или несколько записей из раздела текущего пользователя.','Автозагрузка','OK','Information')|Out-Null;return}
 $choice=[System.Windows.Forms.MessageBox]::Show('Отключить выбранные программы при входе в Windows? Перед изменением будет создана резервная копия. Не отключай незнакомые компоненты безопасности, драйверы и системные средства.','Изменение автозагрузки','YesNo','Warning')
 if($choice -ne [System.Windows.Forms.DialogResult]::Yes){return}
 $backupDirectory=Join-Path $env:LOCALAPPDATA 'WindowsNext\StartupBackup'
 $done=0;$errors=New-Object 'System.Collections.Generic.List[string]'
 foreach($row in $selected){
  try{
   $id=[string]$row.Cells['Id'].Value
   $entry=@(Get-WnStartupEntries|Where-Object{$_.Id -eq $id})
   if($entry.Count -ne 1){throw 'Запись изменилась. Обнови список.'}
   [void](Disable-WnStartupEntry -Entry $entry[0] -BackupDirectory $backupDirectory)
   $done++
  }catch{$errors.Add([string]$_.Exception.Message)}
 }
 Update-WnStartupGrid
 $message=('Отключено записей: {0}.' -f $done)
 if($errors.Count -gt 0){$message+=[Environment]::NewLine+'Ошибки: '+($errors -join '; ')}
 [System.Windows.Forms.MessageBox]::Show($message,'Windows Next','OK','Information')|Out-Null
})
$startupRestore.Add_Click({
 $selected=@($startupGrid.Rows|Where-Object{[bool]$_.Cells['Selected'].Value -and -not [string]::IsNullOrWhiteSpace([string]$_.Cells['BackupFile'].Value)})
 if($selected.Count -eq 0){[System.Windows.Forms.MessageBox]::Show('Выбери резервную копию, которую нужно восстановить.','Автозагрузка','OK','Information')|Out-Null;return}
 $choice=[System.Windows.Forms.MessageBox]::Show('Восстановить выбранные записи автозагрузки? Существующие значения с таким же именем не будут перезаписаны.','Восстановление автозагрузки','YesNo','Question')
 if($choice -ne [System.Windows.Forms.DialogResult]::Yes){return}
 $backupDirectory=Join-Path $env:LOCALAPPDATA 'WindowsNext\StartupBackup'
 $done=0;$errors=New-Object 'System.Collections.Generic.List[string]'
 foreach($row in $selected){
  try{[void](Restore-WnStartupEntry -BackupFile ([string]$row.Cells['BackupFile'].Value) -BackupDirectory $backupDirectory);$done++}
  catch{$errors.Add([string]$_.Exception.Message)}
 }
 Update-WnStartupGrid
 $message=('Восстановлено записей: {0}.' -f $done)
 if($errors.Count -gt 0){$message+=[Environment]::NewLine+'Ошибки: '+($errors -join '; ')}
 [System.Windows.Forms.MessageBox]::Show($message,'Windows Next','OK','Information')|Out-Null
})

$form.Add_Shown({
 try{
  $overview.Text=Get-WnOverview;Update-WnDrivers;Update-WnVolumePicker;Update-WnStartupGrid;Update-WnLogs
  $maintInfo.Text=@'
РАБОЧИЕ ИНСТРУМЕНТЫ WINDOWS NEXT

- Очистка пользовательских временных файлов старше 14 дней.
- Штатная оптимизация любого выбранного внутреннего SSD/HDD средствами Windows.
- Онлайн-проверка выбранного NTFS-накопителя.
- Проверка целостности Windows через DISM и SFC.
- Восстановление Windows с обязательной точкой восстановления.
- Резервное копирование сторонних драйверов с индексом и SHA-256.

Каждая операция пишет журнал. Системные операции требуют подтверждения UAC.
Неодобренные драйверы не устанавливаются автоматически. BIOS, прошивки, напряжение,
частоты и температурные ограничения не изменяются.
'@
 }catch{$overview.Text=('Ошибка загрузки: {0}' -f $_.Exception.Message)}
})
[void]$form.ShowDialog()
