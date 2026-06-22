# Calibration probe — does this pass actually catch bugs?

A QA run that reports "all clear" is worthless if it *couldn't* have caught a real
bug. The calibration probe measures detection power by injecting known faults and
checking whether the pass catches them. It converts "we looked at everything"
into "we caught 9/10 planted S1–S2 faults in the high-impact paths."

## How to run it

1. **Pick targets:** the Tier-1 high-impact paths (`triage-and-fix.md`).
2. **Craft ~10–15 realistic, tiered faults** — not random mutants. Use bugs that
   actually happen, e.g.:
   - drop a `WHERE user_id = ?` / tenant filter (auth/isolation → S1)
   - remove an `await` / drop error handling (race / silent failure → S1/S2)
   - off-by-one a pagination/loop bound (data loss → S2)
   - flip a comparison (`>=`→`>`), invert a boolean guard (S2)
   - wrong rounding / unit / sign in money math (S1/S2)
   - skip input validation (S2/S3)
3. **Inject one at a time into a scratch copy** (git worktree or a copy under the
   central folder — never mutate the real tree), run the relevant oracle layer
   **blind** (the checker doesn't know which fault, or that there is one), record
   caught / missed, revert.
4. **Report the kill rate by severity tier**, e.g. "S1: 5/5, S2: 4/6, S3: 2/4".

## How to read it

- **High S1/S2 kill rate** → trust a clean result on *those oracle classes*.
- **Low kill rate** → the headline is "this pass is partly blind here"; redirect
  effort (add the missing oracle, add a unit test, browser-drive the flow) before
  trusting any "all clear".

## The honest limit (state this in the report)

The probe only validates the **oracle classes you built**, against **the faults
you thought to inject**. If you inject dropped-WHERE / missing-await / off-by-one,
you prove you catch *those* — which your implicit + schema oracles were designed
to catch. It says **nothing** about classes you can't oracle (e.g. wrong
business/generative logic with no external reference). So a green probe score
must never be reported as "the app is healthy" — only as "the oracles we have
bite, on the faults we tried." Pair the score with the abstention map
(`reporting.md`): the probe measures the verified surface; the abstention map
measures what was never in scope to begin with.

## Cost control

The probe is one extra pass over a handful of mutants on the Tier-1 surface — keep
it to ~10–15. Don't approach full mutation testing (every-line mutants): it's
orders of magnitude slower, noisy with equivalent mutants, and not worth it here.
Run the probe every audit by default (it's the trust meter); offer to skip it
only on an explicit lean run.
