---
name: ocean-maps
description: Make station maps, cruise tracks, mooring location maps and section location maps for oceanographic data in R (ggOceanMaps for static, leaflet kept local for interactive), with register-driven position handling for restricted, EEZ-consent and embargoed data. Use for any map or position-bearing figure.
---

# Maps and position-bearing figures

**Every map is a position disclosure.** Check the register before drawing anything:
[`sensitivity.md`](../../oait-knowledge/sensitivity.md).

## Decide what may be shown

For each dataset on the map:

| Register says | Do |
|---|---|
| `share_level: public` | map at native resolution |
| `internal`, `position_resolution` set | round positions to that resolution; say so in the caption |
| `restricted`, or `restricted_area: true`, or resolution `null` | **ask the user** before producing the map; offer alternatives (no positions, regional summary, map for internal use only) |
| EEZ consent with conditions | follow the permit's position/attribution conditions; name the coastal state if required |
| Unregistered | treat as restricted; ask |

Combined maps take the most restrictive entry. A map "for my own use" stays in the data root
or an `outputs/` folder that is git-ignored — never in a repository.

## Static station map (ggOceanMaps)

```r
library(ggOceanMaps)

stations <- ctd_casts |>
  filter(cruise == "<cruise>", direction == "down") |>
  select(dataset_id, station, lon, lat) |>
  collect() |>
  mutate(lon = round(lon / res) * res, lat = round(lat / res) * res) |>   # per register
  distinct()

basemap(data = stations, bathymetry = TRUE) +
  geom_spatial_point(data = stations, aes(lon, lat), colour = "red", size = 1.5) +
  labs(caption = glue::glue("Positions rounded to {res}°"))
```

`basemap()` picks limits from `data`; pass `limits = c(lon_min, lon_max, lat_min, lat_max)` to
fix them. Check `?ggOceanMaps::basemap` for bathymetry options in your installed version.

## Cruise tracks and moving platforms

Ship tracks (VMADCP, ship-met, underway) are dense position records. Thin them for display
(e.g. one point per 10 min), and apply the same register rules. For restricted data, a track
is rarely acceptable even when rounded, because the sequence of points reveals the route.

## Interactive maps (leaflet)

Fine for local exploration. **Do not publish** leaflet HTML built from internal or restricted
data (it embeds the coordinates in the file). Save it outside any repository and remind the
user that the HTML contains the positions.

## Map projections and areas

High latitudes: use ggOceanMaps' polar projections (it chooses one automatically from the
limits). For sections, draw the section line and station ticks on a small inset map; state
whether distance along the section is great-circle distance.
