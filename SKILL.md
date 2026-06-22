---
name: gauntlet
description: >-
  A deliberate, comprehensive correctness audit of an ENTIRE existing codebase,
  grounded in oracles that live outside the code (specs/contracts, metamorphic and
  reference relations, implicit invariants, real execution). The heavyweight,
  run-occasionally QA pass — not an everyday check. It detects the app type
  (HTTP/API, CLI, library, web frontend, data pipeline), risk-ranks the whole
  surface, exercises the system through its real interface, verifies findings with
  reproducible counterexamples, and reports honestly what was proven vs. what it
  could not verify (a coverage/abstention map, not a false "all clear").
  Report-only by default; never writes fixes without confirmation.
  PRIMARY ENTRY is the "/gauntlet" command. Otherwise invoke ONLY when the user
  explicitly asks for a full, exhaustive, or rigorous audit of a WHOLE app or
  codebase — e.g. "do a complete QA audit of my app", "rigorously verify the whole
  app is correct", "exhaustively shake out every bug across the codebase", "audit
  this entire project for correctness before release". This is a high-cost,
  intentional pass.
  Do NOT invoke for everyday or narrow requests — a casual "find a bug", "is this
  working", "test this", "QA this change", reviewing a diff/PR, confirming one
  change, or a security-only review. Those should default to standard behavior or a
  focused tool: code-review for a diff/PR, verify to confirm a specific change,
  security-review for security. gauntlet works at whole-app scope on stable code
  and composes those tools rather than duplicating them.
metadata:
  version: "0.1.0"
---

# Gauntlet

Point this at a working codebase and find the bugs that survive normal review —
the ones where the code is *self-consistent but wrong*. Then say, plainly, how
much of the app you could actually vouch for.

## The core move — read before anything else

Most automated QA is **circular**: it derives a spec from the code, then checks
the code against that spec. That can only find places where the code disagrees
with itself; a function that is wrong but internally consistent passes, and a
model can even invent a spec that contradicts itself and "fix" a non-bug into a
regression. (That failure is the reason this skill exists.)

Gauntlet's one unbreakable rule: **every pass/fail verdict must trace to an
oracle that lives OUTSIDE the code under test.** Reading the implementation is
allowed only to *form hypotheses* — never to issue a verdict. The four legitimate
oracle sources (full detail in `references/oracles.md`):

- **Specified** — an external statement of intent: README, docs, a PRD, route
  contracts, OpenAPI/types, UI copy, DB schema, error messages the product
  promises.
- **Derived** — a relation that must hold regardless of the implementation:
  metamorphic relations (reorder a list → same members; tighten a filter →
  subset; edit then read → only edited fields changed), a clean-room reference
  for a pure function, a golden snapshot.
- **Implicit** — universal truths needing no spec: no crash/5xx/hang, output
  parses and matches its declared shape, idempotent operations stay idempotent,
  no secret/PII/`{{token}}` leak.
- **Execution** — the system actually run and observed: a live API/CLI call, or
  a real browser (compose the `ui-test` skill — see below).

If a target has **none** of these, it is **ABSTAIN** — reported as unverified,
never asserted as passing. Abstention is a first-class result, not a gap to hide.

## How to operate

- **Report-first, always.** The default deliverable is a triaged report. Gauntlet
  does **not** write fixes on its own. Propose fixes; apply only the narrow safe
  class and only with explicit per-fix confirmation (see Phase 5 and
  `references/triage-and-fix.md`). "Fixing" is itself a change that can regress —
  treat it with the same caution as any destructive action.
- **Abstention is the headline.** Lead the report with *"X% of the risk-weighted
  surface was oracle-verified; these high-impact areas were ABSTAINED for lack of
  an external oracle: […]"*. A green result on the cheap-to-check surface while
  the valuable logic was never checked is worse than an honest "couldn't verify".
- **Allocate by risk, never uniformly.** Treating every file/endpoint equally is
  how the last version burned a fortune and risked regressions polishing trivia.
  Spend deep effort only on the high-impact surface (auth, writes, money, data
  loss, irreversible actions, security boundaries, external I/O). See
  `references/triage-and-fix.md`.
- **A finding earns its life with a counterexample.** A FAIL needs a reproducible
  input→wrong-output (a failing assertion, a transcript, a browser observation)
  or a verbatim contradiction of an external source — not an argument. No
  reproduction → downgrade to a low-confidence note. The agent that *finds* an
  issue may not be the one that *confirms* it.
- **Compose, don't rebuild.** Gauntlet orchestrates; it doesn't reimplement other
  skills. Browser execution → `ui-test`. A diff/PR review → `code-review`.
  Confirming one change → `verify`. Security-only → `security-review`. See
  `references/composition.md`.
- **Scale to the repo.** A 500-line library and a 200k-line monorepo are not the
  same job. `scripts/profile.sh` reports size, age, app type, and interfaces;
  let that pick depth (churn-ranking helps a mature repo, is noise on a young
  one — `references/triage-and-fix.md`).
