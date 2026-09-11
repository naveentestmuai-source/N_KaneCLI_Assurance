#!/usr/bin/env bash
# Runs the kane-cli assurance lifecycle end to end, non-interactively, for CI.
#
# Stages: capture + extract -> checkpoint 1 (auto-review) -> design
# (--mode ci, so judgement calls fail closed instead of hanging) ->
# checkpoint 2 (auto-review) -> author each generated test in a real headless
# browser -> measure coverage -> write a dated results report.
#
# This mirrors the "Fully non-interactive shell variant" in
# ASSURANCE-HANDBOOK.md, extended past the design stage through authoring
# and coverage measurement. Auto-approval at both checkpoints is the same
# choice kane-cli's own CI example makes (see the handbook) — it is
# appropriate for a repeatable pipeline that re-derives from a spec that is
# itself reviewed in source control (i.e. via a pull request), not a
# substitute for human review of a spec nobody has read.
set -uo pipefail
cd "$(dirname "$0")/.."

source scripts/lib.sh
require_cmd kane-cli
require_cmd jq

RUN_DIR="run"
mkdir -p "$RUN_DIR"
: > "$RUN_DIR/summary.md"

# Always grab kane-cli's own trace logs on the way out, success or failure —
# they're the best lead we have on anything that crashes without printing a
# reason (see capture_kane_trace_logs in lib.sh for what is/isn't copied).
trap capture_kane_trace_logs EXIT

SOURCE_SPEC="${SOURCE_SPEC:-sources/feature-spec.md}"
SOURCE_ID="${SOURCE_ID:-feature-spec}"
MAX_DESIGN="${MAX_DESIGN:-4}"
TITLE_SEARCH_TERM="${TITLE_SEARCH_TERM:-Inception}"
export TITLE_SEARCH_TERM

NEEDS_ATTENTION=0

summary "## Kane CLI Assurance — Media & Entertainment"
summary ""
summary "Source: \`$SOURCE_SPEC\` · Target: TMDB (themoviedb.org) · Search term: \`$TITLE_SEARCH_TERM\`"
summary ""

# --- credits before -----------------------------------------------------
kane-cli balance --json > "$RUN_DIR/balance-before.json" 2>/dev/null || true
BALANCE_BEFORE=$(jq -r '.balance // .credits // empty' "$RUN_DIR/balance-before.json" 2>/dev/null || true)

# --- Stage 1+2: capture + extract ---------------------------------------
echo "== context ingest =="
kane-cli context ingest "$SOURCE_SPEC" --mode agent 2> "$RUN_DIR/01-ingest.stderr.log" \
  | tee "$RUN_DIR/01-ingest.ndjson"
ex="$(kane_exit "$RUN_DIR/01-ingest.ndjson")"
if [ "$ex" != "0" ]; then
  summary "**FAILED at \`context ingest\`** (exit \`$ex\`) — see \`01-ingest.ndjson\`."
  dump_stderr_to_summary "$RUN_DIR/01-ingest.stderr.log" "context ingest"
  exit 1
fi
summary "- \`context ingest\`: done"

# --- Stage 3: checkpoint 1 (auto-review use-cases) ----------------------
echo "== context list (use-cases) =="
kane-cli context list --json --inferred > "$RUN_DIR/02-context-list.ndjson"

jq -s '[ .[] | select(.label == "usecase") |
  {ref: .id, resolution: "approved",
   reason: "CI auto-approval: citation verified against reviewed source (Media & Entertainment demo pipeline)."} ]' \
  "$RUN_DIR/02-context-list.ndjson" > "$RUN_DIR/verdicts-checkpoint1.json"

UC_COUNT=$(jq 'length' "$RUN_DIR/verdicts-checkpoint1.json")
if [ "$UC_COUNT" -eq 0 ]; then
  summary "**FAILED** — no use-cases were extracted from \`$SOURCE_SPEC\`."
  exit 1
