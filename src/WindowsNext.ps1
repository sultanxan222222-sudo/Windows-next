#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleDirectory = Join-Path $PSScriptRoot 'Modules'
Import-Module (Join-Path $moduleDirectory 'Inventory.psm1') -Force
Import-Module (Join-Path $moduleDirectory 'Report.psm1') -Force

try {
    Write-Host ''
    Write-Host 'Windows Next — hardware and driver inventory' -ForegroundColor Cyan
    Write-Host 'Mode: READ ONLY. No drivers or Windows settings will be changed.'
    Write-Host ''

    $audit = Get-WnAudit
    $report = Export-WnAuditReport -Audit $audit -OutputDirectory $OutputDirectory

    Write-Host 'Inventory completed.' -ForegroundColor Green
    Write-Host ('JSON report: {0}' -f $report.JsonPath)
    Write-Host ('Text report: {0}' -f $report.TextPath)
    Write-Host ''
    Write-Host 'Send the JSON or TXT report for exact driver and hardware matching.'
}
catch {
    Write-Error ('Windows Next inventory failed: {0}' -f $_.Exception.Message)
    exit 1
}
