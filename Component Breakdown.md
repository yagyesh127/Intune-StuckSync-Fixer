# Component Breakdown – Intune-StuckSync-Fixer

## 1. Detection Script
**Purpose:** Decide whether remediation is required.

Responsibilities:
- Check IME service presence
- Evaluate IME log activity freshness
- Validate MDM transport availability
- Output deterministic exit codes

Outputs:
- Exit `0` → Healthy
- Exit `1` → Unhealthy

---

## 2. Remediation Script
**Purpose:** Restore IME health and trigger sync safely.

Responsibilities:
- Restart or start IntuneManagementExtension
- Verify service recovery
- Trigger EnterpriseMgmt scheduled tasks
- Avoid unsafe OS changes

---

## 3. IME Log Evaluation
- Reads IME log files under:
  `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`
- Uses timestamp freshness as health signal
- Avoids registry or event log dependency

---

## 4. EnterpriseMgmt Task Enumeration
- Enumerates tasks under:
  `\Microsoft\Windows\EnterpriseMgmt\`
- Handles GUID-based enrollment paths
- Triggers Push / Schedule tasks safely

---

## 5. Optional Log Analytics Integration
- Sends remediation results to Azure Log Analytics
- Enables centralized reporting and dashboards

---

## 6. Optional User Toast Notification
- Shown only when an interactive user session exists
- Automatically skipped in SYSTEM-only contexts

---

## Non-Goals
- Repair broken MDM enrollment
- Modify OS-owned services
- Replace re-enrollment scenarios
