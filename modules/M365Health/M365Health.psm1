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

function Invoke-M365GraphCollection {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Uri)

    $items = [System.Collections.Generic.List[object]]::new()
    $nextUri = $Uri
    while ($nextUri) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri -OutputType PSObject -ErrorAction Stop
        foreach ($item in @($response.value)) {
            $items.Add($item)
        }
        $nextUri = $response.'@odata.nextLink'
    }
    @($items)
}

function Get-M365LiveData {
    [CmdletBinding()]
    param(
        [switch]$Connect,
        [string[]]$Scopes = @('Organization.Read.All','Policy.Read.All','Directory.Read.All','RoleManagement.Read.Directory','Reports.Read.All')
    )

    if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required for live collection.'
    }

    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context -and $Connect) {
        Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop | Out-Null
        $context = Get-MgContext -ErrorAction Stop
    }
    if (-not $context) {
        throw 'No Microsoft Graph connection is available. Connect first or use -Connect.'
    }

    $notes = [System.Collections.Generic.List[string]]::new()
    $organization = Invoke-MgGraphRequest -Method GET -Uri '/v1.0/organization?$select=id,displayName,verifiedDomains' -OutputType PSObject -ErrorAction Stop
    $organizationRecord = @($organization.value) | Select-Object -First 1
    $tenantName = if ($organizationRecord.displayName) { $organizationRecord.displayName } else { $context.TenantId }

    $policies = @(Invoke-M365GraphCollection -Uri '/v1.0/identity/conditionalAccess/policies?$select=id,displayName,state,conditions,grantControls')
    $enabledPolicies = @($policies | Where-Object state -eq 'enabled')
    $legacyBlockPolicies = @(
        $enabledPolicies | Where-Object {
            $clientApps = @($_.conditions.clientAppTypes)
            $builtInControls = @($_.grantControls.builtInControls)
            ($clientApps -contains 'exchangeActiveSync' -or $clientApps -contains 'other') -and $builtInControls -contains 'block'
        }
    )

    $mfaPercent = 100
    try {
        $registration = @(Invoke-M365GraphCollection -Uri '/beta/reports/authenticationMethods/userRegistrationDetails?$select=isMfaRegistered')
        if ($registration.Count -gt 0) {
            $registeredCount = @($registration | Where-Object isMfaRegistered).Count
            $mfaPercent = [math]::Round(($registeredCount / $registration.Count) * 100, 1)
        }
    }
    catch {
        $notes.Add("MFA registration report unavailable: $($_.Exception.Message)")
    }

    $permanentGlobalAdmins = 0
    try {
        $roles = @(Invoke-M365GraphCollection -Uri '/v1.0/directoryRoles?$select=id,displayName')
        $globalAdminRole = $roles | Where-Object displayName -eq 'Global Administrator' | Select-Object -First 1
        if ($globalAdminRole) {
            $members = @(Invoke-M365GraphCollection -Uri "/v1.0/directoryRoles/$($globalAdminRole.id)/members?`$select=id")
            $permanentGlobalAdmins = $members.Count
        }
    }
    catch {
        $notes.Add("Global Administrator membership unavailable: $($_.Exception.Message)")
    }

    $dkimEnabled = $true
    $externalForwardingCount = 0
    if (Get-Command Get-DkimSigningConfig -ErrorAction SilentlyContinue) {
        try {
            $dkimConfigs = @(Get-DkimSigningConfig -ErrorAction Stop | Where-Object { $_.Domain -notlike '*.onmicrosoft.com' })
            if ($dkimConfigs.Count -gt 0) {
                $dkimEnabled = @($dkimConfigs | Where-Object Enabled).Count -eq $dkimConfigs.Count
            }
        }
        catch {
            $notes.Add("DKIM configuration unavailable: $($_.Exception.Message)")
        }
    }
    else {
        $notes.Add('Exchange Online cmdlets were not available; DKIM was not assessed.')
    }

    if (Get-Command Get-Mailbox -ErrorAction SilentlyContinue) {
        try {
            $mailboxes = @(Get-Mailbox -ResultSize Unlimited -ErrorAction Stop | Select-Object ForwardingSmtpAddress,ForwardingAddress)
            $externalForwardingCount = @($mailboxes | Where-Object { $_.ForwardingSmtpAddress -or $_.ForwardingAddress }).Count
        }
        catch {
            $notes.Add("Mailbox forwarding collection unavailable: $($_.Exception.Message)")
        }
    }
    else {
        $notes.Add('Exchange Online cmdlets were not available; mailbox forwarding was not assessed.')
    }

    $anonymousLinksAllowed = $false
    if (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue) {
        try {
            $spoTenant = Get-SPOTenant -ErrorAction Stop
            $anonymousLinksAllowed = [string]$spoTenant.SharingCapability -match 'Guest'
        }
        catch {
            $notes.Add("SharePoint tenant configuration unavailable: $($_.Exception.Message)")
        }
    }
    else {
        $notes.Add('SharePoint Online cmdlets were not available; anonymous links were not assessed.')
    }

    $anonymousMeetingJoinAllowed = $false
    if (Get-Command Get-CsTeamsMeetingPolicy -ErrorAction SilentlyContinue) {
        try {
            $teamsPolicy = Get-CsTeamsMeetingPolicy -Identity Global -ErrorAction Stop
            $anonymousMeetingJoinAllowed = [bool]$teamsPolicy.AllowAnonymousUsersToJoinMeeting
        }
        catch {
            $notes.Add("Teams meeting policy unavailable: $($_.Exception.Message)")
        }
    }
    else {
        $notes.Add('Teams cmdlets were not available; anonymous meeting join was not assessed.')
    }

    [PSCustomObject]@{
        Classification = 'LIVE READ-ONLY ASSESSMENT DATA'
        TenantName      = $tenantName
        TenantId        = $context.TenantId
        Identity        = [PSCustomObject]@{
            MfaRegistrationPercent       = $mfaPercent
            LegacyAuthenticationAllowed  = $legacyBlockPolicies.Count -eq 0
            ConditionalAccessPolicyCount = $enabledPolicies.Count
            PermanentGlobalAdmins        = $permanentGlobalAdmins
        }
        Exchange        = [PSCustomObject]@{
            DkimEnabled                   = $dkimEnabled
            ExternalForwardingMailboxCount = $externalForwardingCount
        }
        SharePoint      = [PSCustomObject]@{ AnonymousLinksAllowed = $anonymousLinksAllowed }
        Teams           = [PSCustomObject]@{ AnonymousMeetingJoinAllowed = $anonymousMeetingJoinAllowed }
        CollectionNotes = @($notes)
        CollectedAtUtc  = [datetime]::UtcNow
    }
}

