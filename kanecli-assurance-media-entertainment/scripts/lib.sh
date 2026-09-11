#!/usr/bin/env bash
# Shared helpers for the kane-cli assurance CI scripts.
# Source this file; do not execute it directly.

# kane_exit <ndjson-file>
# Reads the exit code out of the last {"type":"done",...} event in an NDJSON
# stream instead of trusting $?. kane-cli's own docs call this out as
# necessary on Windows (a libuv teardown bug collapses every real exit code
# to 127 there) and it is good practice everywhere else too, since the
# assurance commands use exit codes as part of their control flow:
#   0 = success · 2 = refusal (see done.next for the fix) · 3 = paused/resumable
kane_exit() {
  local file="$1"
  grep '"type":"done"' "$file" | tail -1 | jq -r '.exit_code // empty'
}

# kane_field <ndjson-file> <jq-filter>
# Convenience wrapper to pull one field out of the last done event.
kane_field() {
  local file="$1" filter="$2"
  grep '"type":"done"' "$file" | tail -1 | jq -r "$filter // empty"
}

# summary <markdown-line...>
# Appends to both the local run log and (when present) the GitHub Actions
# job summary, so results are visible in the Actions UI without opening
# artifacts.
summary() {
  echo -e "$*" | tee -a "${RUN_DIR:-.}/summary.md" >/dev/null
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo -e "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# require_cmd <name>
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "::error::required command '$1' not found on PATH" >&2; exit 1; }
}

# best_effort_evidence_link <ndjson-file>
# kane-cli's `testmd run` / `testrun run` output can include a shareable
# KaneAI dashboard link for the sealed evidence pack. The exact JSON key
# isn't documented, so this scans defensively for anything link-shaped
# rather than assuming one field name. Never fatal — evidence still lives
# in the uploaded artifacts either way.
best_effort_evidence_link() {
  local file="$1"
  grep -Eo 'https://test-manager\.[a-zA-Z0-9./_?=&%:-]+' "$file" 2>/dev/null | tail -1 || true
}

# capture_kane_trace_logs
# kane-cli writes detailed per-command trace logs under
# ~/.testmuai/kaneai/assurance/*/logs/*.log regardless of what it prints to
# stdout/stderr (see the "trace" field on every run_start event) — these are
# far more likely to explain a silent crash than the terminal output. Copy
# ONLY *.log files that live under a "logs/" directory, never the rest of
# ~/.testmuai (which can hold local auth/session state) — this repo is
# public and the artifact must never carry credentials.
capture_kane_trace_logs() {
  local dest="${RUN_DIR:-run}/kane-trace-logs"
  mkdir -p "$dest"
  find "$HOME/.testmuai" -type f -path '*/logs/*.log' 2>/dev/null | while IFS= read -r f; do
    cp "$f" "$dest/$(echo "$f" | sed "s#^$HOME/##; s#/#__#g")" 2>/dev/null || true
  done
}

# dump_stderr_to_summary <stderr-file> <label>
# When a stage fails without a clean `done` event, the NDJSON file alone
# doesn't explain why — kane-cli's actual error usually lands on stderr.
# Fold it straight into the job summary so it's visible without downloading
# the artifact.
dump_stderr_to_summary() {
  local file="$1" label="$2"
  if [ -s "$file" ]; then
    summary ""
    summary "<details><summary>stderr — $label</summary>"
    summary ""
    summary '```'
    summary "$(cat "$file")"
    summary '```'
    summary "</details>"
  fi
}
