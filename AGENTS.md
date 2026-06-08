# Agent instructions (contributors)

Brief guidance for AI agents editing **grok-brownfield**.

## Scope

- **In scope:** `SKILL.md`, `scripts/verify_skill.sh`, `tests/test_verify_skill.sh`, `README.md`, `CONTRIBUTING.md`
- **Out of scope:** `~/.grok/bundled/skills/` (separate bundle), user `/tmp` artifacts, secrets

## Editing SKILL.md

1. Preserve frontmatter keys: `name`, `description`, `when-to-use`, `argument-hint`, `compatibility`
2. Keep phase numbering consistent (0 → 6, plus 2a, 4b)
3. Tool-call discipline section is normative — do not weaken anti-hallucination rules
4. Resume path validation (`brownfield_id`, workspace_root, artifact allowlist) must stay strict
5. When adding normative behavior, add a matching pattern to `scripts/verify_skill.sh`

## Protocol-update checklist

When changing normative transport or phase behavior in `SKILL.md`, apply all four steps in order:

1. **SKILL.md** — encode the normative section (e.g. Context Budget Protocol, Phase 1b columns, Delegation prompt rule). Cite line ranges; do not inline the full skill in prompts.
2. **`scripts/verify_skill.sh`** — add or update anchored grep patterns that fail if the section is removed or hollowed out.
3. **`tests/test_verify_skill.sh`** — add a negative test that strips the section and expects verify failure (pattern: `NO_CONTEXT_BUDGET`).
4. **`README.md`** — update mermaid, deliverables, or workflow description if the change is user-facing (phases, flags, context budget, artifacts).

Skip step 4 only for purely internal wiring with no contributor or end-user visibility.

## Verification workflow

Always run from repo root:

```bash
bash scripts/verify_skill.sh
bash tests/test_verify_skill.sh
```

Fix failures before committing. Negative tests intentionally mutate copies under `mktemp` — do not skip them.

## README vs SKILL.md

- **README.md** — human-facing GitHub landing (install, examples, tables, mermaid)
- **SKILL.md** — full orchestrator spec for Grok at runtime

Do not duplicate the entire skill in README; link to `SKILL.md` for internals.

## Git

- One logical change per commit when possible
- No tokens or credentials in messages or files
- Public repo: `kartikkabadi/grok-brownfield`

## Do not

- Reference internal hostnames (e.g. `internal.example.com`, `<org>-internal`) in examples
- Commit `/tmp/grok-*` state or design drafts
- Change verify scripts to pass on a weakened skill without updating tests intentionally