function New-M365HtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Result,
        [Parameter(Mandatory)][string]$Path
    )

    $scoreRows = foreach ($entry in $Result.Summary.WorkloadScores.GetEnumerator()) {
        [PSCustomObject]@{ Workload = $entry.Key; Score = $entry.Value }
    }
    $scoreHtml = $scoreRows | Sort-Object Workload | ConvertTo-Html -Fragment
    $findingRows = foreach ($finding in @($Result.Findings)) {
        [PSCustomObject]@{
            Severity       = $finding.Severity
            Confidence     = $finding.Confidence
            ControlId      = $finding.ControlId
            Workload       = $finding.Workload
            Title          = $finding.Title
            Evidence       = $finding.Evidence
            Impact         = $finding.Impact
            Recommendation = $finding.Recommendation
        }
    }
    $findingsHtml = $findingRows | ConvertTo-Html -Fragment
    $style = '<style>body{font-family:Segoe UI,Arial;margin:32px;background:#f8fafc;color:#1f2937}table{border-collapse:collapse;width:100%;background:white;margin:12px 0 28px}th,td{border:1px solid #cbd5e1;padding:8px;text-align:left;vertical-align:top}th{background:#e2e8f0}h1,h2{color:#0f172a}.meta{color:#475569}</style>'
    $html = "<!doctype html><html><head><meta charset='utf-8'><title>Microsoft 365 Tenant Health Assessment</title>$style</head><body><h1>Microsoft 365 Tenant Health Assessment</h1><p class='meta'>Tenant: $($Result.Summary.TenantName) | Generated $([datetime]::UtcNow.ToString('u')) UTC | Classification: $($Result.Evidence.Classification)</p><h2>Workload Scores</h2>$scoreHtml<h2>Findings</h2>$findingsHtml</body></html>"
    Set-Content -Path $Path -Value $html -Encoding UTF8
    Get-Item -Path $Path
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
        $findings.Add((New-M365Finding -ControlId 'M365-ID-002' -Workload 'Identity' -Title 'Legacy authentication is allowed' -Severity High -Confidence 90 -Evidence 'No enabled Conditional Access block policy for legacy client types was detected.' -Impact 'Legacy protocols can bypass modern authentication controls.' -Recommendation 'Identify dependencies, migrate them, and block legacy authentication through approved policy.' -Target $tenant))
    }
    if ($Data.Identity.ConditionalAccessPolicyCount -lt 1) {
        $findings.Add((New-M365Finding -ControlId 'M365-ID-003' -Workload 'Identity' -Title 'No Conditional Access policies detected' -Severity Critical -Confidence 99 -Evidence 'ConditionalAccessPolicyCount=0' -Impact 'Tenant access lacks centralized risk and context-based enforcement.' -Recommendation 'Design and deploy staged Conditional Access policies with exclusions for emergency access accounts.' -Target $tenant))
    }
    if ($Data.Identity.PermanentGlobalAdmins -gt 4) {
        $findings.Add((New-M365Finding -ControlId 'M365-PRIV-001' -Workload 'PrivilegedAccess' -Title 'Excessive permanent Global Administrator assignments' -Severity High -Confidence 94 -Evidence "PermanentGlobalAdmins=$($Data.Identity.PermanentGlobalAdmins)" -Impact 'Standing privileged access increases the impact of account compromise.' -Recommendation 'Review role necessity and move eligible administration to time-bound access where supported.' -Target $tenant))
    }
    if (-not $Data.Exchange.DkimEnabled) {
        $findings.Add((New-M365Finding -ControlId 'M365-EXO-001' -Workload 'ExchangeOnline' -Title 'DKIM signing is not enabled for all assessed custom domains' -Severity Medium -Confidence 94 -Evidence 'DkimEnabled=False' -Impact 'Outbound mail has weaker domain-authentication assurance.' -Recommendation 'Enable DKIM for approved custom domains and validate SPF and DMARC alignment.' -Target $tenant))
    }
    if ($Data.Exchange.ExternalForwardingMailboxCount -gt 0) {
        $findings.Add((New-M365Finding -ControlId 'M365-EXO-002' -Workload 'ExchangeOnline' -Title 'Mailbox forwarding detected' -Severity High -Confidence 90 -Evidence "ForwardingMailboxCount=$($Data.Exchange.ExternalForwardingMailboxCount)" -Impact 'Mail may leave the tenant without appropriate governance or monitoring.' -Recommendation 'Review business justification, destination domains, and approved exceptions.' -Target $tenant))
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
            TenantName     = $tenant
            AssessedAtUtc  = [datetime]::UtcNow
            FindingCount   = $sorted.Count
            Critical       = @($sorted | Where-Object Severity -eq 'Critical').Count
            High           = @($sorted | Where-Object Severity -eq 'High').Count
            Medium         = @($sorted | Where-Object Severity -eq 'Medium').Count
            Low            = @($sorted | Where-Object Severity -eq 'Low').Count
            WorkloadScores = $workloadScores
        }
        Findings = $sorted
        Evidence = $Data
    }

    if ($OutputPath) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        $result | ConvertTo-Json -Depth 12 | Set-Content -Path (Join-Path $OutputPath 'assessment.json') -Encoding UTF8
        $sorted | Export-Csv -Path (Join-Path $OutputPath 'findings.csv') -NoTypeInformation -Encoding UTF8
        New-M365HtmlReport -Result $result -Path (Join-Path $OutputPath 'report.html') | Out-Null
    }

    $result
}

Export-ModuleMember -Function Get-M365SeverityRank,New-M365Finding,Import-M365SyntheticData,Invoke-M365GraphCollection,Get-M365LiveData,New-M365HtmlReport,Invoke-M365Assessment
