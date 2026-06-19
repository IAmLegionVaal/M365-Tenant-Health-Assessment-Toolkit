BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\M365Health\M365Health.psd1'
    Import-Module $modulePath -Force
    $dataPath = Join-Path $PSScriptRoot '..\sample-data\synthetic-tenant.json'
    $script:Data = Import-M365SyntheticData -Path $dataPath
}

Describe 'Microsoft 365 phase-two commands' {
    It 'exports connection, live collection, reporting, and comparison commands' {
        $commands = Get-Command -Module M365Health | Select-Object -ExpandProperty Name
        foreach ($name in @('Connect-M365Assessment','Get-M365LiveData','New-M365HtmlReport','Compare-M365Assessment')) {
            $commands | Should -Contain $name
        }
    }

    It 'compares workload improvements with a baseline' {
        $baseline = Invoke-M365Assessment -Data $script:Data
        $currentData = $script:Data | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $currentData.Identity.LegacyAuthenticationAllowed = $false
        $current = Invoke-M365Assessment -Data $currentData
        $comparison = Compare-M365Assessment -Baseline $baseline -Current $current

        $comparison.Summary.ResolvedCount | Should -Be 1
        $comparison.ResolvedFindings.ControlId | Should -Contain 'M365-ID-002'
        ($comparison.WorkloadScoreChanges | Where-Object Workload -eq 'Identity').Delta | Should -BeGreaterThan 0
    }
}
