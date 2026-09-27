---
name: ocean-ingest
description: Bring raw oceanographic instrument files (Sea-Bird CTD .cnv/.btl, Teledyne RDI ADCP PD0/VmDas, met-station logs, Niskin lab results) from the OAIT raw archive into the local DuckDB + Parquet store, with provenance, QC flags and register checks. Use when the user adds new files, asks to "load", "import" or "ingest" data, or when the store needs rebuilding after a schema change.
---

# Ingest raw files into the store

Ingest is the **only** step that writes to the store. It must be repeatable (running it twice
changes nothing), traceable (every row points to a source file and its hash), and
conservative (it never modifies `raw/`).

Read first: [`data-model.md`](../../oait-knowledge/data-model.md),
[`variables.md`](../../oait-knowledge/variables.md),
[`quality-control.md`](../../oait-knowledge/quality-control.md), and the format file for the
instrument in [`formats/`](../../oait-knowledge/formats/).

## Before starting

1. **Files are in `raw/<cruise-or-deployment>/<instrument>/`.** If they are elsewhere, offer
   to **copy** them in (never move without asking).
2. **The dataset is registered.** If not, register it first via
   [`../ocean-privacy/SKILL.md`](../ocean-privacy/SKILL.md). Ingest refuses unregistered data,
   because every row needs a `dataset_id` whose conditions are known.
3. **No other connection is open** to the store (a read-only session blocks writing).
4. **Inspect one file before writing a loop**: read it, show the user the header metadata
   and variable names (not the data rows), and confirm the mapping to store columns.
5. **Estimate size** for ADCP and high-rate met data; plan chunked reads
   ([`performance.md`](../../oait-knowledge/performance.md)).

## Invariants

- **Idempotent by hash.** Compute `digest::digest(file = f, algo = "sha256")`. If
  `ingest_log` has that hash with `status = 'ok'`, skip. If the same `source_file` path has a
  different hash (the file was reprocessed), delete the rows from that `source_file` and
  re-ingest, inside one transaction.
- **Every data table carries `source_file`** (path relative to the data root), so rows can be
  traced and replaced.
- **Transactions.** Write each file's rows and its `ingest_log` row in one
  `DBI::dbWithTransaction()`; a failure leaves the store as it was.
- **Units and names converted at ingest**, per `variables.md`; the original names/units are
  recorded in `ingest_log.message` when they differed.
- **QC flags stored, not applied.** Map source flags to L20; set 0 where no QC was done.
- **Refresh `datasets`** from the register at the start of each ingest run.
- **Failures are logged**, with `status = 'error'` and the message, and reported to the user.

## Skeleton

```r
library(tidyverse); library(DBI); library(duckdb)
cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))
cfg$store_path <- path.expand(cfg$store_path); cfg$data_root <- path.expand(cfg$data_root)
dir.create(dirname(cfg$store_path), recursive = TRUE, showWarnings = FALSE)

con <- dbConnect(duckdb::duckdb(), dbdir = cfg$store_path)   # write mode: ingest only
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

# 1. Mirror the register into `datasets`
reg <- yaml::read_yaml(path.expand(cfg$register_path))
datasets_tbl <- purrr::map_dfr(reg, \(d) tibble(
  dataset_id          = d$dataset_id,
  source              = d$source %||% NA_character_,
  instrument          = d$instrument %||% NA_character_,
  share_level         = d$share_level %||% "restricted",
  restricted_area     = isTRUE(d$restricted_area),
  embargo_until       = as.Date(d$embargo_until %||% NA),
  eez_consent         = !is.null(d$eez_consent),
  partner_agreement   = !is.null(d$partner_agreement),
  position_resolution = as.numeric(d$position_resolution %||% NA),
  entry_json          = as.character(jsonlite::toJSON(d, auto_unbox = TRUE, null = "null"))
))
dbWriteTable(con, "datasets", datasets_tbl, overwrite = TRUE)

# 2. Helpers
rel_path <- function(f) sub(paste0("^", normalizePath(cfg$data_root, winslash = "/"), "/?"), "",
                            normalizePath(f, winslash = "/"))
already_ingested <- function(sha) {
  dbExistsTable(con, "ingest_log") &&
    nrow(dbGetQuery(con, "SELECT 1 FROM ingest_log WHERE file_sha256 = ? AND status = 'ok'",
                    params = list(sha))) > 0
}
log_ingest <- function(file, sha, dataset_id, reader, status, message = NA_character_) {
  dbWriteTable(con, "ingest_log", tibble(
    source_file = rel_path(file), file_sha256 = sha, dataset_id = dataset_id,
    reader = reader, reader_version = as.character(packageVersion(sub("::.*", "", reader))),
    oait_version = readLines(file.path(path.expand(cfg$oait_path), "VERSION"))[1],
    ingested_at = Sys.time(), status = status, message = message
  ), append = TRUE)
}
```

## CTD (`.cnv`)

