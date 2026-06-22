#!/usr/bin/env bash
# gauntlet/risk_scan.sh — read-only high-impact surface map.
# Greps for patterns that mark the surface where bugs hurt most, then ranks the
# files that concentrate them. A starting point for triage, not a verdict.
# Usage: bash risk_scan.sh [repo_path]   (default: .)
set -euo pipefail
REPO="${1:-.}"
cd "$REPO"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

# git grep (respects .gitignore) when available, else grep -r with excludes.
# Always emits normalized "count<TAB>file" lines (count first, for sort/awk).
scan(){ # scan <regex>
  local raw
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    raw=$(git grep -cEi "$1" -- . 2>/dev/null || true)
  else
    raw=$(grep -rcEi --exclude-dir={node_modules,dist,build,vendor,.venv,.git,coverage} "$1" . 2>/dev/null | awk -F: '$NF>0' || true)
  fi
  # raw lines are "file:count"; filter on the file part, then flip to count<TAB>file.
  printf '%s\n' "$raw" | grep -vE '^$' \
    | grep -vE '(node_modules|dist|build|vendor|\.venv|/\.git/|package-lock|yarn\.lock|pnpm-lock|\.min\.|/tests?/|\.test\.|\.spec\.|_test\.)' \
    | grep -vEi '\.(md|mdx|markdown|csv|tsv|txt|rst|adoc|svg|map|snap|lock|json|ya?ml):[0-9]+$' \
    | grep -vE '(^|/)(docs|doc|documentation|examples?|fixtures?|__snapshots__)/' \
    | sed -E 's/^(.*):([0-9]+)$/\2	\1/' || true
}

declare -a CATS=(
  "AUTH/PERMISSION|auth|login|password|passwd|\\btoken\\b|session|permission|authori[sz]|jwt|bcrypt|\\brole\\b|is_?admin|access[_-]?control|tenant"
  "WRITES/PERSISTENCE|insert |update |delete from|\\.save\\(|\\.create\\(|\\.update\\(|\\.destroy\\(|prisma|sequelize|knex|writeFile|fs\\.write|db\\.(run|exec|prepare)"
  "MONEY/ACCOUNTING|price|payment|charge|invoice|billing|stripe|paypal|\\bquota\\b|credit|balance|refund|\\busage\\b|meter|subscription"
  "DELETE/IRREVERSIBLE|delete|destroy|truncate|drop table|unlink|rm -rf|overwrite|purge|wipe"
  "SECURITY-BOUNDARY|exec\\(|eval\\(|child_process|subprocess|os\\.system|shell|\\bsql\\b|innerHTML|dangerouslySetInnerHTML|deserialize|pickle|yaml\\.load|\\.\\./|path\\.join|redirect"
  "SECRETS|api[_-]?key|secret|private[_-]?key|password\\s*[:=]|token\\s*[:=]|aws_|BEGIN (RSA|PRIVATE)"
  "EXTERNAL-IO|fetch\\(|axios|http\\.request|requests\\.|urllib|net/http|open\\(|readFile|fs\\.read"
)

echo "================ gauntlet risk scan ================"
echo "high-impact surface (deep-test these first). counts = matching lines/files."
for entry in "${CATS[@]}"; do
  name="${entry%%|*}"; rx="${entry#*|}"
  echo ""; echo "---- $name ----"
  scan "$rx" | sort -t$'\t' -k1 -rn 2>/dev/null | head -6 | sed 's/^/  /' || echo "  (none)"
  scan "$rx" | awk -F'\t' '{print $2"\t"$1}' >> "$TMP" 2>/dev/null || true
done

echo ""; echo "---- hottest files overall (sum across categories) ----"
awk -F'\t' '{c[$1]+=$2} END{for(f in c) print c[f]"\t"f}' "$TMP" 2>/dev/null \
  | sort -rn | head -12 | sed 's/^/  /'

echo ""
echo "Note: this is a keyword heuristic — confirm by reading. Files that appear"
echo "in several categories (auth + writes + money) are prime Tier-1 targets."
echo "==================================================="
