# Kane CLI Assurance — Media & Entertainment

A runnable GitHub Actions workflow that drives [kane-cli](https://www.testmuai.com/support/docs/kane-cli-assurance/)'s
**assurance lifecycle** end to end — requirement capture, review, test
design, browser execution, and coverage measurement — with no human in the
loop, and publishes the coverage numbers and sealed evidence as workflow
results.

Target application: [themoviedb.org](https://www.themoviedb.org/) (title
search and trailer playback) — chosen because it needs no login, so the
whole pipeline runs unattended in CI. Swap `sources/feature-spec.md` for a
real Media & Entertainment customer's PRD when you're ready to demo against
their actual product.

Adapted from the upstream demo handbook: <https://github.com/lambdapro/kanecli-assurance>.
See `ASSURANCE-HANDBOOK.md` in this repo for the concepts and what changed
for this sector, and `prompts/` for the interactive (non-CI) way to run the
same lifecycle live in front of a customer.

## What you get

- `.github/workflows/kane-cli-assurance.yml` — the workflow. Trigger it by
  hand (**Actions → Kane CLI Assurance — Media & Entertainment → Run
  workflow**) or it runs automatically on any push that touches `sources/**`.
- A **job summary** on every run with what was extracted, what was
  auto-approved and why, every gap and warning from the design stage, each
  test's pass/fail with an evidence link where kane-cli provides one, and the
  `cover gaps` coverage table.
- A downloadable **artifact** (`kane-cli-assurance-evidence-<run>`)
  containing the raw NDJSON logs for every stage, the generated `*_test.md`
  files, the sealed evidence under `.testmuai/`, and a dated
  `ASSURANCE-RESULTS-<date>.md` report.
- An optional second stage — tick **"Also run the requirements-change
  demo"** when triggering the workflow by hand — that reconciles
  `sources/feature-spec-v2.md` against the original spec and shows proven
  coverage collapsing when a requirement's evidence decays. This is
  deliberately the strongest moment in the demo; see §4/§8 of
  `ASSURANCE-HANDBOOK.md`.

## Setup

1. **Push this repo to GitHub** (or upload these files into your own repo —
   see "Getting these files into your own repo" below).
2. **Add two repository secrets** — Settings → Secrets and variables →
   Actions → New repository secret:

   | Name | Value |
   |---|---|
   | `LT_USERNAME` | your LambdaTest / TestMu AI username |
   | `LT_ACCESS_KEY` | your access key — Dashboard → **Credentials** |

   `kane-cli login --username ... --access-key ...` is the non-interactive
   auth path the CLI documents specifically for CI runners.
3. **Confirm you have assurance credits.** `context extract`, `design
   tests`, and `maintain reconcile` are the only billed stages; a full run
   of this spec (4 requirements, `--max 4` per use-case) budgets well under
   100 credits. Check your balance at any time with `kane-cli balance`.
4. **Run it** — Actions tab → **Kane CLI Assurance — Media & Entertainment**
   → **Run workflow**.

## Running it locally first (recommended)

Rehearse once before you trust it in CI — extraction and design are
non-deterministic, so ids and gap counts will differ run to run:

```bash
npm install -g @testmuai/kane-cli@latest
kane-cli login --username "$LT_USERNAME" --access-key "$LT_ACCESS_KEY"
kane-cli whoami        # must say Authenticated
kane-cli balance       # confirm credits

MAX_DESIGN=4 TITLE_SEARCH_TERM=Inception bash scripts/run-assurance.sh
```

Results land in `run/` (gitignored): NDJSON logs per stage, `summary.md`,
and `ASSURANCE-RESULTS-<date>.md`. Generated tests land in
`.testmuai/tests/` (also gitignored — evidence and the content-addressed
store are meant to stay local/CI-artifact-only, never committed).

To try the requirements-change stage locally afterwards:

```bash
bash scripts/run-reconcile.sh
```

## How the CI script differs from a live demo

`scripts/run-assurance.sh` automates both review checkpoints — it approves
every use-case whose citation checks out, and every design artifact traced
to an approved use-case, the same auto-approval pattern kane-cli's own docs
use for their CI example. That's the right call for a pipeline that
re-derives tests from a spec that's already reviewed through your normal PR
process; it is **not** a substitute for a human reading a spec nobody has
looked at. For a live customer call, use the guided prompt in `prompts/`
instead — it stops and asks, because the checkpoint pausing *is* the pitch.

Design runs in `--mode ci`, which fails closed on judgement calls
(`HIGH_RISK_CI`) instead of pausing indefinitely — appropriate since nothing
is watching a CI job to answer a question. If a stage needs a human, the job
summary says so explicitly and points at the fix (usually: rerun that one
use-case locally with `--mode agent`, answer the question, then rerun the
workflow). The run doesn't hard-fail just because one use-case needs a
person — it keeps going and reports clearly, which is itself worth showing a
customer: the tool tells you what it doesn't know instead of guessing.

## Getting these files into your own repository

If you received this as a folder/zip rather than a git remote:

```bash
cd kanecli-assurance-media-entertainment
git init
git add .
git commit -m "Add kane-cli assurance workflow (Media & Entertainment)"
git branch -M main
git remote add origin https://github.com/<your-org>/<your-repo>.git
git push -u origin main
```

Then add the two secrets (above) and run the workflow from the Actions tab.

## Files

| Path | What it is |
|---|---|
| `.github/workflows/kane-cli-assurance.yml` | the GitHub Actions workflow |
| `scripts/run-assurance.sh` | ingest → review → design → review → author → measure, non-interactively |
| `scripts/run-reconcile.sh` | the optional requirements-change stage |
| `scripts/lib.sh` | shared helpers (NDJSON exit-code parsing, job-summary writer) |
| `sources/feature-spec.md` | the 4-requirement source spec — the only hand-written artifact |
| `sources/feature-spec-v2.md` | the changed spec used for the reconcile demo (+result count, −close-trailer, +cast list) |
| `verdicts/*.example.json` | example verdict files for the interactive prompts (refs are non-deterministic — the CI script builds its own at run time) |
| `prompts/guided-demo-prompt.md` | paste into an agent for a live, checkpoint-pausing demo |
| `prompts/autonomous-demo-prompt.md` | paste into an agent for an unattended, agent-approved run |
| `ASSURANCE-HANDBOOK.md` | the concepts, the command reference, and what's different about this sector |

## Sources

- [Kane CLI Assurance documentation](https://www.testmuai.com/support/docs/kane-cli-assurance/)
- [Kane CLI installation](https://www.testmuai.com/support/docs/kane-cli-installation/)
- [Kane CLI authentication](https://www.testmuai.com/support/docs/kane-cli-authentication/)
- [Upstream demo handbook](https://github.com/lambdapro/kanecli-assurance)
