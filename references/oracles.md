# Oracles — how to know what "correct" is without cheating

A test **oracle** is whatever tells you an observed behavior is right or wrong.
The whole value of gauntlet rests on using *non-circular* oracles. This file is
the catalog.

## The anti-circularity rule

A spec re-derived from the system under test (SUT) is **not** an oracle — it is
the SUT wearing a costume. Checking the SUT against it only finds internal
inconsistency. Two concrete failure modes it cannot catch or actively causes:

- **Wrong-but-consistent logic.** `tax = price * 1.0` is self-consistent and
  passes a code-derived spec; only an *external* statement ("tax is 8%") or a
  *reference* computation exposes it.
- **Self-contradictory invented specs.** An LLM asked "what should this do?"
  while reading the code can emit a spec whose own clauses conflict, then "fix"
  the code to match the wrong clause — a manufactured regression. (This happened
  in v1.)

So: **reading the implementation produces hypotheses, never verdicts.** Every
verdict cites one of the four oracle types below.

## 1. Specified oracles (external statement of intent)

Sources, roughly best-first: a PRD / product brief → README / docs / CHANGELOG →
route contracts / OpenAPI / GraphQL schema / typed interfaces → UI copy and
on-screen promises → DB schema + constraints → error strings the product commits
to. Tag each finding with the exact source line it contradicts.

Cross-source contradiction is itself a high-signal finding: when docs, types,
tests, and UI copy disagree about the same behavior, at least one is wrong — flag
it and let the human pick the source of truth. (Do not assume the code is right.)

Stale-spec guard: a doc can lag the code. When code and a *specified* oracle
disagree, report it as a **discrepancy** with both sides quoted; don't assume the
doc wins. Let severity/recency decide.

## 2. Derived oracles (relations that hold regardless of implementation)

### Metamorphic relations (MRs) — the workhorse
You don't need to know the right output; you need a relation between two runs
that must hold. The reusable set-theoretic patterns (general to any
list/search/transform/CRUD surface):

- **Equivalence** — a change that shouldn't affect membership doesn't: reorder
  inputs, change sort criterion → same set of items returned.
- **Equality / round-trip** — omitting a param equals passing its default;
  reverse-then-reverse, encode-then-decode, undo-then-redo = identity.
- **Subset** — tightening (adding a filter, narrowing a range, AND-ing keywords,
  a smaller page) returns a subset of the looser query.
- **Disjoint** — mutually exclusive filters return non-overlapping results
  (`status=A` vs `status=B`).
- **Complete / partition** — the union of a disjoint partition equals the
  unfiltered whole, and `|whole| == Σ|parts|` (catches pagination loss and
  duplicates).
- **Difference** — create/update returns the resource with *only* the changed
  fields differing from before.

Pick 5–15 that fit the app; instantiate them against the live interface. Do
**not** apply value-equality MRs to nondeterministic
output (LLM text, images, timestamps, random) — use implicit oracles there.

### Differential / reference oracle
Run the same input through an **independently written** implementation (a tiny
clean-room version built from the *spec*, not the code) and require agreement.
High ROI for a handful of pure, high-value functions (money/unit math, parsing,
formatting, access-control predicates); not worth it for glue/IO. Independence is
the point — a reference copied from the SUT is circular again.

### Golden / approval
Snapshot known-good outputs once (after human review), diff on later runs. A
**regression** guard only — it tells you something *changed*, never that the
original was *correct*, so never auto-fix from a golden diff alone.

## 3. Implicit oracles (universal truths, no spec needed)

Layer these on every exercised call — they're impossible to make circular and
catch the highest-severity class cheaply:

- No crash / no 5xx / no unhandled rejection / no hang or timeout on valid input.
- Output parses; conforms to its declared schema/type.
- Idempotent operations are idempotent (GET/PUT/DELETE; double-submit = no-op).
- No leak: secrets, PII, internal stack traces, or unrendered `{{tokens}}` in
  user-facing output.
- Resource conservation: counts add up; no negative quantities; no duplicate IDs.
- Light fuzzing of inputs (empty, huge, unicode, nulls, wrong types) is free
  coverage for these.

## 4. Execution oracles (run it and watch)

The only oracle that isn't an opinion. Exercise the system through its real
interface and assert against types 1–3 above. By app type → `app-types.md`. For
UIs, compose `ui-test` (→ `composition.md`); for APIs/CLIs, a thin harness or
direct invocation. Prefer execution over code-trace wherever it's affordable —
a real failing transcript outranks a plausible code-read argument (see the
counterexample rule).

## The counterexample-or-downgrade rule

A finding is a **FAIL** only with a concrete reproduction: an input and the
observed wrong output (failing assertion, request/response transcript, CLI
session, or browser observation), or a verbatim quote of the external source it
violates. A plausible-sounding argument with no reproduction is a
**low-confidence note**, not a defect — and never enters the fix gate. Keep the
finder and the adjudicator separate: the adjudicator's job is to *refute*, and it
may only keep what it can back with evidence.
