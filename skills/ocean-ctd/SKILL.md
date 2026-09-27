---
name: ocean-ctd
description: Process, quality-control, analyse and plot Sea-Bird CTD profiles in R — reading .cnv, trimming and binning, TEOS-10 conversions, profile plots, T–S diagrams, sections, mixed-layer depth, stratification (N²), dual-sensor checks. Use for any CTD-profile task.
---

# CTD profiles

Read [`formats/seabird-ctd.md`](../../oait-knowledge/formats/seabird-ctd.md) for the file
family and processing order, and [`variables.md`](../../oait-knowledge/variables.md) for
scales. Data come from the store (`ctd_casts`, `ctd_profiles`) or a `.cnv` in file mode.

## Before analysing

1. **What processing have the files had?** Check `ctd_casts.processing` (or the `.cnv`
   header). Unbinned 24 Hz data need trimming and binning first.
2. **Down- or upcast?** Use downcasts for profiles; upcasts for bottle comparison.
3. **QC flags accepted?** Default L20 0, 1, 2, 5; say so.
4. **Register:** section plots and station maps are position-bearing.

## Profile plot

```r
prof <- ctd_profiles |>
  filter(cast_id %in% !!casts_of_interest, temperature_qc %in% c(0, 1, 2, 5)) |>
  select(cast_id, pressure, conservative_temperature, absolute_salinity, sigma0) |>
  collect()

prof |>
  pivot_longer(c(conservative_temperature, absolute_salinity, sigma0)) |>
  ggplot(aes(value, pressure, colour = cast_id)) +
  geom_path() +
  scale_y_reverse() +
  facet_wrap(~name, scales = "free_x",
             labeller = as_labeller(c(conservative_temperature = "Θ (°C)",
                                      absolute_salinity = "S_A (g/kg)",
                                      sigma0 = "σ₀ (kg/m³)"))) +
  labs(x = NULL, y = "Pressure (dbar)") +
  theme_bw()
```

Use `geom_path()`, not `geom_line()` (which sorts by x and scrambles profiles).

## T–S diagram with isopycnals

```r
grid <- expand_grid(
  SA = seq(min(prof$absolute_salinity, na.rm = TRUE) - 0.1,
           max(prof$absolute_salinity, na.rm = TRUE) + 0.1, length.out = 100),
  CT = seq(min(prof$conservative_temperature, na.rm = TRUE) - 0.5,
           max(prof$conservative_temperature, na.rm = TRUE) + 0.5, length.out = 100)
) |>
  mutate(sigma0 = gsw::gsw_sigma0(SA, CT))

ggplot(prof, aes(absolute_salinity, conservative_temperature)) +
  geom_contour(data = grid, aes(SA, CT, z = sigma0), colour = "grey70", binwidth = 0.2) +
  geom_point(aes(colour = pressure), size = 0.6) +
  scale_colour_viridis_c(trans = "reverse", name = "p (dbar)") +
  labs(x = "Absolute Salinity (g/kg)", y = "Conservative Temperature (°C)") +
  theme_bw()
```

The contour labels need `metR::geom_text_contour()` if wanted.

## Mixed-layer depth (density threshold)

A common definition (de Boyer Montégut et al., 2004): the shallowest depth where σ₀ exceeds
its value at 10 dbar by 0.03 kg m⁻³. Say which definition you used; results differ between
threshold and gradient methods, and in weakly stratified water the choice dominates.

```r
mld <- prof |>
  group_by(cast_id) |>
  arrange(pressure, .by_group = TRUE) |>
  summarise(
    sig_ref = approx(pressure, sigma0, xout = 10)$y,
    mld = pressure[which(pressure >= 10 & sigma0 > sig_ref + 0.03)[1]]
  )
```

`NA` means the threshold was never exceeded (mixed to the bottom of the cast) or the cast
started below 10 dbar; report those cases rather than dropping them.

## Stratification (N²)

```r
n2 <- prof |>
  left_join(ctd_casts |> select(cast_id, lat) |> collect(), by = "cast_id") |>
  group_by(cast_id) |>
  arrange(pressure, .by_group = TRUE) |>
  reframe(as_tibble(gsw::gsw_Nsquared(absolute_salinity, conservative_temperature,
                                      pressure, latitude = first(lat))))   # columns N2, p_mid
```

N² from 1 dbar bins is noisy; smooth or bin to 5–10 dbar for display, and say so.

## Sections

A section plots a variable against distance along a line and pressure. **It is
position-bearing**: check the register before producing one. Build distance with
`geosphere::distGeo()` or `oce::geodDist()` between consecutive stations, interpolate on a
regular grid (`akima::interp()` or `oce::as.section()` + `plot()`), and show station
positions as ticks so readers can see where interpolation fills gaps.

## Dual-sensor check

```r
ctd_profiles |>
  filter(!is.na(temperature_2)) |>
  mutate(dT = temperature - temperature_2, dS = practical_salinity - practical_salinity_2) |>
  group_by(cast_id) |>
  summarise(dT_median = median(dT, na.rm = TRUE), dS_median = median(dS, na.rm = TRUE)) |>
  collect()
```

A step change in the median difference between casts points to a sensor event (fouling,
swap, damage). Look at the bottle comparison ([`../ocean-bottle/SKILL.md`](../ocean-bottle/SKILL.md))
to decide which sensor to trust.
