# Makefile — the single entry point for every repo operation.
# Agents call these targets; they never need to remember raw commands.

.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

# ── Core ─────────────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Install all dependencies from a clean checkout
	{{INSTALL_CMD}}

.PHONY: dev
dev: ## Start the local dev server
	{{START_CMD}}

.PHONY: test
test: ## Run the test suite
	{{TEST_CMD}}

.PHONY: check
check: ## Full verification pipeline — must exit 0 before every commit
	{{VERIFY_CMD}}

.PHONY: verify-claims
verify-claims: ## Re-run every feature the repo claims is passing. CI runs this too.
	bash scripts/verify-claims.sh

.PHONY: e2e
e2e: ## End-to-end suite. Required when a change crosses component boundaries.
	{{E2E_CMD}}

# ── Harness ──────────────────────────────────────────────────────────────────

.PHONY: audit
audit: ## Score this repo's harness
	@bash scripts/harness-audit.sh . || true

.PHONY: verify-feature
verify-feature: ## Verify one feature and gate it to passing. Usage: make verify-feature F=F01
	@bash scripts/verify-feature.sh $(F)

.PHONY: vcr
vcr: ## Verified Completion Ratio — passing / activated features
	@bash scripts/verify-feature.sh --ratio

.PHONY: check-arch
check-arch: ## Enforce architectural boundary rules
	@bash scripts/check-arch.sh .

.PHONY: clean-check
clean-check: ## Clean-state gate. Run at clock-out, before committing.
	@bash scripts/clean-state-check.sh .

.PHONY: session-start
session-start: ## Open a session trace
	@bash scripts/session-trace.sh start

.PHONY: session-end
session-end: ## Close the session trace
	@bash scripts/session-trace.sh end

.PHONY: help
help: ## List available targets
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
