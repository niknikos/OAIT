# 🌊 OAIT — Oceanographic AI Toolkit

<!-- version -->**Version 0.1.0** (2026-09-27)<!-- /version -->

**Teach your AI coding agent to work with oceanographic instrument data — safely, on your own
machine.**

OAIT is a knowledge pack that turns a general coding agent (Claude Code, Codex, Cursor, …)
into a competent assistant for heterogeneous oceanographic observations:

- **Sea-Bird CTD** profiles (`.hex`/`.xmlcon` archived; `.cnv`/`.btl` ingested),
- **Teledyne RDI ADCP** currents (moored PD0, VmDas vessel-mounted, lowered),
- **meteorological station** and ship-met records (Campbell TOA5, vendor CSV, ship logs),
- **Niskin bottle** samples and laboratory results (salinity, oxygen, nutrients, chl-a).

Install it and your agent can:

1. **Organise** raw files into a local archive that is never modified, and **ingest** them
   into a queryable DuckDB + Parquet store with provenance (file hash for every row).
2. **Connect** read-only to that store, or to an **institutional ERDDAP** server, from R using
   tidyverse syntax.
3. **Answer data questions** — *"What was the deepest cast on cruise X?"*, *"Mean near-bottom
   temperature at station S03 by year"*, *"Strongest current at the mooring, sanity-checked."*
4. **Process and QC** each instrument type: TEOS-10 conversions, T–S diagrams, mixed-layer
   depth, ADCP coordinate transforms and side-lobe screening, true wind from ship data,
   bottle–CTD calibration checks.
5. **Map** stations and tracks — only as far as each dataset's conditions allow.

> **It is not a trained model.** Your data are never sent anywhere and never enter any model's
> weights. The agent simply *reads this repo* while it helps you. OAIT follows the design of
> [BAIT](https://github.com/DeepWaterIMR/BAIT), the Biotic AI Toolkit, and can be installed
> alongside it.

## 🔒 Privacy and sensitivity first

Oceanographic data are often meant to become open — but not all of them, not yet, and not on
an agent's initiative. OAIT is built so that **raw data stay on your computer** and **release
decisions stay with the people entitled to make them**:

- OAIT contains **instructions only — never data**. `.gitignore`/`.claudeignore` block
  instrument, container and tabular formats, and a **data guard** (pre-commit hook + CI)
  refuses any commit that stages data-like files.
- Data live **outside** this repo, in `~/OAIT_data/` (`raw/`, `store/`, `cache/erddap/`,
  `registry/`).
- A local **sensitivity register** records, per dataset, the conditions that apply:
  **foreign-EEZ research consent**, **restricted or military areas**, **PI embargo**, and
  **partner / third-party agreements**. The agent checks it before producing any output,
  treats unregistered data as restricted, and asks before producing anything position-bearing
  from restricted data. See [`oait-knowledge/sensitivity.md`](oait-knowledge/sensitivity.md).
- During setup, **turn off model training / data retention** for your agent once — OAIT walks
  you through it and records it ([`skills/ocean-privacy`](skills/ocean-privacy/SKILL.md)).

## 🚀 Quickstart

1. **Get an agent**: [Claude Code](https://claude.com/claude-code), Codex, etc.
2. **Tell your agent:**
   ```
   install https://github.com/niknikos/OAIT
   ```
   The agent runs [`oait-install`](skills/oait-install/SKILL.md): a one-time **model training
   is off** check → cloning OAIT → installing the skills **globally** → creating the data root
   and register → configuring your ERDDAP server(s) → verifying.
3. **Register and ingest a first dataset**: *"Register the CTD data from cruise X and ingest
   it."*
4. **Ask away**: *"T–S diagram for cruise X"*, *"How well do the bottle salinities agree with
   the CTD?"*

Installed **once per machine**, then available in all your projects. Keep it current with
*"update OAIT"* ([`oait-update`](skills/oait-update/SKILL.md)).

## 🗂️ What's inside

| Folder | What it holds |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) | Agent entry points (identity + guardrails + router) |
| [`skills/`](skills/) | One skill per capability — install, privacy, connect, ingest, query, CTD, ADCP, met, bottle, maps |
| [`oait-knowledge/`](oait-knowledge/) | Vendor-neutral reference: sensitivity, data model, connection, ERDDAP, variables, QC, performance, instrument formats |
| [`cookbook/`](cookbook/) | Question → code recipes (grows over time) |
| [`examples/`](examples/) | Runnable `.R` scripts, added once recipes are validated on real files |
| [`scripts/`](scripts/) | Maintenance scripts, including the data guard |

The knowledge folder is called `oait-knowledge/` rather than `knowledge/` so that its global
link never collides with BAIT's.

## 🧭 Status

Version 0.1 is a **scaffold**: the structure, guardrails, knowledge base and skills are in
place, and the cookbook recipes are marked `status: draft` because they have **not yet been
run against real files**. The priorities for the next versions are:

1. Validate the ingest routines on real `.cnv`, `.btl`, PD0/VmDas and met files, and move the
   validated code into `examples/`.
2. Settle the QC thresholds used by the programme(s) OAIT serves, and record them in
   `oait-knowledge/quality-control.md`.
3. Confirm the sensitivity categories and defaults with the institution's data manager.

## 🧠 It learns from you

When you ask something new, the agent offers to save the solution as a cookbook recipe. You
review it — especially that no data leaked in — and commit it. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## 🙋 Contact

Maintainer: Nikolaos Nikolioudakis ([@niknikos](https://github.com/niknikos)).
