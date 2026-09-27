# R packages OAIT relies on

| Package | Used for | Notes |
|---|---|---|
| `tidyverse` | data manipulation, plotting (ggplot2), reading text (readr) | house style |
| `DBI`, `duckdb` | the local store | always `read_only = TRUE` outside ingest |
| `arrow` | writing ADCP Parquet partitions at ingest | reading goes through DuckDB |
| `oce` | reading Sea-Bird `.cnv`, RDI PD0; CTD trimming/binning; ADCP coordinate transforms | check function help for your installed version |
| `gsw` | TEOS-10 (SA, CT, σ₀, N², depth from pressure) | prefer over EOS-80 functions |
| `rerddap` | ERDDAP search, `tabledap`, `griddap` | cache inside the data root |
| `yaml` | reading the sensitivity register | |
| `jsonlite` | reading `~/.oait/config.json` | |
| `digest` | SHA-256 of source files for `ingest_log` | `digest::digest(file = f, algo = "sha256")` |
| `lubridate` | time parsing and UTC handling | |
| `ggOceanMaps` | static station maps and bathymetry backgrounds | |
| `leaflet` | interactive maps **kept local** (never published for restricted data) | |
| `sf` | spatial operations, rounding/aggregating positions | |
| `stars` / `terra` | gridded ERDDAP data | |
| `keyring` (optional) | ERDDAP credentials in the OS keychain | alternative to `~/.Renviron` |

Install what is missing:

```r
pkgs <- c("tidyverse", "DBI", "duckdb", "arrow", "oce", "gsw", "rerddap", "yaml", "jsonlite",
          "digest", "lubridate", "ggOceanMaps", "leaflet", "sf")
install.packages(setdiff(pkgs, rownames(installed.packages())))
```

If BAIT is installed, its `r-package-setup` skill describes the preferred header for scripts.
