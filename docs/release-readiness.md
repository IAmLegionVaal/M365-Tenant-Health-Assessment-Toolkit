# Release Readiness

## Completed

- Versioned PowerShell module
- Synthetic and live read-only tenant collection
- Microsoft Graph paging and connection helpers
- Required permission documentation
- Identity, access-policy, privileged-role, mail, sharing, and meeting-policy checks
- Normalized findings and workload scoring
- JSON, CSV, and HTML reporting
- Baseline comparison and workload-score changes
- Pester and PSScriptAnalyzer validation
- Windows GitHub Actions artifacts
- Controlled live-validation procedure

## Remaining merge gate

Run the collector against an authorized test tenant and review sanitized output. Additional endpoint-management, retention, application, and trend collectors can follow in later releases.
