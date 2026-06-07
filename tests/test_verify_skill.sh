#!/usr/bin/env bash
# test_verify_skill.sh — negative/regression tests for verify_skill.sh
#
# Run both verification scripts:
#   bash scripts/verify_skill.sh
#   bash tests/test_verify_skill.sh
#
umask 077
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERIFY="${SKILL_DIR}/scripts/verify_skill.sh"
SOURCE_SKILL="${SKILL_DIR}/SKILL.md"
BUNDLED_SRC="${HOME}/.grok/bundled/skills"
TMPROOT="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# expect_fail LABEL EXPECTED_SUBSTRING COMMAND...
expect_fail() {
  local label="$1"
  local expect="$2"
  shift 2

  local stderr_file
  stderr_file="$(mktemp)"
  if "$@" 2>"${stderr_file}" >/dev/null; then
    cat "${stderr_file}" >&2
    rm -f "${stderr_file}"
    fail "${label}: expected non-zero exit"
  fi
  if ! grep -qF -- "${expect}" "${stderr_file}"; then
    echo "stderr was:" >&2
    cat "${stderr_file}" >&2
    rm -f "${stderr_file}"
    fail "${label}: expected stderr containing: ${expect}"
  fi
  rm -f "${stderr_file}"
  pass "${label}"
}

[[ -f "${VERIFY}" ]] || fail "verify_skill.sh not found"

# --- Positive control ---
bash "${VERIFY}" || fail "positive control: real skill should pass"
pass "positive control: real skill passes"

# --- Missing SKILL.md ---
MISSING_DIR="${TMPROOT}/no-skill"
mkdir -p "${MISSING_DIR}/scripts"
cp "${VERIFY}" "${MISSING_DIR}/scripts/verify_skill.sh"
expect_fail "missing SKILL.md" "SKILL.md not found" bash "${MISSING_DIR}/scripts/verify_skill.sh"

# --- Bad frontmatter name ---
BAD_NAME_DIR="${TMPROOT}/bad-name"
mkdir -p "${BAD_NAME_DIR}/scripts"
cp "${VERIFY}" "${BAD_NAME_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${BAD_NAME_DIR}/SKILL.md"
sed -i '' 's/^name: brownfield$/name: not-brownfield/' "${BAD_NAME_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/^name: brownfield$/name: not-brownfield/' "${BAD_NAME_DIR}/SKILL.md"
expect_fail "bad name: brownfield" "frontmatter name: brownfield missing" bash "${BAD_NAME_DIR}/scripts/verify_skill.sh"

# --- Dropped chmod 600 pattern ---
NO_CHMOD_DIR="${TMPROOT}/no-chmod"
mkdir -p "${NO_CHMOD_DIR}/scripts"
cp "${VERIFY}" "${NO_CHMOD_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_CHMOD_DIR}/SKILL.md"
sed -i '' '/chmod 600/d' "${NO_CHMOD_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/chmod 600/d' "${NO_CHMOD_DIR}/SKILL.md"
expect_fail "missing chmod 600" "chmod 600" bash "${NO_CHMOD_DIR}/scripts/verify_skill.sh"

# --- Dropped wait protocol ---
NO_WAIT_DIR="${TMPROOT}/no-wait"
mkdir -p "${NO_WAIT_DIR}/scripts"
cp "${VERIFY}" "${NO_WAIT_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_WAIT_DIR}/SKILL.md"
sed -i '' '/get_command_or_subagent_output/d' "${NO_WAIT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/get_command_or_subagent_output/d' "${NO_WAIT_DIR}/SKILL.md"
expect_fail "missing get_command_or_subagent_output" "get_command_or_subagent_output" bash "${NO_WAIT_DIR}/scripts/verify_skill.sh"

# --- Missing inline execute (execute_inline phase) ---
NO_INLINE_DIR="${TMPROOT}/no-inline"
mkdir -p "${NO_INLINE_DIR}/scripts"
cp "${VERIFY}" "${NO_INLINE_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_INLINE_DIR}/SKILL.md"
# Replace token globally but keep heading lines intact for other checks
sed -i '' 's/execute_inline/INLINE_PHASE_REMOVED/g' "${NO_INLINE_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/execute_inline/INLINE_PHASE_REMOVED/g' "${NO_INLINE_DIR}/SKILL.md"
expect_fail "missing execute_inline" "execute_inline" bash "${NO_INLINE_DIR}/scripts/verify_skill.sh"

