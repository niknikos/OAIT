# Data model: the data root, the store, and how tables relate

OAIT works with two sources that the agent treats in the same way once connected:

1. **The local data root** — raw instrument files plus a queryable store built from them.
2. **An institutional ERDDAP server** — queried read-only, with responses cached locally.

Both sit outside every repository. Paths come from `~/.oait/config.json`.

## The data root

```
~/OAIT_data/                         # %USERPROFILE%\OAIT_data\ on Windows
├── raw/                             # untouched instrument files; NEVER modified
│   └── <cruise-or-deployment>/
│       ├── ctd/     *.hex *.xmlcon *.hdr *.bl  (+ *.cnv *.btl if processed with SBE software)
│       ├── adcp/    *.000 / *.ENR *.ENX *.STA *.LTA *.N1R …
│       ├── met/     TOA5 *.dat, CSV exports, ship-met logs
│       └── bottle/  lab result sheets (salinity, oxygen, nutrients, chl-a …)
├── store/
│   ├── oait.duckdb                  # catalogue, CTD, bottles, met (see tables below)
│   └── adcp/deployment_id=<id>/*.parquet   # ADCP ensembles, partitioned by deployment
├── cache/erddap/                    # cached ERDDAP responses
└── registry/datasets.yaml           # the sensitivity register (see sensitivity.md)
```

**Rules that keep this trustworthy:**

- `raw/` is the archive of record. Nothing writes into it except the user copying files in.
  Processing always writes to `store/`.
- The store is **rebuildable** from `raw/` + the register + OAIT's ingest code. If in doubt
  about a store table, rebuild it rather than patching it by hand.
- Every data table carries a `source_file` column (path relative to the data root), and
  `ingest_log` holds that file's `file_sha256`, so any value can be traced to the original
  and a reprocessed file can replace exactly its own rows.

## Store tables (`store/oait.duckdb`)

Units follow [`variables.md`](variables.md): pressure in dbar, temperature °C (ITS-90),
velocity m s⁻¹, times as UTC timestamps. Each measured variable `x` may have a companion
`x_qc` flag column using the scheme in [`quality-control.md`](quality-control.md).

### Catalogue

| Table | One row per | Key columns |
|---|---|---|
| `datasets` | register entry (copied at ingest) | `dataset_id`, `instrument`, `share_level`, `restricted_area`, `embargo_until`, … |
| `ingest_log` | ingested source file | `source_file`, `file_sha256`, `dataset_id`, `reader`, `reader_version`, `oait_version`, `ingested_at`, `status`, `message` |

### CTD

| Table | One row per | Key columns |
|---|---|---|
| `ctd_casts` | cast (one down- or upcast) | `cast_id`, `dataset_id`, `cruise`, `station`, `cast`, `direction` (`down`/`up`), `time_start`, `lon`, `lat`, `bottom_depth`, `instrument_model`, `instrument_sn`, `processing`, `bin_size_dbar` |
| `ctd_profiles` | cast × pressure bin | `cast_id`, `pressure`, `depth`, `temperature`, `conductivity`, `practical_salinity`, `absolute_salinity`, `conservative_temperature`, `sigma0`, `oxygen`, `fluorescence`, `turbidity`, `par`, `*_qc` |

`cast_id` is built as `<dataset_id>_<station>_<cast>_<direction>` so it is stable across
rebuilds. Dual-sensor CTDs keep the primary pair in the standard columns and the secondary
pair as `temperature_2`, `conductivity_2`, `practical_salinity_2`.

### Bottles

| Table | One row per | Key columns |
|---|---|---|
| `bottles` | bottle closure (Niskin trip) | `cast_id` (the **upcast**), `niskin`, `pressure`, `time_trip`, `ctd_temperature`, `ctd_practical_salinity`, `ctd_oxygen`, `sample_flag` |
| `bottle_analyses` | bottle × analyte | `cast_id`, `niskin`, `analyte` (`salinity`, `oxygen`, `nitrate`, `phosphate`, `silicate`, `chla`, …), `value`, `unit`, `method`, `replicate`, `lab`, `analysis_date`, `value_qc` |

`bottle_analyses` is **long** because labs report different analytes at different times; pivot
wider at query time.

### Meteorology

| Table | One row per | Key columns |
|---|---|---|
| `met_stations` | station or ship platform | `station_id`, `dataset_id`, `platform_type` (`fixed`/`ship`/`buoy`), `lon`, `lat`, `sensor_heights` (JSON) |
| `met` | station × timestamp | `station_id`, `time`, `averaging_s`, `air_temperature`, `relative_humidity`, `air_pressure`, `wind_speed`, `wind_direction`, `wind_gust`, `shortwave_down`, `longwave_down`, `precipitation`, `sea_surface_temperature`, `*_qc` |

For ship platforms, `lon`/`lat` also appear per row in `met` (the ship moves), and wind is
stored **true** (earth-referenced) with the correction documented in `ingest_log.message`.
`wind_direction` is the direction the wind blows **from**, degrees true (meteorological
convention). See [`formats/met-station.md`](formats/met-station.md).

### ADCP

| Table / dataset | One row per | Key columns |
|---|---|---|
| `adcp_deployments` (DuckDB) | deployment or vessel transect set | `deployment_id`, `dataset_id`, `platform` (`moored`/`vessel`/`lowered`), `instrument_model`, `instrument_sn`, `frequency_khz`, `orientation` (`up`/`down`), `transducer_depth`, `blank_m`, `bin_size_m`, `n_bins`, `coordinate_system`, `declination_applied`, `lon`, `lat` (moored), `time_start`, `time_end` |
| `adcp` (Parquet view) | ensemble (or averaging interval) × bin | `deployment_id`, `time`, `bin`, `depth`, `u` (east), `v` (north), `w`, `error_velocity`, `correlation_min`, `echo_mean`, `percent_good`, `lon`, `lat` (vessel), `uv_qc` |

The ADCP view is created at connect time over the partitioned Parquet files (see
[`connection.md`](connection.md)). Velocities are earth coordinates (east/north/up) after
declination correction; if a deployment could not be corrected, `coordinate_system` says so
and the agent must not present `u`/`v` as east/north.

## How the tables relate

```
datasets ─┬─< ctd_casts ─┬─< ctd_profiles
          │              └─< bottles ─< bottle_analyses
          ├─< met_stations ─< met
          └─< adcp_deployments ─< adcp
ingest_log records every source file behind every table.
```

Join on `dataset_id` to bring in sensitivity fields **before** producing an output; filter
out or degrade rows according to [`sensitivity.md`](sensitivity.md).

## ERDDAP data

ERDDAP `tabledap` responses are tidy tables whose column names follow the server's variable
names (often CF standard names or institution-specific names). Do **not** assume they match
the store's names — read `rerddap::info()` first and rename explicitly. `griddap` responses
are gridded arrays; keep them as `stars`/`terra` objects or tidy them only after subsetting.
See [`connection.md`](connection.md) and [`erddap.md`](erddap.md).
