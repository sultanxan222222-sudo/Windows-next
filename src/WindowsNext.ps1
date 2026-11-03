#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDirectory = Join-Path $env:LOCALAPPDATA 'WindowsNext\Logs'
$logPath = $null

try {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'Windows did not provide LOCALAPPDATA. Cannot create a diagnostic log.'
    }

    [void][System.IO.Directory]::CreateDirectory($logDirectory)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logPath = Join-Path $logDirectory "WindowsNext-Startup-$stamp.log"

    @(
        'WINDOWS NEXT STARTUP LOG'
        ('Time (local): {0}' -f (Get-Date).ToString('o'))
        ('PowerShell: {0}' -f $PSVersionTable.PSVersion)
        ('Script: {0}' -f $PSCommandPath)
        ''
    ) | Set-Content -LiteralPath $logPath -Encoding UTF8

    Write-Host ''
    Write-Host 'Windows Next — hardware and driver inventory' -ForegroundColor Cyan
    Write-Host 'Mode: READ ONLY. No drivers or Windows settings will be changed.'
    Write-Host ''

    $moduleDirectory = Join-Path $PSScriptRoot 'Modules'
    $inventoryModule = Join-Path $moduleDirectory 'Inventory.psm1'
    $reportModule = Join-Path $moduleDirectory 'Report.psm1'

    foreach ($requiredFile in @($inventoryModule, $reportModule)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            throw ('Required project file is missing: {0}' -f $requiredFile)
        }
    }

    Import-Module $inventoryModule -Force -ErrorAction Stop
    Import-Module $reportModule -Force -ErrorAction Stop

    $audit = Get-WnAudit
    $report = Export-WnAuditReport -Audit $audit -OutputDirectory $OutputDirectory

    @(
        ('Status: SUCCESS')
        ('JSON report: {0}' -f $report.JsonPath)
        ('Text report: {0}' -f $report.TextPath)
    ) | Add-Content -LiteralPath $logPath -Encoding UTF8

    Write-Host 'Inventory completed.' -ForegroundColor Green
    Write-Host ('JSON report: {0}' -f $report.JsonPath)
    Write-Host ('Text report: {0}' -f $report.TextPath)
    Write-Host ('Startup log: {0}' -f $logPath)
    Write-Host ''
    Write-Host 'Send the JSON or TXT report for exact driver and hardware matching.'
    exit 0
}
catch {
    $errorText = ($_ | Format-List * -Force | Out-String)
    $details = @(
        'STATUS: FAILED'
        ('Time (local): {0}' -f (Get-Date).ToString('o'))
        ('PowerShell: {0}' -f $PSVersionTable.PSVersion)
        ('Script: {0}' -f $PSCommandPath)
        ''
        'ERROR DETAILS'
        $errorText
        'SCRIPT STACK'
        [string]$_.ScriptStackTrace
    ) -join [Environment]::NewLine

    if (-not [string]::IsNullOrWhiteSpace($logPath)) {
        try {
            Add-Content -LiteralPath $logPath -Value $details -Encoding UTF8
        }
        catch {
            # Keep the original error visible even if the log cannot be written.
        }
    }

    Write-Host ''
    Write-Host 'Windows Next could not complete the inventory.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    if (-not [string]::IsNullOrWhiteSpace($logPath)) {
        Write-Host ('Diagnostic log: {0}' -f $logPath)
    }
    Write-Host 'No driver installation or Windows configuration change was attempted.'
    exit 1
}