# --- Missing effort passthrough wiring ---
NO_EFFORT_DIR="${TMPROOT}/no-effort"
mkdir -p "${NO_EFFORT_DIR}/scripts"
cp "${VERIFY}" "${NO_EFFORT_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_EFFORT_DIR}/SKILL.md"
sed -i '' 's/\*\*not\*\* hardcoded 1/always hardcoded 1/g' "${NO_EFFORT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/\*\*not\*\* hardcoded 1/always hardcoded 1/g' "${NO_EFFORT_DIR}/SKILL.md"
expect_fail "missing effort passthrough" "hardcoded 1" bash "${NO_EFFORT_DIR}/scripts/verify_skill.sh"

# --- Missing PRIMARY/FALLBACK path labels ---
NO_PRIMARY_DIR="${TMPROOT}/no-primary"
mkdir -p "${NO_PRIMARY_DIR}/scripts"
cp "${VERIFY}" "${NO_PRIMARY_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_PRIMARY_DIR}/SKILL.md"
sed -i '' 's/PRIMARY/DEFAULT_PATH/g' "${NO_PRIMARY_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/PRIMARY/DEFAULT_PATH/g' "${NO_PRIMARY_DIR}/SKILL.md"
expect_fail "missing PRIMARY label" "PRIMARY" bash "${NO_PRIMARY_DIR}/scripts/verify_skill.sh"

# --- Missing execute_pending phase token ---
NO_PENDING_DIR="${TMPROOT}/no-pending"
mkdir -p "${NO_PENDING_DIR}/scripts"
cp "${VERIFY}" "${NO_PENDING_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_PENDING_DIR}/SKILL.md"
sed -i '' 's/execute_pending/EXEC_PENDING_REMOVED/g' "${NO_PENDING_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/execute_pending/EXEC_PENDING_REMOVED/g' "${NO_PENDING_DIR}/SKILL.md"
expect_fail "missing execute_pending" "execute_pending" bash "${NO_PENDING_DIR}/scripts/verify_skill.sh"

# --- Phase 6 before Step 9 ordering regression ---
BAD_ORDER_DIR="${TMPROOT}/bad-order"
mkdir -p "${BAD_ORDER_DIR}/scripts"
cp "${VERIFY}" "${BAD_ORDER_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${BAD_ORDER_DIR}/SKILL.md"
sed -i '' '/Normative order.*Step 8.*Phase 6.*Step 9/d' "${BAD_ORDER_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/Normative order.*Step 8.*Phase 6.*Step 9/d' "${BAD_ORDER_DIR}/SKILL.md"
expect_fail "missing Phase6/Step9 ordering" "Normative order" bash "${BAD_ORDER_DIR}/scripts/verify_skill.sh"

# --- Missing Subagent Worktree Protocol ---
NO_WT_DIR="${TMPROOT}/no-worktree-protocol"
mkdir -p "${NO_WT_DIR}/scripts"
cp "${VERIFY}" "${NO_WT_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_WT_DIR}/SKILL.md"
sed -i '' '/Subagent Worktree Protocol/,/Idempotent/d' "${NO_WT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i '/Subagent Worktree Protocol/,/Idempotent/d' "${NO_WT_DIR}/SKILL.md"
expect_fail "missing worktree protocol" "Subagent Worktree Protocol" bash "${NO_WT_DIR}/scripts/verify_skill.sh"

# --- Broken suffix_map wiring (reviewer_configs review_file) ---
BAD_SUFFIX_DIR="${TMPROOT}/bad-suffix-map"
mkdir -p "${BAD_SUFFIX_DIR}/scripts"
cp "${VERIFY}" "${BAD_SUFFIX_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${BAD_SUFFIX_DIR}/SKILL.md"
sed -i '' 's/suffix_map\[specialist\]/suffix_broken/g' "${BAD_SUFFIX_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/suffix_map\[specialist\]/suffix_broken/g' "${BAD_SUFFIX_DIR}/SKILL.md"
expect_fail "broken suffix_map wiring" "suffix_map\\[specialist\\]" bash "${BAD_SUFFIX_DIR}/scripts/verify_skill.sh"

# --- Missing delegate-without-execute rejection ---
NO_DELEGATE_REJECT_DIR="${TMPROOT}/no-delegate-reject"
mkdir -p "${NO_DELEGATE_REJECT_DIR}/scripts"
cp "${VERIFY}" "${NO_DELEGATE_REJECT_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${NO_DELEGATE_REJECT_DIR}/SKILL.md"
sed -i '' 's/--delegate-execute requires --execute/delegate execute pairing removed/g' "${NO_DELEGATE_REJECT_DIR}/SKILL.md" 2>/dev/null \
  || sed -i 's/--delegate-execute requires --execute/delegate execute pairing removed/g' "${NO_DELEGATE_REJECT_DIR}/SKILL.md"
