#!/usr/bin/env bash
# gauntlet/profile.sh — read-only repo profiler.
# Reports size, age/maturity, app type(s), interfaces, and test setup, then
# recommends a depth regime (whether churn-ranking is meaningful).
# Usage: bash profile.sh [repo_path]   (default: .)
set -euo pipefail
REPO="${1:-.}"
cd "$REPO"
PR(){ printf '%s\n' "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
hits(){ # count files matching an extended-regex, respecting ignores when possible
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git grep -lEi "$1" -- . 2>/dev/null | grep -vE '(^|/)(node_modules|dist|build|vendor|\.venv|\.git)/' | wc -l | tr -d ' '
  else
    grep -rlEi --exclude-dir={node_modules,dist,build,vendor,.venv,.git} "$1" . 2>/dev/null | wc -l | tr -d ' '
  fi
}
# yes if ANY supplied glob/pattern matches at least one path (handles BSD ls
# erroring when one of several patterns has no match).
exists(){ local p f; for p in "$@"; do for f in $p; do [ -e "$f" ] && { echo yes; return; }; done; done; echo no; }

PR "================ gauntlet repo profile ================"
PR "repo: $(pwd)"

PR ""; PR "---- size ----"
if have tokei; then tokei 2>/dev/null | tail -n +1 | sed -n '1,20p'
else
  FILES=$(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/vendor/*' -not -path '*/.venv/*' 2>/dev/null | wc -l | tr -d ' ')
  CODE=$(find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.rb' -o -name '*.java' -o -name '*.kt' -o -name '*.php' -o -name '*.c' -o -name '*.cpp' -o -name '*.cs' -o -name '*.swift' \) -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/vendor/*' -not -path '*/.venv/*' 2>/dev/null)
  LOC=$(echo "$CODE" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
  PR "tracked files (approx): $FILES"
  PR "code LOC (approx):      ${LOC:-0}"
  PR "languages present:"
  for ext in ts tsx js jsx py go rs rb java kt php swift; do
    n=$(echo "$CODE" | grep -c "\.$ext$" || true); [ "${n:-0}" -gt 0 ] && PR "  .$ext: $n files"
  done
fi

PR ""; PR "---- maturity (git) ----"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
  FIRST=$(git log --reverse --format=%as 2>/dev/null | head -1)
  LAST=$(git log -1 --format=%as 2>/dev/null)
  AUTHORS=$(git log --format=%ae 2>/dev/null | sort -u | wc -l | tr -d ' ')
  PR "commits: $COMMITS   authors: $AUTHORS   span: ${FIRST:-?} .. ${LAST:-?}"
  PR ""; PR "  top-churn files (numstat; meaningful only on mature repos):"
  git log --numstat --format= 2>/dev/null | awk 'NF==3{c[$3]+=$1+$2} END{for(f in c) print c[f]"\t"f}' \
    | grep -vE '(node_modules|dist|build|vendor|\.venv|package-lock|yarn.lock|pnpm-lock)' \
    | sort -rn | head -8 | sed 's/^/    /'
else
  COMMITS=0; PR "(not a git repo — churn data unavailable)"
fi

PR ""; PR "---- app type signals ----"
# Monorepo-aware: inspect every package.json outside node_modules, not just root.
PKGS=$(find . -name package.json -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
[ -n "$PKGS" ] && {
  PR "node package.json present ($(echo "$PKGS" | wc -l | tr -d ' ') manifest(s))"
  grep -qhE '"(react|vue|svelte|@angular|next|solid-js|preact)"' $PKGS 2>/dev/null && PR "  -> web frontend (UI). Compose ui-test (default-on)."
  grep -qhE '"(express|fastify|koa|@nestjs|hapi)"' $PKGS 2>/dev/null && PR "  -> HTTP/API service."
  grep -qhE '"bin"\s*:' $PKGS 2>/dev/null && PR "  -> CLI (package.json bin field)."
  grep -qhE '"(exports|module)"\s*:' $PKGS 2>/dev/null && PR "  -> library (exports/module)."
}
[ -f pyproject.toml -o -f setup.py -o -f requirements.txt ] && {
  PR "python project present"
  hits 'fastapi|flask|django|aiohttp|starlette' >/dev/null && [ "$(hits 'fastapi|flask|django|aiohttp|starlette')" -gt 0 ] && PR "  -> HTTP/API service."
  [ "$(hits 'argparse|click|typer')" -gt 0 ] && PR "  -> likely CLI (argparse/click/typer)."
  grep -qE 'console_scripts|\[project.scripts\]' setup.py pyproject.toml 2>/dev/null && PR "  -> CLI entry points declared."
}
[ -f go.mod ] && { PR "go module present"; [ "$(hits 'net/http|gin-gonic|chi|echo')" -gt 0 ] && PR "  -> HTTP/API service."; [ "$(hits 'cobra|flag\.')" -gt 0 ] && PR "  -> likely CLI."; }
[ -f Cargo.toml ] && { PR "rust crate present"; grep -qE '^\[\[bin\]\]' Cargo.toml 2>/dev/null && PR "  -> CLI/binary."; grep -qE '^\[lib\]' Cargo.toml 2>/dev/null && PR "  -> library."; }
[ -f Gemfile ] && PR "ruby project present"
[ -f pom.xml -o -f build.gradle -o -f build.gradle.kts ] && PR "jvm project present"
FE=$(find . -name index.html -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/.git/*' 2>/dev/null | head -1)
PR "  index.html present: $([ -n "$FE" ] && echo "yes ($FE)" || echo no)   (frontend signal)"

PR ""; PR "---- interfaces / contracts (external oracle sources) ----"
PR "  OpenAPI/Swagger: $(exists '*openapi* *swagger* **/openapi* **/swagger*' 2>/dev/null)"
PR "  GraphQL schema:  $(exists '*.graphql *.gql schema.graphql' 2>/dev/null)"
PR "  README:          $(exists 'README* readme*')"
PR "  product docs:    $(exists 'docs PRD* *PRD* design*.md')"
PR "  Dockerfile:      $(exists 'Dockerfile docker-compose*')"
PR "  .env example:    $(exists '.env.example .env.sample')"

PR ""; PR "---- test setup ----"
PR "  test dirs:    $(exists 'test tests __tests__ spec')"
PR "  test files:   $(find . -type f \( -name '*.test.*' -o -name '*.spec.*' -o -name '*_test.*' -o -name 'test_*.py' \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' ')"
grep -hoE '"(jest|vitest|mocha|ava|playwright|cypress)"' package.json 2>/dev/null | sort -u | sed 's/^/  runner: /' || true
[ -f pytest.ini -o -f tox.ini ] && PR "  runner: pytest"

PR ""; PR "---- depth recommendation ----"
if [ "${COMMITS:-0}" -lt 80 ]; then
  PR "  YOUNG/SMALL repo (commits<80): churn-ranking is noise — rank by the IMPACT axis"
  PR "  (auth/writes/money/irreversible/security/external-IO). See triage-and-fix.md."
else
  PR "  MATURE repo: churn x complexity hotspots are meaningful — combine with the impact axis."
fi
PR "  Next: run risk_scan.sh for the high-impact surface map."
PR "======================================================"
