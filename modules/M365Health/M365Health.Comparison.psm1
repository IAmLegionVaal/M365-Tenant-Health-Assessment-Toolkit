function Compare-M365Assessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Baseline,
        [Parameter(Mandatory)][psobject]$Current
    )

    $baselineIndex = @{}
    foreach ($finding in @($Baseline.Findings)) {
        $key = '{0}|{1}' -f $finding.ControlId,$finding.Target
        $baselineIndex[$key] = $finding
    }

    $currentIndex = @{}
    foreach ($finding in @($Current.Findings)) {
        $key = '{0}|{1}' -f $finding.ControlId,$finding.Target
        $currentIndex[$key] = $finding
    }

    $newFindings = [System.Collections.Generic.List[object]]::new()
    $resolvedFindings = [System.Collections.Generic.List[object]]::new()
    $persistentFindings = [System.Collections.Generic.List[object]]::new()

    foreach ($key in $currentIndex.Keys) {
        if ($baselineIndex.ContainsKey($key)) {
            $persistentFindings.Add($currentIndex[$key])
        }
        else {
            $newFindings.Add($currentIndex[$key])
        }
    }

    foreach ($key in $baselineIndex.Keys) {
        if (-not $currentIndex.ContainsKey($key)) {
            $resolvedFindings.Add($baselineIndex[$key])
        }
    }

    $scoreChanges = [System.Collections.Generic.List[object]]::new()
    $workloads = @($Baseline.Summary.WorkloadScores.Keys + $Current.Summary.WorkloadScores.Keys | Sort-Object -Unique)
    foreach ($workload in $workloads) {
        $baselineScore = [int]$Baseline.Summary.WorkloadScores[$workload]
        $currentScore = [int]$Current.Summary.WorkloadScores[$workload]
        $scoreChanges.Add([PSCustomObject]@{
            Workload      = $workload
            BaselineScore = $baselineScore
            CurrentScore  = $currentScore
            Delta         = $currentScore - $baselineScore
        })
    }

    [PSCustomObject]@{
        ComparedAtUtc      = [datetime]::UtcNow
        NewFindings        = @($newFindings)
        ResolvedFindings   = @($resolvedFindings)
        PersistentFindings = @($persistentFindings)
        WorkloadScoreChanges = @($scoreChanges)
        Summary            = [PSCustomObject]@{
            BaselineFindingCount = @($Baseline.Findings).Count
            CurrentFindingCount  = @($Current.Findings).Count
            NewCount             = $newFindings.Count
            ResolvedCount        = $resolvedFindings.Count
            PersistentCount      = $persistentFindings.Count
        }
    }
}

Export-ModuleMember -Function Compare-M365Assessment
