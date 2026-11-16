# Recipe library builder (for future library updates)

These Python scripts built the app's built-in recipe library (`assets/seed/recipes.json` + `assets/photos/`).

Pipeline: `fetch_all` (Wikibooks download, not included — re-download with wb.py) → `parse.py` → `classify.py` →
curation (`curated/*.json`, one file per cuisine: chosen Wikibooks pages + original recipes) → `merge.py` →
photo finders (`photos.py`, `photos_wp.py`, picks in `photo_override.json`, rejects in `photo_reject.json`) → `build_seed.py`.

To ship more recipes: add entries to a `curated/*.json` file, bump `LIB_VERSION` in `build_seed.py`, rebuild, and
release a new app version. Installed apps add the new recipes on update without touching the user's own edits.
