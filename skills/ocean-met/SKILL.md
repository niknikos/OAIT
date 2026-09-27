---
name: ocean-met
description: Work with meteorological station and ship-met data in R — reading logger formats (Campbell TOA5, vendor CSV, ship logs), UTC handling, sensor heights, vector-averaged wind, relative-to-true wind for ships, time averaging, wind roses and time-series plots. Use for any meteorological-station or ship weather-data task.
---

# Meteorological data

Read [`formats/met-station.md`](../../oait-knowledge/formats/met-station.md) first. Most met
errors are metadata errors: time zone, sensor height, averaging method, and wind direction
conventions.

## Before analysing

1. **Time zone** — is the logger on UTC? (Store is UTC; confirm for file-mode data.)
2. **Sensor heights** — from `met_stations.sensor_heights`. Don't compare winds from
   different heights without saying so, or adjusting.
3. **Averaging** — interval and scalar vs vector means (`averaging_s`; TOA5 processing line).
4. **Ship data** — confirm winds are **true**, not relative (see `ingest_log.message`).
5. **QC** — range, rate-of-change, flatline; flow-distortion sectors on ships.

## Daily / hourly means

Average **in DuckDB** and vector-average wind direction. The pattern is in
[`performance.md`](../../oait-knowledge/performance.md). Keep `n` (number of records per
interval) and drop intervals with poor coverage — state the threshold (e.g. ≥ 75 % of
expected records).

## Time series

```r
daily |>
  pivot_longer(c(air_temperature, air_pressure, wind_speed)) |>
  ggplot(aes(day, value)) +
  geom_line() +
  facet_wrap(~name, ncol = 1, scales = "free_y") +
  labs(x = "Date (UTC)", y = NULL) +
  theme_bw()
```

## Wind rose

`openair::windRose()` expects columns `ws` and `wd` (direction **from**, degrees), and a
`date` column:

```r
met_hourly |>
  rename(date = hour, ws = wind_speed, wd = wind_direction) |>
  openair::windRose(paddle = FALSE, breaks = c(0, 4, 8, 12, 16, 25))
```

Use data at a consistent averaging interval; a rose from mixed 1-min and 10-min records
over-weights the high-rate period.

## Comparing with ocean data

- Wind **from** vs current **to**: convert before comparing directions.
- Align time bases (instantaneous vs interval means; interval **start** vs **end** labels
  differ between loggers — check).
- Air–sea fluxes need bulk formulae (e.g. COARE 3.x), sensor heights, SST depth and
  humidity. That is a separate, careful piece of work; propose it rather than approximating.

## Sensitivity

Fixed-station positions are usually public, but a ship's met record is a **track**: treat it
as position-bearing and check the register (restricted areas, EEZ conditions).
