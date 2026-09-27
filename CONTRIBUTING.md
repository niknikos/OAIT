# Contributing to OAIT

OAIT improves each time someone solves a new problem with their agent and saves the
solution as a recipe. This file explains how to do that without putting data at risk.

## ⛔ The one hard rule

**Never commit data.** No raw instrument files, no processed profiles or time series, no real
station or track coordinates, no lab result sheets, no register entries, no screenshots of
data tables or maps of restricted areas. Recipes contain *code and prose*, plus rounded or
synthetic example values where needed.

Three nets enforce this — please keep all three:

1. `.gitignore` blocks instrument, container, tabular and figure formats.
2. The **pre-commit hook** runs [`scripts/check-no-data.sh`](scripts/check-no-data.sh) on
   what you stage (data extensions, data-like folders, files over 300 KB).
3. The **Data guard** GitHub Action runs the same check on every push and pull request.

If the guard refuses a file that is genuinely not data (e.g. a small logo), add its path to
`.data-guard-allow` and explain why in the commit message.

## Enable the hook once per clone

```bash
git config core.hooksPath .githooks
```

## Adding a cookbook recipe

1. Copy [`cookbook/_TEMPLATE.md`](cookbook/_TEMPLATE.md) to `cookbook/<short-slug>.md`.
2. Fill in the questions it answers, the approach, the **register check** (which conditions
   matter for its output), the code, and the *shape* of the expected output.
3. Set `status: draft` until the code has been run on real files; then
   `status: validated (<who>, <date>, <OAIT version>)`.
4. If the recipe is runnable end-to-end, add the matching script to [`examples/`](examples/)
   with the same slug.
5. Follow house style: tidyverse, read-only DuckDB, lazy `tbl()` + late `collect()`, real
   column names from [`oait-knowledge/variables.md`](oait-knowledge/variables.md), explicit QC
   choice, UTC times.

### Letting your agent draft it

After your agent solves something new, say *"save this as an OAIT recipe."* It copies the
template, fills it in, and shows you the draft. **You review it** — in particular that no real
values, positions or dataset names that are themselves sensitive have slipped in.

## Improving skills or knowledge

- `skills/*/SKILL.md` — keep procedures short; link to `oait-knowledge/` rather than
  duplicating it.
- `oait-knowledge/` — the shared source of truth. When a change alters the store schema
  (`data-model.md`), bump the **minor** version and say in the commit message which tables
  need rebuilding.
- Keep [`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) in sync — they are intentionally
  near-identical so every agent gets the same guardrails.

## Versioning

`VERSION` is stamped by the pre-commit hook: the **patch** level bumps on each commit and the
date is refreshed. Bump **minor** (new skills, schema changes) or **major** (changes that
break existing installs) by editing `VERSION` before committing; the hook keeps a hand-set
version.

## Style

- Markdown wrapped at ~95 columns.
- R: tidyverse, meaningful names, comments matching the surrounding density.
- One logical change per pull request; describe *why*, not only *what*.
