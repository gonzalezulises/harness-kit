# A flag that is quietly ignored is worse than one that does not exist

**Decided:** `harness-activate.sh --with <pack>` rejects anything but `gherkin`
with exit 64 and an error naming the pack, plus where the other packs actually
come from. Three regression cases pin it: the exit code, the pack named in the
message, and that nothing is scaffolded when the flag is rejected.

**Why:** the parser was `[[ "$2" == "gherkin" ]] && WITH_GHERKIN=1`. Anything
else fell through with no branch, no message, no non-zero exit — so
`--with sentry` scaffolded the repo, installed no pack, and printed a success
banner. The user walks away believing the observability gate is in place. That
is the failure this kit exists to prevent, committed by the kit's own entry
point: the gap between what a command claims and what it did.

Found while updating the `harness-creator` skill, where the fix was about to be
written down as a warning to work around. A warning in a document is not a fix;
the command now refuses.

**Given up:** `--with` could have grown into a real pack installer for all four.
Not done — `sentry` and `load-testing` need repo-specific wiring (a DSN,
a target URL) that an unattended flag cannot supply, and pretending otherwise
would rebuild the same lie one level up. Refusing honestly beats installing
half a pack.

**Same pass:** figures quoted in living docs were corrected or removed —
`tests/run-tests.sh` printed a score out of 74 when the rubric has 84, and
README and the Sentry pack quoted assertion counts that had drifted four times
in a day. Counts that only age were deleted rather than re-pinned; the numbers
that matter are the ones the tools print at run time.
