# Intune-StuckSync-Fixer
An Intune Proactive Remediation that detects stuck device sync by validating MDM transport, IME execution health, and IME activity freshness — and safely remediates only when appropriate.

## Features
- Detection + Remediation split
- Safe IME restart
- Log Analytics integration
- User toast notification
- Idempotent and automation-ready

**What This Solves**

Some Windows devices appear enrolled in Intune but stop:
Checking in
Running Win32 apps
Executing scripts or Proactive Remediations

Intune-StuckSync-Fixer detects this condition and restores Intune Management Extension (IME) health using supported, enterprise-safe actions.

**How It Works**

**Detection Script**

1.Validates IME presence
2.Checks recent IME activity via logs
3.Confirms MDM transport availability
4.→ Healthy (Exit 0) or Unhealthy (Exit 1)

**Remediation Script (runs only if unhealthy)**

1.Restarts IME safely
2.Verifies IME recovery
3.Triggers Intune sync via EnterpriseMgmt scheduled tasks
4.(Optional) Sends logs to Azure Log Analytics
5.(Optional) Notifies the logged-in user

**Why This Is Different**

--Detection-first – no blind restarts or forced syncs

--Platform-safe – no registry hacks, no OS service recreation

--Scale-ready – built for Intune Proactive Remediations

--Resilient – enumerates EnterpriseMgmt tasks (GUID-safe)

**DECISION MATRIX**			
				
flowchart TD
    A[Windows Device<br/>Intune Enrolled?]

    A -->|No| Z[Not applicable<br/>Outside scope]

    A -->|Yes| B{MDM Transport<br/>Running?}

    B -->|No| C[Unhealthy<br/>Transport broken<br/>Re-enrollment required<br/>❌ No remediation]

    B -->|Yes| D{IME Installed?}

    D -->|No| E[Unhealthy<br/>IME missing<br/>Enrollment issue<br/>❌ No remediation]

    D -->|Yes| F{IME Activity<br/>Fresh?}

    F -->|Yes| G[Healthy<br/>✅ No action]

    F -->|No| H[Unhealthy but fixable<br/>IME stalled<br/>✅ Remediation runs]

**Documentation**

Detailed documentation is split by responsibility:
📄 Deployment: Main/Deployment.md
🏗 Architecture: Main/Architecture.md
🧩 Components: Main/Components.md

## Author
Yagyesh Agarwal 
https://www.linkedin.com/in/yagyeshagarwal/
