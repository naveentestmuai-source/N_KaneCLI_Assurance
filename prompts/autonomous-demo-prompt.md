# Autonomous demo prompt

Use this for an unattended agent-driven run (pipeline demos, regression
refreshes) rather than the GitHub Actions workflow — it grants the
auto-approval that the guided prompt withholds. Read the guardrail table at
the bottom before using it live.

---

> Run the full kane-cli assurance lifecycle autonomously in this repository
> from `sources/feature-spec.md`, targeting themoviedb.org (TMDB). Do not
> stop to ask me anything.
>
> **I explicitly authorize you to take over every acceptance decision in this
> workflow — every review checkpoint, every pause question, every gap
> answer, every confirmation prompt — and to answer them yourself using the
> recommended option. Do not hand any of them back to me.** Enumerate
> everything you accepted, and on whose recommendation, in your final
> summary — and still surface every warning, gap, and conflict you hit.
>
> - Ingest and extract, then approve all use-cases whose claims are properly
>   cited to the source. Reject nothing — if a use-case looks wrong, leave it
>   `skipped` and tell me why.
> - Design tests for **every** trusted use-case, one at a time, `--max 4`
>   each. Never run two store-mutating commands concurrently.
> - **Take use-case refs from `context list --json`, never from a guessed
>   `uc-N` pattern.**
> - **Approve every newly-minted use-case before designing it.** `design
>   tests` refuses unreviewed targets (`UC_UNREVIEWED`, exit 2).
> - Approve the design output, then author each new test once with
>   `testmd run --agent --headless`. For any `{{variable}}` the design left
>   open, pick a value that is known-good for TMDB (e.g. `Inception`,
>   `The Matrix`) and record which value you chose and why.
> - If any command pauses (exit 3 / `session_paused`), read the pending
>   question, answer it yourself using the recommended option, and resume
>   with the verbatim resume command. Never drop a pause.
> - Never pass `--allow-archive`, never `--force` a redesign, never delete a
>   lock file, and never run a destructive `context retire` / `revert` /
>   `rebuild`.
> - Stop immediately and report if credits exceed 250, if a paid turn
>   errors, or if a citation fails verification (`CITE_UNVERIFIED`).
> - Then run `cover gaps --mode agent` and record the designed × proven
>   numbers.
> - **If I have given you a changed version of the spec**
>   (`sources/feature-spec-v2.md`), finish by running `maintain reconcile
>   --from sources/feature-spec-v2.md --source-id feature-spec --mode agent`.
>   Do **not** `context ingest` the new file first. Expect it to end at
>   exit 3 with an archive decision stored for a human: report the plan path
>   and stop there. Never pass `--apply` or `--allow-archive` yourself. Then
>   re-run `cover gaps` and tell me how the proven number moved.
> - Finish by writing a dated run report to `ASSURANCE-RESULTS-<date>.md`
>   containing: what was extracted, what you approved and why, every gap and
>   warning, the test results with evidence links, the final designed ×
>   proven numbers, and the total credits.

---

### The guardrails, and why each is there

| Guardrail | Reason |
|---|---|
| explicit approval grant | without it, an agent following the skill correctly will stop and wait forever |
| "reject nothing, use `skipped`" | rejections create `pending_archive` facts; skips leave no trace and stay queued |
| one design at a time | the store is single-writer — concurrency gets you `EXTRACT_LOCKED`, exit 2 |
| answer pauses, never drop them | a dropped pause silently abandons a 24h session and the work already paid for |
| no `--allow-archive` / `--force` / lock deletion | the destructive verbs; they need a human's explicit request every time |
| credit ceiling + no auto-retry | design has **no spend cap** — `--max` limits deliverable size, not credits |
| record the variable value chosen | otherwise the gap is silently closed by a guess |

For the version of this same idea that runs on a schedule with no agent
in the loop at all, see `.github/workflows/kane-cli-assurance.yml`.
