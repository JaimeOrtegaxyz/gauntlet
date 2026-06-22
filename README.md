# gauntlet

A Claude Code skill for QA-auditing an existing codebase — and reporting honestly what it could and couldn't vouch for.

Point it at a working app and it finds the bugs normal review misses: the ones where the code is *self-consistent but wrong*. It runs the system through a gauntlet of independent oracles, then leads with a coverage/abstention map instead of a false "all clear."

## How it works

- **Non-circular by rule.** Every verdict traces to an oracle that lives *outside* the code under test — a spec/doc/contract, a derived relation (metamorphic or a clean-room reference), an implicit truth (no crash, valid shape, idempotency), or real execution. Reading the code only forms hypotheses, never verdicts.
- **Works on any app.** It detects the type (HTTP/API, CLI, library, web frontend, data pipeline) and picks the right way to exercise it. For UIs it composes the `ui-test` skill rather than rebuilding a browser harness.
- **Spends by risk, not uniformly.** Deep effort goes to the high-impact surface (auth, writes, money, irreversible actions, security, I/O); the long tail gets cheap implicit checks.
- **Honest, and safe.** A finding needs a reproducible counterexample, not an argument. **Report-only by default** — it never writes fixes without explicit confirmation. The report leads with what it *couldn't* verify, includes a "Killed findings" section, and is written to `~/.claude/gauntlet/` — never into the audited repo.
- **Composes, doesn't duplicate.** For a diff/PR use `code-review`; to confirm one change use `verify`; for security-only use `security-review`. gauntlet audits stable code and calls those as tools.

## Install

Copy the folder into your skills directory:

```sh
git clone https://github.com/JaimeOrtegaxyz/gauntlet.git ~/.claude/skills/gauntlet
```

Or into `.claude/skills/gauntlet/` inside a project to scope it there.

Full method — the oracle taxonomy, per-app-type recipes, the risk/fix gate, the calibration probe, and the report format — lives in `SKILL.md` and `references/`.
