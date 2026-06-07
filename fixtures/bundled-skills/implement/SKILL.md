---
name: implement
description: Minimal implement skill stub for grok-brownfield verify fixture.
when-to-use: Verify fixture only — not for runtime use.
argument-hint: "[--effort N] <description>"
---
# Implement (verify fixture stub)

This file exists so `scripts/verify_skill.sh` can resolve bundled skills in CI
without a full Grok Build install. Runtime brownfield uses your local
`~/.grok/bundled/skills/implement/SKILL.md`.