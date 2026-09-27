# Meteorological station data

Met data arrive in more formats than any other instrument type in OAIT. The work is less
about parsing than about recording **what was measured, where, at what height, averaged how,
and referenced to what**.

## Common sources

| Source | Typical format | Notes |
|---|---|---|
| Campbell Scientific logger | **TOA5** ASCII (`.dat`): 4 header lines, then CSV | line 1 environment, line 2 field names, line 3 units, line 4 processing (`Avg`, `Smp`, `WVc`, …) |
| Campbell Scientific logger | TOB1 binary | convert with LoggerNet/CardConvert to TOA5 first |
| Vaisala / other weather stations | CSV / vendor text | read the vendor header; units vary |
| Ship's met system (e.g. SCS or vendor systems) | CSV / NMEA logs | wind usually **relative** to the ship; see below |
| National met services | CSV / API downloads | respect licence terms; register as partner/third-party data |

## Reading TOA5

```r
read_toa5 <- function(file) {
  hdr   <- readr::read_csv(file, skip = 1, n_max = 3, col_names = FALSE,
                           col_types = readr::cols(.default = "c"))
  names <- unlist(hdr[1, ])
  units <- unlist(hdr[2, ])
  procs <- unlist(hdr[3, ])
  data  <- readr::read_csv(file, skip = 4, col_names = names,
                           na = c("NAN", "NaN", "", "-7999", "7999"),
                           col_types = readr::cols(TIMESTAMP = "c", .default = "d"))
  data <- dplyr::mutate(data, TIMESTAMP = lubridate::ymd_hms(TIMESTAMP, tz = "UTC"))
  attr(data, "units") <- setNames(units, names)
  attr(data, "processing") <- setNames(procs, names)
  data
}
```

**Check the logger's clock setting before assuming UTC** — many loggers run on local
standard time. If so, convert and record the offset in `ingest_log.message`.

## What must be recorded per station (`met_stations`)

- Position (fixed stations) or that positions come per row (ships, buoys).
- **Sensor heights** above ground/sea level for wind, temperature, humidity; depth of the SST
  sensor. Wind speed at 25 m on a ship's mast is not comparable with 10 m wind without a
  height adjustment (logarithmic profile; stability-dependent — use a bulk flux algorithm such
  as COARE if precision matters).
- **Averaging interval** and method (scalar vs vector mean for wind).

## Wind conventions

- Direction is where the wind blows **from**, degrees true (meteorological convention).
- **Vector-average** wind direction (average the u/v components, then convert back); a
  scalar average of directions across north (350° and 10°) gives 180° — wrong.
- Campbell `WVc` outputs are already vector-averaged; `Avg` of a direction column is not.

```r
# direction "from" (deg) and speed -> components of the vector the wind blows TOWARD
wind_uv <- function(speed, dir_from) {
  rad <- dir_from * pi / 180
  tibble::tibble(u = -speed * sin(rad), v = -speed * cos(rad))
}
wind_dir_from <- function(u, v) (atan2(-u, -v) * 180 / pi) %% 360
```

## Ship winds: relative → true

A ship's anemometer measures wind relative to the moving ship and to the ship's bow. True
wind needs the ship's **heading**, **course over ground** and **speed over ground** at the
same time:

1. Convert relative direction (from bow) to a direction relative to north: add heading.
2. Convert to components (as above) → relative wind vector.
3. Add the ship's velocity vector (from COG/SOG) to get the true wind vector.
4. Convert back to speed/direction "from".

This is the standard vector method (Smith et al., 1999, describe it and its pitfalls). Use
time-matched navigation, and flag intervals with rapid heading changes. Winds from sectors
blocked by the superstructure should be flagged (see
[`../quality-control.md`](../quality-control.md)).

## Pressure

Station pressure differs from mean-sea-level pressure by roughly 0.12 hPa per metre of
height near sea level. Store station-level `air_pressure`; if reducing to MSL, name the
column `air_pressure_msl` and record the barometer height.