- **Never pollute the audited repo.** Scratch harnesses, seeded data, and the
  report go in a dated central folder (`~/.claude/gauntlet/<repo>-<date>/`),
  not the target's tree. Any test files added *to* the repo are proposed, shown,
  and committed only with confirmation.

## Workflow

### Phase 0 — Profile & risk map
Run `bash <skill-dir>/scripts/profile.sh <repo>` and `bash
<skill-dir>/scripts/risk_scan.sh <repo>` (both read-only). From their output and
a quick look, establish: app type(s) and how the system is exercised (HTTP, CLI,
import, browser); the **high-impact surface** (hand-listed: auth/permission,
persistence/writes, money/accounting/quota, delete/irreversible, security
boundaries, external I/O); and the **oracle-source inventory** (which external
specs exist — README/docs/PRD/contracts/types/schema). Output a ranked target
list, each tagged with its likely oracle source or `ABSTAIN`. Confirm scope and
the high-impact list with the user before spending. See
`references/triage-and-fix.md`.

### Phase 1 — Oracle assignment (de-circularize)
For every target, assign an oracle **type** (specified / derived / implicit /
execution) per `references/oracles.md`. Targets with no external oracle are
marked `ABSTAIN` now — do not paper over them with a code-trace. This phase is
what separates gauntlet from circular QA; do it explicitly.

### Phase 2 — Cheap precision layer (where bugs are findable)
Pick recipes by app type from `references/app-types.md`. In rough ROI order:
1. **Pure-function unit tests** for the few deterministic, high-value functions
   (parsing, money/units math, formatting, token substitution, access checks).
   A true external oracle for near-zero phantom risk — do this first.
2. **Implicit-oracle wrapper** on every exercised call (no 5xx/crash/hang,
   parses, schema-valid, idempotency). Cheap, never circular, catches the
   high-severity class.
3. **Metamorphic relations** on list/search/CRUD/transform surfaces (membership,
   subset, partition-completeness, edit-difference). See `references/oracles.md`.
4. **Browser execution** (default-on when the app has a UI): compose `ui-test`
   for the top flows that have no API/unit oracle — auth gate, create→persist→
   re-read, limit/quota enforcement. See `references/composition.md`.

### Phase 3 — Hypotheses & adjudication
For surface the cheap layer can't cover, finder agents propose suspected bugs
(recall-tuned). A **separate adjudicator** keeps a finding only if it has a
reproducible counterexample or a cited external-source contradiction; otherwise
downgrade or abstain. Reserve multi-vote/quorum for contested, high-severity
items only — don't vote on everything.

### Phase 4 — Calibration probe (does this pass even catch bugs?)
Inject a small, tiered set (~10–15) of realistic faults into the high-impact
paths, run the pass blind, and report the catch rate. Right-sizes trust and
proves the oracles bite. **State its limit honestly:** it only validates the
oracle classes you built — abstained areas remain unmeasured. See
`references/calibration.md`.

### Phase 5 — Report & gated fix
Write the report (`references/reporting.md`): the abstention/coverage headline
first; confirmed findings ranked by severity×confidence, each with a
reproduction; a mandatory **"Killed findings (and why)"** section (proof the
self-refute pass ran); the honest coverage statement (unit- / harness- /
browser-verified vs abstained). **Fixing is gated and report-only by default.**
A finding may be *offered* for autonomous fix only if: severity ≥ S2 **and**
high confidence **and** backed by a non-golden independent oracle. Even then,
show the diff, get explicit confirmation, apply, and re-run the exact failing
check **plus** a regression pass; revert if anything worsens. Everything else is
reported for the human to handle. See `references/triage-and-fix.md`.

## Stop conditions

- **Find:** stop a surface when consecutive rounds surface nothing new above the
  severity bar — not when "everything" is covered.
- **Spend:** the high-impact surface gets depth; the long tail gets the implicit
  wrapper or enumerate-only. Log what was downgraded — never silently cap.
- **Fix:** only the gated safe class, with confirmation. No open-ended "fix every
  issue."

## Bundled resources

- `scripts/profile.sh` — repo size/age, languages, app type, interfaces, test
  setup, and a depth recommendation. Read-only.
- `scripts/risk_scan.sh` — grep-based high-impact surface map (auth, writes,
  money, delete/irreversible, exec/network/file, secrets). Read-only.
- `references/oracles.md` — the oracle taxonomy, the anti-circularity rule,
  metamorphic-relation patterns, the counterexample-or-downgrade rule.
- `references/app-types.md` — per-app-type exercise + oracle recipes (HTTP/API,
  CLI, library, web frontend, data pipeline).
- `references/triage-and-fix.md` — risk ranking, severity×confidence gate, the
  fix-gate policy, scale-awareness.
- `references/calibration.md` — the fault-injection probe and its honest limits.
- `references/reporting.md` — report format, the abstention headline, where to
  write artifacts.
- `references/composition.md` — when to compose `ui-test` / `code-review` /
  `verify` / `security-review` instead of duplicating them.
