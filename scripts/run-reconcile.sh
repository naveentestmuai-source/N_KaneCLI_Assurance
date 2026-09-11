#!/usr/bin/env bash
# Demonstrates the "requirements changed" stage: `maintain reconcile`.
#
# Must run in the SAME job/workspace as run-assurance.sh, right after it —
# reconcile operates on the .context/ store that ingest just created. It is
# NOT a re-ingest; passing the changed spec to `context ingest` first would
# corrupt the version history (see ASSURANCE-HANDBOOK.md §8 / §4 Stage 8).
#
# Expected outcome: exit 3. ARCHIVE rows (a requirement whose evidence
# decayed) are never applied headless, by design — the run stops with a
# stored plan for a human. That is success, not a failure, for this stage.
set -uo pipefail
cd "$(dirname "$0")/.."

source scripts/lib.sh
require_cmd kane-cli
require_cmd jq

RUN_DIR="run"
mkdir -p "$RUN_DIR"

NEW_SPEC="${NEW_SPEC:-sources/feature-spec-v2.md}"
SOURCE_ID="${SOURCE_ID:-feature-spec}"

summary ""
summary "## Requirements-change demo (\`maintain reconcile\`)"
summary ""
summary "Reconciling against \`$NEW_SPEC\` — do NOT read this as a normal pass/fail step;"
summary "exit 3 with a stored archive plan is the expected, correct outcome."
summary ""

out="$RUN_DIR/09-reconcile.ndjson"
err="$RUN_DIR/09-reconcile.stderr.log"
kane-cli maintain reconcile --from "$NEW_SPEC" --source-id "$SOURCE_ID" --mode agent 2> "$err" | tee "$out"
ex="$(kane_exit "$out")"

case "$ex" in
  0)
    summary "- \`maintain reconcile\`: applied cleanly, no archive decision pending"
    ;;
  3)
    plan=$(kane_field "$out" '.plan_path // .plan // empty')
    summary "- \`maintain reconcile\`: **paused at exit 3 — a human must confirm at least one archive.**"
    summary "  ${plan:+Stored plan: \`$plan\`}"
    summary "  This is the strongest moment in the demo — proven coverage is about to collapse"
    summary "  for the requirement(s) whose evidence no longer traces to a live source."
    ;;
  "")
    summary "- \`maintain reconcile\`: **no \`done\` event in the stream** — process may have crashed. See \`$(basename "$out")\`."
    dump_stderr_to_summary "$err" "maintain reconcile"
    ;;
  *)
    summary "- \`maintain reconcile\`: unexpected exit \`$ex\` — see \`$(basename "$out")\`"
    dump_stderr_to_summary "$err" "maintain reconcile"
    ;;
esac

echo "== cover gaps (post-reconcile) =="
kane-cli cover gaps --json > "$RUN_DIR/10-cover-post-reconcile.json" 2>/dev/null || true
kane-cli cover gaps > "$RUN_DIR/10-cover-post-reconcile.txt" 2>&1 || true

summary ""
summary "### Coverage after reconcile"
summary ""
summary '```'
summary "$(cat "$RUN_DIR/10-cover-post-reconcile.txt")"
summary '```'
summary ""
summary "Compare this against the \`cover gaps\` output earlier in the summary. A drop in"
summary "\`proven\` here — even with every test still passing — is the point: those tests were"
summary "proving a promise the product no longer makes."

echo "Reconcile stage complete (exit 3 is expected/success for this demo)."
exit 0
