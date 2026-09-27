---
name: oait-install
description: 'Install or set up OAIT (Oceanographic AI Toolkit) for working with CTD, ADCP, meteorological and Niskin bottle data. Use when the user says "install OAIT", "set up OAIT", or first asks to work with oceanographic instrument data and OAIT is not yet installed. Runs the onboarding: privacy gate, clone OAIT, install skills globally, create the data root and sensitivity register, configure ERDDAP servers, verify.'
---

# Install OAIT

Goal: OAIT working **once per machine**, available in **every** project. Run the steps in
order; resolve any blocker before moving on.

---

## Step 1 — Privacy gate (blocking once at install)

1. If `~/.oait/config.json` contains `privacy_onboarded_at`, onboarding is done; a short
   reminder is enough for a reinstall or repair.
2. Otherwise, try to determine whether model training / data retention is off for the agent
   you are. If you cannot verify it, do **not** assume it.
3. If unverified or on a consumer tier, say plainly:
   > "Model training has to be turned off before using OAIT with your data."
   Give agent-specific pointers to the provider's current privacy / data-controls page (menus
   change; don't assert exact paths). See [`../ocean-privacy/SKILL.md`](../ocean-privacy/SKILL.md).
4. **Gate on one explicit confirmation:** "I have turned off model training." In Claude Code,
   use a selection prompt; otherwise wait for an unambiguous yes.
5. Also confirm the user understands the **sensitivity register**: datasets under foreign-EEZ
   consent, from restricted areas, under PI embargo, or from partners will be registered and
   handled by their recorded conditions, and unregistered data are treated as restricted.
6. Record `privacy_onboarded_at` (date) and `privacy_onboarded_for` (agent / tier) in the
   config (Step 2.6).

---

## Step 2 — Locate or clone the OAIT repo

1. **Look for an existing install first**: `oait_path` in `~/.oait/config.json`; valid if it
   contains `AGENTS.md`, `CLAUDE.md`, and `skills/oait-install/SKILL.md`. If found, reuse it,
   report `git status --short --branch`, and skip cloning. Remove any accidental duplicate
   clone after checking it has no user changes.
2. **If not found, ask where to clone.** Suggest the user's usual code folder, or
   `~/Documents/OAIT` / `~/OAIT`.
3. **🔒 Never at a filesystem root or system directory** (`/`, `C:\`, `/usr`, `/opt`,
   `C:\Windows`, `C:\Program Files`). If the user insists, decline and propose a user-space
   path, explaining the permissions/security risk.
4. **Clone** (the repository is private; the user needs access):
   ```bash
   git clone https://github.com/niknikos/OAIT "<chosen-path>"
   git -C "<chosen-path>" config core.hooksPath .githooks
   ```
   The hook stamps the version **and refuses commits that contain data** — enable it.
5. **Install skills globally** (only for agents present on the machine):
   - macOS/Linux:
     ```bash
     mkdir -p ~/.claude/skills ~/.codex/skills
     cp -R "<oait_path>/skills/." ~/.claude/skills/
     cp -R "<oait_path>/skills/." ~/.codex/skills/
     ln -sfn "<oait_path>/oait-knowledge" ~/.claude/oait-knowledge
     ln -sfn "<oait_path>/oait-knowledge" ~/.codex/oait-knowledge
     ```
   - Windows (PowerShell; symlinks need Developer Mode or admin, otherwise copy and re-copy on
     every update):
     ```powershell
     New-Item -ItemType Directory -Force "$HOME/.claude/skills", "$HOME/.codex/skills" | Out-Null
     Copy-Item -Recurse -Force "<oait_path>/skills/*" "$HOME/.claude/skills/"
     Copy-Item -Recurse -Force "<oait_path>/skills/*" "$HOME/.codex/skills/"
     New-Item -ItemType SymbolicLink -Force -Path "$HOME/.claude/oait-knowledge" -Target "<oait_path>/oait-knowledge"
     New-Item -ItemType SymbolicLink -Force -Path "$HOME/.codex/oait-knowledge" -Target "<oait_path>/oait-knowledge"
     ```
   Skills reference `../../oait-knowledge/`. The link name is deliberately **not**
   `knowledge`, which BAIT uses; do not overwrite BAIT's link.
6. **Record the install** in `~/.oait/config.json` (merge, don't clobber). Full schema in
   [`../../oait-knowledge/connection.md`](../../oait-knowledge/connection.md):
   ```json
   { "oait_path": "<chosen-path>",
     "data_root": "~/OAIT_data",
     "store_path": "~/OAIT_data/store/oait.duckdb",
     "register_path": "~/OAIT_data/registry/datasets.yaml",
     "erddap_cache": "~/OAIT_data/cache/erddap",
     "erddap_servers": [],
     "privacy_onboarded_at": "<YYYY-MM-DD>",
     "privacy_onboarded_for": "<agent-or-tier>",
     "skills_synced_to": ["~/.claude/skills"],
     "installed": "<YYYY-MM-DD>" }
   ```
   On Windows use explicit `%USERPROFILE%`-based absolute paths.
7. Save to your own long-term memory that OAIT lives at `<chosen-path>` and what it is for.

---

## Step 3 — Create the data root and the register

1. **Ask where the data root should live.** Default `~/OAIT_data/`
   (`%USERPROFILE%\OAIT_data\` on Windows). Same location rules as Step 2. Recommend **not**
   a cloud-synced folder (Dropbox, OneDrive, iCloud) unless the institution has approved it
   for this data — sync services copy files off the machine.
2. Create the layout:
   ```bash
   mkdir -p ~/OAIT_data/{raw,store/adcp,cache/erddap,registry}
   ```
3. Create an empty register `registry/datasets.yaml` with a header comment explaining that it
   must never be committed. Offer to register the user's first datasets now
   ([`../ocean-privacy/SKILL.md`](../ocean-privacy/SKILL.md) → "Registering a dataset").
4. If the user already has raw files elsewhere, **do not move them without asking**. Offer to
   copy (not move) them into `raw/<cruise-or-deployment>/<instrument>/`, preserving the
   originals until the user is satisfied.

---

## Step 4 — Configure ERDDAP servers (optional)

1. Ask for the institutional ERDDAP base URL(s) (ending in `/erddap/`), and whether any
   datasets need a login.
2. Add them to `erddap_servers` in the config as `{name, url, auth}`, where `auth` is `none`
   or a short description of the method. **Never store credentials in the config.** If a
   login is needed, help the user put it in `~/.Renviron` or the OS keychain.
3. Test with a metadata-only call:
   ```r
   rerddap::ed_datasets(url = "<server-url>") |> nrow()
   ```

---

## Step 5 — Verify

```r
source_cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))
stopifnot(dir.exists(path.expand(source_cfg$data_root)))
pkgs <- c("tidyverse", "DBI", "duckdb", "arrow", "oce", "gsw", "rerddap", "yaml", "jsonlite", "digest")
setdiff(pkgs, rownames(installed.packages()))   # install anything listed
```

If the store does not exist yet, that is expected: it is built by
[`../ocean-ingest/SKILL.md`](../ocean-ingest/SKILL.md) on the first ingest.

## Done

Summarise: where OAIT is; that skills are installed globally; where the data root and
register are; which ERDDAP servers are configured; and that updates go through
[`../oait-update/SKILL.md`](../oait-update/SKILL.md).
