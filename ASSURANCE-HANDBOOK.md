# Kane CLI Assurance — Media & Entertainment Demo Handbook

Adapted from LambdaTest/TestMu AI's [kanecli-assurance handbook](https://github.com/lambdapro/kanecli-assurance)
for a Media & Entertainment target (TMDB title discovery and trailer
playback) and extended with a fully automated GitHub Actions path. Read this
for the concepts; read `README.md` for how to actually run things in this
repo.

## 1. What you are demonstrating

Most test tooling answers *"did the tests pass?"* The assurance lifecycle
answers a harder question customers actually care about:

> **"What exactly is covered by our requirements, how do we know, and what is
> still owed?"**

The pitch in one line: **requirements go in, a reviewed and traceable test
suite comes out, and coverage is measured against the requirements — not
against the test count.**

### Assurance vs. `generate` — pick the right pipeline

| | `kane-cli generate` | **Assurance** (`context` / `design` / `cover` / `maintain`) |
|---|---|---|
| Input | a sentence or two of description | actual requirement documents — PRD, spec, Jira, Confluence |
| Output | quick scenario and case ideas | ACs → scenarios → one test per scenario, each tagged to what it verifies |
| Traceability | none | every claim cites a line range of the source |
| Human gates | none | two mandatory review checkpoints |
| Coverage | not measured | designed % × proven %, per use-case debt |
| Use when | brainstorming, quick smoke ideas | compliance, formal requirements, "prove it" conversations |

If a Media & Entertainment prospect has a PRD for a feature — a discovery
flow, a playback contract, a recommendations rule — and asks "how do we know
we tested the right things?", that is the assurance demo.

## 2. The loop

```
  requirement docs                          product changes
        │                                          │
        ▼                                          ▼
  context ingest ──► context extract ──► context review ──► design tests
  (snapshot the      (agent proposes       (CHECKPOINT 1:    (ACs, scenarios,
   source)            use-cases, cites      human promotes    one test per
                      every claim)          to trusted)       scenario)
                                                                   │
                                                                   ▼
  maintain ◄── cover ◄── testrun run ◄── testmd run ◄── context review
  reconcile   (designed   (batch replay    (author each      (CHECKPOINT 2:
  (a source    × proven    + evidence)      test once in      human approves
   changed)     + debt)                     a real browser)   the design)
```

**The two checkpoints are the whole point.** Nothing downstream is generated
until upstream artifacts have been reviewed.

### Command reference

| Stage | Command | Cost |
|---|---|---|
| Capture + Extract | `kane-cli context ingest <src> --mode agent` | credits |
| Inspect | `kane-cli context list --json --inferred` | free |
| Inspect one item | `kane-cli context explain <ref> --json` | free |
| **Checkpoint 1** | `kane-cli context review --verdicts <file> --json` | free |
| Design | `kane-cli design tests --use-case <ref> --mode agent\|ci --max 8` | credits |
| Why this test? | `kane-cli design explain <t-ref>` | free |
| **Checkpoint 2** | `kane-cli context review --verdicts <file> --json` | free |
| Author (once per test) | `kane-cli testmd run <file> --agent` | execution |
| Replay (from then on) | `kane-cli testrun run --match 't-'` | execution |
| Measure | `kane-cli cover gaps` | free |
| Requirements changed | `kane-cli maintain reconcile --from <new> --source-id <id> --mode agent` | credits |

Only **extract, design, and reconcile** call the service. Everything else is
local and free — a good thing to say out loud when a customer worries about
cost.

## 3. What's different about the Media & Entertainment version

The upstream handbook demos an e-commerce storefront (search → product →
add/remove cart). This repo swaps the target and the state-changing action
for one that fits a media catalogue and needs no login:

