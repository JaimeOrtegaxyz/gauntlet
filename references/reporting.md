# Reporting — the deliverable

Write to `~/.claude/gauntlet/<repo>-<YYYY-MM-DD>/` (never the audited repo):
- `report.md` — the human-facing report (structure below)
- `findings.csv` — one row per finding, for tracking across runs
- `harness/` — any scratch harness, seeded data, calibration mutants kept for
  reproducibility

Tell the user the path. If you wrote unit tests worth keeping *in the repo*,
propose them separately and commit only with confirmation.

## report.md structure

**1. Coverage & abstention map — THE HEADLINE (put it first).**
> Risk-weighted surface oracle-verified: **N%**.
> Verified: <areas, by oracle type>.
> **ABSTAINED (no external oracle — unverified, NOT passing):** <high-impact
> areas with no oracle, each with why and what would close it>.

This goes first because the dangerous outcome is a green result on cheap-to-check
code while the valuable logic was never checked. Lead with what you *couldn't*
vouch for.

**2. Calibration result.** Kill rate by severity tier + the one-line honest
limit (`calibration.md`): "validates the oracle classes built, on the faults
injected; abstained areas unmeasured."

**3. Confirmed findings** — ranked by severity × confidence. Each:
- ID, severity, confidence, priority, area
- the **reproduction** (failing assertion / request-response / CLI session /
  browser observation) or the verbatim external-source contradiction
- oracle type that caught it
- a concrete fix suggestion (proposed, not applied — unless it passed the fix
  gate and the user confirmed)

**4. Killed findings (and why)** — MANDATORY. Hypotheses that were raised and
then refuted, with the evidence that killed each. This is proof the adversarial
self-refute pass actually ran, and it's often where the user learns the most
about their code. Never omit it, even if empty ("none raised").

**5. Coverage statement** — per area: unit-verified / harness-verified /
browser-verified / code-traced-only / abstained. No silent caps: if you only ran
some oracle types or sampled some endpoints, say which and why.

**6. Recommendations** — the few highest-ROI next actions (usually: write these
N pure-function unit tests; browser-drive these M flows to close abstentions;
fix these K confirmed S1/S2).

## findings.csv columns

`id, area, oracle_type, severity, confidence, priority, status, reproduction,
suggested_fix, notes`

`status`: Confirmed / Killed / Abstained / Fixed (only if it passed the gate and
was confirmed). Reuse the file across runs to track regressions and whether
abstentions get closed.

## Tone

Honest over reassuring. "8 minor findings + 40% of the surface abstained" is a
better deliverable than a confident "all clear" that quietly never looked at the
risky half. The abstention map is the product as much as the bug list.
