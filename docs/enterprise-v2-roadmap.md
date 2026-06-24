# Microsoft 365 Tenant Health Assessment Toolkit — Enterprise v2 Roadmap

## Objective

Evolve the current tenant-readiness and assessment script into a senior-level Microsoft 365 and Entra assurance platform with explicit permissions, resilient Graph access, workload-specific scoring, and professional evidence handling.

## v2 architecture

- Versioned PowerShell module
- Provider adapters for Microsoft Graph, Exchange Online, Teams, SharePoint Online, and optional Intune
- Authentication abstraction supporting delegated and app-only modes
- Explicit permission manifest and least-privilege documentation
- Retry, throttling, paging, timeout, and partial-failure handling
- Typed findings and evidence objects
- Tenant-wide scoring and workload scorecards
- JSON, CSV, and HTML output
- Simulation mode with synthetic tenant data

## Senior-level assessment domains

### Identity and access

- Tenant and verified-domain inventory
- Conditional Access coverage and policy-state review
- Authentication methods and registration posture
- MFA and legacy-authentication exposure
- Privileged role assignments and eligible access
- Guest-user and external-collaboration posture
- Break-glass account documentation checks

### Exchange Online

- Mail-flow and connector inventory
- Accepted domains and remote domains
- Anti-spam, anti-malware, Safe Links, and Safe Attachments posture
- DKIM, DMARC, and SPF evidence
- Shared mailbox and forwarding exposure
- Transport-rule review
- Audit and retention settings

### SharePoint and OneDrive

- External-sharing posture
- Anonymous-link exposure
- Site ownership and orphaned-site indicators
- Storage and quota trends
- Sync and sharing governance evidence
- Retention and sensitivity-label coverage

### Teams

- Meeting, messaging, federation, and guest policy review
- External access and anonymous joining
- Application permission posture
- Teams lifecycle and ownership indicators

### Intune and endpoint management

- Enrollment and compliance coverage
- Configuration-profile and security-baseline coverage
- Application deployment health
- Update-ring posture
- Device-risk and stale-device indicators

### Reporting

- Executive tenant health score
- Workload scorecards
- Severity, confidence, business impact, evidence, and remediation
- Permission and data-access disclosure
- Sanitized sample reports and synthetic datasets

## Engineering standards

- Pester tests with mocked Graph responses
- Contract tests for provider adapters
- PSScriptAnalyzer
- GitHub Actions on Windows
- Semantic versioning
- Changelog, security policy, and contribution guidance
- Data-handling and redaction documentation
- API throttling and retry tests

## Delivery phases

### Phase 1

- Module structure
- Authentication and permission model
- Graph paging and retry engine
- Tenant, identity, role, and domain collectors
- CI, tests, and enterprise report

### Phase 2

- Exchange, SharePoint, OneDrive, and Teams collectors
- Workload scoring
- Synthetic tenant datasets

### Phase 3

- Intune collectors
- Baseline comparison and trend reporting
- Scheduled assessments and ticketing integrations

## Completion standard

The upgrade is ready only after CI passes, synthetic API tests succeed, a controlled tenant assessment is reviewed, required permissions are documented, and no customer or employer data is committed to the repository.