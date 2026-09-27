---
title: <short imperative title, e.g. "T–S diagram for a cruise">
questions:
  - "<a natural-language question this recipe answers>"
  - "<a paraphrase the agent might also see>"
instruments: [ctd]        # ctd | adcp | met | bottle
source: store             # store | erddap | file
tables: [ctd_casts, ctd_profiles]
packages: [tidyverse, duckdb, gsw]
position_bearing: false   # true → the recipe must check the register before output
status: draft             # draft (not yet run on real files) | validated (<who>, <date>, <oait version>)
tags: [plot]              # query | plot | map | qc | calibration | ingest
---

# <Title>

**Answers:** <one-line restatement of the question(s).>

## Approach

<2–4 sentences: which tables, key columns, QC flags accepted, unit/scale choices.>

## Register check

<Which register fields matter for this output (share level, restricted area, embargo,
position resolution) and what the recipe does with them.>

## Code

```r
library(tidyverse); library(DBI); library(duckdb)
cfg <- jsonlite::read_json(path.expand("~/.oait/config.json"))
con <- dbConnect(duckdb::duckdb(), dbdir = path.expand(cfg$store_path), read_only = TRUE)

# ... the query / plot ...

dbDisconnect(con, shutdown = TRUE)
```

## Expected output

<Describe the SHAPE of the result — columns, row count order of magnitude, plot type.
Use rounded or synthetic numbers ONLY. Never paste real records, profiles or positions.>

## Notes & caveats

- <scales (SP/SA), QC choice, down/upcast, time zone, declination, averaging, etc.>

## Related

- Skill: `skills/<skill>/SKILL.md`
- Recipes: `<other-recipe>.md`
