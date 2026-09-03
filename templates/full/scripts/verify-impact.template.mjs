#!/usr/bin/env node
/**
 * verify-impact — a rule change is a hypothesis until you run it against real data.
 *
 * COPY THIS FILE, fill the four marked blocks, run it, and paste the output into
 * the pull request. It is not meant to be committed as-is or to live long: it is
 * scaffolding for one change, and it belongs in a scratch directory.
 *
 * ── Why this exists ──────────────────────────────────────────────────────────
 * On 2026-09-03 a rule was fixed so a supplier list reading «8D/D6» would match
 * an «8D» catalogue entry — a set of equivalent groups, not one opaque string.
 * Unit tests passed, the full suite passed, every gate passed, and the reasoning
 * was right. Then the same rule was run against the live catalogue, and one line
 * («25/35/D23») now matched two products of opposite polarity: physically, a
 * battery whose terminals are on the left cannot also be the one with them on the
 * right. The rule had been made correct in general and wrong in a specific,
 * shippable way.
 *
 * No unit test found that, because a unit test only knows the cases its author
 * imagined. No review found it either — two people read the diff. What found it
 * was running the new rule over every row the system actually holds and printing
 * the verdicts that changed.
 *
 * ── The rule ─────────────────────────────────────────────────────────────────
 * Any change to a decision rule, ranking, filter or SQL view ships with the
 * output of a run like this in its PR: how many verdicts change, in which
 * direction, and the full list when it is small enough to read.
 *
 * Read the result adversarially. The number is not the point — the point is
 * whether each individual flip is one you can defend out loud. A change that
 * flips nothing did not do what you think, and a change that flips everything
 * needs a much better story than "the tests pass".
 *
 * Above all, look at the flips going the PERMISSIVE way: something now accepted
 * that was rejected before. Those are the ones that reach production quietly. A
 * newly rejected row shows up on screen and someone complains; a wrongly accepted
 * one becomes a purchase order.
 */

// ── 1. How to reach the real data ───────────────────────────────────────────
// Read-only. If your repo has a read-only client helper, use it: a script that
// cannot write cannot damage what it is measuring.
//   import { createReadOnlyServiceClient } from "./service-readonly-client.mjs";
//   const db = createReadOnlyServiceClient(process.env.DB_URL, process.env.DB_KEY);
const db = null; // TODO

// ── 2. The rule, old and new ────────────────────────────────────────────────
// The old one is usually two lines inline (string equality, a regex, a
// threshold). Do not import it from the branch — you changed it there.
const decideBefore = (_row) => false; // TODO
const decideAfter = (_row) => false; // TODO

// ── 3. Every row the rule can see ───────────────────────────────────────────
// Every one. A sample hides exactly the rare shape that breaks.
async function loadRows() {
  return []; // TODO
}

// ── 4. How to identify a row when it is printed ─────────────────────────────
const describe = (row) => JSON.stringify(row); // TODO

// ── Nothing below here needs editing ────────────────────────────────────────
const ENV_HINT = process.env.IMPACT_TARGET ?? "(set IMPACT_TARGET to name it)";
console.log(`Target: ${ENV_HINT}`); // Name the object. See rules/atribucion.md.

const rows = await loadRows();
if (rows.length === 0) {
  console.error("\nNo rows loaded. An empty run proves nothing — fix block 3.");
  process.exit(2);
}

const flips = { permissive: [], restrictive: [] };
for (const row of rows) {
  const before = Boolean(decideBefore(row));
  const after = Boolean(decideAfter(row));
  if (before === after) continue;
  flips[after ? "permissive" : "restrictive"].push(describe(row));
}

const total = flips.permissive.length + flips.restrictive.length;
console.log(`\nRows evaluated: ${rows.length}`);
console.log(`Verdicts changed: ${total}`);
console.log(`  now accepted (was rejected): ${flips.permissive.length}   <- read these first`);
console.log(`  now rejected (was accepted): ${flips.restrictive.length}`);

const LIST_LIMIT = 60;
for (const [dir, list] of Object.entries(flips)) {
  if (list.length === 0) continue;
  console.log(`\n${dir === "permissive" ? "NOW ACCEPTED" : "NOW REJECTED"} (${list.length}):`);
  for (const line of list.slice(0, LIST_LIMIT)) console.log(`  ${line}`);
  if (list.length > LIST_LIMIT) console.log(`  … and ${list.length - LIST_LIMIT} more`);
}

if (total === 0) {
  console.log(
    "\nNothing changed. Either the change is inert on this data, or the data does " +
      "not contain the case you fixed. Both are worth saying out loud in the PR — " +
      "neither is evidence that the change works.",
  );
}
console.log(
  "\nPaste this into the PR. For each flip above, be able to say why it is right.\n" +
    "An unexplained permissive flip is the finding, not the noise.",
);
