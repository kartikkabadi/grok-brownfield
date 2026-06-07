# Contributing to grok-brownfield

Thank you for helping improve the `/brownfield` Grok Build skill.

## What to contribute

- **Bug fixes** in `SKILL.md` (orchestration logic, prompts, edge cases)
- **Verification** improvements in `scripts/verify_skill.sh` and `tests/test_verify_skill.sh`
- **Documentation** clarifications in `README.md` or this file
- **Issues** describing confusing behavior, missing resume paths, or verify gaps

Please do **not** open PRs that:

- Add secrets, internal paths, or machine-specific configuration
- Include `/tmp` design drafts or personal memory files
- Weaken fail-fast persona loading or security checks (umask, path allowlists, `chmod 600`)

## Development setup

1. Clone the repo:

   ```bash
   git clone https://github.com/kartikkabadi/grok-brownfield.git
   cd grok-brownfield
   ```

2. Install the skill locally (optional, for live Grok testing):

   ```bash
   cp -r . ~/.grok/skills/brownfield
   ```

3. Ensure bundled Grok skills exist at `~/.grok/bundled/skills/` (required for verify scripts).

## Verification (required before PR)

Both commands must exit `0`:

```bash
bash scripts/verify_skill.sh
bash tests/test_verify_skill.sh
```

- `verify_skill.sh` — frontmatter, required headings, design-mandated patterns, persona resolution, `memory.py` snapshot
- `test_verify_skill.sh` — negative/regression cases (missing patterns, stale messaging, broken wiring)

If you change `SKILL.md`, add or update grep patterns in `verify_skill.sh` when the change is normative (not cosmetic).

## Pull request checklist

- [ ] `bash scripts/verify_skill.sh` passes
- [ ] `bash tests/test_verify_skill.sh` passes
- [ ] No secrets or personal paths in diff
- [ ] README updated if user-facing flags, phases, or install steps change
- [ ] Clear commit message (what + why)

## Reporting issues

Include when possible:

- Grok Build environment (if known)
- Invocation string (redact paths/secrets)
- `BROWNFIELD_ID` and relevant `/tmp/grok-brownfield-*` artifact names (not full contents unless sanitized)
- Expected vs actual phase or error message

## Code of conduct

Be constructive and precise. This skill coordinates long-running agent workflows — reproducibility and safety matter more than speed.