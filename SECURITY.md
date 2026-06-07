# Security Policy

## Supported versions

Security fixes apply to the latest release on the `main` branch of
[kartikkabadi/grok-brownfield](https://github.com/kartikkabadi/grok-brownfield).

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report security issues privately via one of:

1. **[GitHub Security Advisories](https://github.com/kartikkabadi/grok-brownfield/security/advisories/new)** (preferred)
2. A private email to the maintainer listed in [LICENSE](./LICENSE) if GitHub advisories are unavailable

Include:

- Description of the issue and potential impact
- Steps to reproduce (redact secrets and internal paths)
- Suggested fix or mitigation, if you have one

## Response timeline

| Stage | Target |
|-------|--------|
| Initial acknowledgement | Within 7 days |
| Triage and severity assessment | Within 14 days |
| Fix or documented mitigation | Depends on severity; critical issues prioritized |

## Scope notes

- This repository ships a **Grok Build skill specification** (`SKILL.md`) and verification scripts — not a hosted service.
- Runtime execution depends on Grok Build and bundled personas under `~/.grok/bundled/skills/`, which are outside this repo.
- Do not include API keys, tokens, or customer data in issue reports or PRs.