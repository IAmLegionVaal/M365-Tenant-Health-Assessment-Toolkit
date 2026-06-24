BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\modules\M365Health\M365Health.psd1'
    Import-Module $modulePath -Force
    $dataPath = Join-Path $PSScriptRoot '..\sample-data\synthetic-tenant.json'
    $script:Data = Import-M365SyntheticData -Path $dataPath
}

Describe 'M365Health module' {
    It 'imports successfully' {
        Get-Module M365Health | Should -Not -BeNullOrEmpty
    }

    It 'creates normalized findings' {
        $finding = New-M365Finding -ControlId TEST-001 -Workload Identity -Title 'Synthetic control' -Severity High -Confidence 90 -Evidence Evidence -Impact Impact -Recommendation Recommendation -Target tenant.test
        $finding.SeverityRank | Should -Be 4
        $finding.ControlId | Should -Be 'TEST-001'
    }

    It 'produces expected synthetic findings and workload scores' {
        $result = Invoke-M365Assessment -Data $script:Data
        $result.Summary.FindingCount | Should -Be 8
        $result.Summary.Critical | Should -Be 1
        $result.Summary.High | Should -Be 4
        $result.Summary.Medium | Should -Be 2
        $result.Summary.Low | Should -Be 1
        $result.Summary.WorkloadScores.Identity | Should -Be 20
        $result.Summary.WorkloadScores.ExchangeOnline | Should -Be 70
        $result.Findings.ControlId | Should -Contain 'M365-ID-003'
        $result.Findings.ControlId | Should -Contain 'M365-EXO-002'
    }

    It 'exports JSON and CSV evidence' {
        $outputPath = Join-Path $TestDrive 'assessment'
        Invoke-M365Assessment -Data $script:Data -OutputPath $outputPath | Out-Null
        Test-Path (Join-Path $outputPath 'assessment.json') | Should -BeTrue
        Test-Path (Join-Path $outputPath 'findings.csv') | Should -BeTrue
    }
}