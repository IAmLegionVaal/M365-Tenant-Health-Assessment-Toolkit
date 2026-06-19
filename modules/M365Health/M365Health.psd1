@{
    RootModule        = 'M365Health.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = '88306af2-c086-4f03-a540-859f68f8f7ac'
    Author            = 'Dewald Pretorius'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Dewald Pretorius. All rights reserved.'
    Description       = 'Enterprise Microsoft 365 tenant health assessment framework.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-M365Finding','Get-M365SeverityRank','Import-M365SyntheticData','Invoke-M365Assessment')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('Microsoft365','Entra','Graph','Assessment','PowerShell'); ProjectUri = 'https://github.com/IAmLegionVaal/M365-Tenant-Health-Assessment-Toolkit' } }
}