# Connecting: the local store and ERDDAP

Two connection modes, one set of habits: **read-only, lazy, collect late, and know which
datasets you are touching** (so the register can be applied).

## Configuration

`~/.oait/config.json` (written by `oait-install`):

```json
{
  "oait_path": "~/Documents/OAIT",
  "data_root": "~/OAIT_data",
  "store_path": "~/OAIT_data/store/oait.duckdb",
  "register_path": "~/OAIT_data/registry/datasets.yaml",
  "erddap_cache": "~/OAIT_data/cache/erddap",
  "erddap_servers": [
    {"name": "institute", "url": "https://erddap.example.org/erddap/", "auth": "none"}
  ],
  "privacy_onboarded_at": "YYYY-MM-DD",
  "privacy_onboarded_for": "<agent-or-tier>",
  "skills_synced_to": ["~/.claude/skills", "~/.codex/skills"],
  "installed": "YYYY-MM-DD"
}
```

On Windows store absolute `%USERPROFILE%`-based paths rather than `~`, because R can expand
`~` to the (possibly OneDrive-redirected) Documents folder.

Read it from R:

```r
oait_config <- function() {
  f <- if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("USERPROFILE"), ".oait", "config.json")
  } else {
    path.expand("~/.oait/config.json")
  }
  if (!file.exists(f)) stop("OAIT is not installed: ", f, " not found. Run oait-install.")
  cfg <- jsonlite::read_json(f)
  expand <- function(p) if (is.character(p)) path.expand(p) else p
  purrr::modify_at(cfg, c("data_root", "store_path", "register_path", "erddap_cache"), expand)
}
cfg <- oait_config()
```

## Mode 1 — the local store (DuckDB + Parquet)

```r
library(tidyverse); library(DBI); library(duckdb)

con <- DBI::dbConnect(duckdb::duckdb(), dbdir = cfg$store_path, read_only = TRUE)

datasets        <- tbl(con, "datasets")
ctd_casts       <- tbl(con, "ctd_casts")
ctd_profiles    <- tbl(con, "ctd_profiles")
bottles         <- tbl(con, "bottles")
bottle_analyses <- tbl(con, "bottle_analyses")
met_stations    <- tbl(con, "met_stations")
met             <- tbl(con, "met")
adcp_deployments <- tbl(con, "adcp_deployments")

# ADCP ensembles live in partitioned Parquet next to the database. Query them lazily
# without creating anything in the (read-only) database:
adcp_glob <- file.path(dirname(cfg$store_path), "adcp", "*", "*.parquet") |>
  normalizePath(winslash = "/", mustWork = FALSE)
adcp <- tbl(con, sql(glue::glue(
  "SELECT * FROM read_parquet('{adcp_glob}', hive_partitioning = true)"
)))
```

**Rules**

- Always `read_only = TRUE`. Only `ocean-ingest` opens the store for writing, and it does so
  with no other connection open.
- Build queries lazily; `collect()` only the final, reduced result. Never `collect()` a whole
  table — `met` and `adcp` run to many millions of rows.
- **Missing values in filters.** A lazy `!x %in% c(...)` becomes SQL `NOT IN`, which drops
  `NULL` rows; after `collect()` the same R code keeps them. Say what missing means:
  `filter(is.na(temperature_qc) | !temperature_qc %in% c(3, 4))`.
- **Join the register fields early** (`left_join(datasets, by = "dataset_id")`) so share level
  and restricted-area flags travel with the rows you produce.
- `DBI::dbDisconnect(con, shutdown = TRUE)` when done. A lingering connection blocks ingest.

## Mode 2 — ERDDAP (read-only, cached)

```r
library(rerddap)

server <- purrr::detect(cfg$erddap_servers, \(s) s$name == "institute")$url

# Keep ERDDAP's cache inside the data root, not in a default user-cache folder that might be
# synced or backed up elsewhere. (Check ?rerddap::cache_setup for your installed version.)
rerddap::cache_setup(full_path = cfg$erddap_cache)

# 1. Discover
rerddap::ed_search(query = "CTD", url = server)          # candidate datasets
meta <- rerddap::info("<datasetID>", url = server)        # variables, units, attributes
meta$variables                                            # read before choosing fields

# 2. Retrieve a subset — constrain on the server, not after download
ctd <- rerddap::tabledap(
  meta,
  fields = c("time", "latitude", "longitude", "depth", "sea_water_temperature"),
  "time>=2025-01-01", "time<2025-02-01",
  url = server
) |>
  as_tibble()
```

**Rules**

- **Constrain on the server** (time, bounding box, variables). Pulling a whole dataset to
  filter in R is slow for everyone and puts more data on disk than needed.
- **Units and names come from the server**: read `info()`; rename explicitly to OAIT names
  (see [`variables.md`](variables.md)) and convert units deliberately.
- **Register what you retrieve** (`source: erddap`, with server name and datasetID), and apply
  its share level exactly as for local data. See [`sensitivity.md`](sensitivity.md).
- **Credentials** for access-controlled datasets are never written in code, config files you
  commit, or chat. Keep them in `~/.Renviron` (read with `Sys.getenv()`) or the OS keychain
  (`keyring` package). How to authenticate depends on the server's login method; ask the
  server's administrator for the supported route.
- **Querying is fine; sending data is not.** A request to the user's ERDDAP carries only the
  query. Never post data *to* any service.
- Details on protocols, constraints and pitfalls: [`erddap.md`](erddap.md).

## File mode (no store yet; a few files)

For a quick look at a handful of files before ingesting:

```r
library(oce)
cast <- oce::read.ctd.sbe("path/to/cast.cnv")     # processed Sea-Bird profile
adp  <- oce::read.adp.rdi("path/to/deploy.000")   # RDI PD0 binary (can be large: see performance.md)
```

Convert to a tibble at the boundary (`as_tibble(cast@data)`). Anything you will analyse
more than once belongs in the store — see [`../skills/ocean-ingest/SKILL.md`](../skills/ocean-ingest/SKILL.md).

## If the store is missing

`file.exists(cfg$store_path)` is `FALSE` → nothing has been ingested yet. Offer
`ocean-ingest`, or use ERDDAP / file mode for the immediate question.
