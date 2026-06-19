[CmdletBinding()]
param(
    [string]$SyntheticDataPath = (Join-Path $PSScriptRoot 'sample-data\synthetic-tenant.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'artifacts\latest-assessment')
)

$modulePath = Join-Path $PSScriptRoot 'modules\M365Health\M365Health.psd1'
Import-Module $modulePath -Force -ErrorAction Stop
$data = Import-M365SyntheticData -Path $SyntheticDataPath
$result = Invoke-M365Assessment -Data $data -OutputPath $OutputPath
$result.Summary | Format-List
$result.Findings | Format-Table Severity,Confidence,ControlId,Workload,Title -AutoSize
