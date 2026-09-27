---
title: T–S diagram for a cruise
questions:
  - "Make a T–S diagram for cruise X"
  - "Plot temperature against salinity for all casts on the cruise, with density contours"
instruments: [ctd]
source: store
tables: [datasets, ctd_casts, ctd_profiles]
packages: [tidyverse, duckdb, gsw]
position_bearing: false
status: draft
tags: [plot]
---

# T–S diagram for a cruise

**Answers:** a Conservative Temperature – Absolute Salinity diagram for all downcasts on one
cruise, coloured by pressure, with σ₀ isopycnals.

## Approach

Join `ctd_profiles` to `ctd_casts` for the cruise's downcasts, keep L20 flags 0/1/2/5 for
both temperature and salinity, and collect only the three plotted columns plus pressure.
Isopycnals are computed on a grid with `gsw_sigma0()`. TEOS-10 throughout.

## Register check

No positions are plotted, so the figure is not position-bearing. It still carries the
dataset's **embargo** and **partner** conditions: check `share_level` and `embargo_until`
before the figure leaves the machine.

## Code

```r
library(tidyverse); library(DBI); library(duckdb)
cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))
con <- dbConnect(duckdb::duckdb(), dbdir = path.expand(cfg$store_path), read_only = TRUE)

cruise_id <- "<cruise>"
good <- c(0, 1, 2, 5)

casts <- tbl(con, "ctd_casts") |> filter(cruise == cruise_id, direction == "down")

# Register conditions for what we are about to plot
tbl(con, "datasets") |>
  semi_join(casts, by = "dataset_id") |>
  select(dataset_id, share_level, embargo_until, partner_agreement) |>
  collect()

ts <- tbl(con, "ctd_profiles") |>
  semi_join(casts, by = "cast_id") |>
  filter(temperature_qc %in% good, practical_salinity_qc %in% good) |>
  select(cast_id, pressure, absolute_salinity, conservative_temperature) |>
  collect()

dbDisconnect(con, shutdown = TRUE)

grid <- expand_grid(
  SA = seq(min(ts$absolute_salinity) - 0.1, max(ts$absolute_salinity) + 0.1, length.out = 120),
  CT = seq(min(ts$conservative_temperature) - 0.5, max(ts$conservative_temperature) + 0.5,
           length.out = 120)
) |>
  mutate(sigma0 = gsw::gsw_sigma0(SA, CT))

ggplot(ts, aes(absolute_salinity, conservative_temperature)) +
  geom_contour(data = grid, aes(SA, CT, z = sigma0), colour = "grey75", binwidth = 0.25) +
  geom_point(aes(colour = pressure), size = 0.5) +
  scale_colour_viridis_c(trans = "reverse", name = "Pressure\n(dbar)") +
  labs(x = "Absolute Salinity (g/kg)", y = "Conservative Temperature (°C)",
       caption = "TEOS-10; downcasts; QC flags 0, 1, 2, 5; grey lines σ₀ every 0.25 kg/m³") +
  theme_bw()
```

## Expected output

A scatter plot with a few thousand to tens of thousands of points (1 dbar bins × casts),
σ₀ contours in the background, deeper points darker. Water masses appear as clusters or
curves; isolated points far from the cloud are candidates for QC review.

## Notes & caveats

- Uses SA/CT (TEOS-10). If a colleague expects SP/θ (EOS-80) plots, say which you used.
- Very large cruises: collect a thinned subset (e.g. every 5 dbar) for plotting.
- If `absolute_salinity` is missing for casts without positions, those casts drop out;
  report how many.

## Related

- Skill: `skills/ocean-ctd/SKILL.md`
