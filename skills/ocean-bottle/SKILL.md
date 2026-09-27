---
name: ocean-bottle
description: Work with Niskin bottle data in R — joining Sea-Bird .btl closures to laboratory results (salinity, Winkler oxygen, nutrients, chlorophyll), detecting mis-trips and leaks, handling replicates and detection limits, and comparing CTD sensors against bottle references for calibration. Use for any water-sample or CTD-calibration task.
---

# Niskin bottles and CTD calibration

Read [`formats/niskin-bottle.md`](../../oait-knowledge/formats/niskin-bottle.md) first.
Tables: `bottles` (closures, with upcast CTD values) and `bottle_analyses` (lab results,
long format).

## Before analysing

1. **Join key** is `cast_id + niskin`; lab sample numbers map through the archived sample
   log. Never join on depth.
2. **Unmatched samples/closures** are reported, not dropped.
3. **Replicates** summarised; poor agreement flagged.
4. **Detection limits** (flag 6) handled explicitly.
5. **Register**: bottle data inherit the CTD dataset's conditions; lab data from a partner lab
   may carry their own.

## Wide table for analysis

```r
bottle_wide <- bottle_analyses |>
  filter(value_qc %in% c(0, 1, 2, 5)) |>
  group_by(cast_id, niskin, analyte) |>
  summarise(value = mean(value, na.rm = TRUE), n_rep = n(), .groups = "drop") |>
  collect() |>
  pivot_wider(names_from = analyte, values_from = c(value, n_rep)) |>
  left_join(bottles |> collect(), by = c("cast_id", "niskin"))
```

## Salinity calibration check (CTD vs salinometer)

```r
resid <- bottle_wide |>
  filter(!is.na(value_salinity), !is.na(ctd_practical_salinity)) |>
  mutate(dS = value_salinity - ctd_practical_salinity)

# Robust summary, then look for structure
resid |> summarise(median_dS = median(dS), mad_dS = mad(dS), n = n())

ggplot(resid, aes(dS, pressure)) +
  geom_vline(xintercept = 0, colour = "grey70") +
  geom_point(alpha = 0.6) +
  scale_y_reverse() +
  labs(x = "Bottle − CTD practical salinity", y = "Pressure (dbar)") +
  theme_bw()
```

Then plot `dS` against station order (time) and temperature. Interpretation:

- **Flat cloud around a small median** (within the salinometer's precision, often
  ~0.002–0.003): no correction warranted; report the offset and spread.
- **Offset that changes at one point in the cruise**: a sensor event (fouling, swap);
  consider a piecewise correction, and check the secondary sensor.
- **Trend with pressure**: a conductivity-cell or pressure effect; a linear correction of
  conductivity against pressure may be appropriate.
- **Scattered outliers**: check for mis-trips, leaks, and closures in strong gradients (large
  `.btl` standard deviation) before treating them as sensor problems.

Exclusion rules (e.g. `|dS − median| > 3 × MAD`, or `.btl` sdev above a threshold) must be
stated. A correction is **proposed with its evidence**, and the user decides; never apply it
silently to the store.

## Oxygen (SBE 43 vs Winkler)

Same approach, on a consistent unit (µmol kg⁻¹; conversion in
[`variables.md`](../../oait-knowledge/variables.md)). SBE 43 errors are often proportional to
concentration and can depend on pressure and temperature; a ratio (`winkler / ctd`) versus
pressure is usually more informative than a difference.

## Chlorophyll (fluorometer vs extracted chl-a)

Fluorescence per unit chlorophyll varies with phytoplankton community, light history
(non-photochemical quenching near the surface in daylight) and depth. A single linear
regression across a cruise is a strong assumption; show the relationship by depth range and
time of day before proposing one.
