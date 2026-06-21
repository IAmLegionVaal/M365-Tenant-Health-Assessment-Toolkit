[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param(
 [switch]$InstallRequiredModules,
 [switch]$UpdateRequiredModules,
 [switch]$EnableTls12,
 [switch]$RepairPowerShellGallery,
 [switch]$DryRun,[switch]$Yes,
 [string]$OutputPath=(Join-Path $env:LOCALAPPDATA 'M365AdminRepairReports')
)
$ErrorActionPreference='Stop';$script:Failures=0;$script:Actions=0
$run=Join-Path $OutputPath (Get-Date -Format yyyyMMdd_HHmmss);New-Item -ItemType Directory $run -Force|Out-Null
$log=Join-Path $run 'repair.log';$before=Join-Path $run 'before.json';$after=Join-Path $run 'after.json'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Tee-Object -FilePath $log -Append}
function State{[pscustomobject]@{Collected=Get-Date;PowerShell=$PSVersionTable.PSVersion.ToString();Tls=[Net.ServicePointManager]::SecurityProtocol.ToString();Repositories=Get-PSRepository -ErrorAction SilentlyContinue|Select-Object Name,SourceLocation,InstallationPolicy;Modules=Get-Module Microsoft.Graph,ExchangeOnlineManagement -ListAvailable|Select-Object Name,Version,Path}}
function Act($d,[scriptblock]$a){$script:Actions++;Log $d;if($DryRun){Log "DRY-RUN: $d";return};try{&$a;Log "SUCCESS: $d"}catch{$script:Failures++;Log "FAILED: $d - $($_.Exception.Message)"}}
State|ConvertTo-Json -Depth 5|Set-Content $before -Encoding UTF8
if(-not($InstallRequiredModules -or $UpdateRequiredModules -or $EnableTls12 -or $RepairPowerShellGallery)){Write-Error 'Choose at least one repair action.';exit 2}
if(-not $Yes -and -not $DryRun){if((Read-Host 'Apply selected Microsoft 365 admin workstation repairs? Type YES') -ne 'YES'){Log 'Cancelled.';exit 10}}
if($EnableTls12){Act 'Enabling TLS 1.2 for the current PowerShell process' {[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}}
if($RepairPowerShellGallery){Act 'Registering the default PowerShell Gallery repository' {if(Get-PSRepository PSGallery -ErrorAction SilentlyContinue){Set-PSRepository PSGallery -InstallationPolicy Trusted}else{Register-PSRepository -Default;Set-PSRepository PSGallery -InstallationPolicy Trusted}}}
if($InstallRequiredModules){foreach($m in 'Microsoft.Graph','ExchangeOnlineManagement'){Act "Installing $m for the current user" {Install-Module $m -Scope CurrentUser -Force -AllowClobber -Repository PSGallery}}}
if($UpdateRequiredModules){foreach($m in 'Microsoft.Graph','ExchangeOnlineManagement'){Act "Updating $m" {Update-Module $m -Force -ErrorAction Stop}}}
State|ConvertTo-Json -Depth 5|Set-Content $after -Encoding UTF8
if($script:Failures){Log "Completed with $script:Failures failure(s).";exit 20};Log "Repair completed. Actions: $script:Actions";exit 0
