---
name: ocean-adcp
description: Process, quality-control, analyse and plot Teledyne RDI ADCP current data in R — moored, vessel-mounted (VmDas) and lowered — including coordinate transforms, magnetic declination, bin depths, side-lobe and QC screening, mean profiles, time–depth plots, principal axes and tidal analysis. Use for any ADCP or current-profile task.
---

# ADCP currents

Read [`formats/teledyne-rdi-adcp.md`](../../oait-knowledge/formats/teledyne-rdi-adcp.md)
first: the platform (moored / vessel / lowered) decides almost everything that follows.

## Before analysing

1. **Platform and files.** Moored PD0? VmDas `.LTA`/`.STA`/`.ENX`? UHDAS/CODAS output? LADCP
   processed profiles? Each has a different route; don't mix them.
2. **Coordinate system and declination.** Check `adcp_deployments.coordinate_system` and
   `declination_applied`. If velocities are not in earth coordinates relative to true north,
   **do not label them east/north**.
3. **Bin geometry.** Transducer depth (nominal vs pressure-sensor), orientation, blank, cell
   size; which bins are side-lobe contaminated.
4. **QC flags** (`uv_qc`) and the thresholds that produced them; state them.
5. **Size.** Reduce in DuckDB; ADCP tables are large
   ([`performance.md`](../../oait-knowledge/performance.md)).

## Mean profile with spread

```r
adcp |>
  filter(deployment_id == "<id>", uv_qc %in% c(1, 2)) |>
  group_by(bin, depth) |>
  summarise(u_mean = mean(u), v_mean = mean(v),
            u_sd = sd(u), v_sd = sd(v), n = n(), .groups = "drop") |>
  collect() |>
  pivot_longer(c(u_mean, v_mean), names_to = "component", values_to = "mean") |>
  ggplot(aes(mean, depth, colour = component)) +
  geom_vline(xintercept = 0, colour = "grey70") +
  geom_path() +
  scale_y_reverse() +
  labs(x = "Velocity (m/s)", y = "Depth (m)") +
  theme_bw()
```

For a moored instrument whose depth varies (knock-down), `depth` per ensemble differs; group
by `bin` and report the median depth per bin, or regrid to fixed depths first.

## Time–depth plot

Average to a manageable resolution in the database (e.g. hourly), then
`geom_raster(aes(time, depth, fill = v))` with a diverging scale centred on zero
(`scale_fill_gradient2()`), `scale_y_reverse()`. Mark gaps as gaps (don't interpolate across
missing ensembles without saying so).

## Principal axes and variance ellipses

The principal axis is the direction of maximum variance of (u, v): the eigenvector of their
covariance matrix. Report it as a direction **towards** which the flow varies, in degrees
true, with the fraction of variance explained.

```r
uv <- adcp |> filter(deployment_id == "<id>", bin == 5, uv_qc %in% c(1, 2)) |>
  select(u, v) |> collect()
e <- eigen(cov(uv))
major_dir_deg <- (atan2(e$vectors[1, 1], e$vectors[2, 1]) * 180 / pi) %% 180  # ambiguous by 180°
var_explained <- e$values[1] / sum(e$values)
```

## Tidal analysis

`oce::tidem()` fits tidal constituents to a time series (one component or depth at a time;
apply to u and v separately, or use a complex-series package for ellipse parameters). Needs
a record long enough to separate the constituents you ask for (≈15 days for M2/S2;
Rayleigh criterion), regular sampling, and gaps handled deliberately. Report the record
length and which constituents were resolvable.

## Vessel-mounted ADCP

- Start from `.LTA` (long-term averages) unless the user needs custom averaging.
- Check that ship velocity has been removed (bottom track or GPS reference) and that heading
  came from the gyro/GNSS, not the ADCP compass.
- Exclude or flag data during turns and speed changes.
- Positions come per ensemble: **all VMADCP output is position-bearing** — check the register
  before mapping or plotting along-track sections.
