#!/usr/bin/env python3
"""Permanent focused regression runner for H01 verifier hardening.

The review probes remain immutable evidence.  This runner imports those exact
tests and selects only R01-R09 and R13, leaving installer R11 and repair-only
R12 to their planned milestones.
"""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = Path(os.environ.get("H01_SCRIPT_ROOT", ROOT))
REVIEW = ROOT / "docs/reviews/2026-09-05-harness-hardening"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReviewRoundOneRegressions(unittest.TestCase):
    """Marker regressions for the first independent-review findings."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix=self._testMethodName + "-", dir=self.out))
        self.env = os.environ.copy()
        self.env.update(NO_COLOR="1", PYTHONDONTWRITEBYTECODE="1",
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        self.env.pop("CLAIMS_BASE_FILE", None)
        self.env.pop("DECISIONS_BASE_FILE", None)

    def copy_scripts(self, *names):
        scripts = self.work / "scripts"
        scripts.mkdir(exist_ok=True)
        for name in names:
            shutil.copy2(SCRIPT_ROOT / "scripts" / name, scripts / name)

    def run_gate(self, script, *args, env=None):
        return subprocess.run(["bash", "scripts/" + script, *args], cwd=self.work,
                              env=env or self.env, capture_output=True, text=True, timeout=20)

    def git(self, *args):
        return subprocess.run(
            ["git", "-c", "core.hooksPath=" + os.devnull, "-c", "commit.gpgsign=false",
             "-c", "user.name=H01 Review Fixture", "-c", "user.email=h01@example.invalid", *args],
            cwd=self.work, env=self.env, capture_output=True, text=True, check=True, timeout=20)

    def feature(self, *, state="active", command="true", budgets=True, ledger="absent"):
        value = {"id": "F", "state": state, "evidence": [],
                 "layers": [{"label": "l", "cmd": command, "repair": "r"}]}
        if budgets:
            value["budgets"] = {"review_rounds_max": 2, "repeated_blocker_max": 2,
                                 "stop_condition": "stop"}
        if ledger != "absent":
            value["ledger"] = ledger
        return value

    def write_features(self, features):
        (self.work / "feature_list.json").write_text(
            json.dumps({"features": features}, indent=2) + "\n", encoding="utf-8")

    def test_recorded_attempt_requires_recovery_authority(self):
        self.copy_scripts("verify-feature.sh")
        fixtures = (
            ("remaining-budget", True, {"review_rounds": 1, "blockers": [{"signature": "layer:l", "count": 1}]}, 2),
            ("raised-maximum", True, {"review_rounds": 2, "blockers": [{"signature": "layer:l", "count": 2}]}, 3),
            ("removed-budgets", False, {"review_rounds": 1, "blockers": [{"signature": "layer:l", "count": 1}]}, None),
        )
        for name, budgets, ledger, maximum in fixtures:
            with self.subTest(name=name):
                marker = self.work / (name + "-executed")
                feature = self.feature(command=f"touch {marker.name}", budgets=budgets, ledger=ledger)
                if maximum is not None:
                    feature["budgets"]["review_rounds_max"] = maximum
                self.write_features([feature])
                before = json.loads((self.work / "feature_list.json").read_text())
                result = self.run_gate("verify-feature.sh", "F")
                after = json.loads((self.work / "feature_list.json").read_text())
                self.assertEqual(result.returncode, 5, "recorded work needs verified recovery authority")
                self.assertFalse(marker.exists(), "unauthorized recovery must stop before layer effects")
                self.assertIn("RECOVERY_AUTHORITY_REQUIRED", result.stderr + result.stdout)
                self.assertNotIn("BUDGET_EXHAUSTED", result.stderr + result.stdout,
                                 "remaining budget is not the same as authority to recover")
                self.assertEqual(after["features"][0]["ledger"], before["features"][0]["ledger"])
                self.assertEqual(after["features"][0].get("budgets"), before["features"][0].get("budgets"))

    def test_budgeted_first_run_remains_valid(self):
        self.copy_scripts("verify-feature.sh")
        self.write_features([self.feature(command="touch first-run-executed")])
        result = self.run_gate("verify-feature.sh", "F")
        self.assertEqual(result.returncode, 0)
        self.assertTrue((self.work / "first-run-executed").exists())

    def test_partial_and_null_ledgers_reject_before_effects(self):
        self.copy_scripts("verify-feature.sh")
        for i, ledger in enumerate(({}, {"review_rounds": 0}, {"blockers": []}, None)):
            with self.subTest(ledger=ledger):
                marker = self.work / f"ledger-{i}-executed"
                self.write_features([self.feature(command=f"touch {marker.name}; false", ledger=ledger)])
                result = self.run_gate("verify-feature.sh", "F")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(marker.exists(), "an unusable ledger must fail preflight")

    def test_partial_and_null_claim_ledgers_reject_before_effects(self):
        self.copy_scripts("verify-claims.sh")
        self.git("init", "-q", "--initial-branch=main")
        (self.work / "README.md").write_text("base\n")
        self.git("add", "-A"); self.git("commit", "-qm", "base")
        for i, ledger in enumerate(({}, {"review_rounds": 0}, {"blockers": []}, None)):
            with self.subTest(ledger=ledger):
                marker = self.work / f"claim-ledger-{i}-executed"
                claim = self.feature(state="passing", command=f"touch {marker.name}", ledger=ledger)
                claim["evidence"] = ["receipt"]
                self.write_features([claim])
                result = self.run_gate("verify-claims.sh")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(marker.exists(), "an unusable claim ledger must fail preflight")

    def test_inconsistent_ledger_rejects_before_feature_effects(self):
        inconsistent = {"review_rounds": 0,
                        "blockers": [{"signature": "layer:old", "count": 1}]}
        self.copy_scripts("verify-feature.sh")
        self.write_features([self.feature(command="touch feature-inconsistent", ledger=inconsistent)])
        feature_result = self.run_gate("verify-feature.sh", "F")
        self.assertNotEqual(feature_result.returncode, 0)
        self.assertFalse((self.work / "feature-inconsistent").exists())

    def test_inconsistent_ledger_rejects_before_claim_head_effects(self):
        inconsistent = {"review_rounds": 0,
                        "blockers": [{"signature": "layer:old", "count": 1}]}
        self.copy_scripts("verify-claims.sh")
        self.git("init", "-q", "--initial-branch=main")
        (self.work / "README.md").write_text("base\n")
        self.git("add", "-A"); self.git("commit", "-qm", "base")
        claim = self.feature(state="passing", command="touch claim-inconsistent", ledger=inconsistent)
        claim["evidence"] = ["receipt"]
        self.write_features([claim])
        claim_result = self.run_gate("verify-claims.sh")
        self.assertNotEqual(claim_result.returncode, 0)
        self.assertFalse((self.work / "claim-inconsistent").exists())

    def test_inconsistent_ledger_rejects_before_claim_authority_effects(self):
        inconsistent = {"review_rounds": 0,
                        "blockers": [{"signature": "layer:old", "count": 1}]}
        self.copy_scripts("verify-claims.sh")
        self.git("init", "-q", "--initial-branch=main")
        (self.work / "README.md").write_text("base\n")
        self.git("add", "-A"); self.git("commit", "-qm", "base")
        claim = self.feature(state="passing", command="touch authority-inconsistent", budgets=False)
        claim["evidence"] = ["receipt"]
        self.write_features([claim])
        authority = self.work / "inconsistent-authority.json"
        authority.write_text(json.dumps({"features": [self.feature(
            state="passing", command="touch authority-inconsistent",
            budgets=False, ledger=inconsistent)]}))
        env = self.env.copy(); env["CLAIMS_BASE_FILE"] = str(authority)
        result = self.run_gate("verify-claims.sh", env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.work / "authority-inconsistent").exists())

    def test_nul_feature_command_rejects_before_effects(self):
        self.copy_scripts("verify-feature.sh")
        self.write_features([self.feature(command="tou\0ch executed", budgets=False)])
        result = self.run_gate("verify-feature.sh", "F")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.work / "executed").exists())

    def test_nul_claim_command_rejects_before_effects(self):
        self.copy_scripts("verify-claims.sh")
        self.git("init", "-q", "--initial-branch=main")
        (self.work / "README.md").write_text("base\n")
        self.git("add", "-A"); self.git("commit", "-qm", "base")
        claim = self.feature(state="passing", command="tou\0ch executed", budgets=False)
        claim["evidence"] = ["receipt"]
        self.write_features([claim])
        result = self.run_gate("verify-claims.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.work / "executed").exists())

    def test_nul_arch_command_rejects_before_effects(self):
        self.copy_scripts("check-arch.sh")
        (self.work / ".harness").mkdir()
        rule = {"id": "R", "check": "tou\0ch executed", "expect": "exit0",
                "what": "w", "why": "y", "fix": "f"}
        (self.work / ".harness/arch-rules.json").write_text(json.dumps({"rules": [rule]}))
        result = self.run_gate("check-arch.sh", ".")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.work / "executed").exists())

    def decision_fixture(self):
        self.copy_scripts("verify-decisions.sh")
        self.git("init", "-q", "--initial-branch=main")
        base = b"# Decisions\r\n\r\n## A-2\r\nprotected original\r\n\r\n## A\r\none\r\n\r\n## A\r\ntwo\r\n"
        (self.work / "DECISIONS.md").write_bytes(base)
        self.git("add", "-A"); self.git("commit", "-qm", "base")
        return base

    def test_decision_slug_collision_cannot_discard_entry(self):
        base = self.decision_fixture()
        rewritten = base.replace(b"protected original", b"silently rewritten")
        (self.work / "DECISIONS.md").write_bytes(rewritten)
        collision = self.run_gate("verify-decisions.sh", "main")
        self.assertNotEqual(collision.returncode, 0, "slug collisions cannot discard a protected entry")

    def test_decision_comparison_preserves_exact_newline_bytes(self):
        base = self.decision_fixture()
        (self.work / "DECISIONS.md").write_bytes(base.replace(b"\r\n", b"\n"))
        newline = self.run_gate("verify-decisions.sh", "main")
        self.assertNotEqual(newline.returncode, 0, "CRLF/LF conversion changes protected bytes")

    def test_arch_rule_requires_explicit_exit_contract(self):
        self.copy_scripts("check-arch.sh")
        (self.work / ".harness").mkdir()
        unsafe = {"id": "R", "check": "false # grep", "expect": "empty",
                  "what": "w", "why": "y", "fix": "f"}
        (self.work / ".harness/arch-rules.json").write_text(json.dumps({"rules": [unsafe]}))
        result = self.run_gate("check-arch.sh", ".")
        self.assertNotEqual(result.returncode, 0)

        (self.work / "input.txt").write_text("haystack\n")
        safe = {"id": "R", "check": {"type": "match_argv", "argv": ["grep", "needle", "input.txt"],
                                        "match_exit": 0, "no_match_exit": 1},
                "expect": "empty", "what": "w", "why": "y", "fix": "f"}
        (self.work / ".harness/arch-rules.json").write_text(json.dumps({"rules": [safe]}))
        result = self.run_gate("check-arch.sh", ".")
        self.assertEqual(result.returncode, 0, "a typed grep no-match remains a valid empty result")

        missing = {"id": "R", "check": {"type": "match_argv", "argv": ["h01-command-does-not-exist"],
                                           "match_exit": 0, "no_match_exit": 1},
                   "expect": "empty", "what": "w", "why": "y", "fix": "f"}
        (self.work / ".harness/arch-rules.json").write_text(json.dumps({"rules": [missing]}))
        result = self.run_gate("check-arch.sh", ".")
        self.assertNotEqual(result.returncode, 0, "a typed matcher launch failure is never no-match")
        self.assertIn("CHECK ERROR", result.stdout + result.stderr)

    def test_arch_filters_compile_in_whole_document_preflight(self):
        self.copy_scripts("check-arch.sh")
        (self.work / ".harness").mkdir()
        def rule(rid, argv, pattern="ok"):
            return {"id": rid,
                    "check": {"type": "match_argv", "argv": argv,
                              "match_exit": 0, "no_match_exit": 1,
                              "filters": [{"action": "include", "pattern": pattern}]},
                    "expect": "empty", "what": "w", "why": "y", "fix": "f"}

        earlier = rule("earlier", ["sh", "-c", "touch earlier-filter-marker; exit 1"])
        later_invalid = rule("later", ["true"], "(")
        (self.work / ".harness/arch-rules.json").write_text(
            json.dumps({"rules": [earlier, later_invalid]}))
        result = self.run_gate("check-arch.sh", ".")
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.work / "earlier-filter-marker").exists(),
                         "a later invalid filter must reject before an earlier rule runs")

    def test_invalid_arch_filter_cannot_hide_behind_no_match(self):
        self.copy_scripts("check-arch.sh")
        (self.work / ".harness").mkdir()
        invalid_no_match = {
            "id": "invalid-no-match",
            "check": {"type": "match_argv",
                      "argv": ["sh", "-c", "touch no-match-filter-marker; exit 1"],
                      "match_exit": 0, "no_match_exit": 1,
                      "filters": [{"action": "include", "pattern": "("}]},
            "expect": "empty", "what": "w", "why": "y", "fix": "f"}
        (self.work / ".harness/arch-rules.json").write_text(
            json.dumps({"rules": [invalid_no_match]}))
        result = self.run_gate("check-arch.sh", ".")
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.work / "no-match-filter-marker").exists(),
                         "no-match cannot bypass invalid filter validation")

    def test_decision_append_requires_real_line_boundary(self):
        self.copy_scripts("verify-decisions.sh")
        self.git("init", "-q", "--initial-branch=main")
        base = b"# Decisions\n\n## A\nprotected original"
        base_file = self.work / "base-no-final-newline.md"
        base_file.write_bytes(base)
        env = self.env.copy(); env["DECISIONS_BASE_FILE"] = str(base_file)

        (self.work / "DECISIONS.md").write_bytes(base + b"## B\nconcatenated\n")
        invalid = self.run_gate("verify-decisions.sh", env=env)
        self.assertNotEqual(invalid.returncode, 0)

        extending_separators = {
            "dashes": b"---\n## B\nnew decision\n",
            "spaces-before-newline": b" \t\n## B\nnew decision\n",
            "indented-dashes": b"\t---\n## B\nnew decision\n",
        }
        for name, suffix in extending_separators.items():
            with self.subTest(invalid_separator=name):
                (self.work / "DECISIONS.md").write_bytes(base + suffix)
                invalid = self.run_gate("verify-decisions.sh", env=env)
                self.assertNotEqual(
                    invalid.returncode, 0,
                    "separator bytes cannot extend the protected final line")

        valid_appends = {
            "lf-boundary": b"\n\n---\n\n## B\nseparate\n",
            "crlf-boundary": b"\r\n\r\n---\r\n\r\n## B\r\nseparate\r\n",
        }
        for name, suffix in valid_appends.items():
            with self.subTest(valid_separator=name):
                (self.work / "DECISIONS.md").write_bytes(base + suffix)
                valid = self.run_gate("verify-decisions.sh", env=env)
                self.assertEqual(
                    valid.returncode, 0,
                    "a real line boundary may precede a separate appended decision")

        terminated = base + b"\n"
        base_file.write_bytes(terminated)
        (self.work / "DECISIONS.md").write_bytes(
            terminated + b"---\n\n## B\nseparate after terminated base\n")
        valid = self.run_gate("verify-decisions.sh", env=env)
        self.assertEqual(valid.returncode, 0,
                         "an already terminated base may be followed by separator content")

    def test_duplicate_feature_keys_reject_before_effects(self):
        self.copy_scripts("verify-feature.sh")
        feature = ('{"id":"F","state":"active","evidence":[],"budgets":'
                   '{"review_rounds_max":2,"repeated_blocker_max":2,"stop_condition":"stop"},'
                   '"layers":[{"label":"l","cmd":"touch %s","repair":"r"}]}')
        fixtures = {
            "root": '{"features":[],"features":[' + feature % "duplicate-root" + ']}',
            "feature": '{"features":[' + (feature % "duplicate-feature").replace(
                '"state":"active"', '"state":"blocked","state":"active"') + ']}',
            "layer": '{"features":[' + (feature % "duplicate-layer").replace(
                '"cmd":"touch duplicate-layer"', '"cmd":"false","cmd":"touch duplicate-layer"') + ']}',
            "budgets": '{"features":[' + (feature % "duplicate-budgets").replace(
                '"review_rounds_max":2', '"review_rounds_max":1,"review_rounds_max":2') + ']}',
            "ledger": '{"features":[' + (feature % "duplicate-ledger").replace(
                '"layers":', '"ledger":{"review_rounds":0,"review_rounds":0,"blockers":[]},"layers":') + ']}',
            "blocker": '{"features":[' + (feature % "duplicate-blocker").replace(
                '"layers":', '"ledger":{"review_rounds":0,"blockers":'
                '[{"signature":"layer:old","count":1,"count":1}]},"layers":') + ']}',
        }
        for depth, raw in fixtures.items():
            with self.subTest(depth=depth):
                marker = self.work / ("duplicate-" + depth)
                (self.work / "feature_list.json").write_text(raw)
                result = self.run_gate("verify-feature.sh", "F")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(marker.exists(), "duplicate keys must reject at " + depth + " depth")

    def test_duplicate_claim_head_keys_reject_before_effects(self):
        self.copy_scripts("verify-claims.sh")
        self.git("init", "-q", "--initial-branch=main")
        (self.work / "README.md").write_text("base\n"); self.git("add", "-A"); self.git("commit", "-qm", "base")
        (self.work / "feature_list.json").write_text(
            '{"features":[{"id":"F","state":"passing","evidence":["e"],"layers":'
            '[{"label":"l","cmd":"false","cmd":"touch executed","repair":"r"}]}]}')
        result = self.run_gate("verify-claims.sh")
        self.assertNotEqual(result.returncode, 0); self.assertFalse((self.work / "executed").exists())

    def test_duplicate_claim_authority_keys_reject_before_effects(self):
        self.copy_scripts("verify-claims.sh")
        self.git("init", "-q", "--initial-branch=main")
        (self.work / "README.md").write_text("base\n"); self.git("add", "-A"); self.git("commit", "-qm", "base")
        self.write_features([dict(self.feature(state="passing", command="touch authority-executed", budgets=False), evidence=["e"])])
        base_file = self.work / "duplicate-base.json"
        base_file.write_text('{"features":[],"features":[]}')
        env = self.env.copy(); env["CLAIMS_BASE_FILE"] = str(base_file)
        result = self.run_gate("verify-claims.sh", env=env)
        self.assertNotEqual(result.returncode, 0); self.assertFalse((self.work / "authority-executed").exists())

    def test_duplicate_arch_keys_reject_before_effects(self):
        self.copy_scripts("check-arch.sh"); (self.work / ".harness").mkdir()
        (self.work / ".harness/arch-rules.json").write_text(
            '{"rules":[{"id":"R","check":"false","check":"touch executed","expect":"exit0",'
            '"what":"w","why":"y","fix":"f"}]}')
        result = self.run_gate("check-arch.sh", ".")
        self.assertNotEqual(result.returncode, 0); self.assertFalse((self.work / "executed").exists())


def main() -> int:
    review = load("h01_review_regressions", REVIEW / "red_regressions.py")
    local = load("h01_local_regressions", REVIEW / "local_red_regressions.py")
    state = load("h01_state_regressions", REVIEW / "supplemental_state_red.py")

    with tempfile.TemporaryDirectory(prefix="h01-regressions-") as tmp:
        out = Path(tmp)
        suites = []

        ReviewRoundOneRegressions.out = out
        suites.extend(unittest.defaultTestLoader.loadTestsFromTestCase(ReviewRoundOneRegressions))

        review_out = out / "review"
        (review_out / "fixtures").mkdir(parents=True)
        review.CONTEXT.update(repo=ROOT, out=review_out, records=[])
        suites.extend(
            review.RegressionTests(name)
            for name in (
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
