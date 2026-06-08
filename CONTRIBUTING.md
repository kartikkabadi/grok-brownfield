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

### Quick Start for First-Time Contributors

Get from clone to first successful PR in ~10 minutes:

1. **Clone the repo** (2 minutes)
   ```bash
   git clone https://github.com/kartikkabadi/grok-brownfield.git
   cd grok-brownfield
   ```

2. **Run the dev setup script** (3 minutes)
   ```bash
   bash scripts/dev_setup.sh
   ```
   This validates fixtures, runs verification, and runs tests. What success looks like: script exits with "🎉 Development setup complete!"

3. **Make a trivial change** (2 minutes)
   - Edit `README.md` and add a single character to the title
   - Run `make verify` to confirm it passes
   - What success looks like: "All brownfield skill structure checks passed."

4. **Run verification** (1 minute)
   ```bash
   make all
   ```
   This runs `verify`, `test`, and `bootstrap` in sequence. What success looks like: "All verification passed!"

5. **Submit your PR** (2 minutes)
   - Commit your trivial change with a clear message
   - Push to your fork and open a PR
   - CI will run the same verification automatically

**Stuck?** See the [Troubleshooting](#debugging-verify-failures) section below or open an issue with the `good first issue` label.

### Full Setup

1. Clone the repo:

   ```bash
   git clone https://github.com/kartikkabadi/grok-brownfield.git
   cd grok-brownfield
   ```

2. Install the skill locally (optional, for live Grok testing):

   ```bash
   cp -r . ~/.grok/skills/brownfield
   # Or use the Makefile:
   make install-dev
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
   # Or use the Makefile:
   make bootstrap
   ```

   Refresh fixture files from a local Grok install (optional):

   ```bash
   bash scripts/bootstrap_bundled_fixture.sh --refresh
   # Or use the Makefile:
   make bootstrap-refresh
   ```

   Resolution order is implemented in `scripts/resolve_bundled_root.sh`:
   `BUNDLED_SKILLS_ROOT` → `~/.grok/bundled/skills` → `fixtures/bundled-skills`.

### Local Development Without Grok

You can develop and test most changes without a full Grok Build installation using the fixture system:

```bash
# Use the fixture for verification
export BUNDLED_SKILLS_ROOT=$(pwd)/fixtures/bundled-skills
bash scripts/verify_skill.sh
bash tests/test_verify_skill.sh
# Or use Makefile with BUNDLED_SKILLS_ROOT set
BUNDLED_SKILLS_ROOT=$(pwd)/fixtures/bundled-skills make all
```

**When you DO need full Grok:**
- Testing persona-specific changes (persona behavior varies by Grok version)
- End-to-end skill execution (requires full orchestrator)
- Validating bundled skill compatibility after updates

**Limitations of fixture-only development:**
- Fixture personas are minimal stubs, not full runtime versions
- Some persona resolution edge cases may differ
- Memory.py behavior may vary slightly in full Grok environment

### Development Tools

**Makefile**
Convenience targets for common development tasks:
```bash
make help           # Show all available commands
make verify         # Run structure verification
make test           # Run negative/regression tests
make bootstrap      # Validate bundled-skills fixture
make all            # Run verify + test + bootstrap
make clean          # Remove temporary files
make install-dev    # Install skill locally for Grok testing
```

**Pre-commit hooks (optional)**
Install pre-commit to run verification automatically before commits:
```bash
# Install pre-commit (if not already installed)
pip install pre-commit

# Install the hooks
pre-commit install

# Hooks will now run before each commit
# To skip hooks: git commit --no-verify
```
The pre-commit configuration runs `verify_skill.sh` and `test_verify_skill.sh` on relevant file changes.

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

### Context budget verify patterns

When changing transport-layer behavior in `SKILL.md`, keep `scripts/verify_skill.sh` greps aligned. Required patterns (see `verify_skill.sh` for the canonical list):

| Pattern / anchor | What it guards |
|------------------|----------------|
| `^## Context Budget Protocol` | Normative transport section exists |
| `400,?000\|400000` | Hard cap constant documented |
| `pre-spawn` | Pre-spawn gate before specialist launch |
| `spawn log` / `spawn_log_file` / `grok-brownfield-spawn-log` | Spawn log artifact wiring |
| `excerpt-only` | Downstream handoff uses excerpts, not full artifacts |
| `MUST NOT inject full.*SKILL\|never.*full SKILL` | Full SKILL.md injection prohibited |
| `Phase 0b\|Source Principles Ingestion` | Optional Pass 0 chunked source ingestion |
| `grok-brownfield-source-merged` | Merged source artifact path |
| `Est\. input chars`, `Budget status`, `Transport mode` | Phase 1b budget columns |
| Delegated Execution Path + `context budget` + `excerpt-only` + `instructions_file` | Nested `/execute-plan` handoff parity |

**Negative test:** `tests/test_verify_skill.sh` includes `NO_CONTEXT_BUDGET` — stripping the Context Budget Protocol section must fail verify. Add or update a negative test when introducing a new normative protocol section.

**Security trunk** (replaces deprecated chmod/umask ceremony): Context Budget Protocol, path allowlist (`/tmp/grok-brownfield-*`), and `[REDACTED]` redaction — all three must remain verified.

### Debugging Verify Failures

Common verify failure modes and how to resolve them:

**1. Missing required heading pattern**
- Example error: `required heading missing: ^## Context Budget Protocol`
- Root cause: A required section heading was renamed or removed from SKILL.md
- Resolution: Restore the exact heading pattern (anchored regex must match)
- Verify: Run `make verify` again
- When to open an issue: Only if the heading pattern in verify_skill.sh appears incorrect

**2. Context budget pattern mismatch**
- Example error: `Context Budget Protocol missing 400k cap constant`
- Root cause: The Context Budget Protocol section is missing the `400,000` character constant or related patterns
- Resolution: Ensure SKILL.md has the Context Budget Protocol section with all required patterns (see CONTRIBUTING.md context budget verify patterns list)
- Verify: Run `make verify` again
- When to open an issue: If the pattern in verify_skill.sh is incorrect or outdated

**3. Persona resolution failure**
- Example error: `persona missing: design-doc-writer`
- Root cause: Required persona file not found in bundled skills
- Resolution: Run `make bootstrap` to validate fixture; install Grok Build or set `BUNDLED_SKILLS_ROOT` appropriately
- Verify: Check that all required personas exist in the resolved bundled skills root
- When to open an issue: If verify script is checking for a persona that no longer exists

**4. Memory.py JSON schema error**
- Example error: `memory.py snapshot returned invalid JSON or wrong types`
- Root cause: memory.py helper returned invalid JSON or wrong field types
- Resolution: Ensure fixture memory.py is valid; try `bash scripts/bootstrap_bundled_fixture.sh --refresh` if using local Grok
- Verify: Run `python3 fixtures/bundled-skills/implement/scripts/memory.py snapshot` manually
- When to open an issue: If fixture memory.py is valid but verify still fails

**5. Fixture sync issues**
- Example error: `bundled_skills_root not found`
- Root cause: No bundled skills root available (fixture missing, Grok not installed, BUNDLED_SKILLS_ROOT invalid)
- Resolution: Run `make bootstrap` to validate fixture; install Grok Build; or set `BUNDLED_SKILLS_ROOT` explicitly
- Verify: Run `bash scripts/resolve_bundled_root.sh` to see which path is being used
- When to open an issue: If resolve script logic appears incorrect

**When to open an issue:**
- Error message is unclear or doesn't point to a specific problem
- You followed resolution steps but verification still fails
- You suspect the verify script logic is incorrect (not your SKILL.md changes)
- Environment-specific issue (e.g., Python version compatibility) not covered in troubleshooting

Always include:
- Full error output from `make verify`
- Your OS and shell version
- Whether you're using fixture or local Grok Build
- Steps you've already tried to resolve

### SKIP behavior

`test_verify_skill.sh` may print `SKIP` for the unreadable-cwd `memory.py` test on permissive filesystems. SKIP is not a failure. If you change memory path logic, run that test on a stricter environment or add an explicit regression case.

## Pull request checklist

- [ ] `make verify` or `bash scripts/verify_skill.sh` passes
- [ ] `make test` or `bash tests/test_verify_skill.sh` passes
- [ ] No secrets or personal paths in diff
- [ ] **Normative SKILL change** → matching `verify_skill.sh` grep pattern added or updated
- [ ] **New protocol section** → negative regression test in `test_verify_skill.sh` (e.g. `NO_CONTEXT_BUDGET`)
- [ ] **User-facing phases, flags, deliverables, or transport behavior** → `README.md` updated
- [ ] Context budget / path allowlist / redaction trunk not weakened
- [ ] Clear commit message (what + why)
- [ ] Update `CHANGELOG.md` with entry under "Unreleased" section

## Reporting issues

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) when possible. Include:

- Grok Build environment (if known)
- Invocation string (redact paths/secrets)
- `BROWNFIELD_ID` and relevant `/tmp/grok-brownfield-*` artifact names (not full contents unless sanitized)
- Expected vs actual phase or error message

## Code of conduct

See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). Be constructive and precise — reproducibility and safety matter more than speed for long-running agent workflows.