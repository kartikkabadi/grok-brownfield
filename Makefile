# SPDX-License-Identifier: MIT
# Makefile for grok-brownfield development workflow

.PHONY: help verify test bootstrap clean all install-dev

# Default target
help:
	@echo "grok-brownfield development commands:"
	@echo ""
	@echo "  make verify          Run structure verification (verify_skill.sh)"
	@echo "  make test            Run negative/regression tests (test_verify_skill.sh)"
	@echo "  make bootstrap       Validate bundled-skills fixture"
	@echo "  make bootstrap-refresh Refresh fixture from local Grok install"
	@echo "  make all             Run verify + test + bootstrap"
	@echo "  make clean           Remove temporary files"
	@echo "  make install-dev      Install skill locally for Grok Build testing"
	@echo ""
	@echo "Verification (required before PR):"
	@echo "  make verify && make test"

# Verification
verify:
	@echo "Running structure verification..."
	@bash scripts/verify_skill.sh

# Tests
test:
	@echo "Running negative/regression tests..."
	@bash tests/test_verify_skill.sh

# Bootstrap fixture
bootstrap:
	@echo "Validating bundled-skills fixture..."
	@bash scripts/bootstrap_bundled_fixture.sh

# Refresh fixture from local Grok install
bootstrap-refresh:
	@echo "Refreshing fixture from local Grok install..."
	@bash scripts/bootstrap_bundled_fixture.sh --refresh

# Run all verification
all: verify test bootstrap
	@echo ""
	@echo "All verification passed!"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -rf /tmp/grok-brownfield-*
	@rm -rf .scratch
	@echo "Clean complete"

# Install skill locally for development
install-dev:
	@echo "Installing skill locally for Grok Build testing..."
	@mkdir -p ~/.grok/skills/brownfield
	@cp -r . ~/.grok/skills/brownfield/
	@echo "Skill installed to ~/.grok/skills/brownfield/"
	@echo "Reload Grok Build to discover the skill"
