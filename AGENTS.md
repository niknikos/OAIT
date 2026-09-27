# AGENTS.md — OAIT (Oceanographic AI Toolkit)

You are helping a scientist work with **oceanographic observation data** through **OAIT**, a
knowledge pack for heterogeneous instrument data: **Sea-Bird CTD** profiles, **Teledyne RDI
ADCP** current profiles, **meteorological station** records, and **Niskin bottle** samples,
held either in a **local archive and store** on the user's machine or on an **institutional
ERDDAP server**. You write **R** using **tidyverse** syntax: `oce` and `gsw` for instrument
formats and TEOS-10, ggplot2 for figures, ggOceanMaps/leaflet for maps.

> This is the entry point for **Codex, Cursor, Gemini CLI, and other agents**. Claude Code
> reads the equivalent guidance in [`CLAUDE.md`](CLAUDE.md). Keep substantive guidance in
> sync while preserving agent-specific links and setup notes.
>
> Agents without `.claudeignore` support: treat [`.claudeignore`](.claudeignore) as your
> do-not-read list — never open raw instrument files, the store, or the register unless the
> user points you at a specific file.

---

## ⛔ PRIVACY AND SENSITIVITY — non-negotiable, keep in mind on every task

Oceanographic data are often destined for open archives, but **not yet, not all of them, and
not on the agent's initiative.** Four categories need particular care: data collected under
**foreign-EEZ research consent**, data from **restricted or military areas**, **unpublished
data under PI embargo**, and **partner / third-party data** under agreement. **The whole point
of OAIT is that raw data never leaves the user's machine, and that release decisions stay with
people.**

1. **Never upload, paste, or transmit raw data** to any external service, API, or web tool.
   That includes pasting rows, profiles, or file contents into a chat that reaches a model
   provider. Querying the user's own configured ERDDAP server is permitted; sending data *to*
   anything else is not.
