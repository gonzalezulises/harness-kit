# Makefile — the single entry point for every repo operation.
# Agents call these targets; they never need to remember raw commands.

.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

# ── Core ─────────────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Install all dependencies from a clean checkout
	

.PHONY: dev
dev: ## Start the local dev server
	@echo "This is a library, not a service. Try: make check"

.PHONY: test
test: ## Run the test suite
	bash tests/run-tests.sh

.PHONY: check
check: ## Full verification pipeline — must exit 0 before every commit
	bash tests/run-tests.sh
# The packs ship their own failure matrices. Linting them was never the same as
# running them: a pack could regress with the repo's gate still green, which is
# the exact failure the packs exist to prevent.
	@for p in packs/*/verify-pack.sh; do \
	  [ -f "$$p" ] || continue; \
	  echo ""; bash "$$p" || exit 1; \
	done

.PHONY: verify-claims
verify-claims: ## Re-run every feature this repo claims is passing
	bash scripts/verify-claims.sh

.PHONY: verify-decisions
verify-decisions: ## Confirm no earlier decision was rewritten
	bash scripts/verify-decisions.sh

.PHONY: verify-agent-notes
verify-agent-notes: ## Agent Notes tree and format gate
	bash scripts/verify-agent-notes.sh

.PHONY: gates
gates: ## Run the registered quality gates. Usage: make gates [A=quick|full]
	bash scripts/run-gates.sh $(or $(A),quick)

.PHONY: hooks-install
hooks-install: ## Opt-in fast staged-only git hooks (refuses to fight husky)
	bash scripts/install-githooks.sh

.PHONY: lint
lint: ## shellcheck over every script the kit ships
	shellcheck -S warning bin/*.sh scripts/*.sh tests/*.sh \
	  templates/full/scripts/*.sh packs/*/verify-pack.sh

.PHONY: e2e
e2e: ## End-to-end suite. Required when a change crosses component boundaries.
	bash tests/run-tests.sh

# ── Harness ──────────────────────────────────────────────────────────────────

.PHONY: audit
audit: ## Score this repo's harness
	@bash bin/harness-audit.sh . || true

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
