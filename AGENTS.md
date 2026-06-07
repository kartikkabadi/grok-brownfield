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

- Reference `kartikkabadi-max` or other internal hostnames
- Commit `/tmp/grok-*` state or design drafts
- Change verify scripts to pass on a weakened skill without updating tests intentionally