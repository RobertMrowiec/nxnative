# Security Policy & Branch Protection Guidelines

## 🛡️ Open Source Security Philosophy

**NxNative Launcher** is an open-source project. Being open-source means the source code, releases, and documentation are public for everyone to view, audit, and download.

However, **public read access does NOT grant write access**. The project enforces strict branch protection, clean-room standards, automated security scanning, and manual code reviews to prevent malicious code injection, supply-chain attacks, or unauthorized changes to the `main` branch.

---

## 🔒 Branch Protection & Access Control

To ensure the integrity of the codebase:

1. **`main` is a Protected Branch**:
   - **Allowed to push**: **Maintainers only** (only the project owner can push).
   - **Allowed to merge**: **Maintainers only**.
   - **Force push**: **Disabled** (no one can rewrite git history).
   - **Branch deletion**: **Disabled**.

2. **Fork & Merge Request Workflow**:
   - Community contributors cannot push directly to `main` or any branch in this repository.
   - Any external contributions must be submitted via a **Fork** and a **Merge Request (MR)**.
   - All Merge Requests require:
     - Passing automated CI/CD security and clean-room pipelines.
     - Mandatory peer review and approval by the project maintainer.

3. **CI/CD Security Gatekeeper**:
   - Every Merge Request triggers automated checks:
     - **Clean-Room Verification**: Validates that no proprietary Nintendo keys (`prod.keys`, `title.keys`), ROM dumps (`.nsp`, `.xci`), or copyrighted binary assets are included.
     - **Secret Detection**: Scans for leaked personal access tokens, API credentials, or certificates.
     - **Code Injection Scanner**: Audits scripts and shell invocations against malicious payload patterns (`curl | bash`, base64 eval, suspicious external connections).

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or malicious behavior in NxNative Launcher:

1. **Do NOT open a public issue.**
2. Send a confidential report directly to the maintainer via GitLab Confidential Issues or via email to the maintainer: `rennancr93@gmail.com`.
3. Provide:
   - Detailed description of the vulnerability.
   - Steps to reproduce or proof-of-concept.
   - Potential impact and suggested mitigations.

We will acknowledge reports within 48 hours and work on a fix promptly.
