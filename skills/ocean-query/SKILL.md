---
name: ocean-query
description: Turn a natural-language question about oceanographic data into a tidyverse/dplyr query against the OAIT store or an ERDDAP server (e.g. "deepest cast on cruise X", "mean bottom temperature at station S03 by year", "strongest current at the mooring"). Use for any data-retrieval or summary question.
---

# Answer data questions (NL → dplyr)

## Workflow

1. **Register first.** Identify the dataset(s); read their register entries. Unregistered →
   restricted; ask. See [`../ocean-privacy/SKILL.md`](../ocean-privacy/SKILL.md).
2. **Connect** read-only — [`../ocean-connect/SKILL.md`](../ocean-connect/SKILL.md). Choose
   store or ERDDAP; if both hold the data, prefer the store and say so.
3. **Pick the table** — [`data-model.md`](../../oait-knowledge/data-model.md).
4. **Map words → columns and units** — [`variables.md`](../../oait-knowledge/variables.md).
   Confirm with `colnames()`; don't guess. Be explicit about SP vs SA, pressure vs depth,
   "from" vs "to", magnetic vs true.
5. **Choose QC flags** — [`quality-control.md`](../../oait-knowledge/quality-control.md).
   Default: accept L20 0, 1, 2, 5. State the choice in the answer.
6. **Build lazily; reduce in DuckDB; `collect()` only the small result.** Count first for
   unknown sizes — [`performance.md`](../../oait-knowledge/performance.md).
7. **Sanity-check extremes**: top ~10, check flags, bounds, neighbours, clustering; report the
   largest plausible value and the rejected candidates.
8. **Apply the register to the output**: degrade or drop positions as required; don't include
   raw rows from restricted datasets in the reply beyond what the question needs.
9. **Answer the whole question** — with units, scales, time zone (UTC), QC choice, and the
   number of observations behind any mean.
10. New kind of question → **offer a cookbook recipe**.

## Patterns

**Deepest cast on a cruise**
```r
ctd_profiles |>
  filter(!is.na(pressure)) |>
  group_by(cast_id) |>
  summarise(max_pressure = max(pressure, na.rm = TRUE)) |>
  inner_join(ctd_casts |> filter(cruise == "<cruise>"), by = "cast_id") |>
  slice_max(max_pressure, n = 10) |>
  select(cast_id, station, time_start, max_pressure) |>
  collect()
```
(Positions deliberately left out; add them only if the register allows.)

**Annual mean near-bottom temperature at a station**
```r
near_bottom <- ctd_profiles |>
  filter(temperature_qc %in% c(0, 1, 2, 5)) |>
  group_by(cast_id) |>
  filter(pressure >= max(pressure, na.rm = TRUE) - 5) |>   # deepest 5 dbar of each cast
  summarise(t_bottom = mean(temperature, na.rm = TRUE), .groups = "drop")

near_bottom |>
  inner_join(ctd_casts |> filter(station == "S03", direction == "down"), by = "cast_id") |>
  mutate(year = year(time_start)) |>
  group_by(year) |>
  summarise(t_bottom = mean(t_bottom, na.rm = TRUE), n_casts = n()) |>
  arrange(year) |>
  collect()
```
Say what "near bottom" means (deepest 5 dbar of each cast is **not** the seabed unless the
casts reached it; `bottom_depth` tells you how close they got).

**Strongest current at a mooring (sanity-checked)**
```r
adcp |>
  filter(deployment_id == "<id>", uv_qc %in% c(1, 2)) |>
  mutate(speed = sqrt(u^2 + v^2)) |>
  slice_max(speed, n = 10) |>
  select(time, bin, depth, u, v, speed, error_velocity, correlation_min) |>
  collect()
```
Check the candidates: clustered in the bin nearest the surface → side-lobe or wave
contamination; isolated single ensembles → fish or noise; many consecutive ensembles → likely
real (a storm or tidal peak).

**Met: daily mean wind from high-rate records** — see the vector-averaging example in
[`performance.md`](../../oait-knowledge/performance.md).
