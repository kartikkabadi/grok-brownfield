#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# dev_setup.sh — One-command development setup for new contributors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🚀 Setting up grok-brownfield development environment..."
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v git &> /dev/null; then
  echo "❌ git is required but not installed"
  exit 1
fi

if ! command -v bash &> /dev/null; then
  echo "❌ bash is required but not installed"
  exit 1
fi

if ! command -v python3 &> /dev/null; then
  echo "❌ python3 is required but not installed"
  exit 1
fi

echo "✅ Prerequisites satisfied"
echo ""

# Validate bundled-skills fixture
echo "Validating bundled-skills fixture..."
if ! bash "${SCRIPT_DIR}/bootstrap_bundled_fixture.sh"; then
  echo "❌ Fixture validation failed"
  exit 1
fi
echo "✅ Fixture validated"
echo ""

# Run verification
echo "Running verification..."
if ! bash "${SCRIPT_DIR}/verify_skill.sh"; then
  echo "❌ Verification failed"
  exit 1
fi
echo "✅ Verification passed"
echo ""

# Run tests
echo "Running tests..."
if ! bash "${REPO_ROOT}/tests/test_verify_skill.sh"; then
  echo "❌ Tests failed"
  exit 1
fi
echo "✅ Tests passed"
echo ""

# Optional: Install skill locally for Grok Build testing
echo ""
echo "Optional: Install skill locally for Grok Build testing?"
read -p "Install to ~/.grok/skills/brownfield/? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  mkdir -p ~/.grok/skills/brownfield
  cp -r "${REPO_ROOT}"/* ~/.grok/skills/brownfield/
  echo "✅ Skill installed to ~/.grok/skills/brownfield/"
  echo "   Reload Grok Build to discover the skill"
fi

echo ""
echo "🎉 Development setup complete!"
echo ""
echo "Quick start:"
echo "  make verify          # Run structure verification"
echo "  make test            # Run tests"
echo "  make all             # Run all verification"
echo "  make install-dev     # Install skill locally"
echo ""
echo "See CONTRIBUTING.md for contributor guidelines."
