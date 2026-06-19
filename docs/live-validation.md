# Controlled Live Validation

Use only an authorized Microsoft 365 tenant and a dedicated assessment account. Review the requested permissions before connecting.

## Microsoft Graph connection

```powershell
Connect-MgGraph -Scopes @(
  'Organization.Read.All',
  'Policy.Read.All',
  'Directory.Read.All',
  'RoleManagement.Read.Directory',
  'Reports.Read.All'
)
```

Optional workload checks require their normal administrative modules and read access:

- Exchange Online Management
- SharePoint Online Management Shell
- Microsoft Teams PowerShell

## Run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-M365TenantHealthV2.ps1 `
  -Mode Live `
  -OutputPath .\artifacts\live-assessment `
  -OpenReport
```

## Expected outputs

- `assessment.json`
- `findings.csv`
- `report.html`

## Review checklist

- Review `CollectionNotes` for workloads that were not assessed.
- Confirm MFA-registration and Conditional Access evidence against the Entra admin center.
- Validate privileged-role counts and mailbox forwarding.
- Review DKIM, SharePoint sharing, and Teams meeting-policy findings.
- Never commit tenant identifiers, user lists, tokens, certificates, or private evidence.

The collector is read-only and performs no tenant changes.
