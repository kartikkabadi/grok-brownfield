#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# resolve_bundled_root.sh — resolve bundled Grok skills directory for verify scripts
#
# Resolution order:
#   1. BUNDLED_SKILLS_ROOT (explicit override, used in CI)
#   2. $HOME/.grok/bundled/skills (local Grok Build install)
#   3. repo fixtures/bundled-skills (portable fallback for contributors/CI)
#
# Prints the resolved absolute path on stdout. Exits 1 if none are usable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_BUNDLED="${HOME}/.grok/bundled/skills"
FIXTURE_BUNDLED="${REPO_ROOT}/fixtures/bundled-skills"

usable_bundled_root() {
  local root="$1"
  [[ -d "${root}" ]] \
    && [[ -f "${root}/implement/SKILL.md" ]] \
    && [[ -f "${root}/implement/scripts/memory.py" ]] \
    && [[ -d "${root}/shared/personas" ]]
}

if [[ -n "${BUNDLED_SKILLS_ROOT:-}" ]]; then
  if usable_bundled_root "${BUNDLED_SKILLS_ROOT}"; then
    cd "${BUNDLED_SKILLS_ROOT}" && pwd
    exit 0
  fi
  echo "resolve_bundled_root: BUNDLED_SKILLS_ROOT is set but incomplete: ${BUNDLED_SKILLS_ROOT}" >&2
  exit 1
fi

if usable_bundled_root "${DEFAULT_BUNDLED}"; then
  cd "${DEFAULT_BUNDLED}" && pwd
  exit 0
fi

if usable_bundled_root "${FIXTURE_BUNDLED}"; then
  cd "${FIXTURE_BUNDLED}" && pwd
  exit 0
fi

echo "resolve_bundled_root: no bundled skills root found." >&2
echo "  Tried: BUNDLED_SKILLS_ROOT (unset), ${DEFAULT_BUNDLED}, ${FIXTURE_BUNDLED}" >&2
echo "  Install Grok Build or run: bash scripts/bootstrap_bundled_fixture.sh" >&2
exit 1