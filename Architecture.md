# Architecture – Intune-StuckSync-Fixer

## High-Level Architecture

Intune-StuckSync-Fixer follows a **detection-driven remediation model**
aligned with Microsoft Intune Proactive Remediations.

Flow:
1. Device health is evaluated locally
2. Only unhealthy devices are remediated
3. Remediation actions are verified
4. Script exits cleanly

---

## Logical Flow

Windows Device  
→ Detection Script  
→ Health Decision (Healthy / Unhealthy)  
→ Remediation Script (only if unhealthy)  
→ Verification & Optional Telemetry

---

## Detection Logic
The detection script evaluates:
- Presence and state of Intune Management Extension (IME)
- Recent IME activity via log freshness
- MDM transport presence (read-only check)

Detection outcome:
- Exit `0`: Healthy → No action
- Exit `1`: Unhealthy → Remediation triggered

---

## Remediation Logic
The remediation script:
- Validates MDM transport (no auto-fix)
- Restarts IME safely
- Verifies IME recovery
- Triggers Intune sync via EnterpriseMgmt scheduled tasks
- Optionally sends logs to Log Analytics
- Optionally notifies the user

---

## Design Constraints
- No OS-level service recreation
- No registry-based sync assumptions
- No hard-coded scheduled task paths
- No blind remediation

---

## Intended Outcome
- Restore IME execution health
- Trigger supported Intune sync paths
- Avoid remediation loops or device instability
