#!/usr/bin/env node
// gherkin-validate — decide whether a Cucumber run actually proved anything.
//
// Usage:
//   bin/gherkin-validate <messages.ndjson> [--expect N]
//
// Cucumber's exit code answers "did anything fail?". It does not answer "did
// anything run?", and those are different questions. A feature file with no
// matching steps, a wrong path, or a filter that matches nothing all exit 0.
// That is the same failure k6 has — a broken script exits successfully — and it
// is why this validator reads the report instead of trusting the exit code.
//
// Exit codes:
//   0  the run is trustworthy
//   1  a scenario or step did not pass
//   2  the run proved nothing (nothing executed, or fewer cases than declared)
//   3  the report itself is unusable (malformed or truncated)
//   64 usage error

// .mjs, not .js: a repo with "type": "module" would parse a bare .js as ESM and
// break require(). The extension pins the module system regardless of the host repo.
import fs from "node:fs";

const NON_PASSING = ["FAILED", "UNDEFINED", "AMBIGUOUS", "PENDING", "SKIPPED"];

function die(code, label, detail) {
  console.error(`GHERKIN_${label}: ${detail}`);
  process.exit(code);
}

const args = process.argv.slice(2);
const reportPath = args.find((a) => !a.startsWith("--"));
const expectIdx = args.indexOf("--expect");
const expected = expectIdx === -1 ? null : Number(args[expectIdx + 1]);

if (!reportPath) {
  die(64, "USAGE", "a messages ndjson path is required");
}
if (expectIdx !== -1 && (!Number.isInteger(expected) || expected < 1)) {
  die(64, "USAGE", "--expect needs a positive integer");
}
if (!fs.existsSync(reportPath)) {
  die(3, "REPORT_MISSING", `no report at ${reportPath} — the run produced nothing`);
}

const lines = fs
  .readFileSync(reportPath, "utf8")
  .split("\n")
  .filter((l) => l.trim() !== "");

const messages = [];
for (const [i, line] of lines.entries()) {
  try {
    messages.push(JSON.parse(line));
  } catch {
    die(3, "REPORT_MALFORMED", `line ${i + 1} is not valid JSON`);
  }
}

// A run that was killed mid-flight leaves a report that looks fine until the end.
if (!messages.some((m) => m.testRunFinished)) {
  die(3, "REPORT_TRUNCATED", "no testRunFinished — the run did not complete");
}

// ── Duplicate scenario identity ──────────────────────────────────────────────
// Two scenarios sharing an @SCN- tag make traceability meaningless: evidence
// cannot be attributed to one of them.
const seen = new Map();
for (const m of messages) {
  if (!m.pickle) continue;
  for (const tag of m.pickle.tags || []) {
    const name = typeof tag === "string" ? tag : tag.name;
    if (!name || !name.startsWith("@SCN-")) continue;
    if (seen.has(name)) {
      die(1, "DUPLICATE_SCENARIO_ID", `${name} is used by more than one scenario`);
    }
    seen.set(name, m.pickle.name);
  }
}

// ── What actually ran ────────────────────────────────────────────────────────
const executed = messages.filter((m) => m.testCaseFinished).length;

const statuses = {};
for (const m of messages) {
  const status = m.testStepFinished?.testStepResult?.status;
  if (!status) continue;
  statuses[status] = (statuses[status] || 0) + 1;
}

if (executed === 0) {
  die(
    2,
    "ZERO_EXECUTION",
    "the run exited without executing a single scenario — no feature matched, " +
      "or every step is missing. This is the failure an exit code hides.",
  );
}

// The absolute counter. Without a declared expectation, a run that silently
// drops half its scenarios still looks green.
if (expected !== null && executed !== expected) {
  die(
    2,
    "COUNT_MISMATCH",
    `declared ${expected} scenario(s), executed ${executed}. ` +
      "A run that skips what it promised proves less than it claims.",
  );
}

const offenders = NON_PASSING.filter((s) => statuses[s]);
if (offenders.length > 0) {
  const detail = offenders.map((s) => `${s}=${statuses[s]}`).join(" ");
  die(
    1,
    "NOT_PASSED",
    `${detail}. Pending, skipped, undefined and ambiguous are not passes — ` +
      "they are steps that never proved anything.",
  );
}

console.log(
  `GHERKIN_OK: ${executed} scenario(s) executed, ${statuses.PASSED || 0} step(s) passed.`,
);
process.exit(0);
