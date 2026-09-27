# Quality control: flag scheme, tests, and what to accept

Every quantitative answer depends on which values you let through. OAIT stores QC flags
rather than deleting data, so the decision stays visible and reversible. **State the flags
you accepted in every answer** ("values flagged 1–2 only").

## Flag scheme in the store

OAIT stores flags as the **SeaDataNet L20** integer codes, which the European data centres
use and which map cleanly from the other common schemes.

| Code | Meaning | Default use in analysis |
|---|---|---|
| 0 | no QC performed | include, but say QC was not performed |
| 1 | good | include |
| 2 | probably good | include |
| 3 | probably bad | exclude |
| 4 | bad | exclude |
| 5 | changed (corrected value) | include; say it was corrected |
| 6 | below detection limit | handle explicitly (not as zero, not as NA) |
| 7 | in excess of quoted value | handle explicitly |
| 8 | interpolated | include only if interpolation is acceptable for the question |
| 9 | missing | exclude |

Mapping at ingest:

| Source scheme | → L20 |
|---|---|
| IOOS QARTOD 1 pass / 2 not evaluated / 3 suspect / 4 fail / 9 missing | 1 / 0 / 3 / 4 / 9 |
| Argo 0 / 1 / 2 / 3 / 4 / 5 / 8 / 9 | 0 / 1 / 2 / 3 / 4 / 5 / 8 / 9 |
| Sea-Bird `flag` column (0 good, otherwise bad) | 0 → keep with 0; non-zero → 4 |
| Server-specific (ERDDAP) | read `flag_values` / `flag_meanings`, map explicitly, record the mapping |

A standard filter that keeps missing flags visible:

```r
good <- c(0, 1, 2, 5)
ctd_profiles |>
  filter(temperature_qc %in% good, practical_salinity_qc %in% good)
```

(`%in%` on a lazy table becomes SQL `IN`, which excludes `NULL` flags. If un-flagged rows
should count as "no QC performed", fill them with 0 at ingest rather than relying on `NULL`.)

## Tests by instrument

Thresholds below are **starting points** and depend on region, season and instrument; the
IOOS QARTOD manuals (temperature/salinity, currents, winds, dissolved oxygen) give fuller
guidance and are worth reading before settling thresholds for a programme.

### CTD profiles

| Test | What it catches | Notes |
|---|---|---|
| Gross range | sensor failure, unit slips | e.g. T −2.5…40 °C, SP 0…42; tighten regionally |
| Climatology / regional range | plausible but wrong values | needs a regional reference |
| Spike | single-scan glitches | compare to neighbours: \|x − (x₋ + x₊)/2\| − \|(x₊ − x₋)/2\| |
| Gradient / density inversion | T–C misalignment, salinity spikes in sharp thermoclines | small inversions (~0.03 kg m⁻³) can be real in mixed layers |
| Pressure monotonic (loop edit) | ship heave causing the CTD to re-sample water | Sea-Bird `LoopEdit`, or drop scans with decreasing pressure on the downcast |
| Surface soak | pump not yet on, sensors not equilibrated | drop scans before the pump turns on and the initial soak |
| Dual-sensor difference | drift or fouling in one sensor pair | persistent ΔSP > ~0.01 or ΔT > ~0.005 °C deserves a look |
| Bottle comparison | conductivity and oxygen drift | the calibration check; see [`../skills/ocean-bottle/SKILL.md`](../skills/ocean-bottle/SKILL.md) |

### ADCP (Teledyne RDI)

| Test | What it catches | Typical starting point |
|---|---|---|
| Correlation | low signal coherence | beam correlation < 64 counts (WorkHorse default) → bad |
| Echo intensity | beyond useful range; fish; bottom/surface | sharp rise near boundaries; single-beam spikes suggest fish |
| Percent good | too few good pings in the ensemble | configuration-dependent; record the threshold used |
| Error velocity | inhomogeneous flow across beams | flag \|err\| > a multiple of its standard deviation |
| Side-lobe contamination | reflection from surface/bottom | discard the last ~6 % of the range to the boundary for 20° beams: range × (1 − cos θ) plus one cell |
| Tilt | instrument knocked over | pitch/roll beyond ~20° (manufacturer limit) |
| Heading / declination | rotation to the wrong north | verify `declination_applied`; compare with known flow direction |
| Vessel-mounted: bottom track / GPS | ship velocity not removed correctly | large residual in along-track velocity near turns |

### Meteorology

| Test | What it catches | Notes |
|---|---|---|
| Gross range | sensor failure | e.g. RH 0–100 %, pressure 900–1070 hPa |
| Rate of change | spikes, logger resets | variable-specific |
| Persistence / flatline | frozen sensor, iced anemometer | identical values over many intervals |
| Flow distortion (ships) | wind obstructed by superstructure | flag relative-wind directions from the obstructed sector |
| Night-time radiation offset | pyranometer zero offset | shortwave should be ≈ 0 at night |

### Niskin bottles

| Test | What it catches |
|---|---|
| Mis-trip | a bottle closed at the wrong depth: bottle value matches another depth's CTD value |
| Leaking bottle | salinity/oxygen offset relative to CTD larger than neighbouring bottles |
| Replicate agreement | analytical problems (Winkler replicates, salinometer runs) |
| Detection limit | nutrients near zero: flag 6, never substitute zero silently |

## Sanity-checking extremes

For "highest / lowest / strongest" questions, the single extreme is the value most likely to
be a spike, a unit slip, or a bad scan. Pull the **top ~10** in DuckDB, check each against:

1. its QC flag;
2. physical bounds and the regional range;
3. its neighbours (adjacent pressure bins, adjacent ensembles, adjacent timestamps);
4. clustering — several extremes from the same cast, deployment or file point to a
   systematic problem (wrong calibration file, unit slip for a whole file), not to nature.

Report the largest **plausible** value and list the rejected candidates with the likely
reason, so the user can check the source file.
