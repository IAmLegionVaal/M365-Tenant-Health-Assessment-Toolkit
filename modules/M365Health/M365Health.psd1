@{
    RootModule        = 'M365Health.psm1'
    NestedModules     = @('M365Health.Connection.psm1','M365Health.Comparison.psm1')
    ModuleVersion     = '2.2.0'
    GUID              = '88306af2-c086-4f03-a540-859f68f8f7ac'
    Author            = 'Dewald Pretorius'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Dewald Pretorius. All rights reserved.'
    Description       = 'Microsoft 365 tenant assessment, connection, reporting, scoring, and comparison module.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'New-M365Finding',
        'Get-M365SeverityRank',
        'Import-M365SyntheticData',
        'Invoke-M365GraphCollection',
        'Get-M365LiveData',
        'New-M365HtmlReport',
        'Invoke-M365Assessment',
        'Connect-M365Assessment',
        'Compare-M365Assessment'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Microsoft365','Entra','Graph','Assessment','PowerShell')
            ProjectUri = 'https://github.com/IAmLegionVaal/M365-Tenant-Health-Assessment-Toolkit'
        }
    }
}
