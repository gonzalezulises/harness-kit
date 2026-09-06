# Spec compliance: Approved for H02 fix round 1

**Quality verdict: Approved. M1: ADDRESSED. M2: ADDRESSED. M3: ADDRESSED. Remaining findings: Critical 0, High 0, Medium 0, Low 0.**

Scope: the supplied frozen diff `45d528d6cdc0bb15032982909cc5b2f19f595c04..e4534d3c5388081eafd932ce2ea0641be0eb0bd2`, the appended fix-round report, and evidence specific to M1–M3. This is the scoped correction gate, not a renewed whole-H02 or whole-branch review.

## Findings disposition

| Finding | Disposition | Source and assessment |
|---|---|---|
| M1 — Setup module shadowing and false successful installation | **ADDRESSED** | `scripts/setup-oracles.sh:7` and `:8`, with identical template changes, now use `-I` for pip and the final PyYAML import/version assertion. Both previously exposed import paths are isolated. `tests/h02-hardening-regressions.py:294` adds four real subprocess cases: cwd/PYTHONPATH crossed with pip/final import. Each checks that no injected marker appears, setup fails, and the isolated venv truly lacks the parser. |
| M2 — Status timeout leaves recipe descendants running | **ADDRESSED** | `bin/harness-status.sh:28` starts make in a new session; `:33` signals its owned process group with TERM; `:41` escalates to KILL even when the direct parent exited; communication/reaping waits remain bounded. The test at `tests/h02-hardening-regressions.py:321` exercises normal and TERM-ignoring children, verifies no delayed mutation, and verifies an unrelated process survives. The implementation covers ordinary descendants without asserting containment of deliberately escaped process groups. |
| M3 — Explicit missing delivery source silently passes | **ADDRESSED** | `scripts/verify-delivery-doc.sh:63`–`:67` and the identical template now block missing, non-file or unreadable sources whenever nonempty DELIVERY_DOC is explicitly set, regardless of DELIVERY_DOC_REQUIRED. The absent default scaffold remains valid. `tests/h02-hardening-regressions.py:348` tests default absence, an explicit missing path and an explicit directory, plus mirror parity. |

## Quality and fix-created breakage

No fix-created blocking breakage identified. The changes are confined to the affected interfaces, use structural import/process/path checks, and preserve the intended default-scaffold behavior. Timeout cleanup targets the new process group rather than unrelated processes. The new tests verify observable effects and exercise each original defect; they do not merely assert source strings.

`docs/harness-capabilities.md:35` documents the corrected boundaries. `.harness/oracles/AC-H02.yaml:40` identifies the initial-H02 source overlay separately from its historical anchor and points to a new receipt. The replacement receipt does not falsely describe the corrected final tests as tests of unchanged H01 source, and the prior receipt remains preserved.

## Evidence assessment

The following paths are under `docs/implementation/2026-09-05-harness-hardening/h02/fix-1/`:

- `red-01.stderr.log:80` and `:82`: three tests, eight causal failed subtests, no errors. Its command records show all four setup-shadow cases incorrectly returned zero and both explicit delivery cases incorrectly returned zero before correction; the timeout failures are delayed child mutations.
- `red-full-02.stderr.log:107` and `:109`: all 30 final test cases against reconstructed initial-H02 source, with the same eight failures and no errors. Independently compared `red-full-02-tests.py` with the current shipping test bytes: equal.
- `green-focused-01.stderr.log:6` and `:8`: three tests, OK. `green-full-02.stderr.log:33` and `:35`: 30 tests, OK; corresponding exits are zero. Command records confirm corrected explicit sources return 2 and isolated setup cannot pass without real PyYAML. Expected package-unavailable/import-error diagnostics belong to the deliberate offline negative fixtures; no unexpected test or lint warning was identified.
- `lint-02.exit:1`: zero, with empty stdout/stderr. `syntax-parity-02.json:1` onward records successful syntax checks for all five changed shell files and equality of both root/template pairs. `diff-check-02.exit:1`: zero, with empty streams.
- `oracles-02.stdout.log:1`–`:6`: both AC-H01 and AC-H02 receipts consistent, oracle gate zero. Independently recomputed all 11 tests/source/log hashes in `h02-red-receipt-v2.json`: no mismatch.
- Read the supplied fix diff and named evidence only; no additional probes were necessary because the source and recorded behavioral tests answered the scoped doubts. No suites rerun, subagents, checkout/index/ref edits, or external operations occurred.

## Limits and controller gates

This approval addresses M1–M3 and breakage introduced by their corrections. Controller full integration/make check and feature promotion remain outstanding. Earlier core/load/concurrency runs retain their original source identities and were not represented as reruns of this fix. Minimum-version runtime execution, authenticated load coverage, remote required-quality execution and protected-policy adoption remain the previously disclosed limits. No baseline, production deployment, recovery grant or historical-claim alteration is approved by this review.
