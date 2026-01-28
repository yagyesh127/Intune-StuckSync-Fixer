---

## Component Breakdown

### 1. Detection Script

**Purpose**
- Determine whether the device has failed to sync with Intune within a defined SLA window.

**Key Characteristics**
- Read-only
- No service restarts
- Fast execution
- Deterministic output

**Data Source**
- Registry:  
  `HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension`

**Exit Codes**
- `0` → Device is healthy
- `1` → Sync is stale or undetermined

---

### 2. Remediation Script

**Purpose**
- Safely recover Intune sync without unnecessary disruption.

**Actions**
- Re-validate sync age
- Restart `IntuneManagementExtension` service only when required
- Allow natural policy re-evaluation
- Avoid redundant or repeated actions

**Safety Controls**
- Threshold-based execution
- Try/Catch with graceful failure
- No reboot or destructive operations

---

### 3. Log Analytics Integration

**Why Central Logging Matters**
- Intune reporting alone does not explain *why* remediation ran
- Logs enable:
  - Root-cause analysis
  - Pattern detection
  - Auditability

**Implementation**
- Azure Monitor HTTP Data Collector API
- Custom table: `IntuneSyncFixer_CL`
- Fields:
  - TimeGenerated
  - Computer
  - Level (INFO/WARN/ERROR)
  - Message

---

### 4. User Toast Notification

**Purpose**
- Improve transparency and user trust
- Reduce helpdesk tickets caused by “silent fixes”

**Design**
- Non-technical language
- No action required from user
- Triggered only after remediation

---

## Design Principles

| Principle | Implementation |
|---------|----------------|
| Least privilege | Read-only detection |
| Idempotency | No repeated restarts |
| Observability | Central logging |
| UX awareness | Toast notifications |
| Scalability | Tenant-wide deployment |

---

## Supported Platforms

- Windows 10 (20H2+)
- Windows 11
- Microsoft Intune (MEM)
- Azure Log Analytics

---

## Future Enhancements

- Azure Monitor alerts for repeated remediation
- Correlation with Endpoint Analytics scores
- Graph-based device health validation
- Multi-tenant MSP adaptation
