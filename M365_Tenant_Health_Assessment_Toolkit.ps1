#requires -Version 5.1
<#
.SYNOPSIS
    M365 Tenant Health Assessment Toolkit.
.DESCRIPTION
    Readiness and documentation tool for Microsoft 365 tenant health assessments.
#>
[CmdletBinding()]
param([string]$OutputPath)
$RunStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'M365_Tenant_Assessment'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null
function New-Check{param($Area,$Name,$Status,$Value,$Recommendation)[PSCustomObject]@{Area=$Area;Name=$Name;Status=$Status;Value=$Value;Recommendation=$Recommendation}}
$checks=@()
foreach($m in 'Microsoft.Graph','ExchangeOnlineManagement','MicrosoftTeams'){$mod=Get-Module -ListAvailable -Name $m|Select-Object -First 1;$checks+=New-Check 'Modules' $m ($(if($mod){'OK'}else{'Info'})) ($(if($mod){$mod.Version}else{'Not installed'})) 'Install module when live tenant assessment is required.'}
foreach($hostName in 'login.microsoftonline.com','graph.microsoft.com','admin.microsoft.com','outlook.office.com','teams.microsoft.com'){
try{[void][System.Net.Dns]::GetHostAddresses($hostName);$dns='Resolved'}catch{$dns='DNS failed'}
try{$tcp=Test-NetConnection -ComputerName $hostName -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue}catch{$tcp=$false}
$checks+=New-Check 'Connectivity' $hostName ($(if($tcp){'OK'}else{'Warning'})) "DNS=$dns; TCP443=$tcp" 'Review DNS, proxy, firewall, or internet path.'}
$checklist=@('Tenant domains verified','Admin break-glass accounts documented','MFA / conditional access reviewed','Licensing report exported','Exchange mail flow reviewed','Teams policy baseline reviewed','OneDrive sharing settings reviewed','Audit logging reviewed','Security defaults or CA strategy documented','Service health reviewed')|ForEach-Object{[PSCustomObject]@{ChecklistItem=$_;Status='Not assessed';Notes=''}}
$checks|Export-Csv (Join-Path $OutputPath "m365_readiness_checks_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$checks|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutputPath "m365_readiness_checks_$RunStamp.json") -Encoding UTF8
$checklist|Export-Csv (Join-Path $OutputPath "tenant_assessment_checklist_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$md=@('# M365 Tenant Health Assessment Checklist','',"Generated: $(Get-Date)",'')+$checklist.ForEach({"- [ ] $($_.ChecklistItem)"})
$md -join [Environment]::NewLine|Set-Content (Join-Path $OutputPath "tenant_assessment_checklist_$RunStamp.md") -Encoding UTF8
$html="<h1>M365 Tenant Health Assessment</h1><p>Generated $(Get-Date)</p><h2>Readiness Checks</h2>$($checks|ConvertTo-Html -Fragment)<h2>Checklist</h2>$($checklist|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'M365 Tenant Assessment'|Set-Content (Join-Path $OutputPath "m365_tenant_assessment_$RunStamp.html") -Encoding UTF8
$checks|Format-Table -AutoSize -Wrap
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
