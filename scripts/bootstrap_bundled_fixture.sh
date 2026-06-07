#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# bootstrap_bundled_fixture.sh — ensure fixtures/bundled-skills is ready for verify/CI
#
# The committed fixture under fixtures/bundled-skills/ is sufficient for CI.
# This script validates it and, when a local Grok install exists, can refresh
# persona/memory files from ~/.grok/bundled/skills for developers who want parity.
#
# Usage:
#   bash scripts/bootstrap_bundled_fixture.sh          # validate only (CI default)
#   bash scripts/bootstrap_bundled_fixture.sh --refresh  # copy from local Grok install

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE="${REPO_ROOT}/fixtures/bundled-skills"
LOCAL_BUNDLED="${HOME}/.grok/bundled/skills"
REFRESH=false

if [[ "${1:-}" == "--refresh" ]]; then
  REFRESH=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: bash scripts/bootstrap_bundled_fixture.sh [--refresh]" >&2
  exit 1
fi

required_paths=(
  "implement/SKILL.md"
  "implement/scripts/memory.py"
  "shared/personas/design-doc-writer.md"
  "shared/personas/design-doc-reviewer.md"
  "shared/personas/implementer.md"
  "shared/personas/reviewer.md"
  "shared/personas/security-auditor.md"
)

validate_fixture() {
  local missing=0
  for rel in "${required_paths[@]}"; do
    if [[ ! -s "${FIXTURE}/${rel}" ]]; then
      echo "bootstrap: missing or empty fixture file: fixtures/bundled-skills/${rel}" >&2
      missing=1
    fi
  done
  return "${missing}"
}

if [[ "${REFRESH}" == true ]]; then
  if [[ ! -d "${LOCAL_BUNDLED}" ]]; then
    echo "bootstrap: --refresh requires local Grok install at ${LOCAL_BUNDLED}" >&2
    exit 1
  fi
  mkdir -p "${FIXTURE}/implement/scripts" "${FIXTURE}/shared/personas"
  cp "${LOCAL_BUNDLED}/implement/SKILL.md" "${FIXTURE}/implement/SKILL.md"
  cp "${LOCAL_BUNDLED}/implement/scripts/memory.py" "${FIXTURE}/implement/scripts/memory.py"
  for persona in design-doc-writer design-doc-reviewer implementer reviewer security-auditor; do
    cp "${LOCAL_BUNDLED}/shared/personas/${persona}.md" \
      "${FIXTURE}/shared/personas/${persona}.md"
  done
  echo "bootstrap: refreshed fixtures from ${LOCAL_BUNDLED}"
fi

if validate_fixture; then
  echo "bootstrap: fixtures/bundled-skills ready"
  exit 0
fi

echo "bootstrap: fixture incomplete — run with --refresh after installing Grok Build," >&2
echo "  or set BUNDLED_SKILLS_ROOT to a full bundled-skills tree." >&2
exit 1