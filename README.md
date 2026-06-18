# M365 Tenant Health Assessment Toolkit

A PowerShell toolkit for Microsoft 365 tenant health assessment preparation.

## Features

- Checks for Microsoft Graph and Exchange Online modules
- Generates a tenant assessment checklist
- Tests key Microsoft 365 service endpoints
- Creates CSV, JSON, Markdown, and HTML outputs
- Supports demo/readiness mode without tenant sign-in

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\M365_Tenant_Health_Assessment_Toolkit.ps1
```

## Safety

Readiness-focused. It does not change tenant settings.
