# Teledyne RDI ADCP files

Teledyne RDI instruments (WorkHorse, Sentinel V, Ocean Surveyor, Pinnacle, …) write the
binary **PD0** ensemble format. The platform determines which files exist and what
processing is needed.

## Platforms and files

| Platform | Acquisition software | Files | Notes |
|---|---|---|---|
| Moored (self-contained) | internal recorder | `*.000`, `*.001`, … (PD0) | beam, instrument or earth coordinates as configured |
| Vessel-mounted | VmDas | `.ENR` raw PD0; `.ENS` (after screening, with nav); `.ENX` (earth coordinates, single ping); `.STA` / `.LTA` (short/long-term averages); `.N1R`/`.N2R` raw NMEA | `.LTA` is the usual starting point; `.ENX` for custom averaging |
| Vessel-mounted | UHDAS (University of Hawaii) | own directory structure; CODAS database | process with UHDAS/CODAS (Python), then bring results into R |
| Lowered (LADCP) | BBTalk / LADCP software | PD0 from down- and up-looking heads | processing (e.g. LDEO IX) is a specialist task; import its output |
| Small-boat / river | WinRiver II | `.PD0`, `.mmt` | discharge-oriented |

All PD0 files carry, per ensemble: fixed leader (configuration), variable leader (time,
heading, pitch, roll, temperature, depth), velocity, correlation, echo intensity, percent
good, and optionally bottom track and navigation.

## Reading in R

```r
library(oce)
adp <- oce::read.adp.rdi(file)                 # PD0; reads all ensembles by default
adp <- oce::read.adp.rdi(file, from = 1, to = 5000, by = 1)   # subset: large files!

adp@metadata$oceCoordinate                     # "beam", "xyz", "enu", …
adp@metadata$frequency; adp@metadata$numberOfBeams
adp@metadata$cellSize; adp@metadata$bin1Distance
adp@metadata$orientation                       # "upward" / "downward"
dim(adp@data$v)                                # ensembles × bins × beams
```

Check `?oce::read.adp.rdi` for the arguments your version supports (`from`, `to`, `by`,
`tz`, `longitude`, `latitude`, …).

## Coordinate transforms

```r
adp_xyz <- oce::beamToXyzAdp(adp)       # if recorded in beam coordinates
adp_enu <- oce::xyzToEnuAdp(adp_xyz)    # needs heading/pitch/roll
# Rotate from magnetic to true north if the instrument did not apply declination (EB setting):
decl <- oce::magneticField(lon, lat, adp@data$time[1])$declination
adp_true <- oce::applyMagneticDeclination(adp_enu, declination = decl)
```

`oce::toEnu()` chains the first two steps. Record the declination and whether it was applied
in `adcp_deployments`. **Never apply declination twice** — check the instrument's EB command
setting (in the fixed leader / deployment log) first.

## Geometry

- **Bin centre distance** from the transducer = `bin1Distance + (bin − 1) × cellSize`.
  Depth = transducer depth ± that distance (− for upward-looking, + for downward-looking).
- **Blanking distance** hides the first metres after the transducer.
- **Side-lobe contamination**: the last ~(1 − cos θ) of the range to a boundary is unusable —
  ~6 % for the common 20° beam angle, ~13 % for 30°. Discard those bins plus one cell.
- **Moored instruments move**: knock-down in strong currents changes transducer depth; use
  the pressure sensor (if present) rather than the nominal deployment depth.

## Vessel-mounted specifics

- The instrument measures water velocity **relative to the ship**. Absolute velocity needs the
  ship's velocity from **bottom track** (in shallow water) or **GPS** navigation.
- Heading should come from the ship's gyro or GNSS heading, not the ADCP's internal compass
  (which is disturbed by the hull).
- Transducer misalignment angle and scale factor must be calibrated (bottom-track or
  water-track calibration); uncorrected misalignment shows as cross-track velocity bias that
  flips sign with ship direction.
- Data during turns and speed changes are noisy; flag or exclude them.

## Large files

A year-long moored record or a full cruise of VmDas data can be several GB and expand further
in memory (ensembles × bins × beams × variables). Read in chunks with `from`/`to`, reduce
(QC, rotate, average) per chunk, and write each chunk to Parquet. See
[`../performance.md`](../performance.md).
