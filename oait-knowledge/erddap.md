# ERDDAP: what the agent needs to know

ERDDAP is a data server that exposes tabular and gridded datasets through a consistent URL
API. OAIT treats a configured ERDDAP as a second, read-only data source alongside the local
store. The R client is [`rerddap`](https://docs.ropensci.org/rerddap/).

## Two protocols

| Protocol | Data shape | Typical content | `rerddap` call |
|---|---|---|---|
| `tabledap` | rows (one per observation) | CTD casts, bottle data, met records, moored time series, ship underway | `tabledap()` |
| `griddap` | n-dimensional arrays | model output, satellite products, gridded ADCP sections, climatologies | `griddap()` |

A dataset is one or the other; `rerddap::info()` tells you which (`meta$type`).

## Workflow

1. **Search** (`ed_search(query, url = server)`), or browse the server's own search page with
   the user.
2. **Inspect** with `info(datasetID, url = server)`: variable names, units, `standard_name`,
   `_FillValue`, time coverage, `license`, `institution`, `creator_name`. Record the licence
   in the register entry.
3. **Retrieve a constrained subset** — time, space, and only the variables you need.
4. **Rename and convert** to OAIT conventions ([`variables.md`](variables.md)).
5. **Apply QC** — many servers publish QC flag variables alongside data (e.g.
   `sea_water_temperature_qc`); read their `flag_values`/`flag_meanings` attributes before
   filtering, because schemes differ between servers.

## Constraints (tabledap)

Constraints are strings, evaluated **on the server**:

```r
rerddap::tabledap(
  "<datasetID>",
  fields = c("time", "latitude", "longitude", "depth", "sea_water_practical_salinity"),
  "time>=2024-06-01T00:00:00Z", "time<2024-07-01T00:00:00Z",
  "latitude>=60", "latitude<=62",
  url = server
)
```

- Times are ISO 8601 in UTC; include the `Z` to avoid ambiguity.
- `distinct = TRUE` and `orderby`/`orderbymax` reduce responses on the server (e.g. the
  latest record per station).
- Strings in constraints need quotes inside the string: `'station="S01"'`.

## Ranges (griddap)

```r
rerddap::griddap(
  "<datasetID>",
  time = c("2024-06-01", "2024-06-30"),
  latitude = c(60, 62), longitude = c(2, 6),
  fields = "sea_water_temperature",
  url = server
)
```

Check axis order and direction in `info()` (some grids store latitude descending, some use
0–360 longitude). A mismatch returns an error or, worse, an empty slice.

## Pitfalls

- **Missing values.** ERDDAP returns `NaN` or the dataset's `_FillValue`; convert explicitly
  (`na_if(x, fill_value)`) before computing anything.
- **Units in the response.** CSV responses from `rerddap` can carry a units row; `rerddap`
  handles it, but always check the column types after retrieval.
- **Depth vs pressure.** Some datasets report `depth` (m, positive down), some `pressure`
  (dbar), some `altitude` (negative down). Do not mix them without converting (`gsw`).
- **Time zone.** ERDDAP times are UTC. Keep them UTC.
- **Large requests** time out or are refused. Split by time window and bind the results.
- **Cache staleness.** `rerddap` caches responses; if the server data have been updated,
  clear the relevant cache entries (`rerddap::cache_delete_all()` removes everything —
  confirm with the user first).

## Access control

An institutional ERDDAP may require login for some datasets. The mechanism depends on how
the server is configured, so the agent should not improvise it: ask the user (or their
server administrator) for the supported route, keep any credentials in `~/.Renviron` or the
OS keychain, and never write them into code, config files, or the conversation. Retrieving a
dataset with credentials does not change its share level — see
[`sensitivity.md`](sensitivity.md).
