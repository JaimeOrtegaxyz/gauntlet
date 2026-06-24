# App-type recipes — how to exercise each kind of system

Gauntlet is app-agnostic; only the *exercise mechanism* changes. `profile.sh`
reports the type(s); a repo is often several at once (e.g. an API + a web
frontend). Pick the matching recipes; the oracle types (`oracles.md`) are the
same everywhere.

For every type: build the harness/scratch data in `~/.claude/gauntlet/<repo>-<date>/`,
never in the repo. Use a throwaway DB/data dir and a non-default port. Prefer the
project's own test runner and fixtures when they exist.

## HTTP / API service (REST, GraphQL, RPC)
- **Exercise:** boot the server against a throwaway DB + isolated port; hit it
  with the real HTTP client. Seed state directly in the datastore for routes that
  normally require expensive/AI/3rd-party calls, then test the cheap, deterministic
  logic (reads, validation, auth, selection/exclusivity, undo, pagination).
- **Implicit:** wrap every request — status ≠ 5xx, body parses, validates against
  the route's declared schema/types, idempotent methods idempotent, 404 on
  missing / 4xx on invalid with the documented error shape.
- **Metamorphic:** pagination completeness (`|all| == Σ|pages|`, no dupes),
  filter ⊆ unfiltered, sort preserves membership, edit-then-GET changes only
  edited fields, default-param == explicit-default.
- **Specified:** OpenAPI/GraphQL schema and route contracts are gold — assert
  responses conform; assert documented status codes.
- **Frugality:** generation/LLM/payment endpoints cost money and are
  nondeterministic — exercise them once for shape/persistence, code-trace the
  rest, and say so. Never loop expensive endpoints for coverage.

## CLI tool
- **Exercise:** invoke the built binary/script in a temp working dir with crafted
  args, stdin, env, and fixture files; capture exit code, stdout, stderr.
- **Implicit:** exit code 0 on valid input / non-zero + message on invalid; no
  stack trace leaking to the user; `--help` exits 0; honors `--quiet`/`--json`.
- **Metamorphic:** idempotent commands re-run cleanly; `--dry-run` makes no
  changes; order-independent flags commute; round-trips (export→import,
  encode→decode) restore the input.
- **Specified:** `--help`/man text and README examples are a contract — run the
  documented examples verbatim and assert they behave as written.

## Library / package (public API)
- **Exercise:** import it and call the public surface directly (its own test
  runner).
- **Derived:** this is where clean-room **differential** oracles and
  **property-based** tests (fast-check / Hypothesis / proptest) shine — generate
  random inputs and assert invariants (round-trips, monotonicity, bounds,
  algebraic laws). Highest ROI for pure logic.
- **Specified:** docstrings/README/type signatures are the contract; test the
  promises, including documented exceptions.
- **Implicit:** no crash on edge inputs (empty, huge, unicode, null), no mutation
  of caller-owned inputs, no resource leaks.

## Web frontend / SPA
- **Exercise:** compose the `ui-test` skill (real browser; accessibility-tree
  mode beats pixels for a web app) — see `composition.md`. Default-on for the top
  flows. Run against a local dev/build server with seeded backend state.
- **Top flows (default candidates):** auth/login/gate, create→persist→reload→
  re-read (data survives a refresh), limit/quota enforcement, destructive action
  + confirm, error/empty/loading states render.
- **Implicit (UI):** no console errors/unhandled rejections; no broken
  images/links; no unrendered `{{tokens}}`; forms validate; disabled controls
  actually disabled; keyboard/aria basics.
- **Caveat:** visual-judgment assertions are the least reliable tier — keep them
  out of the fix gate.

## Data pipeline / batch / ETL
- **Exercise:** run the pipeline on a small crafted dataset with a known shape.
- **Metamorphic/implicit:** row-count conservation (no silent drops/dupes),
  schema stability, idempotent re-runs, deterministic output for fixed input,
  null/dupe/out-of-range handling, partition union == whole.
- **Differential:** recompute a sample by hand / with a trivial reference and
  diff.

## Anything else
Fall back to first principles: find the system's real interface, exercise it,
and assert the implicit oracles (no crash, valid shape, idempotency, no leak) +
whatever external spec exists. If there is genuinely no external oracle and no
way to run it, **abstain** and say so.
