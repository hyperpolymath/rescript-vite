<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
# Security Policy

## Reporting Security Issues

**Do not open public issues for security vulnerabilities.**

If you discover a security vulnerability, please email the maintainers directly:

- Jonathan D.A. Jewell: j.d.a.jewell@open.ac.uk

Please include:
- Description of the vulnerability
- Steps to reproduce (if applicable)
- Potential impact
- Suggested fix (if available)

We will investigate and respond within a reasonable timeframe.

## Security Practices

### Dependency Management

- Dependencies are kept up-to-date via automated tooling
- Security scanning is performed on all commits
- Known vulnerabilities are remediated promptly

### Code Quality

- Type-safe ReScript prevents entire classes of runtime errors
- All code is reviewed before merging
- Static analysis tools detect potential issues

### Releases

- Security updates are released as soon as fixes are available
- Patch releases may be issued outside normal release cycles for critical issues

## Vulnerability Disclosure

We follow responsible disclosure. Once a security issue is fixed:

1. A patch release is issued
2. Security advisories are published
3. All users are notified

Thank you for helping keep rescript-vite secure!
