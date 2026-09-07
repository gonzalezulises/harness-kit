# Give the complete required verification job time to finish

- Date: 2026-09-07
- Owner: harness-kit maintainers under the authorized PR33–37 closure
- Context: `AGENTS.md`; `DECISIONS.md`; `.github/workflows/required-quality.yml`

PR35 head 6677 passed the repository pipeline, then its protected claim checks
were cancelled approximately at the job's 30-minute envelope. The log does not
state a timeout cause explicitly. The cancelled run remains blocked.

Increase only the outer Required quality job timeout to 60 minutes. Every command,
required conclusion, sentinel, workflow permission, protected v1 judge byte and
signed runtime budget is unchanged. This is a bounded CI scheduling adjustment,
independently reviewed as mechanical under the closure mandate. It is not GR03
isolation or permission to merge an incomplete check. A hung job can consume up
to 30 additional runner minutes; its limit is still finite. The exact new head
must run all ordinary checks and finish satisfactorily before integration.
