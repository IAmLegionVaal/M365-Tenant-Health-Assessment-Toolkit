[CmdletBinding()]
param(
    [ValidateSet('Synthetic','Live')][string]$Mode = 'Synthetic',
    [string]$SyntheticDataPath = (Join-Path $PSScriptRoot 'sample-data\synthetic-tenant.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'artifacts\latest-assessment'),
    [switch]$OpenReport
)

$modulePath = Join-Path $PSScriptRoot 'modules\M365Health\M365Health.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

if ($Mode -eq 'Live') {
    $data = Get-M365LiveData
}
else {
    $data = Import-M365SyntheticData -Path $SyntheticDataPath
}

$result = Invoke-M365Assessment -Data $data -OutputPath $OutputPath
$result.Summary | Format-List
$result.Findings | Format-Table Severity,Confidence,ControlId,Workload,Title -AutoSize

$reportPath = Join-Path $OutputPath 'report.html'
if ($OpenReport -and (Test-Path $reportPath)) {
    Start-Process $reportPath
}
