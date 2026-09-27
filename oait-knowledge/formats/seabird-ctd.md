# Sea-Bird CTD files

Sea-Bird instruments (SBE 911plus, SBE 25plus, SBE 19plus, …) produce a family of files per
cast. Knowing which file holds what, and what has already been done to it, matters more than
any single reader function.

## The files

| Extension | Content | Human-readable? | OAIT use |
|---|---|---|---|
| `.hex` | raw frequencies/voltages, one line per scan | no (hex-encoded) | archive of record; keep in `raw/` |
| `.xmlcon` / `.con` | instrument configuration and **calibration coefficients** | yes | archive; required to convert `.hex` |
| `.hdr` | header: NMEA position/time, operator-entered station info | yes | cast metadata (position, time, station) |
| `.bl` | bottle-fire log: scan numbers where Niskins closed | yes | bottle positions in the scan record |
| `.mrk` | operator marks | yes | occasionally useful for events |
| `.cnv` | **converted** engineering units (after SBE Data Processing) | yes (header + columns) | main CTD input |
| `.btl` | bottle summary: mean ± sd of CTD values at each bottle closure | yes | bottle input |
| `.ros` | scans around each bottle closure | yes | rarely needed |
| `.psa` | processing settings for each SBE module | yes | documents how `.cnv` was produced |

**Converting `.hex` to `.cnv` needs the matching `.xmlcon`**, and is normally done with Sea-Bird's
SBE Data Processing (Windows) or Seasoft. R has no general, validated `.hex` converter; OAIT
therefore ingests `.cnv`/`.btl` and archives `.hex` + `.xmlcon` alongside them. If the user
has only `.hex` files, say so and point to SBE Data Processing rather than improvising a
conversion.

## Standard processing order (SBE Data Processing)

The `.cnv` header's `# datcnv_…`, `# filter_…`, `# loopedit_…` etc. lines record which modules
ran. Read them before trusting a file; record them in `ctd_casts.processing`.

1. **Data Conversion** (`DatCnv`) — `.hex` + `.xmlcon` → `.cnv` (and `.ros` for bottles).
2. **Bottle Summary** — `.ros` → `.btl`.
3. **Filter** — low-pass pressure (and conductivity on some instruments).
4. **Align CTD** — shift conductivity/oxygen in time relative to temperature (response times;
   the SBE 911plus deck unit usually advances primary conductivity already).
5. **Cell Thermal Mass** — correct conductivity for the cell's thermal inertia.
6. **Loop Edit** — flag scans where the CTD moved upward (ship heave) or was below a minimum
   descent rate.
7. **Derive** — salinity, density, oxygen, depth.
8. **Bin Average** — usually 1 dbar or 1 m bins; separate down- and upcasts.

A `.cnv` straight out of `DatCnv` has none of steps 3–8. Ask the user what processing their
files have had when the header is ambiguous.

## Reading `.cnv` in R

```r
library(oce)
cast <- oce::read.ctd.sbe(file)             # header + data
cast@metadata$station; cast@metadata$startTime
cast@metadata$longitude; cast@metadata$latitude   # from NMEA header if present
names(cast@data)                            # oce names (temperature, salinity, pressure …)
cast@metadata$dataNamesOriginal             # original .cnv names, for the mapping in variables.md

# Remove surface soak and upcast, if the file is not yet bin-averaged by direction:
down <- oce::ctdTrim(cast, method = "downcast")
# Bin to 1 dbar if the file is not binned:
binned <- oce::ctdDecimate(down, p = 1)
```

Check `?oce::read.ctd.sbe` for your installed version — argument names and header parsing
have changed between releases. Positions in `.cnv` headers come from NMEA strings (reliable)
or from operator-typed header lines (less reliable); if both exist and disagree, flag it.

## Down- vs upcast

- Profiles for analysis: **downcast** (sensors lead the package into undisturbed water).
- **Bottles close on the upcast.** Their CTD values come from the upcast (`.btl`), so compare
  bottles against upcast CTD data, or accept a small down/up difference in sharp gradients.

## Common problems

- **Pump-off scans** at the start of the cast: salinity nonsense near the surface → trim.
- **Salinity spikes** in sharp thermoclines from T–C misalignment → check the `AlignCTD`
  advance and cell-thermal-mass settings.
- **Wrong calibration file** (`.xmlcon` from another cruise) → systematic offsets across a
  whole cruise; compare with bottles.
- **Station metadata** typed by operators: inconsistent station names, missing leading zeros,
  local vs UTC time. Normalise at ingest; keep the original in `ingest_log.message`.
