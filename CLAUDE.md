# Fallen Below — notes for Claude

- Engine: Godot 4.7, GDScript, GL Compatibility renderer, 1280x720 canvas_items stretch.
- Design source of truth: `docs/GDD.md` (Russian). Update its checklist (section 12) when features land.
- Talk to the owner in Russian. In-game text is English for now (Steam audience); localization via `tr()` later.
- Prototype M0 lives in `scripts/main.gd` with primitive drawing. When moving to M1, split into `scripts/systems/` (loop, combat, cards, souls, heroes) and `data/` resources.
- GDScript gotcha: don't use `:=` on values read from Dictionaries (Variant) — declare explicit types.
