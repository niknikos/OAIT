# Memory & performance — don't crash the user's machine

Oceanographic records are long. A moored ADCP year is ~10⁵ ensembles × tens of bins × four
beams × several variables; a 1 Hz met record is ~3 × 10⁷ rows per year. The first risk is
pulling too much into R memory. **Reduce in DuckDB (or per file chunk); collect only the small
final result.**

## Golden rules

1. **Filter and aggregate before `collect()`.** A lazy `tbl()` costs nothing until collected.
2. **Never `collect()` a whole table** — especially `met`, `ctd_profiles` and `adcp`.
3. **Compute extremes, means, and binned summaries in DuckDB**, not in R.
4. **`select()` only the columns you need** before `collect()`.
5. **Count and estimate before an unknown-sized collect; ask if it is large** (below).
6. **Read large raw files in chunks** (`oce::read.adp.rdi(from =, to =)`), reduce each chunk,
   write it to Parquet, and move on. Do not hold a full-deployment `adp` object in memory
   unless you know it fits.

## Time averaging in the database

```r
# Hourly means of wind from 1 Hz / 1 min records — vector-average direction.
met |>
  filter(station_id == "S01", time >= "2025-01-01", time < "2025-02-01") |>
  mutate(
    hour = sql("date_trunc('hour', time)"),
    u = -wind_speed * sin(radians(wind_direction)),
    v = -wind_speed * cos(radians(wind_direction))
  ) |>
  group_by(hour) |>
  summarise(u = mean(u, na.rm = TRUE), v = mean(v, na.rm = TRUE),
            wind_speed = mean(wind_speed, na.rm = TRUE), n = n()) |>
  collect() |>
  mutate(wind_direction = (atan2(-u, -v) * 180 / pi) %% 360)
```

(`radians()` is a DuckDB function and passes through dbplyr unchanged. Keep the `n` column:
an hourly mean from 3 values is not the same as one from 3600.)

## Estimate before collecting an unknown-sized result

```r
n <- query |> summarise(n = n()) |> pull(n)

total_ram <- switch(Sys.info()[["sysname"]],
  Darwin  = as.numeric(system("sysctl -n hw.memsize", intern = TRUE)),
  Linux   = as.numeric(system("awk '/MemTotal/{print $2}' /proc/meminfo", intern = TRUE)) * 1024,
  Windows = as.numeric(system2("powershell",
              c("-NoProfile", "-Command",
                "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"),
              stdout = TRUE)),
  NA_real_)

est_bytes <- n * n_selected_columns * 64   # rough; wide character columns are heavier
```

**Decision rule:** if `est_bytes` exceeds ~25 % of `total_ram`, or the row count runs to
millions, stop and tell the user the estimate, and offer lighter routes: aggregate in the
database, narrow the time window or depth range, select fewer columns, or collect a
per-day/per-bin summary first. If RAM cannot be determined, treat > 1–2 million rows as large.

## Raw file sizes

| Input | Rough in-memory expansion | Approach |
|---|---|---|
| `.cnv`, 1 dbar binned | small | read whole |
| `.cnv`, 24 Hz unbinned | tens of MB per deep cast | read whole, bin, discard scans |
| RDI PD0, moored, months | GB | chunked reads → Parquet |
| VmDas `.ENX`/`.ENR`, cruise | GB | prefer `.LTA`; otherwise chunk |
| Met, 1 Hz, years | GB as CSV | ingest per file into DuckDB; average in SQL |

## Other tips

- Disconnect when done: `DBI::dbDisconnect(con, shutdown = TRUE)`.
- Parquet partitions by `deployment_id` let DuckDB skip whole deployments; filter on
  `deployment_id` first.
- For ERDDAP, constrain on the server and split long time ranges into windows.