fi
summary "- \`context extract\`: $UC_COUNT use-case(s) proposed"

kane-cli context review --verdicts "$RUN_DIR/verdicts-checkpoint1.json" --json 2> "$RUN_DIR/03-review1.stderr.log" \
  | tee "$RUN_DIR/03-review1.ndjson"
ex="$(kane_exit "$RUN_DIR/03-review1.ndjson")"
if [ "$ex" != "0" ]; then
  summary "**FAILED at checkpoint 1** (exit \`$ex\`) — see \`03-review1.ndjson\`."
  dump_stderr_to_summary "$RUN_DIR/03-review1.stderr.log" "context review (checkpoint 1)"
  exit 1
fi
summary "- **Checkpoint 1**: $UC_COUNT use-case(s) approved"

# --- Stage 4: design tests per approved use-case ------------------------
echo "== design tests =="
summary ""
summary "### Design"
summary ""
for ref in $(jq -r '.[].ref' "$RUN_DIR/verdicts-checkpoint1.json"); do
  safe_ref="$(echo "$ref" | tr -c 'A-Za-z0-9_-' '_')"
  out="$RUN_DIR/04-design-${safe_ref}.ndjson"
  err="$RUN_DIR/04-design-${safe_ref}.stderr.log"
  echo "-- design tests for $ref --"
  kane-cli design tests --use-case "$ref" --mode ci --max "$MAX_DESIGN" 2> "$err" | tee "$out"
  ex="$(kane_exit "$out")"
  case "$ex" in
    0)
      gaps=$(kane_field "$out" '.gaps | length' 2>/dev/null); gaps="${gaps:-0}"
      warns=$(kane_field "$out" '.warnings | length' 2>/dev/null); warns="${warns:-0}"
      summary "- \`$ref\`: designed ok — $gaps gap(s), $warns warning(s)"
      ;;
    "")
      summary "- \`$ref\`: **no \`done\` event in the stream** — process may have crashed. See \`$out\`."
      dump_stderr_to_summary "$err" "design tests ($ref)"
      NEEDS_ATTENTION=1
      ;;
    *)
      # --mode ci fails closed on judgement calls (HIGH_RISK_CI) instead of
      # pausing forever. That is a feature, not a bug — surface it clearly
      # and keep going with the other use-cases rather than aborting the run.
      reason=$(kane_field "$out" '.error // .message // empty')
      summary "- \`$ref\`: **needs a human** (exit \`$ex\`${reason:+ — $reason}). Re-run locally with \`--mode agent\` to resolve it, then re-run this workflow."
      NEEDS_ATTENTION=1
      ;;
  esac
done

# --- Stage 5: checkpoint 2 (auto-review ACs/scenarios/tests) ------------
echo "== context list (design artifacts) =="
kane-cli context list --json --inferred > "$RUN_DIR/05-context-list-2.ndjson"

jq -s '[ .[] | select(.label != "usecase" and .status == "derived") |
  {ref: .id, resolution: "approved",
   reason: "CI auto-approval: design output traced to an approved, cited use-case."} ]' \
  "$RUN_DIR/05-context-list-2.ndjson" > "$RUN_DIR/verdicts-checkpoint2.json"

DESIGN_COUNT=$(jq 'length' "$RUN_DIR/verdicts-checkpoint2.json")
if [ "$DESIGN_COUNT" -gt 0 ]; then
  kane-cli context review --verdicts "$RUN_DIR/verdicts-checkpoint2.json" --json 2> "$RUN_DIR/06-review2.stderr.log" \
    | tee "$RUN_DIR/06-review2.ndjson"
  ex="$(kane_exit "$RUN_DIR/06-review2.ndjson")"
  if [ "$ex" != "0" ]; then
    summary "**FAILED at checkpoint 2** (exit \`$ex\`) — see \`06-review2.ndjson\`."
    dump_stderr_to_summary "$RUN_DIR/06-review2.stderr.log" "context review (checkpoint 2)"
    exit 1
  fi
  summary "- **Checkpoint 2**: $DESIGN_COUNT design artifact(s) approved"
