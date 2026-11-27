extends Node
## ABYSSAL GENESIS event bus (TECH_SPEC 2.3). Registered as autoload "Bus".
## Systems emit facts here; UI, audio, narrative and the threat log listen.
## Fallen Below code does not use it.

signal organ_damaged(uid: int, amount: float, kind: String)
signal organ_state_changed(uid: int, state: String)
signal creature_born(uid: int, species_id: String)
signal creature_died(uid: int, cause: String)
signal mind_released(uid: int, enemy_id: String)
signal mind_resolved(uid: int, choice: String)   # digest / archive / zero
signal invasion_started(squad_id: int, faction_id: String)
signal boss_phase(boss_id: String, phase: int)
signal decision_made(decision_id: String, option: String)
signal memory_found(memory_id: String)
signal resources_changed(delta: Dictionary)
signal saved(kind: String, ok: bool)
