extends RefCounted
## ABYSSAL GENESIS definitions (vertical slice). Immutable data, read through registry.gd.
## Every id is permanent: "<kind>.<name>". Never reuse an id; renames go to RENAMED.
## Player-facing strings are English source keys, shown with Loc.t(...).
## Numbers are first-pass placeholders until stage 04 balance (GDD 4.1, 5, 6, 8; Narrative Bible 10).

const SCHEMA := 3

## old id -> new id, applied when loading saves (TECH_SPEC 2.4)
const RENAMED := {}

const RESOURCES := {
	"resource.biomass": {"name": "Biomass", "desc": "Living matter digested from bodies. Builds organs, grows creatures, repairs tissue."},
	"resource.energy": {"name": "Energy", "desc": "The Heart's pulse. Pays upkeep for organs, creatures, nerve impulses and kept minds."},
	"resource.genome": {"name": "Genetic material", "desc": "Fragments of foreign code. Spent on mutations, experiments and new species."},
}

const ORGANS := {
	"organ.heart": {
		"name": "Heart Bud", "desc": "The heart of this sprout. If it dies, the sprout burns out.",
		"category": "central", "footprint": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"cost": {}, "hp": 400, "upkeep": {}, "produces": {"resource.energy": 3.0},
		"needs_channel": false, "ability": "nightfall", "slots": 2, "resist": {}, "weak": {"holy": 0.25},
	},
	"organ.stomach": {
		"name": "Stomach", "desc": "Digests bodies and minds into biomass and genetic material.",
		"category": "digestive", "footprint": [Vector2i(0, 0), Vector2i(1, 0)],
		"cost": {"resource.biomass": 20}, "hp": 120, "upkeep": {"resource.energy": 0.5}, "produces": {},
		"needs_channel": true, "ability": "rapid_digest", "slots": 1, "resist": {"poison": 0.5}, "weak": {"fire": 0.25},
	},
	"organ.incubator": {
		"name": "Incubator", "desc": "Grows creatures from biomass and genome. Shows the likely traits of each brood.",
		"category": "production", "footprint": [Vector2i(0, 0), Vector2i(1, 0)],
		"cost": {"resource.biomass": 30}, "hp": 100, "upkeep": {"resource.energy": 1.0}, "produces": {},
		"needs_channel": true, "ability": "urgent_brood", "slots": 1, "resist": {}, "weak": {"fire": 0.25},
	},
	"organ.nerve_node": {
		"name": "Nerve Node", "desc": "Generates nerve impulses and extends the reach of your commands.",
		"category": "transport", "footprint": [Vector2i(0, 0)],
		"cost": {"resource.biomass": 15, "resource.genome": 5}, "hp": 70, "upkeep": {"resource.energy": 0.5},
		"produces": {"impulse": 0.2}, "needs_channel": true, "ability": "impulse_wave", "slots": 1,
		"resist": {}, "weak": {"holy": 0.25},
	},
	"organ.sensor": {
		"name": "Sensor", "desc": "Foresees invasions and reveals nearby halls. Its Call chooses which faction you lure.",
		"category": "sensory", "footprint": [Vector2i(0, 0)],
		"cost": {"resource.biomass": 15}, "hp": 60, "upkeep": {"resource.energy": 0.5}, "produces": {},
		"needs_channel": true, "ability": "call", "slots": 1, "resist": {}, "weak": {"physical": 0.25},
	},
	"organ.regen_tissue": {
		"name": "Regenerative Tissue", "desc": "Slowly heals organs and channels around it.",
		"category": "support", "footprint": [Vector2i(0, 0)],
		"cost": {"resource.biomass": 25}, "hp": 80, "upkeep": {"resource.energy": 0.5}, "produces": {},
		"needs_channel": true, "ability": "emergency_regen", "slots": 1, "resist": {}, "weak": {"fire": 0.5},
	},
}

const SPECIES := {
	"species.bone_crawler": {
		"name": "Bone Crawler", "desc": "Armoured with bone. Holds a corridor while others strike.",
		"role": "defender", "stats": {"hp": 90, "atk": 6, "armor": 4, "speed": 0.6},
		"traits": ["trait.bone_armor"], "breed": {"kind": "egg", "time": 20.0, "cost": {"resource.biomass": 18}},
	},
	"species.blood_tick": {
		"name": "Blood Tick", "desc": "Drains life and infects whatever it bites.",
		"role": "parasite", "stats": {"hp": 30, "atk": 4, "armor": 0, "speed": 1.2},
		"traits": ["trait.drain", "trait.infect"], "breed": {"kind": "division", "time": 10.0, "cost": {"resource.biomass": 8}},
	},
	"species.devourer": {
		"name": "Devourer", "desc": "Hunts the wounded and grows with every kill.",
		"role": "hunter", "stats": {"hp": 60, "atk": 12, "armor": 1, "speed": 1.0},
		"traits": ["trait.execute", "trait.grow_on_kill"], "breed": {"kind": "egg", "time": 25.0, "cost": {"resource.biomass": 25, "resource.genome": 5}},
	},
	"species.nerve_stalker": {
		"name": "Nerve Stalker", "desc": "Unseen until it strikes. The first blow lands hardest.",
		"role": "ambusher", "stats": {"hp": 45, "atk": 10, "armor": 0, "speed": 1.1},
		"traits": ["trait.stealth", "trait.first_strike"], "breed": {"kind": "egg", "time": 22.0, "cost": {"resource.biomass": 20, "resource.genome": 8}},
	},
	"species.lymphatic": {
		"name": "Lymphatic", "desc": "Mends creatures and channels nearby.",
		"role": "support", "stats": {"hp": 50, "atk": 2, "armor": 1, "speed": 0.8},
		"traits": ["trait.heal_aura"], "breed": {"kind": "spore", "time": 18.0, "cost": {"resource.biomass": 15, "resource.genome": 3}},
	},
}