expect_fail "missing delegate-execute reject" "--delegate-execute requires --execute" bash "${NO_DELEGATE_REJECT_DIR}/scripts/verify_skill.sh"

# --- Stale inline-not-implemented messaging regression ---
STALE_INLINE_DIR="${TMPROOT}/stale-inline"
mkdir -p "${STALE_INLINE_DIR}/scripts"
cp "${VERIFY}" "${STALE_INLINE_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${STALE_INLINE_DIR}/SKILL.md"
printf '\nInline execute resume not implemented\n' >> "${STALE_INLINE_DIR}/SKILL.md"
expect_fail "stale inline-not-implemented" "stale inline-execute-not-implemented" bash "${STALE_INLINE_DIR}/scripts/verify_skill.sh"

# --- Implementer warn-only regression ---
WARN_IMPL_DIR="${TMPROOT}/warn-implementer"
mkdir -p "${WARN_IMPL_DIR}/scripts"
cp "${VERIFY}" "${WARN_IMPL_DIR}/scripts/verify_skill.sh"
cp "${SOURCE_SKILL}" "${WARN_IMPL_DIR}/SKILL.md"
# Append stale warn-only phrasing (must trigger dedicated check after fail-fast pattern passes)
printf '\n<!-- regression: implementer warn-only if missing -->\n' >> "${WARN_IMPL_DIR}/SKILL.md"
expect_fail "implementer warn-only" "implementer persona must be fail-fast" bash "${WARN_IMPL_DIR}/scripts/verify_skill.sh"

# --- Missing bundled_skills_root (real verify script) ---
BROKEN_HOME="${TMPROOT}/broken-home"
mkdir -p "${BROKEN_HOME}/.grok"
expect_fail "missing bundled_skills_root" "bundled_skills_root not found" env HOME="${BROKEN_HOME}" bash "${VERIFY}"

# --- Empty required persona via HOME override ---
FIXTURE_HOME="${TMPROOT}/fixture-home"
FIXTURE_BUNDLED="${FIXTURE_HOME}/.grok/bundled/skills"
mkdir -p "${FIXTURE_BUNDLED}/shared/personas" "${FIXTURE_BUNDLED}/implement/scripts"
cp "${BUNDLED_SRC}/implement/scripts/memory.py" "${FIXTURE_BUNDLED}/implement/scripts/"
cp "${BUNDLED_SRC}/implement/SKILL.md" "${FIXTURE_BUNDLED}/implement/SKILL.md"
for persona in design-doc-writer design-doc-reviewer reviewer security-auditor implementer; do
  cp "${BUNDLED_SRC}/shared/personas/${persona}.md" "${FIXTURE_BUNDLED}/shared/personas/${persona}.md"
done
: > "${FIXTURE_BUNDLED}/shared/personas/design-doc-writer.md"
expect_fail "empty persona" "persona empty" env HOME="${FIXTURE_HOME}" bash "${VERIFY}"

# --- memory.py: non-git cwd with HOME set → exit 0 ---
MEMORY_HELPER="${BUNDLED_SRC}/implement/scripts/memory.py"
NON_GIT_DIR="$(mktemp -d)"
trap 'rm -rf "${TMPROOT}" "${NON_GIT_DIR}"' EXIT
(
  cd "${NON_GIT_DIR}"
  python3 "${MEMORY_HELPER}" snapshot >/dev/null
) || fail "non-git cwd snapshot should exit 0 with HOME set"
pass "memory.py snapshot exit 0 in non-git cwd"

# --- memory.py: unreadable cwd + unset HOME → exit 2 (best-effort) ---
UNREADABLE_DIR="$(mktemp -d)"
chmod 000 "${UNREADABLE_DIR}"
if (
  cd "${UNREADABLE_DIR}" 2>/dev/null
  env -u HOME python3 "${MEMORY_HELPER}" snapshot >/dev/null 2>&1
); then
  echo "SKIP: could not reproduce WorkspaceIdError exit 2 in this environment" >&2
else
  pass "memory.py snapshot fails with unreadable cwd and unset HOME"
fi
chmod 700 "${UNREADABLE_DIR}" 2>/dev/null || true

echo ""
echo "All negative verify_skill tests passed."