2. **Data are not in this repo and must never be copied here.** The data root lives outside
   the repo at `~/OAIT_data/` (`%USERPROFILE%\OAIT_data\` on Windows): `raw/` (untouched
   instrument files), `store/` (the queryable DuckDB + Parquet store), `cache/erddap/`, and
   `registry/` (the sensitivity register). Reference them by path from `~/.oait/config.json`.
3. **Never write raw records, profiles, or precise positions** into any file that gets
   committed (cookbook, examples, docs, commit messages). Recipes use *code*, not data — and
   rounded/synthetic values when an example value is needed.
4. **Check the sensitivity register before producing any output.** Every dataset has an entry
   in `registry/datasets.yaml` with a `share_level` and flags for EEZ consent, restricted area,
   embargo, and partner agreement. **An unregistered dataset is treated as `restricted`** until
   the user registers it. Rules per category are in
   [`oait-knowledge/sensitivity.md`](oait-knowledge/sensitivity.md).
5. **Default to derived outputs, and degrade positions.** Aggregates, climatologies, model
   fits and figures are generally shareable *within the dataset's share level*; raw records and
   exact positions are not. For restricted-area data, **ask before producing anything
   position-bearing at all** — even a rounded position or a section plot can be sensitive.
6. **Embargo applies to derived products too.** A figure or mean from embargoed data is still
   embargoed unless the PI has agreed otherwise.
7. **Remind the user about model training, but don't re-gate every query.** Training /
   data-retention is a **one-time onboarding check** handled by
   [`oait-install`](skills/oait-install/SKILL.md) and recorded in `~/.oait/config.json`
   (`privacy_onboarded_at`). If that marker exists, **do not block routine local work** on a
   fresh confirmation. See [`skills/ocean-privacy`](skills/ocean-privacy/SKILL.md).
8. **Never store credentials in the repo.** ERDDAP logins/tokens live in the user's
   `~/.Renviron` or OS keychain, never in config files you commit or in chat.

If a request would breach any of the above, stop and explain rather than comply.

---

## What OAIT is

A vendor-neutral knowledge pack — **not** a trained model. Nothing about the user's data
enters a model's weights. You learn the formats and conventions by *reading this repo at
runtime*. The repo is the memory; it grows as users contribute recipes.

## Working across projects (important)

OAIT is installed **once per machine** and used in **every** project — not cloned into each
repo. `oait-install` saves OAIT's location to `~/.oait/config.json` and, where supported,
copies the skills to the agent's user-level skills folder (`~/.codex/skills/` for Codex;
`~/.claude/skills/` for Claude Code) and links the shared knowledge as `oait-knowledge` beside
it (a distinct name, so it never collides with BAIT's `knowledge` link). Other agents can read
skills from the saved `oait_path` through project/agent instructions.

- **Trigger:** whenever a task involves CTD, ADCP, Niskin/bottle, met-station, ERDDAP, or
  other oceanographic observation data, reach for the `ocean-*` skills.
- **If OAIT isn't installed yet** (e.g. the user says *"install OAIT"*), run
  [`oait-install`](skills/oait-install/SKILL.md) first. If you cloned the repo before finding
  an existing `~/.oait/config.json`, reuse the configured install and clean up the duplicate
  after verifying it has no user changes.
- **Stay current (best-effort, at most once a day).** The first time you reach for an
  `ocean-*` skill in a session, read `oait_path` from `~/.oait/config.json` (skip silently if
  absent). If `~/.oait/.last-update-check` is under ~24 h old, skip; otherwise write the
  current time to it, `git -C "<oait_path>" fetch`, and compare `HEAD` with `@{u}`. If behind,
  tell the user once they can run [`oait-update`](skills/oait-update/SKILL.md). **Only report
  — never pull automatically.** Offline or any error → skip silently.
- **🔒 Never install OAIT or the data root at a filesystem root / system directory** (`/`,
  `C:\`, …), nor inside a cloud-synced folder, unless the user's institution explicitly
  approves that folder for this data. If asked, refuse and suggest a safe user-space location.

## How to work — capability router

Pick the matching skill and read it before acting. Skills link into `oait-knowledge/` for the
shared source of truth.

| If the user wants to… | Read |
|---|---|
| Install / set up OAIT (clone, skills, data root, register, verify) | [`skills/oait-install`](skills/oait-install/SKILL.md) |
| Update OAIT (git pull + re-sync skills) | [`skills/oait-update`](skills/oait-update/SKILL.md) |
| Handle data safely, register a dataset, decide what can be shared | [`skills/ocean-privacy`](skills/ocean-privacy/SKILL.md) |
| Connect to the local store or an ERDDAP server from R | [`skills/ocean-connect`](skills/ocean-connect/SKILL.md) |
| Bring new raw files into the store (CTD, ADCP, met, bottle) | [`skills/ocean-ingest`](skills/ocean-ingest/SKILL.md) |
| Answer a data question ("deepest cast on cruise X?", "mean SST at station Y") | [`skills/ocean-query`](skills/ocean-query/SKILL.md) |
| Process / QC / plot CTD profiles, T–S diagrams, sections, mixed-layer depth | [`skills/ocean-ctd`](skills/ocean-ctd/SKILL.md) |
| Process / QC ADCP currents (moored, vessel-mounted, lowered) | [`skills/ocean-adcp`](skills/ocean-adcp/SKILL.md) |
| Work with meteorological station or ship-met records | [`skills/ocean-met`](skills/ocean-met/SKILL.md) |
| Work with Niskin bottle samples, or calibrate CTD sensors against them | [`skills/ocean-bottle`](skills/ocean-bottle/SKILL.md) |
| Make a station map, cruise track, or section plot | [`skills/ocean-maps`](skills/ocean-maps/SKILL.md) |

If BAIT is also installed, its `quarto-reporting` and `r-package-setup` skills apply here
too; OAIT does not duplicate them.

## Before answering any data question

1. Read [`oait-knowledge/sensitivity.md`](oait-knowledge/sensitivity.md) and look up the
   dataset(s) in the register. Unregistered → treat as `restricted` and ask.
2. Read [`oait-knowledge/connection.md`](oait-knowledge/connection.md) — always connect
   read-only, query lazily with `dplyr::tbl()`, and `collect()` only at the end. **Filters on
   nullable columns must state what missing means** (`is.na(x) | !x %in% ...`): a lazy
   `!x %in% ...` runs as SQL `NOT IN` and silently drops every `NULL` row.
3. Read [`oait-knowledge/data-model.md`](oait-knowledge/data-model.md) — the store's tables and
   how they relate (casts → profiles → bottles; deployments → ADCP ensembles; stations → met).
4. Use [`oait-knowledge/variables.md`](oait-knowledge/variables.md) to translate plain-English
   terms into column names **and units**. Don't guess column names; don't mix practical
   salinity (PSS-78) with Absolute Salinity (TEOS-10), or pressure with depth.
5. Before any quantitative result, read
   [`oait-knowledge/quality-control.md`](oait-knowledge/quality-control.md) and decide which QC
   flags you accept. State that choice in the answer.
6. For raw-format questions, read the matching file in
   [`oait-knowledge/formats/`](oait-knowledge/formats/).
7. Check [`cookbook/`](cookbook/) — a recipe may already exist; adapt it.
8. **Query within memory limits** — ADCP and met series are large. Aggregate/filter in DuckDB
   and `collect()` only the small final result. See
   [`oait-knowledge/performance.md`](oait-knowledge/performance.md).
9. **Sanity-check extremes** — the single `max()` of a sensor record is usually a spike, a
   bad scan, or a unit slip. Pull the top ~10, check them against physical bounds and
   neighbours, and report the largest *plausible* value, flagging the rest.

## Which version of OAIT is this?

`VERSION` at the repo root holds the current version and date, stamped automatically by the
`.githooks/pre-commit` hook (see [`CONTRIBUTING.md`](CONTRIBUTING.md)). The same hook runs
[`scripts/check-no-data.sh`](scripts/check-no-data.sh), which refuses to commit data.

## Learning loop

After you solve a task that **isn't** already in `cookbook/`, *offer* to save it as a recipe
(copy [`cookbook/_TEMPLATE.md`](cookbook/_TEMPLATE.md), fill it in, propose it to the user).
Models do not learn between sessions — *this repo* is how knowledge persists.

## House style

- tidyverse, not base R, for data manipulation. `|>` or `%>%` (match the user's file).
- `oce` objects stay inside the reading/processing step; convert to tibbles at the boundary.
- TEOS-10 via `gsw` for derived quantities; report which salinity/temperature scale you used.
- ggplot2 with `theme_bw()`; depth/pressure axes reversed (`scale_y_reverse()`).
- Times in UTC, stored as POSIXct; say so when you show them.
- Comment density and naming should match the surrounding script you're editing.
