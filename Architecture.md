# Architecture – Intune Stuck Sync Fixer

## Overview

The **Intune Stuck Sync Fixer** is a production-grade automation designed to
detect and remediate Windows devices that silently stop syncing with Microsoft Intune.

It uses **Endpoint Analytics Proactive Remediations** to:
- Detect stale Intune check-ins
- Perform safe, minimal remediation
- Log every action centrally to Azure Log Analytics
- Notify users transparently when remediation occurs

The design follows **least privilege**, **idempotency**, and **observability-first** principles.

---

## High-Level Architecture