const TRAITS := {
	"trait.bone_armor": {"name": "Bone armour", "desc": "Physical damage taken is reduced."},
	"trait.drain": {"name": "Drain", "desc": "Heals for part of the damage dealt."},
	"trait.infect": {"name": "Infection", "desc": "Hits apply infection."},
	"trait.execute": {"name": "Execute", "desc": "Deals extra damage to wounded targets."},
	"trait.grow_on_kill": {"name": "Gorge", "desc": "Each kill grants maximum health."},
	"trait.stealth": {"name": "Stealth", "desc": "Invisible until it attacks, unless the enemy can see hidden things."},
	"trait.first_strike": {"name": "First strike", "desc": "The first attack from stealth deals double damage."},
	"trait.heal_aura": {"name": "Mending", "desc": "Heals nearby creatures and channels."},
}

## Every mutation has a cost or drawback (GDD 8).
const MUTATIONS := {
	"mutation.bone_plate": {"name": "Bone Plate", "desc": "+3 armour.", "drawback": "-15% speed.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 10}, "requires": [], "excludes": []},
	"mutation.acid_blood": {"name": "Acid Blood", "desc": "Attackers take damage when they hit.", "drawback": "-10% maximum health.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 12}, "requires": [], "excludes": []},
	"mutation.fireproof_shell": {"name": "Fireproof Shell", "desc": "Fire damage halved.", "drawback": "Healing received -25%.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 14}, "requires": [], "excludes": []},
	"mutation.swift_tendons": {"name": "Swift Tendons", "desc": "+30% speed.", "drawback": "-1 armour.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 8}, "requires": [], "excludes": ["mutation.bone_plate"]},
	"mutation.spore_sac": {"name": "Spore Sac", "desc": "On death releases spores that slow enemies.", "drawback": "+20% biomass cost to breed.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 10}, "requires": [], "excludes": []},
	"mutation.dark_sight": {"name": "Dark Sight", "desc": "Sees hidden enemies.", "drawback": "Takes +25% holy damage.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 9}, "requires": [], "excludes": []},
	"mutation.regenerative_tissue": {"name": "Regenerative Tissue", "desc": "Regenerates 1% health per second.", "drawback": "+0.3 energy upkeep.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 12}, "requires": [], "excludes": []},
	"mutation.dense_tissue": {"name": "Dense Tissue", "desc": "+25% maximum health.", "drawback": "-10% damage.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 10}, "requires": [], "excludes": []},
	"mutation.nerve_insulation": {"name": "Nerve Insulation", "desc": "Immune to stun and the Executioner's dampening.", "drawback": "Nerve impulses cost +1 on this target.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 15}, "requires": [], "excludes": []},
	"mutation.predator_instinct": {"name": "Predator Instinct", "desc": "+25% damage against wounded enemies.", "drawback": "Ignores Protect commands while prey is near.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 11}, "requires": [], "excludes": []},
}

const FACTIONS := {
	"faction.order": {"name": "Order of Dawn", "desc": "They burn what they cannot understand and carry the light down into the dark."},
}

const ENEMIES := {
	"enemy.pilgrim": {"name": "Pilgrim", "desc": "Scouts the halls. Brings a mind worth keeping.",
		"faction": "faction.order", "goal": "scout", "stats": {"hp": 40, "atk": 3, "armor": 0, "speed": 0.9},
		"counters": [], "sees_hidden": false, "sentient": true},
	"enemy.knight": {"name": "Knight", "desc": "Hallowed blade. Cuts organs open.",
		"faction": "faction.order", "goal": "organ", "stats": {"hp": 110, "atk": 12, "armor": 4, "speed": 0.7},
		"counters": ["holy"], "sees_hidden": false, "sentient": true},
	"enemy.burner": {"name": "Burner Priest", "desc": "Sets organs alight. Sees what hides in the dark.",
		"faction": "faction.order", "goal": "organ", "stats": {"hp": 60, "atk": 8, "armor": 1, "speed": 0.8},
		"counters": ["fire"], "sees_hidden": true, "sentient": true},
}

const BOSSES := {
	"boss.iron_executioner": {
		"name": "Iron Executioner", "desc": "Brother Kassian. His armour has not let him feel anything for twenty years.",
		"faction": "faction.order", "biome": "biome.catacombs", "stats": {"hp": 900, "atk": 20, "armor": 8, "speed": 0.6},
		"phases": [
			{"hp_below": 1.0, "abilities": ["brand_organ"], "telegraph": 2.0},
			{"hp_below": 0.66, "abilities": ["brand_organ", "dampen_nerves"], "telegraph": 2.5},
			{"hp_below": 0.33, "abilities": ["unhelmed_fury"], "telegraph": 1.5},
		],
		"decision": "decision.E2",
	},
}

const BIOMES := {
	"biome.catacombs": {"name": "Forgotten Catacombs", "desc": "Bone, candles and narrow passages. The old bones are minerals.",
		"act": 1, "boss_id": "boss.iron_executioner", "factions": ["faction.order"]},
}

## Key story decisions (Narrative Bible 14.1). Options must match tools/narrative_check.py.
const DECISIONS := {
	"decision.Z1": {"name": "Aurelia at the wall", "act": 1, "options": ["let_speak", "silence"]},
	"decision.E2": {"name": "Kassian's mind", "act": 1, "options": ["archive", "digest"]},
}
