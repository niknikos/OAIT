---
name: oait-update
description: Update OAIT to the latest version — git pull the OAIT repo and re-sync the skills into the global skills folders. Use when the user says "update OAIT", "pull the latest OAIT", or asks for new recipes/skills.
---

# Update OAIT

1. **Find the repo**: `oait_path` in `~/.oait/config.json`. If OAIT isn't installed, switch
   to [`../oait-install/SKILL.md`](../oait-install/SKILL.md).
2. **Protect local work**: `git -C "<oait_path>" status`. If the user has local changes (e.g.
   draft recipes), don't clobber them — commit, stash, or pull on a clean tree.
3. **Pull**:
   ```bash
   git -C "<oait_path>" pull --ff-only
   ```
4. **Re-sync skills** to the folders listed in `skills_synced_to`:
   ```bash
   cp -R "<oait_path>/skills/." ~/.claude/skills/
   cp -R "<oait_path>/skills/." ~/.codex/skills/
   ```
   (Windows: `Copy-Item -Recurse -Force "<oait_path>/skills/*" "$HOME/.claude/skills/"`.)
   This overwrites OAIT-managed skill folders only (`oait-*`, `ocean-*`).
5. **Check the knowledge link** (a symlink tracks `git pull` automatically):
   ```bash
   [ -L ~/.claude/oait-knowledge ] || ln -sfn "<oait_path>/oait-knowledge" ~/.claude/oait-knowledge
   ```
   If it was copied (Windows without symlink rights), re-copy it.
6. **Make sure the hook is enabled** (it stamps the version and blocks data commits):
   ```bash
   git -C "<oait_path>" config core.hooksPath .githooks
   ```
7. **Report what changed**:
   ```bash
   cat "<oait_path>/VERSION"
   git -C "<oait_path>" log --oneline -5
   ```
8. **Store compatibility.** If the update changed [`../../oait-knowledge/data-model.md`](../../oait-knowledge/data-model.md)
   (a schema change), tell the user, and offer a rebuild of the affected store tables from
   `raw/` via [`../ocean-ingest/SKILL.md`](../ocean-ingest/SKILL.md). Never alter the store
   in place to match a new schema.

Preserve every existing field in `~/.oait/config.json`, including `privacy_onboarded_at`.
