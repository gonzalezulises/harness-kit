.DEFAULT_GOAL := help

.PHONY: check
check: ## Full verification pipeline — run before clock-out and PR
	{{VERIFY_CMD}}

.PHONY: check-fast
check-fast: ## Fast gate for every commit: unit tests (seconds)
	{{TEST_CMD}}

.PHONY: verify-claims
verify-claims: ## Re-run every feature this repo claims is passing (none in lite). CI runs this too.
	bash scripts/verify-claims.sh

.PHONY: verify-decisions
verify-decisions: ## Confirm no earlier decision was rewritten. CI runs this too.
	bash scripts/verify-decisions.sh

.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'
