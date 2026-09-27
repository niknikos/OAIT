# Sensitivity: categories, the register, and what may be shared

Most oceanographic data are eventually meant to be open — through national data centres,
SeaDataNet, ICES, or an institutional ERDDAP. That does not make every dataset open **now**,
and it never makes the agent the one who decides. This file sets out how OAIT decides what
it may produce from a dataset, and when it must stop and ask.

> **Principle:** the release decision belongs to the data owner and the institution. The
> agent's job is to keep raw data local, apply the recorded conditions consistently, and ask
> whenever the register does not settle the question.

## The four categories

Each category below says *why* it matters, what the agent does by default, and what it must
never do. Conditions differ between permits, agreements, and countries; the register entry
for a dataset always takes precedence over these defaults.

### 1. Foreign-EEZ research consent

**Why.** Marine scientific research in another state's EEZ or on its continental shelf needs
that coastal state's consent (UNCLOS Part XIII). Consent commonly comes with conditions:
sharing data and samples with the coastal state, delivering preliminary and final reports,
and sometimes limits on publication or international availability for results of direct
significance to resource exploration. The research permit is the authority, not a general rule.

**Default.** Treat as `restricted` until the register records the permit conditions. Keep
positions at the resolution the permit allows (if silent, ask). Note the coastal state in any
output that leaves the machine, where the permit requires attribution.

**Never.** Publish, share, or upload data or derived products that the permit reserves for
the coastal state or subjects to its prior approval.

### 2. Restricted or military areas

**Why.** High-resolution positions, depth/seabed information, and current or sound-speed
profiles near naval areas, harbours, and other restricted zones can be security-classified
under national law (for example, some countries restrict publication of detailed seabed and
depth data near their coasts). What counts as restricted is a legal question for the
institution's data manager or security officer, not for the agent.

**Default.** Treat as `restricted`. **Ask before producing anything position-bearing** —
station maps, cruise tracks, section plots with distance axes, even rounded coordinates.
Non-spatial aggregates (e.g. a mean T–S relationship with positions removed) may be
acceptable but still require the user's confirmation for this dataset.

**Never.** Put positions, tracks, or bathymetry from these areas into figures, tables, or
files that leave the data root without explicit, recorded approval. Never "helpfully" look
up whether an area is restricted by sending coordinates to an external service.

### 3. Unpublished data under PI embargo

**Why.** Data typically belong to a PI, project, or consortium until a release date or
publication. Early release can pre-empt a publication, breach a project agreement, or
simply undermine trust between collaborators.

**Default.** Treat as `internal` to the named people until `embargo_until` passes. **Derived
products are embargoed too** — a figure or a mean computed from embargoed data carries the
same embargo unless the PI has agreed otherwise (record that in `notes`).

**Never.** Include embargoed data or derived results in anything shared beyond the people the
register names, or in anything committed to a repository.

### 4. Partner and third-party data

**Why.** Data received from another institution, a company, or a monitoring network come
under a licence or data-sharing agreement. Common conditions: no redistribution, attribution
in a specified form, use limited to a named project, deletion at project end.

**Default.** Follow the `licence` and `partner_agreement` fields. If the agreement is not
recorded, treat as `restricted` and ask. Always carry the required attribution into outputs.

**Never.** Redistribute raw partner data, merge it into a shared product without checking the
agreement, or keep it beyond an agreed deletion date without raising it with the user.

## Share levels

| `share_level` | Raw data | Derived products (aggregates, figures, fits) | Positions |
|---|---|---|---|
| `public` | Only through the institution's approved archive route | Shareable, with attribution | Shareable at native resolution |
| `internal` | Stays on this machine / approved institutional storage | Within the institution and named partners | Rounded (default 0.1°) unless the user says otherwise |
| `restricted` | Stays on this machine | Only after the user confirms for this output | **Ask first**, every time |

When several datasets are combined, **the most restrictive share level wins**.

## The register

The register lives **outside the repo** at `~/OAIT_data/registry/datasets.yaml` (path in
`~/.oait/config.json` as `register_path`). It is metadata, but it can itself be sensitive —
a list of restricted-area datasets reveals where restricted work happened — so it is never
committed, pasted, or shared.

One entry per dataset. A *dataset* is the unit at which conditions apply: usually one
instrument type on one cruise or one deployment.

```yaml
# ~/OAIT_data/registry/datasets.yaml  — NOT in any repository
- dataset_id: CRUISE2025-01_ctd          # unique, used as a key in the store
  source: local                          # local | erddap
  erddap: null                           # {server: <name in config>, dataset: <ERDDAP datasetID>}
  instrument: ctd                        # ctd | adcp | met | bottle
  raw_path: raw/CRUISE2025-01/ctd        # relative to the data root (local only)
  owner: "PI name, institute"
  contact: "who to ask about release"
  licence: internal                      # e.g. CC-BY-4.0, internal, see-agreement
  share_level: restricted                # public | internal | restricted
  eez_consent:                           # null if not applicable
    coastal_state: "<state>"
    permit_ref: "<permit number>"
    conditions: "share data with coastal state; positions at 0.5° in publications"
  restricted_area: false                 # true → ask before any position-bearing output
  embargo_until: 2027-06-30              # null if none; derived products included
  partner_agreement: null                # {partner: ..., ref: ..., conditions: ..., delete_by: ...}
  position_resolution: 0.1               # degrees allowed in outputs; null → ask
  notes: "PI agreed to share cruise-mean profiles with project partners (email 2025-11-03)"
  registered_at: 2026-01-15
```

### How the agent uses the register

1. **Before producing an output**, find every `dataset_id` involved and read its entry.
2. **Unregistered dataset** → treat as `restricted`, tell the user, and offer to draft an
   entry (the user fills in owner, licence and conditions; you do not guess them).
3. **Combined datasets** → apply the most restrictive level and the union of conditions.
4. **Expired embargo** → do not silently relax it; mention it and let the user update the
   entry.
5. **State the basis** of any sharing decision in your reply ("share level `internal`,
   positions rounded to 0.1° per the register").

The store copies the register into a `datasets` table at each ingest, so queries can join on
it; the YAML file remains the source of truth.

## Degrading positions

When positions are allowed only at reduced resolution:

```r
round_to <- function(x, res) round(x / res) * res
stations_out <- stations |>
  mutate(lon = round_to(lon, 0.1), lat = round_to(lat, 0.1))
```

Rounding alone can leak a restricted position when only one or two stations fall into a grid
cell, or when a track is plotted at high temporal resolution. For restricted-area data,
removing positions entirely is safer than rounding; ask the user.

## ERDDAP-sourced data

Data retrieved from an ERDDAP server are registered like any other dataset. Public servers
(e.g. national or regional ERDDAPs) usually carry an explicit licence in the dataset metadata;
record it. An institutional ERDDAP may serve both public and access-controlled datasets —
the fact that you *can* retrieve a dataset with the user's credentials does not make it
public. Cached responses live in `~/OAIT_data/cache/erddap/` and inherit the dataset's
share level.
