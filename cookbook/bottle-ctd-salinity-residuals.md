---
title: Bottle vs CTD salinity residuals for a cruise
questions:
  - "How well does the CTD salinity agree with the salinometer samples on cruise X?"
  - "Does the CTD conductivity need a correction?"
instruments: [ctd, bottle]
source: store
tables: [ctd_casts, bottles, bottle_analyses]
packages: [tidyverse, duckdb]
position_bearing: false
status: draft
tags: [qc, calibration]
---

# Bottle vs CTD salinity residuals

**Answers:** the distribution of `bottle − CTD` practical salinity across a cruise, and
whether it shows structure (offset, step, pressure trend) that would justify a correction.

## Approach

Average replicate salinometer values per bottle, join to the bottle closure's upcast CTD
salinity (`bottles.ctd_practical_salinity`, from the `.btl` mean), and compute residuals.
Exclude closures in strong gradients using the `.btl` standard deviation if it was stored,
and outliers beyond 3 × MAD from the median. Plot residuals against pressure and station
order.

## Register check

Not position-bearing. Bottle and lab data inherit the cruise's embargo; lab results from a
partner laboratory may carry their own conditions.

## Code

```r
library(tidyverse); library(DBI); library(duckdb)
cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))
con <- dbConnect(duckdb::duckdb(), dbdir = path.expand(cfg$store_path), read_only = TRUE)

cruise_id <- "<cruise>"
up_casts <- tbl(con, "ctd_casts") |> filter(cruise == cruise_id, direction == "up")

sal_bottle <- tbl(con, "bottle_analyses") |>
  semi_join(up_casts, by = "cast_id") |>
  filter(analyte == "salinity", value_qc %in% c(0, 1, 2, 5)) |>
  group_by(cast_id, niskin) |>
  summarise(sal_bottle = mean(value, na.rm = TRUE),
            sal_rep_range = max(value, na.rm = TRUE) - min(value, na.rm = TRUE),
            n_rep = n(), .groups = "drop")

resid <- tbl(con, "bottles") |>
  inner_join(sal_bottle, by = c("cast_id", "niskin")) |>
  inner_join(up_casts |> select(cast_id, station, time_start), by = "cast_id") |>
  select(cast_id, station, time_start, niskin, pressure,
         ctd_practical_salinity, sal_bottle, sal_rep_range, n_rep) |>
  collect() |>
  mutate(dS = sal_bottle - ctd_practical_salinity)

dbDisconnect(con, shutdown = TRUE)

med <- median(resid$dS, na.rm = TRUE); spread <- mad(resid$dS, na.rm = TRUE)
resid <- resid |> mutate(outlier = abs(dS - med) > 3 * spread)

resid |> filter(!outlier) |>
  summarise(median_dS = median(dS), mad_dS = mad(dS), n = n())

resid |>
  mutate(station_order = dense_rank(time_start)) |>
  pivot_longer(c(pressure, station_order), names_to = "against") |>
  ggplot(aes(value, dS, colour = outlier)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_point(alpha = 0.7) +
  facet_wrap(~against, scales = "free_x",
             labeller = as_labeller(c(pressure = "Pressure (dbar)",
                                      station_order = "Station order"))) +
  scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = "red")) +
  labs(x = NULL, y = "Bottle − CTD salinity (PSS-78)") +
  theme_bw()
```

## Expected output

A one-row summary (median offset, MAD, n — e.g. an offset of order 0.00x with a spread of
similar order on a well-behaved cruise) and a two-panel residual plot. Outliers in red.

## Notes & caveats

- Compare against **upcast** CTD values (bottles close on the upcast).
- Poor replicate agreement (`sal_rep_range`) points to sampling or analysis problems, not the
  CTD; look at those bottles first.
- Several outliers on one cast suggest a mis-trip or a rosette problem; on one station
  onwards, a sensor event.
- A correction is proposed with this evidence; the user decides. Nothing here modifies the
  store.

## Related

- Skill: `skills/ocean-bottle/SKILL.md`
- Knowledge: `oait-knowledge/formats/niskin-bottle.md`
