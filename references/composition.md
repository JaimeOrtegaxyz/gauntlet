# Composition — orchestrate, don't duplicate

Gauntlet's job is the non-circular, whole-system behavioral audit. Several
existing skills already do adjacent jobs better than a reimplementation would.
Compose them; if gauntlet's output starts to look like one of these, it has
collapsed into a redundant reviewer.

## Use instead of / alongside

- **`ui-test` (browserbase)** — real-browser execution. This IS gauntlet's
  execution oracle for web UIs (Phase 2, default-on). Hand it the top flows from
  `app-types.md`; treat its green/red as a candidate finding, and keep its
  visual-judgment tier out of the fix gate. Do **not** build a browser harness.
- **`code-review` (and `code-review ultra`)** — reviews a **diff/PR** for bugs and
  cleanups. Different scope: gauntlet audits *stable, already-merged* code against
  external oracles. If the user actually wants a diff reviewed, point them to
  `code-review`. After gauntlet's gated fixes, `code-review` is a good second pair
  of eyes on the resulting diff.
- **`verify`** — confirms *one specific change* does what it should by running the
  app. Gauntlet is discovery across the whole surface, not confirmation of a known
  change. Reuse `verify`'s run-the-app patterns; don't duplicate its purpose.
- **`security-review`** — gated security review of pending changes. Gauntlet covers
  security *boundaries* as part of the high-impact surface (implicit oracles:
  injection, path traversal, secret leaks), but for a focused security pass on a
  diff, defer to `security-review`.
- **`run`** — launches the project's app. Use it to stand up the server/app for
  execution oracles instead of reinventing launch logic.

## What stays gauntlet's own job

- Building the **non-circular oracle** (sourcing intended behavior from outside
  the code) — no other skill does this.
- **Risk-ranking the whole surface** and allocating effort by tier.
- **Metamorphic + implicit + differential** oracles on API/CLI/library surfaces.
- **Adjudication** (counterexample-or-downgrade) and the **calibration probe**.
- The **abstention-first report** and the **gated fix** policy.

## Rule of thumb

If a request is "review this diff" → `code-review`. "Does this change work" →
`verify`. "Is this secure" → `security-review`. "Is my app, as it stands,
actually correct — and how much of it can you vouch for" → gauntlet (which will
call the others as tools).
