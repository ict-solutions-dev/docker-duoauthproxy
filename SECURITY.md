# Security Policy

## Supported Versions

| Version | Supported |
| --- | --- |
| Latest release (`v1.x.x`) | Yes |
| `edge-*` (develop) | Best effort |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email: **support@ictsolutions.net**

Include:

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact

We will acknowledge your report within **48 hours** and aim to provide a fix or mitigation within **7 days** for critical issues.

## Security Measures

This project implements the following security practices:

- **Non-root container** — runs as user `duo` (UID/GID `35505`)
- **Vulnerability scanning** — [Trivy](https://github.com/aquasecurity/trivy) on every build, results in GitHub Security tab
- **SBOM generation** — SPDX format for supply chain transparency
- **Build provenance** — attested via [GitHub Attestations](https://github.com/actions/attest-build-provenance)
- **Dependency updates** — Dependabot monitors Docker base image and GitHub Actions
- **Secret handling** — supports `_FILE` suffix pattern for Docker secrets; never logs plaintext credentials
- **Minimal base image** — build dependencies are not carried into the final layer

## Disclosure Policy

We follow [coordinated vulnerability disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure). We ask that you give us reasonable time to address the issue before public disclosure.