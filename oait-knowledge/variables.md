# Variables, names and units

Translate plain-English terms into store column names, and know which scale each one is on.
Most errors in oceanographic analysis are not coding errors; they are scale errors
(practical vs Absolute Salinity, pressure vs depth, true vs magnetic north, "from" vs "to").

## Store columns

| Plain English | Store column | Unit | Scale / convention | CF `standard_name` (for export) |
|---|---|---|---|---|
| pressure | `pressure` | dbar | sea pressure (absolute − 10.1325 dbar) | `sea_water_pressure_due_to_sea_water` |
| depth | `depth` | m, positive down | from pressure via `gsw_z_from_p()` | `depth` |
| temperature (in situ) | `temperature` | °C | ITS-90 | `sea_water_temperature` |
| conductivity | `conductivity` | S m⁻¹ | — | `sea_water_electrical_conductivity` |
| salinity (practical) | `practical_salinity` | unitless | PSS-78 (SP) | `sea_water_practical_salinity` |
| Absolute Salinity | `absolute_salinity` | g kg⁻¹ | TEOS-10 (SA) | `sea_water_absolute_salinity` |
| Conservative Temperature | `conservative_temperature` | °C | TEOS-10 (CT) | `sea_water_conservative_temperature` |
| potential density anomaly | `sigma0` | kg m⁻³ | TEOS-10, ref. 0 dbar (σ₀ = ρ − 1000) | `sea_water_sigma_theta` (approx.) |
| dissolved oxygen | `oxygen` | µmol kg⁻¹ | — | `moles_of_oxygen_per_unit_mass_in_sea_water` |
| chlorophyll fluorescence | `fluorescence` | sensor units (e.g. mg m⁻³ nominal) | **not** chlorophyll unless calibrated against bottles | — |
| turbidity | `turbidity` | NTU / FTU | — | `sea_water_turbidity` |
| PAR | `par` | µmol photons m⁻² s⁻¹ | — | `downwelling_photosynthetic_photon_flux_in_sea_water` |
| eastward current | `u` | m s⁻¹ | earth coordinates, **true** north | `eastward_sea_water_velocity` |
| northward current | `v` | m s⁻¹ | earth coordinates, true north | `northward_sea_water_velocity` |
| vertical current | `w` | m s⁻¹ | positive up | `upward_sea_water_velocity` |
| air temperature | `air_temperature` | °C | at sensor height (see `met_stations`) | `air_temperature` |
| relative humidity | `relative_humidity` | % | — | `relative_humidity` |
| air pressure | `air_pressure` | hPa | station level unless column says `_msl` | `air_pressure` |
| wind speed | `wind_speed` | m s⁻¹ | at sensor height, true (earth-referenced) | `wind_speed` |
| wind direction | `wind_direction` | degrees true | direction wind blows **from** | `wind_from_direction` |
| shortwave radiation | `shortwave_down` | W m⁻² | downwelling | `surface_downwelling_shortwave_flux_in_air` |
| sea surface temperature | `sea_surface_temperature` | °C | sensor depth in `met_stations` | `sea_surface_temperature` |
| time | `time` / `time_start` | POSIXct | **UTC** | `time` |
| longitude / latitude | `lon` / `lat` | decimal degrees | WGS84; lon −180…180 | `longitude` / `latitude` |

## Sea-Bird `.cnv` names → store columns

`oce::read.ctd.sbe()` renames many of these automatically (`t090C` → `temperature`,
`sal00` → `salinity`, `prDM` → `pressure`); check `names(cast@data)` and the
`cast@metadata$dataNamesOriginal` mapping rather than assuming.

| `.cnv` name | Meaning | Store column |
|---|---|---|
| `prDM` / `prdM` | pressure, Digiquartz / strain gauge | `pressure` |
| `depSM` | depth, salt water, m | recompute with `gsw` instead |
| `t090C`, `t190C` | temperature ITS-90, primary / secondary | `temperature`, `temperature_2` |
| `t068C` | temperature IPTS-68 | convert: T90 = T68 / 1.00024 |
| `c0S/m`, `c1S/m` | conductivity S m⁻¹ | `conductivity`, `conductivity_2` |
| `c0mS/cm` | conductivity mS cm⁻¹ | ÷ 10 → S m⁻¹ |
| `sal00`, `sal11` | practical salinity, primary / secondary | `practical_salinity`, `practical_salinity_2` |
| `sbeox0ML/L`, `sbeox0Mm/Kg`, `sbox0Mm/Kg` | SBE 43 oxygen, ml l⁻¹ or µmol kg⁻¹ | `oxygen` (convert to µmol kg⁻¹) |
| `flECO-AFL`, `flC`, `wetStar` | fluorescence | `fluorescence` |
| `turbWETntu0` | turbidity | `turbidity` |
| `par`, `par/log` | PAR | `par` |
| `sigma-é00`, `sigma-t00` | EOS-80 density anomalies | recompute `sigma0` with `gsw` |
| `timeS`, `timeJ`, `scan` | elapsed time, Julian day, scan count | provenance only |
| `flag` | Sea-Bird bad-scan flag (0 good) | drop rows with `flag != 0` |

## Conversions you will need

```r
library(gsw)
# lon/lat in decimal degrees, p in dbar, SP practical salinity, t in-situ °C (ITS-90)
SA   <- gsw_SA_from_SP(SP, p, lon, lat)
CT   <- gsw_CT_from_t(SA, t, p)
sig0 <- gsw_sigma0(SA, CT)
z    <- gsw_z_from_p(p, lat)      # height, NEGATIVE below the surface
depth <- -z

# Oxygen ml/l -> µmol/kg (needs potential density; 44.6596 µmol per ml of O2)
rho_theta <- gsw_rho(SA, CT, 0)   # kg m^-3
oxygen_umolkg <- oxygen_mll * 44.6596 * 1000 / rho_theta
```

## Conventions that cause silent errors

- **Salinity.** Store both SP (what the instrument measures) and SA (TEOS-10). Report which
  one a figure shows. Archives (e.g. SeaDataNet, WOD) generally hold SP.
- **Density.** Compute from SA and CT with `gsw`; do not reuse `.cnv` `sigma-t` or
  `sigma-theta` columns, which are EOS-80.
- **Pressure vs depth.** Keep pressure as the vertical coordinate for CTD work; derive depth
  only for display or for joining to depth-referenced data. The difference is ~1 % at
  1000 dbar — small, but enough to misalign bins.
- **North.** ADCP compasses measure magnetic heading; velocities must be rotated to true
  north with the magnetic declination at the deployment time and place. `adcp_deployments.
  declination_applied` records whether that was done.
- **Direction.** Currents are reported as the direction they flow **to**; winds as the
  direction they blow **from**. When comparing wind and current, convert one of them.
- **Time.** Store UTC. Ship logs and some loggers record local time; convert at ingest and
  write the offset into `ingest_log.message`.
- **Longitude.** Store −180…180. Some ERDDAP grids use 0…360.
