---
name: ocean-connect
description: Connect to oceanographic data from R — the local OAIT store (DuckDB + Parquet, read-only) or an institutional ERDDAP server via rerddap — or read a few raw CTD/ADCP files directly. Use whenever a task needs data access set up before querying, plotting, or analysing CTD, ADCP, met or bottle data.
---

# Connect to oceanographic data (R + tidyverse)

Full reference: [`../../oait-knowledge/connection.md`](../../oait-knowledge/connection.md).
The essentials:

## 0. Read the config and the register

```r
library(tidyverse)
cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))   # Windows: see connection.md
cfg[c("data_root", "store_path", "register_path", "erddap_cache")] <-
  lapply(cfg[c("data_root", "store_path", "register_path", "erddap_cache")], path.expand)
register <- yaml::read_yaml(cfg$register_path)
```

You need the register to apply [`sensitivity.md`](../../oait-knowledge/sensitivity.md) to
whatever you produce. Missing config → [`../oait-install/SKILL.md`](../oait-install/SKILL.md).

## 1. Local store

```r
library(DBI); library(duckdb)
con <- dbConnect(duckdb::duckdb(), dbdir = cfg$store_path, read_only = TRUE)

datasets     <- tbl(con, "datasets")
ctd_casts    <- tbl(con, "ctd_casts");   ctd_profiles <- tbl(con, "ctd_profiles")
bottles      <- tbl(con, "bottles");     bottle_analyses <- tbl(con, "bottle_analyses")
met_stations <- tbl(con, "met_stations"); met <- tbl(con, "met")
adcp_deployments <- tbl(con, "adcp_deployments")
adcp_glob <- normalizePath(file.path(dirname(cfg$store_path), "adcp", "*", "*.parquet"),
                           winslash = "/", mustWork = FALSE)
adcp <- tbl(con, sql(glue::glue(
  "SELECT * FROM read_parquet('{adcp_glob}', hive_partitioning = true)")))

# ... work lazily; collect() only the reduced result ...
dbDisconnect(con, shutdown = TRUE)
```

**Rules:** `read_only = TRUE`; lazy queries; never `collect()` a whole table; state what
missing means in filters on nullable columns; disconnect when done.

## 2. ERDDAP

```r
server <- purrr::detect(cfg$erddap_servers, \(s) s$name == "<name>")$url
rerddap::cache_setup(full_path = cfg$erddap_cache)
meta <- rerddap::info("<datasetID>", url = server)
x <- rerddap::tabledap(meta, fields = c(...), "time>=...", "time<...", url = server)
```

Constrain on the server; rename to OAIT names; register the dataset; credentials only via
`~/.Renviron` / keychain. See [`erddap.md`](../../oait-knowledge/erddap.md).

## 3. File mode (quick look, no store)

```r
cast <- oce::read.ctd.sbe("path/to/cast.cnv")
adp  <- oce::read.adp.rdi("path/to/file.000", from = 1, to = 1000)   # subset large files
```

Anything used more than once belongs in the store → [`../ocean-ingest/SKILL.md`](../ocean-ingest/SKILL.md).

## Next

- Questions → [`../ocean-query/SKILL.md`](../ocean-query/SKILL.md)
- Instrument-specific work → `ocean-ctd`, `ocean-adcp`, `ocean-met`, `ocean-bottle`
- Tables and columns → [`data-model.md`](../../oait-knowledge/data-model.md),
  [`variables.md`](../../oait-knowledge/variables.md)
