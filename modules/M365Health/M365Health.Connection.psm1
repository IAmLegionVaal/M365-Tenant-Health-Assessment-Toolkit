function Connect-M365Assessment {
    [CmdletBinding(DefaultParameterSetName='Delegated')]
    param(
        [Parameter(ParameterSetName='Delegated')]
        [string[]]$Scopes = @(
            'Organization.Read.All',
            'Policy.Read.All',
            'Directory.Read.All',
            'RoleManagement.Read.Directory',
            'Reports.Read.All'
        ),

        [Parameter(Mandatory,ParameterSetName='AppOnly')]
        [string]$TenantId,

        [Parameter(Mandatory,ParameterSetName='AppOnly')]
        [string]$ClientId,

        [Parameter(Mandatory,ParameterSetName='AppOnly')]
        [string]$CertificateThumbprint
    )

    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required.'
    }

    if ($PSCmdlet.ParameterSetName -eq 'AppOnly') {
        Connect-MgGraph `
            -TenantId $TenantId `
            -ClientId $ClientId `
            -CertificateThumbprint $CertificateThumbprint `
            -NoWelcome `
            -ErrorAction Stop | Out-Null
    }
    else {
        Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop | Out-Null
    }

    Get-MgContext -ErrorAction Stop
}

Export-ModuleMember -Function Connect-M365Assessment
