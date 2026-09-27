---
title: Retrieve a CTD subset from the institutional ERDDAP
questions:
  - "Get the CTD profiles for June 2024 in area Y from our ERDDAP"
  - "Download temperature and salinity from ERDDAP dataset Z for a time window"
instruments: [ctd]
source: erddap
tables: []
packages: [tidyverse, rerddap, gsw]
position_bearing: true
status: draft
tags: [query]
---

# Retrieve a CTD subset from ERDDAP

**Answers:** a tidy table of CTD observations from a `tabledap` dataset, constrained on the
server by time, area and variables, renamed to OAIT conventions.

## Approach

Inspect the dataset with `info()` to learn variable names, units and QC variables; request
only the needed variables and a bounded time/space window; rename and convert; apply the
server's QC flags after mapping them to L20. The result contains positions, so the register
applies before anything leaves the machine.

## Register check

Register the ERDDAP dataset (`source: erddap`, server name, datasetID, licence from
`info()`). A dataset that required a login is not public because you could read it.

## Code

```r
library(tidyverse); library(rerddap)
cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))
server <- purrr::detect(cfg$erddap_servers, \(s) s$name == "<server-name>")$url
rerddap::cache_setup(full_path = path.expand(cfg$erddap_cache))

meta <- rerddap::info("<datasetID>", url = server)
meta$variables                                   # names; read units from meta$alldata

raw <- rerddap::tabledap(
  meta,
  fields = c("station", "time", "latitude", "longitude", "PRES", "TEMP", "PSAL",
             "TEMP_QC", "PSAL_QC"),              # <- replace with the dataset's real names
  "time>=2024-06-01T00:00:00Z", "time<2024-07-01T00:00:00Z",
  "latitude>=<lat_min>", "latitude<=<lat_max>",
  "longitude>=<lon_min>", "longitude<=<lon_max>",
  url = server
) |>
  as_tibble()

ctd <- raw |>
  transmute(
    station,
    time = lubridate::ymd_hms(time, tz = "UTC"),
    lat = as.numeric(latitude), lon = as.numeric(longitude),
    pressure = as.numeric(PRES),
    temperature = as.numeric(TEMP),
    practical_salinity = as.numeric(PSAL),
    temperature_qc = as.integer(TEMP_QC),        # map to L20 per the server's flag_meanings
    practical_salinity_qc = as.integer(PSAL_QC)
  ) |>
  mutate(
    absolute_salinity = gsw::gsw_SA_from_SP(practical_salinity, pressure, lon, lat),
    conservative_temperature = gsw::gsw_CT_from_t(absolute_salinity, temperature, pressure)
  )
```

## Expected output

A tibble with one row per observation (station, time, position, pressure, T, SP, SA, CT, QC
flags). Size depends on the window; for long windows, loop over months and bind.

## Notes & caveats

- Variable names (`PRES`, `TEMP`, …) differ between servers; the ones above are placeholders
  in an OceanSITES/Argo-like style. Use the names `info()` reports.
- Some datasets give `depth` instead of pressure; convert with `gsw_p_from_z(-depth, lat)`.
- Check the QC variable's `flag_values`/`flag_meanings` attributes and map to L20 explicitly.
- Cached responses sit in the data root and inherit the dataset's share level.

## Related

- Skill: `skills/ocean-connect/SKILL.md`
- Knowledge: `oait-knowledge/erddap.md`, `oait-knowledge/sensitivity.md`
