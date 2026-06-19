Set-StrictMode -Version Latest

function Get-M365SeverityRank {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('Critical','High','Medium','Low','Informational')][string]$Severity)
    switch ($Severity) {
        'Critical' { 5 }
        'High' { 4 }
        'Medium' { 3 }
        'Low' { 2 }
        'Informational' { 1 }
    }
}

function New-M365Finding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ControlId,
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][ValidateSet('Critical','High','Medium','Low','Informational')][string]$Severity,
        [Parameter(Mandatory)][ValidateRange(0,100)][int]$Confidence,
        [Parameter(Mandatory)][string]$Evidence,
        [Parameter(Mandatory)][string]$Impact,
        [Parameter(Mandatory)][string]$Recommendation,
        [string]$Target
    )

    [PSCustomObject]@{
        FindingId      = [guid]::NewGuid().Guid
        ControlId      = $ControlId
        Workload       = $Workload
        Title          = $Title
        Severity       = $Severity
        SeverityRank   = Get-M365SeverityRank -Severity $Severity
        Confidence     = $Confidence
        Target         = $Target
        Evidence       = $Evidence
        Impact         = $Impact
        Recommendation = $Recommendation
        ObservedAtUtc  = [datetime]::UtcNow
    }
}

function Import-M365SyntheticData {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$Path)
    Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Invoke-M365Assessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Data,
        [string]$OutputPath
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $tenant = $Data.TenantName

    if ($Data.Identity.MfaRegistrationPercent -lt 90) {
        $severity = if ($Data.Identity.MfaRegistrationPercent -lt 70) { 'High' } else { 'Medium' }
        $findings.Add((New-M365Finding -ControlId 'M365-ID-001' -Workload 'Identity' -Title 'MFA registration coverage below target' -Severity $severity -Confidence 95 -Evidence "MfaRegistrationPercent=$($Data.Identity.MfaRegistrationPercent)" -Impact 'Accounts without strong authentication have increased takeover risk.' -Recommendation 'Complete authentication-method registration and enforce approved access policies.' -Target $tenant))
    }

    if ($Data.Identity.LegacyAuthenticationAllowed) {
        $findings.Add((New-M365Finding -ControlId 'M365-ID-002' -Workload 'Identity' -Title 'Legacy authentication is allowed' -Severity High -Confidence 98 -Evidence 'LegacyAuthenticationAllowed=True' -Impact 'Legacy protocols can bypass modern authentication controls.' -Recommendation 'Identify dependencies, migrate them, and block legacy authentication through approved policy.' -Target $tenant))
    }

    if ($Data.Identity.ConditionalAccessPolicyCount -lt 1) {
        $findings.Add((New-M365Finding -ControlId 'M365-ID-003' -Workload 'Identity' -Title 'No Conditional Access policies detected' -Severity Critical -Confidence 99 -Evidence 'ConditionalAccessPolicyCount=0' -Impact 'Tenant access lacks centralized risk and context-based enforcement.' -Recommendation 'Design and deploy staged Conditional Access policies with exclusions for emergency access accounts.' -Target $tenant))
    }

    if ($Data.Identity.PermanentGlobalAdmins -gt 4) {
        $findings.Add((New-M365Finding -ControlId 'M365-PRIV-001' -Workload 'PrivilegedAccess' -Title 'Excessive permanent Global Administrator assignments' -Severity High -Confidence 94 -Evidence "PermanentGlobalAdmins=$($Data.Identity.PermanentGlobalAdmins)" -Impact 'Standing privileged access increases the impact of account compromise.' -Recommendation 'Review role necessity and move eligible administration to time-bound access where supported.' -Target $tenant))
    }

    if (-not $Data.Exchange.DkimEnabled) {
        $findings.Add((New-M365Finding -ControlId 'M365-EXO-001' -Workload 'ExchangeOnline' -Title 'DKIM signing is not enabled' -Severity Medium -Confidence 94 -Evidence 'DkimEnabled=False' -Impact 'Outbound mail has weaker domain-authentication assurance.' -Recommendation 'Enable DKIM for approved custom domains and validate SPF and DMARC alignment.' -Target $tenant))
    }

    if ($Data.Exchange.ExternalForwardingMailboxCount -gt 0) {
        $findings.Add((New-M365Finding -ControlId 'M365-EXO-002' -Workload 'ExchangeOnline' -Title 'External mailbox forwarding detected' -Severity High -Confidence 96 -Evidence "ExternalForwardingMailboxCount=$($Data.Exchange.ExternalForwardingMailboxCount)" -Impact 'Mail may leave the tenant without appropriate governance or monitoring.' -Recommendation 'Review business justification, disable unauthorized forwarding, and document approved exceptions.' -Target $tenant))
    }

    if ($Data.SharePoint.AnonymousLinksAllowed) {
        $findings.Add((New-M365Finding -ControlId 'M365-SPO-001' -Workload 'SharePointOnline' -Title 'Anonymous sharing links are allowed' -Severity Medium -Confidence 92 -Evidence 'AnonymousLinksAllowed=True' -Impact 'Content can be accessed without authenticated user attribution.' -Recommendation 'Restrict anonymous sharing or apply tightly scoped expiry and governance controls.' -Target $tenant))
    }

    if ($Data.Teams.AnonymousMeetingJoinAllowed) {
        $findings.Add((New-M365Finding -ControlId 'M365-TEAMS-001' -Workload 'Teams' -Title 'Anonymous meeting join is allowed' -Severity Low -Confidence 85 -Evidence 'AnonymousMeetingJoinAllowed=True' -Impact 'Meeting participation controls may be weaker than intended for sensitive meetings.' -Recommendation 'Align meeting policies with business requirements and use restricted policies for sensitive users.' -Target $tenant))
    }

    $sortProperties = @(
        @{ Expression = 'SeverityRank'; Descending = $true },
        @{ Expression = 'Confidence'; Descending = $true }
    )
    $sorted = @($findings | Sort-Object -Property $sortProperties)

    $workloadScores = @{}
    foreach ($workload in @('Identity','PrivilegedAccess','ExchangeOnline','SharePointOnline','Teams')) {
        $deduction = 0
        foreach ($finding in @($sorted | Where-Object Workload -eq $workload)) {
            $deduction += switch ($finding.Severity) {
                'Critical' { 40 }
                'High' { 20 }
                'Medium' { 10 }
                'Low' { 5 }
                default { 0 }
            }
        }
        $workloadScores[$workload] = [math]::Max(0, 100 - $deduction)
    }

    $result = [PSCustomObject]@{
        Summary = [PSCustomObject]@{
            TenantName       = $tenant
            AssessedAtUtc    = [datetime]::UtcNow
            FindingCount     = $sorted.Count
            Critical         = @($sorted | Where-Object Severity -eq 'Critical').Count
            High             = @($sorted | Where-Object Severity -eq 'High').Count
            Medium           = @($sorted | Where-Object Severity -eq 'Medium').Count
            Low              = @($sorted | Where-Object Severity -eq 'Low').Count
            WorkloadScores   = $workloadScores
        }
        Findings = $sorted
        Evidence = $Data
    }

    if ($OutputPath) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $OutputPath 'assessment.json') -Encoding UTF8
        $sorted | Export-Csv -Path (Join-Path $OutputPath 'findings.csv') -NoTypeInformation -Encoding UTF8
    }

    $result
}

Export-ModuleMember -Function Get-M365SeverityRank,New-M365Finding,Import-M365SyntheticData,Invoke-M365Assessment
