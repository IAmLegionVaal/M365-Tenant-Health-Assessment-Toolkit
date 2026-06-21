# M365 Tenant Health Assessment Toolkit

A PowerShell toolkit for Microsoft 365 health assessment preparation and local support-workstation readiness.

## Assessment

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\M365_Tenant_Health_Assessment_Toolkit.ps1
```

## Local repair

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\M365_Admin_Workstation_Repair.ps1 -InstallRequiredModules -DryRun
```

Available local actions:

```powershell
.\M365_Admin_Workstation_Repair.ps1 -EnableTls12
.\M365_Admin_Workstation_Repair.ps1 -RepairPowerShellGallery
.\M365_Admin_Workstation_Repair.ps1 -InstallRequiredModules
.\M365_Admin_Workstation_Repair.ps1 -UpdateRequiredModules
```

The repair script restores the local PowerShell prerequisites used by the assessment toolkit. It can enable TLS 1.2 for the session, repair the default gallery registration, install the required Microsoft Graph and Exchange Online modules for the current user, and update those modules. It creates before-and-after reports, supports `-DryRun`, asks for confirmation, logs each action, and returns clear exit codes.

The repair script does not change tenant users, licences, mailboxes, policies or service configuration.

## Author

Dewald Pretorius — L2 IT Support Engineer
