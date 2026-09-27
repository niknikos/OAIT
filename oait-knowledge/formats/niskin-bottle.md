# Niskin bottle data

Bottle data join two worlds: the **CTD's record of where and when each bottle closed**, and
the **laboratory's results** for water drawn from it, often weeks later and in a spreadsheet.
Most errors happen at the join.

## Sources

| Source | Content | Key fields |
|---|---|---|
| Sea-Bird `.btl` | one block per bottle: mean (`avg`) and standard deviation (`sdev`) of CTD channels over the scans around closure | bottle position, date/time, pressure, T, C, SP, O₂ … |
| Sea-Bird `.bl` | scan numbers of each bottle fire | bottle position, scan |
| Rosette/deck log | operator's record of intended depths, misfires, leaks | station, cast, bottle, comments |
| Lab sheets | salinometer salinity, Winkler oxygen, nutrients, chl-a, … | station, cast, bottle (or sample number), value, unit, replicate, method |

## Reading `.btl`

The `.btl` layout: header lines beginning `*` and `#`; two lines of column names; then two
lines per bottle — the first with `(avg)` and the date, the second with `(sdev)` and the time.
Column positions are fixed-width and depend on the channels selected, so parse from the
column-name lines rather than hard-coding widths. **Validate any reader on your own files**
(bottle count equals `.bl` fires; pressures match the deck log) before trusting it. Check
whether your installed `oce` version offers a `.btl` reader before writing your own.

## The join key

`cruise + station + cast + niskin` (rosette position) is the reliable key. Lab sheets often
use a **sample number** instead; keep the lab's sample-number → (station, cast, niskin)
mapping as part of the raw archive, and join through it. Never join on depth — nominal and
actual trip depths differ.

## Checks before using bottle data

1. **Every bottle in the lab sheet exists in the `.btl`** (and vice versa, allowing for
   bottles not sampled). Report mismatches; do not drop them silently.
2. **Mis-trips**: a bottle whose value matches the CTD at a different depth closed in the wrong
   place. Compare bottle salinity/oxygen to the upcast CTD profile, not only at the nominal
   depth.
3. **Leaks**: offsets larger than neighbouring bottles, often towards surface values.
4. **Replicates**: summarise (mean, spread) before use; flag poor replicate agreement.
5. **Detection limits** (nutrients): keep below-detection values flagged (L20 flag 6), with the
   limit recorded; do not substitute zero.

## CTD calibration against bottles

Bottle salinity (salinometer) and oxygen (Winkler) are the **reference** for CTD conductivity
and SBE 43 oxygen:

- Compute residuals `bottle − CTD` at each closure, using the **upcast** CTD value at the
  bottle's pressure (the `.btl` mean).
- Exclude bottles in strong gradients (large `sdev` in the `.btl`), mis-trips, and leaks —
  record the rule used.
- Look for structure: a residual trend with pressure, station (time), or temperature
  suggests a correction (e.g. a linear conductivity correction with pressure). A flat,
  scattered residual cloud around a small mean suggests none is needed.
- A correction is a decision with consequences for everything derived from the CTD; propose
  it, show the evidence, and let the user decide. Never apply it silently.
