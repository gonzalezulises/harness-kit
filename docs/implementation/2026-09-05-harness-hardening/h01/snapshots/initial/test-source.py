#!/usr/bin/env python3
"""Permanent focused regression runner for H01 verifier hardening.

The review probes remain immutable evidence.  This runner imports those exact
tests and selects only R01-R09 and R13, leaving installer R11 and repair-only
R12 to their planned milestones.
"""
from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True


ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "docs/reviews/2026-09-05-harness-hardening"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    review = load("h01_review_regressions", REVIEW / "red_regressions.py")
    local = load("h01_local_regressions", REVIEW / "local_red_regressions.py")
    state = load("h01_state_regressions", REVIEW / "supplemental_state_red.py")

    with tempfile.TemporaryDirectory(prefix="h01-regressions-") as tmp:
        out = Path(tmp)
        suites = []

        review_out = out / "review"
        (review_out / "fixtures").mkdir(parents=True)
        review.CONTEXT.update(repo=ROOT, out=review_out, records=[])
        suites.extend(
            review.RegressionTests(name)
            for name in (
                "test_01_blocked_budget_requires_authorized_reopening",
                "test_02_empty_command_must_not_execute_repair_text",
                "test_03_claim_parse_failures_must_not_approve_empty_or_partial_claims",
                "test_04_claims_require_the_explicit_authority_baseline",
                "test_05_cached_success_must_not_survive_changed_verification_inputs",
                "test_06_decisions_require_a_resolvable_explicit_base",
                "test_07_decision_whitespace_must_not_change_executable_policy",
            )
        )

        local_out = out / "local"
        (local_out / "fixtures").mkdir(parents=True)
        (local_out / "tmp").mkdir()
        clean_env = {
            "PATH": os.environ.get("PATH", os.defpath),
            "LANG": "C.UTF-8",
            "NO_COLOR": "1",
            "TMPDIR": str(local_out / "tmp"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        }
        local.CONTEXT.update(repo=ROOT, out=local_out, env=clean_env, records=[])
        suites.extend(
            local.LocalRegressions(name)
            for name in (
                "test_09_exit0_rule_must_reject_false_command",
                "test_10_invalid_arch_root_must_not_pass",
            )
        )

        state_out = out / "state"
        (state_out / "fixtures").mkdir(parents=True)
        state.CONTEXT.update(repo=ROOT, out=state_out, records=[])
        suites.extend(
            state.StateRegressionTests(name)
            for name in (
                "test_01_not_started_cannot_skip_activation",
                "test_02_wip_violation_blocks_before_execution",
                "test_03_duplicate_ids_cannot_promote_unexecuted_feature",
            )
        )

        result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(suites))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