```r
ingest_ctd_cnv <- function(file, dataset_id, direction = c("down", "up")) {
  direction <- match.arg(direction)
  sha <- digest::digest(file = file, algo = "sha256")
  if (already_ingested(sha)) return(invisible("skipped"))

  cast <- oce::read.ctd.sbe(file)
  md <- cast@metadata
  # If the file is not bin-averaged per direction, trim and bin here (see formats/seabird-ctd.md):
  # cast <- oce::ctdTrim(cast, method = "downcast"); cast <- oce::ctdDecimate(cast, p = 1)

  d <- as_tibble(cast@data)
  if ("flag" %in% names(d)) d <- filter(d, flag == 0)
  lon <- md$longitude; lat <- md$latitude

  cast_id <- paste(dataset_id, md$station, md$cast %||% 1, direction, sep = "_")
  prof <- tibble(
    cast_id, source_file = rel_path(file),
    pressure = d$pressure, temperature = d$temperature,
    conductivity = d$conductivity,          # check units: oce may keep mS/cm or ratio
    practical_salinity = d$salinity
  ) |>
    mutate(
      absolute_salinity        = gsw::gsw_SA_from_SP(practical_salinity, pressure, lon, lat),
      conservative_temperature = gsw::gsw_CT_from_t(absolute_salinity, temperature, pressure),
      sigma0                   = gsw::gsw_sigma0(absolute_salinity, conservative_temperature),
      depth                    = -gsw::gsw_z_from_p(pressure, lat),
      across(c(temperature, practical_salinity), \(x) 0L, .names = "{.col}_qc")
    )

  casts <- tibble(
    cast_id, dataset_id, source_file = rel_path(file),
    cruise = md$cruise %||% NA_character_, station = md$station, cast = md$cast %||% 1L,
    direction, time_start = md$startTime, lon, lat,
    instrument_model = md$type %||% NA_character_,
    instrument_sn = md$serialNumber %||% NA_character_,
    processing = paste(grep("^# (datcnv|filter|align|celltm|loop|derive|bin)",
                            md$header, value = TRUE), collapse = "; ")
  )

  dbWithTransaction(con, {
    for (t in c("ctd_profiles", "ctd_casts")) if (dbExistsTable(con, t))
      dbExecute(con, glue::glue("DELETE FROM {t} WHERE source_file = ?"), params = list(rel_path(file)))
    dbWriteTable(con, "ctd_casts", casts, append = TRUE)
    dbWriteTable(con, "ctd_profiles", prof, append = TRUE)
    log_ingest(file, sha, dataset_id, "oce::read.ctd.sbe", "ok")
  })
}
```

Metadata field names (`station`, `cast`, `cruise`, `type`, `serialNumber`, `header`) vary with
`oce` versions and with how the `.cnv` header was written; **inspect `names(cast@metadata)` on
the user's files and adapt** before looping over a cruise. Add oxygen, fluorescence etc. in
the same way, converting units per `variables.md`.

## Bottles (`.btl` + lab sheets)

1. Parse `.btl` into `bottles` (one row per closure; `cast_id` of the **upcast**). See
   [`formats/niskin-bottle.md`](../../oait-knowledge/formats/niskin-bottle.md) for layout and
   validation (bottle count = `.bl` fires).
2. Read lab sheets with `readxl`/`readr`; map sample numbers to (station, cast, niskin);
   pivot to long `bottle_analyses` (`analyte`, `value`, `unit`, `method`, `replicate`, `lab`).
3. **Report unmatched bottles and samples** to the user; don't drop them.

## Met

1. Identify the format (TOA5, vendor CSV, ship log) — [`formats/met-station.md`](../../oait-knowledge/formats/met-station.md).
2. Confirm the logger's **time zone** and **sensor heights** with the user; convert to UTC.
3. Ship data: compute **true wind** from relative wind + heading + COG/SOG before storing.
4. Write station metadata to `met_stations`, records to `met` (append per file).

## ADCP

1. Read in chunks (`oce::read.adp.rdi(file, from =, to =)`), per
   [`formats/teledyne-rdi-adcp.md`](../../oait-knowledge/formats/teledyne-rdi-adcp.md).
2. Per chunk: transform to earth coordinates, apply declination **once** (check EB setting),
   compute bin depths, apply QC flags (correlation, percent good, error velocity, side lobe),
   and flatten to long format (`time`, `bin`, `depth`, `u`, `v`, `w`, `error_velocity`, …).
3. Write chunks with `arrow::write_dataset(chunk, file.path(<store>/adcp), partitioning =
   "deployment_id", existing_data_behavior = "overwrite")` for the first chunk of a
   deployment and append thereafter — or write one file per chunk into the partition folder.
4. Record the deployment in `adcp_deployments`, including `coordinate_system` and
   `declination_applied`.

## After ingest

- Report per file: ingested / skipped / failed, row counts, and any unmatched or suspicious
  items (e.g. casts without positions, bottles without lab values).
- Run a quick plausibility summary (ranges per variable) and show **ranges, not rows**.
- Offer a cookbook recipe if the user's format needed special handling.
