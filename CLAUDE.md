# Fallen Below — notes for Claude

- Engine: Godot 4.7, GDScript, GL Compatibility renderer, 1280x720 canvas_items stretch.
- Design source of truth: `docs/GDD.md` (Russian). Update its checklist (section 12) when features land.
- Talk to the owner in Russian. In-game text is English for now (Steam audience); localization via `tr()` later.
- Architecture: `run.gd` (root, clock, input) owns `RunState` (RefCounted, all run data + queries) and system Nodes in `scripts/systems/` that get `run` and `s` injected. View (`run_view.gd`) and HUD (`run_hud.gd`) only read state and call run/system methods. All data/balance in `scripts/data/game_data.gd`. Meta progression + save in autoload `Meta`.
- Use `const X = preload(...)` instead of `class_name` to avoid global-class cache issues. Systems must not preload `run.gd` (cycle); keep `var run` untyped.
- Drawing is still primitives; sprites come in M2.
- Concept: "Loop Hero in reverse" with a story (Order of Dawn vs. the Heart of the Abyss), 4 acts with bosses. Only Act I is playable. Story text lives in `game_data.gd` (STORY, WHISPERS, ACTS); `scenes/story.tscn` plays pages via `Meta.play_story()`.
- Map is procedurally generated each run in `run_state.gd` (`_random_region` → `_trace_ring` → `_commit_loop` + detours).
- Design rule from the owner: no mechanics for the sake of mechanics. Every feature must create a visible player decision tied to the core loop.
- GDScript gotcha: don't use `:=` on values read from Dictionaries (Variant) — declare explicit types.