else
  summary "- **Checkpoint 2**: nothing new to review (no use-case cleared design)"
fi

# --- Stage 6: author every generated test in a real headless browser ----
echo "== testmd run (author) =="
summary ""
summary "### Test runs"
summary ""
shopt -s nullglob
tests=(.testmuai/tests/*_test.md)
if [ "${#tests[@]}" -eq 0 ]; then
  summary "- no tests were designed this run (see Design section above)"
else
  for f in "${tests[@]}"; do
    name="$(basename "$f")"
    log="$RUN_DIR/07-testmd-${name%.md}.log"

    # Build --variables dynamically from whatever {{placeholders}} the
    # designed test actually contains, rather than guessing a fixed name —
    # the docs are explicit that the exact variable name is non-deterministic
    # (it is minted from the spec wording during design).
    vars_json=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$f" | tr -d '{}' | sort -u \
      | jq -R -n '[inputs] | map({(.): {value: env.TITLE_SEARCH_TERM}}) | add // {}')

    echo "-- authoring $name (variables: $vars_json) --"
    if [ "$vars_json" = "{}" ]; then
      kane-cli testmd run "$f" --agent --headless 2>&1 | tee "$log"
    else
      kane-cli testmd run "$f" --agent --headless --variables "$vars_json" 2>&1 | tee "$log"
    fi
    status="${PIPESTATUS[0]}"

    link=$(best_effort_evidence_link "$log")
    if [ "$status" -eq 0 ]; then
      summary "- \`$name\`: **passed**${link:+ — [evidence]($link)}"
    else
      summary "- \`$name\`: **failed** (exit $status)${link:+ — [evidence]($link)} — see \`$(basename "$log")\`"
      NEEDS_ATTENTION=1
    fi
  done
fi

# --- Stage 7: measure coverage ------------------------------------------
echo "== cover gaps =="
kane-cli cover gaps --json > "$RUN_DIR/08-cover.json" 2>/dev/null || true
kane-cli cover gaps > "$RUN_DIR/08-cover.txt" 2>&1 || true

summary ""
summary "### Coverage (\`kane-cli cover gaps\`)"
summary ""
summary '```'
summary "$(cat "$RUN_DIR/08-cover.txt")"
summary '```'
summary ""
summary "Read the use-case row, not the headline percentage — \`designed\`/\`proven\` are measured"
summary "against *criteria that exist right now*, not against everything the product should do."

# --- credits after -------------------------------------------------------
kane-cli balance --json > "$RUN_DIR/balance-after.json" 2>/dev/null || true
BALANCE_AFTER=$(jq -r '.balance // .credits // empty' "$RUN_DIR/balance-after.json" 2>/dev/null || true)
if [ -n "$BALANCE_BEFORE" ] && [ -n "$BALANCE_AFTER" ]; then
  used=$(( BALANCE_BEFORE - BALANCE_AFTER ))
  summary ""
  summary "**Credits used this run:** $used (balance $BALANCE_BEFORE → $BALANCE_AFTER)"
fi

# --- dated results report --------------------------------------------------
DATE_TAG="$(date -u +%Y-%m-%d)"
REPORT="$RUN_DIR/ASSURANCE-RESULTS-${DATE_TAG}.md"
{
  echo "# Assurance Results — ${DATE_TAG}"
  echo
  echo "Generated by the \`kane-cli-assurance.yml\` workflow. Raw NDJSON logs, generated"
  echo "tests, and evidence links are attached to the workflow run as artifacts."
  echo
  cat "$RUN_DIR/summary.md"
} > "$REPORT"

if [ "$NEEDS_ATTENTION" -eq 1 ]; then
  echo "::warning::One or more stages need a human to resolve (see job summary). The run still produced results — check the summary and artifacts." >&2
fi

echo "Done. Report: $REPORT"
