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
- Weaken fail-fast persona loading or security trunk (Context Budget Protocol, path allowlist, `[REDACTED]` redaction)

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

3. **Bundled skills for verify** — choose one:

   | Option | When to use |
   |--------|-------------|
   | **Fixture (default for CI)** | No Grok install — uses `fixtures/bundled-skills/` automatically |
   | **Local Grok Build** | Full runtime parity — `~/.grok/bundled/skills/` is preferred when present |
   | **Explicit override** | `export BUNDLED_SKILLS_ROOT=/path/to/bundled/skills` |

   Validate the fixture:

   ```bash
   bash scripts/bootstrap_bundled_fixture.sh
   ```

   Refresh fixture files from a local Grok install (optional):

   ```bash
   bash scripts/bootstrap_bundled_fixture.sh --refresh
   ```

   Resolution order is implemented in `scripts/resolve_bundled_root.sh`:
   `BUNDLED_SKILLS_ROOT` → `~/.grok/bundled/skills` → `fixtures/bundled-skills`.

## Verification (required before PR)

Both commands must exit `0`:

```bash
bash scripts/verify_skill.sh
bash tests/test_verify_skill.sh
```

- `verify_skill.sh` — frontmatter, required headings, normative wiring patterns, persona resolution, `memory.py` snapshot
- `test_verify_skill.sh` — negative/regression cases (missing patterns, stale messaging, broken wiring)

### Verify script notes

- **Pattern categories** are documented in `verify_skill.sh`: `NORMATIVE_WIRING`, `STRUCTURAL_GUARDS`, `PROSE_GUARDS`.
- Add or update grep patterns when a `SKILL.md` change is **normative** (not cosmetic prose).
- **Frontmatter quality** (description wording, flag ordering) is intentionally out-of-scope beyond presence checks.
- **Skills-list override** persona resolution is a known limitation — only bundled fallback paths are tested.

### SKIP behavior

`test_verify_skill.sh` may print `SKIP` for the unreadable-cwd `memory.py` test on permissive filesystems. SKIP is not a failure. If you change memory path logic, run that test on a stricter environment or add an explicit regression case.

## Pull request checklist

- [ ] `bash scripts/verify_skill.sh` passes
- [ ] `bash tests/test_verify_skill.sh` passes
- [ ] No secrets or personal paths in diff
- [ ] README updated if user-facing flags, phases, or install steps change
- [ ] Clear commit message (what + why)

## Reporting issues

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) when possible. Include:

- Grok Build environment (if known)
- Invocation string (redact paths/secrets)
- `BROWNFIELD_ID` and relevant `/tmp/grok-brownfield-*` artifact names (not full contents unless sanitized)
- Expected vs actual phase or error message

## Code of conduct

See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). Be constructive and precise — reproducibility and safety matter more than speed for long-running agent workflows.