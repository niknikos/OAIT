---
name: ocean-privacy
description: Guide safe handling of oceanographic data with AI agents — model-training opt-out, keeping raw data local, the sensitivity register (foreign-EEZ consent, restricted/military areas, PI embargo, partner data), registering datasets, and deciding what outputs may be shared. Use during onboarding, when registering a dataset, for privacy or sharing questions, and before producing any position-bearing or shareable output.
---

# Handling oceanographic data safely

OAIT's promise: **raw data stay on the user's machine, never train a model, and are released
only by the people entitled to release them.** Full rules:
[`../../oait-knowledge/sensitivity.md`](../../oait-knowledge/sensitivity.md).

> A coding agent does not train on data by reading it. Training happens only if data are
> sent to a provider **and** the provider may retain/train on them. OAIT closes both doors,
> and adds a third: the register, which records what each dataset's owners have agreed.

## Onboarding check (blocking, once per machine/agent)

1. Training / data retention is **off** for the agent in use.
2. The data root is **outside** any repository and not in an unapproved cloud-synced folder.
3. The user knows unregistered data are treated as **restricted**.

Record `privacy_onboarded_at` in `~/.oait/config.json`. After that, routine local work is not
re-gated in each session.

## Routine use (non-blocking, but register-aware)

1. **Look up the register** for every dataset in the task. This is cheap and is what makes
   the rest possible.
2. **Proceed with local analysis** within the dataset's share level.
3. **Pause and ask** when:
   - a dataset is **unregistered**;
   - the output is **position-bearing** (map, track, section, coordinate table) and any
     dataset has `restricted_area: true`, `position_resolution: null`, or `share_level:
     restricted`;
   - the output will **leave the machine** (email, report, repository, website) and any
     dataset is embargoed, partner-restricted, or under EEZ conditions;
   - an **embargo date has passed** (don't relax it silently; let the user update the entry).
4. **State the basis** of any sharing decision in your reply.

The hard block is **sending raw data out of the machine**, or **producing restricted outputs
without confirmation**. A missing fresh training-toggle confirmation in the current chat is
not, by itself, a reason to block routine local work.

## Registering a dataset

When the user brings in new data (or you meet an unregistered `dataset_id`):

1. Propose an entry using the template in
   [`sensitivity.md`](../../oait-knowledge/sensitivity.md) → "The register", pre-filled only
   with what you can read from the files (instrument, cruise, dates, raw path).
2. **Ask the user for the rest** — owner, licence, share level, EEZ permit and conditions,
   restricted-area status, embargo date, partner agreement, allowed position resolution.
   **Do not guess these**: a wrong guess in the permissive direction is a breach, and a
   wrong guess in the restrictive direction silently blocks legitimate work.
3. Write the entry to `registry/datasets.yaml` (outside the repo) only after the user
   confirms it.
4. Remind the user that the register itself is sensitive and must not be committed or shared.

## Turning off training / retention (verify — UIs change)

- **Claude / Claude Code (consumer):** privacy settings — disable the model-improvement /
  training option. **API / Team / Enterprise / Bedrock / Vertex:** inputs are not used for
  training by default; zero-data-retention can be arranged.
- **OpenAI / Codex / ChatGPT:** data controls — turn off model improvement. API usage is not
  used for training by default.
- **Other agents:** find the equivalent "privacy mode" / "do not train" / ZDR setting.

Point the user to the provider's current page and have them confirm; don't assert exact menus.

## Outputs

- **Aggregates, climatologies, fitted parameters, figures without positions**: generally
  shareable **within the dataset's share level**.
- **Raw records, profiles, precise positions**: stay local.
- **Maps and sections** of restricted-area data: ask every time.
- **Embargoed data**: derived products are embargoed too.
- **Partner data**: carry the required attribution; don't redistribute raw data.
- **Combined datasets**: the most restrictive entry governs.

## Sharing with colleagues

A deliberate act, not something routed through the agent: export to a file outside the repo,
transfer through the institution's approved channels, and note what, to whom and why (the
register's `notes` field is a good place). Formal archiving (national data centre,
SeaDataNet, ICES, public ERDDAP) follows the institution's submission route.

## If something leaks

Tell the user immediately and stop. Help them remove the exposed copy, revoke any shared
access, and report through the institution's data-handling route. For EEZ-consent or partner
data, the permit or agreement may require notifying the coastal state or partner. Data sent to
an external service may persist after deletion.
