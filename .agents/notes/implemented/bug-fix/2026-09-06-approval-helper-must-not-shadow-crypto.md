# Approval helpers must call the cryptographic verifier

Under AGENTS.md, DECISIONS.md MIGRATION-01 and docs/quality-document.md, current
and recorded approval paths share one envelope validator named `verifyEnvelope`.
Its name must remain distinct from the imported cryptographic `verify` function.
The earlier helper shadowed that import: a recursive parse failure returned a
truthy stop object where a cryptographic boolean was required. Consequently, a
well-shaped fabricated signature incorrectly gained authority. Renaming the
helper restores the actual pinned-key signature check in both paths, without
introducing another verifier or changing event-time semantics.

A separate focused test preserves the original H06 test bytes and exercises all
approval kinds with genuine, fabricated and altered signatures, plus actual
continuation registration and rehashed recorded-grant replay. The exact reviewed
source produces seven assertion failures. This is preferable to additional prose
assurances about signed data: the regression directly distinguishes a real
cryptographic result from the prior truthy-error bypass.

The same bounded fix makes the public continuation entry point parse its required
observed defect before verification or registration. Internal revalidation may
omit observation, but `undefined` and `null` cannot invoke that internal behavior
through the public API. No permissions, budget rules or capabilities are expanded.
Revisit these tests whenever shared approval dispatch or public/internal
continuation argument handling changes.