| | Upstream (e-commerce) | This repo (Media & Entertainment) |
|---|---|---|
| Target | LambdaTest e-commerce playground | [themoviedb.org](https://www.themoviedb.org/) |
| R1 | Search for a product | Search for a movie/show title |
| R2 | Open a product, see name + price | Open a title, see name + release year |
| R3 | Add to cart updates the header count | Play trailer opens the video player |
| R4 | Remove from cart empties it | Close trailer returns to the detail page |
| v2 change (for reconcile) | +result count, −remove-from-cart, +wishlist | +result count, −close-trailer, +cast list |

The requirement pattern — search → detail → a stateful action and its
inverse — is what makes the coverage story work (a designed/proven pair per
use-case). Swap `sources/feature-spec.md` for your own customer's actual PRD
before a real demo; TMDB is here so the workflow is runnable out of the box.

## 4. Three ways to run this

1. **GitHub Actions (`.github/workflows/kane-cli-assurance.yml`)** — fully
   non-interactive. Auto-approves both checkpoints on the assumption that the
   spec itself was reviewed via your normal PR process, runs design in
   `--mode ci` (fails closed on judgement calls instead of hanging), authors
   every generated test headless, and publishes coverage + evidence as
   workflow artifacts and a job summary. This is the "run it and get
   results" path — see `README.md`.
2. **Guided prompt (`prompts/guided-demo-prompt.md`)** — for a live customer
   call, driven by an agent (e.g. Claude Code with the kane-cli skill) that
   stops at both checkpoints and asks you. The pause **is** the demo.
3. **Autonomous prompt (`prompts/autonomous-demo-prompt.md`)** — an
   agent-driven run that takes over both checkpoints itself, for regression
   refreshes or pipeline demos where the agent should report rather than ask.

## 5. Known limitations — read before demoing

Documented honestly, same as the upstream handbook:

- **Gap detection is a tendency, not a guarantee.** Vague requirement words
  ("confirmation", "visible", "clearly") can become hard assertions when the
  agent doesn't ask.
- **Tests claim more than they machine-check.** A test can be tagged against
  several ACs while hard-asserting only one; the rest ride prose.
- **Ids and risk grades are not stable between runs.** Take use-case refs
  from `context list --json` — never assume `uc-1` is the same thing twice.
  The CI script in this repo does exactly that.
- **Windows needs a patch.** Published win32-x64 builds can ship mismatched
  CLI/agent contract digests (`PAIR_MISMATCH`), and a libuv teardown bug can
  collapse every exit code to 127 — parse `done.exit_code` from the NDJSON
  stream instead of `$?`. (The Linux GitHub Actions runner used here is not
  affected, but `scripts/lib.sh` parses `done.exit_code` anyway, for
  consistency with local Windows runs.)
- **`{{variables}}` can go unresolved specifically at the final verification
  checkpoint (kane-cli 0.8.12).** Action steps (e.g. "search for
  `{{x_search_term}}`") resolve correctly, but a verification step that
  compares against a variable (e.g. "assert the release year shows
  `{{x_expected_release_year}}`") can receive the literal, un-substituted
  `{{global.x_expected_release_year}}` string instead — which then fails to
  match the real page content, even though `--variables` was passed the
  documented `{"key": {"value": ...}}` shape with correct bare keys (no
  `global.` prefix — that's kane-cli's own internal rewrite, not something you
  add). This matches upstream report
  [LambdaTest/kane-cli#87](https://github.com/LambdaTest/kane-cli/issues/87).
  In this repo it shows up as the four "discover a title by search" tests
  failing at their final step while both "trailer" tests pass — the trailer
  tests' final assertions check page *state* ("a video player is visible")
  rather than comparing against a variable's value, so they don't hit the
  bug. There is no workaround available from the CI script side; a `proven`
  percentage below `designed` for UC-1 in this demo is this bug, not a
  product defect in TMDB. Re-check
  [kane-cli#87](https://github.com/LambdaTest/kane-cli/issues/87) for a fix
  before treating this stage as broken.

## 6. Troubleshooting

| Signal | Meaning | Do |
|---|---|---|
| **exit 3** | **paused and resumable — not a failure** | read `session_paused`, answer, resume with the verbatim command |
| `EXTRACT_LOCKED` (exit 2) | another store-mutating run is live | wait — never delete a lock file |
| `UC_UNREVIEWED` (exit 2) | designing against an unreviewed use-case | run the review command from `next` |
| `NO_STORE` | no `.context/` here | wrong directory, or ingest hasn't run yet |
| `CITE_UNVERIFIED` | a citation failed verification | report it; the item did not commit with bad provenance |
| `HIGH_RISK_CI` | a `--mode ci` run hit a judgement call | this is expected in CI — re-run locally with `--mode agent` to resolve it, then re-run the workflow |
| `missing_meta` from `testrun` | test was designed but never authored | `testmd run` it once first |
| `PAIR_MISMATCH` | CLI/agent contract digests differ (Windows) | reinstalling will not fix it; see upstream repo's Windows bugs report |

### Never do these on someone else's store

- hand-edit anything under `.context/`
- run two store-mutating commands concurrently
- delete a lock file
- pass `--allow-archive` without an explicit request and a reason
- `context retire` / `revert` / `rebuild` — destructive, explicit request only

## 7. Vocabulary

| Term | Meaning |
|---|---|
| **Source** | a requirement document snapshotted into the store |
| **Use-case** | a user goal extracted from the source, with cited evidence |
| **AC** | a specific verifiable criterion a test must prove |
| **Scenario** | one path through a use-case — happy, negative, or edge |
| **Test** | a runnable `*_test.md`, permanently tagged with the criteria it verifies |
| **derived / trusted / archived** | artifact states; generated content starts `derived` |
| **fresh / stale / orphaned** | whether an artifact still matches its source snapshot |
| **Gap** | a recorded, ranked missing piece — with a `ready_command` to close it |
| **Designed %** | share of live ACs that have a verifying test |
| **Proven %** | share of live ACs backed by the store's own recorded execution facts |
| **Evidence pack** | a sealed `.evidence` file that is proof of a coverage claim, produced per test run |
