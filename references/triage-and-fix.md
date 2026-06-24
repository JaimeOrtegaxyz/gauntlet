# Triage & fix — where to spend, what to fix

Two jobs: (1) decide where deep effort goes, (2) decide what (if anything) gets
fixed autonomously.

## Risk ranking (the high-impact surface)

Rank by **likelihood × impact**, but lead with impact.

**Impact axis (the high-impact surface — always deep-test this):**
- Authn/authz, permission checks, tenant isolation
- Persistence / any write or mutation
- Money, billing, quotas, accounting, usage metering
- Delete / overwrite / irreversible actions
- Security boundaries: input parsing, deserialization, file paths, shell/SQL,
  template rendering, redirects, secrets handling
- External I/O: network calls, third-party APIs, the filesystem

**Likelihood axis:**
- **Scale-aware churn:** on a mature repo, `git log --numstat` hotspots
  (high-churn × high-complexity) genuinely predict defects. On a young/small repo
  (few commits, flat churn) churn is noise — **skip it** and rely on the impact
  axis. `profile.sh` flags which regime you're in.
- Complexity proxies: long functions, deep nesting, many branches.
- Recent/large/AI-generated changes.

Require **≥2 signals** before escalating a file to the deepest tier. Three tiers:
- **Tier 1 (high-impact ∩ likely):** full treatment — metamorphic + implicit +
  execution + (UI) browser + finder/adjudicator.
- **Tier 2:** implicit-oracle wrapper + targeted checks.
- **Tier 3 (cold/trivial/glue):** enumerate-only or skip; log that you did.

## Severity & confidence

**Severity** (impact if real): S1 critical (data loss, auth bypass, money wrong,
crash on a core path) · S2 major (feature broken / wrong result) · S3 minor
(edge/degraded) · S4 cosmetic/contract.

**Confidence** (is it real): *high* = reproduced via execution or a verbatim spec
contradiction · *medium* = strong static evidence, not reproduced · *low* =
argument only (a note, not a defect).

Report findings ranked by **severity × confidence**. Keep priority separate from
severity — an S2 on a never-used admin path may be lower priority than an S3 on
the primary flow; note priority, let the human decide.

## The fix gate (report-only by default)

Gauntlet does **not** write fixes autonomously by default. It produces the
report; the human fixes (or invokes `code-review --fix`, etc.).

A finding may be **offered** for an autonomous fix **only if ALL hold**:
1. severity ≥ S2, **and**
2. confidence = high (reproduced), **and**
3. backed by a **non-golden, independent** oracle (specified / derived-reference
   / metamorphic / execution — never a golden-diff alone), **and**
4. the fix is local and low-blast-radius.

Even then, the loop is: **show the diff → get explicit confirmation → apply →
re-run the exact failing check → run a regression pass (the rest of the harness +
typecheck/build/tests) → revert if anything worsens.** Never batch-apply silently.
When in doubt, report, don't touch.

Low-confidence and low-severity findings are **always** report-only, regardless
of the above. So are anything from golden diffs and any visual-judgment UI
assertion.

## Stop conditions

- **Find:** stop a surface after K consecutive rounds with nothing new above the
  severity bar (loop-until-dry, bar-gated) — not "until everything is covered."
- **Budget:** if the user set a token/time budget, spend it on Tier 1 first.
- **Fix:** only the gated safe class. No open-ended "fix every issue" — that has
  no stop condition and is how scope creep + regressions happen.
