extends RefCounted
## ABYSSAL GENESIS definitions (vertical slice). Immutable data, read through registry.gd.
## Every id is permanent: "<kind>.<name>". Never reuse an id; renames go to RENAMED.
## Player-facing strings are English source keys, shown with Loc.t(...).
## Numbers are first-pass placeholders until stage 04 balance (GDD 4.1, 5, 6, 8; Narrative Bible 10).

const SCHEMA := 3

## old id -> new id, applied when loading saves (TECH_SPEC 2.4)
const RENAMED := {}

## Economy constants (GDD 5). Rates are per second.
const ECONOMY := {
	"start": {"resource.biomass": 120.0, "resource.energy": 40.0, "resource.genome": 20.0},
	"channel_cost": {"resource.biomass": 2},
	"reabsorb_refund": 0.5,        # share of the organ's cost returned when the player reabsorbs it
	"digest_speed": 3.0,           # body mass digested per second by one Stomach
	"regen_heal": 2.0,             # hp per second healed by Regenerative Tissue on each organ in range
	"regen_range": 3,              # cells (Chebyshev) from any cell of the tissue
	"regen_cost": 0.25,            # biomass per hp healed
	"impulse_base_cap": 3.0,
	"impulse_cap_per_node": 2.0,
}

## Bodies the Stomach can digest (combat adds these from stage 07; the sandbox drops them for testing).
const BODIES := {
	"body.pilgrim": {"name": "Pilgrim's body", "mass": 30.0, "yield": {"resource.biomass": 30.0, "resource.genome": 6.0}},
	"body.knight": {"name": "Knight's body", "mass": 45.0, "yield": {"resource.biomass": 40.0, "resource.genome": 8.0}},
	"body.burner": {"name": "Burner Priest's body", "mass": 35.0, "yield": {"resource.biomass": 28.0, "resource.genome": 10.0}},
}

const RESOURCES := {
	"resource.biomass": {"name": "Biomass", "desc": "Living matter digested from bodies. Builds organs, grows creatures, repairs tissue."},
	"resource.energy": {"name": "Energy", "desc": "The Heart's pulse. Pays upkeep for organs, creatures, nerve impulses and kept minds."},
	"resource.genome": {"name": "Genetic material", "desc": "Fragments of foreign code. Spent on mutations, experiments and new species."},
}

const ORGANS := {
	"organ.heart": {
		"name": "Heart Bud", "desc": "The heart of this sprout. If it dies, the sprout burns out.",
		"category": "central", "footprint": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"cost": {}, "hp": 400, "upkeep": {}, "produces": {"resource.energy": 4.0, "resource.biomass": 0.6},
		"storage": {"resource.biomass": 300, "resource.energy": 100, "resource.genome": 120},
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
		"role": "defender", "stats": {"hp": 90, "atk": 6, "armor": 4, "speed": 0.6, "sight": 4.0, "upkeep": 0.3},
		"traits": ["trait.bone_armor"], "breed": {"kind": "egg", "time": 20.0, "cost": {"resource.biomass": 18}},
	},
	"species.blood_tick": {
		"name": "Blood Tick", "desc": "Drains life and infects whatever it bites.",
		"role": "parasite", "stats": {"hp": 30, "atk": 4, "armor": 0, "speed": 1.2, "sight": 8.0, "upkeep": 0.1},
		"traits": ["trait.drain", "trait.infect"], "breed": {"kind": "division", "time": 10.0, "cost": {"resource.biomass": 8}},
	},
	"species.devourer": {
		"name": "Devourer", "desc": "Hunts the wounded and grows with every kill.",
		"role": "hunter", "stats": {"hp": 60, "atk": 12, "armor": 1, "speed": 1.0, "sight": 10.0, "upkeep": 0.4},
		"traits": ["trait.execute", "trait.grow_on_kill"], "breed": {"kind": "egg", "time": 25.0, "cost": {"resource.biomass": 25, "resource.genome": 5}},
	},
	"species.nerve_stalker": {
		"name": "Nerve Stalker", "desc": "Unseen until it strikes. The first blow lands hardest.",
		"role": "ambusher", "stats": {"hp": 45, "atk": 10, "armor": 0, "speed": 1.1, "sight": 3.5, "upkeep": 0.3},
		"traits": ["trait.stealth", "trait.first_strike"], "breed": {"kind": "egg", "time": 22.0, "cost": {"resource.biomass": 20, "resource.genome": 8}},
	},
	"species.lymphatic": {
		"name": "Lymphatic", "desc": "Mends creatures and channels nearby.",
		"role": "support", "stats": {"hp": 50, "atk": 2, "armor": 1, "speed": 0.8, "sight": 6.0, "upkeep": 0.2},
		"traits": ["trait.heal_aura"], "breed": {"kind": "spore", "time": 18.0, "cost": {"resource.biomass": 15, "resource.genome": 3}},
	},
}

## Zero (Ren): the unique avatar, not bred (Narrative Bible 6.2, GDD 6). Adapted from Fallen Below's Bone Warden:
## stats of Marrowgrave, growth from kills, Bone Storm as the active ability.
const ZERO := {
	"species.zero": {
		"name": "Zero", "desc": "A child's silhouette in a bone mask. He fights for you because he believes you are his younger brother.",
		"role": "avatar", "stats": {"hp": 70, "atk": 6, "armor": 0, "speed": 1.3, "sight": 9.0, "upkeep": 0.3},
		"traits": [], "embody_cost": {"resource.biomass": 40, "resource.genome": 10},
		"xp_per_kill": 4, "xp_levels": [10, 25, 45, 70, 100],
		"level_up": {"hp": 0.12, "atk": 1.0, "heal": 0.3},
		"storm": {"name": "Bone Storm", "desc": "Double damage to every invader next to Zero.", "cooldown": 20.0, "radius": 1.5, "mult": 2.0},
		"leash": 14.0,
	},
}

## Creature behaviour constants (GDD 6). Distances in cells, times in seconds.
const AI := {
	"move_speed": 2.0,         # cells per second at speed 1.0
	"attack_range": 1.5,
	"attack_period": 1.0,
	"repath": 1.0,
	"stuck_time": 4.0,         # no progress this long -> re-path, then drop the target
	"retreat_hp": 0.3,
	"recover_hp": 0.8,
	"recover_rate": 0.03,      # share of max hp per second while resting at home
	"defender_leash": 5.0,
	"alert_time": 3.0,         # an attacked organ calls defenders for this long
	"alert_radius": 10.0,
	"heal_rate": 4.0,          # Lymphatic: hp per second to one ally in range
	"heal_range": 2.0,
	"drain": 0.5,
	"infect_dps": 1.5,
	"infect_time": 4.0,
	"execute_below": 0.4,
	"execute_bonus": 0.5,
	"gorge_hp": 5.0,
	"rehide_time": 5.0,
	"starve_dps": 1.0,
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
	"trait.ash_carapace": {"name": "Ash Carapace", "desc": "A rare union of bone and ash: fire cannot harm it.", "effect": {"resist": {"fire": 0.5}}, "rare": true},
}

## Every mutation has a cost and a drawback (GDD 8). A mutation is applied to a line:
## a species strain (all living members and future broods) or an organ type (all such organs).
## "effect" applies to creatures, "organ_effect" to organs (with its own drawback text).
## "inherit": dominant = always passed to offspring, recessive = with GENETICS.recessive_chance.
const MUTATIONS := {
	"mutation.bone_plate": {"name": "Bone Plate", "desc": "+3 armour.", "drawback": "-15% speed.",
		"organ_desc": "Takes 30% less physical damage.", "organ_drawback": "+0.2 energy upkeep.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 10}, "inherit": "dominant",
		"requires": [], "excludes": ["mutation.swift_tendons"],
		"effect": {"armor": 3.0, "speed_mult": 0.85}, "organ_effect": {"resist": {"physical": 0.3}, "upkeep": 0.2}},
	"mutation.acid_blood": {"name": "Acid Blood", "desc": "Attackers take 3 damage when they hit.", "drawback": "-10% maximum health.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 12}, "inherit": "dominant",
		"requires": [], "excludes": [], "effect": {"thorns": 3.0, "hp_mult": 0.9}},
	"mutation.fireproof_shell": {"name": "Fireproof Shell", "desc": "Fire damage halved.", "drawback": "Healing received -25%.",
		"organ_desc": "Fire damage halved.", "organ_drawback": "Healing received -25%.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 14}, "inherit": "dominant",
		"requires": [], "excludes": [],
		"effect": {"resist": {"fire": 0.5}, "heal_mult": 0.75}, "organ_effect": {"resist": {"fire": 0.5}, "heal_mult": 0.75}},
	"mutation.swift_tendons": {"name": "Swift Tendons", "desc": "+30% speed.", "drawback": "-1 armour.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 8}, "inherit": "recessive",
		"requires": [], "excludes": ["mutation.bone_plate"], "effect": {"speed_mult": 1.3, "armor": -1.0}},
	"mutation.spore_sac": {"name": "Spore Sac", "desc": "On death releases spores that slow nearby invaders by half for 4 s.", "drawback": "+20% biomass cost to breed.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 10}, "inherit": "recessive",
		"requires": [], "excludes": [], "effect": {"spores": true, "breed_cost_mult": 1.2}},
	"mutation.dark_sight": {"name": "Dark Sight", "desc": "Sees hidden enemies.", "drawback": "Takes +25% holy damage.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 9}, "inherit": "recessive",
		"requires": [], "excludes": [], "effect": {"sees_hidden": true, "weak": {"holy": 0.25}}},
	"mutation.regenerative_tissue": {"name": "Regenerative Tissue", "desc": "Regenerates 1% health per second.", "drawback": "+0.3 energy upkeep.",
		"organ_desc": "Regenerates 1% health per second.", "organ_drawback": "+0.3 energy upkeep.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 12}, "inherit": "recessive",
		"requires": [], "excludes": [],
		"effect": {"regen": 0.01, "upkeep": 0.3}, "organ_effect": {"regen": 0.01, "upkeep": 0.3}},
	"mutation.dense_tissue": {"name": "Dense Tissue", "desc": "+25% maximum health.", "drawback": "-10% damage.",
		"organ_desc": "+25% maximum health.", "organ_drawback": "+0.2 energy upkeep.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 10}, "inherit": "dominant",
		"requires": [], "excludes": [],
		"effect": {"hp_mult": 1.25, "atk_mult": 0.9}, "organ_effect": {"hp_mult": 1.25, "upkeep": 0.2}},
	"mutation.nerve_insulation": {"name": "Nerve Insulation", "desc": "Immune to stun and the Executioner's dampening.", "drawback": "Nerve impulses cost +1 on this target.",
		"organ_desc": "Immune to the Executioner's dampening.", "organ_drawback": "+0.2 energy upkeep.",
		"targets": ["species", "organ"], "slots": 1, "cost": {"resource.genome": 15}, "inherit": "recessive",
		"requires": [], "excludes": [],
		"effect": {"insulated": true, "impulse_cost": 1}, "organ_effect": {"insulated": true, "upkeep": 0.2}},
	"mutation.predator_instinct": {"name": "Predator Instinct", "desc": "+25% damage against invaders below half health.", "drawback": "Ignores calls to protect organs.",
		"targets": ["species"], "slots": 1, "cost": {"resource.genome": 11}, "inherit": "recessive",
		"requires": [], "excludes": [], "effect": {"predator": 0.25, "ignores_alarm": true}},
}

## Inheritance rules (GDD 8). Deterministic given the "breeding" RNG stream; results become known recipes.
const GENETICS := {
	"strain_slots": 2,          # mutations per species line
	"zero_slots": 3,
	"recessive_chance": 0.5,
	"combos": [
		{"all": ["mutation.acid_blood", "mutation.regenerative_tissue"], "result": "defect.unstable_flesh", "chance": 1.0},
		{"all": ["mutation.bone_plate", "mutation.fireproof_shell"], "result": "trait.ash_carapace", "chance": 0.25},
	],
	# adaptation (GDD 8 "Адаптивная эволюция")
	"threat_window": 60.0,      # seconds of memory
	"threat_threshold": {"fire": 120.0, "holy": 150.0, "physical": 250.0, "swarm": 5.0},
	"threat_answers": {
		"fire": ["mutation.fireproof_shell"],
		"holy": ["mutation.dense_tissue", "mutation.nerve_insulation"],
		"physical": ["mutation.bone_plate", "mutation.dense_tissue"],
		"swarm": ["mutation.spore_sac", "mutation.acid_blood"],
	},
	"adapt_discount": 0.5,      # adaptations cost half of a deliberate mutation
	"proposal_time": 45.0,
	"reject_cooldown": 60.0,
}

const DEFECTS := {
	"defect.unstable_flesh": {"name": "Unstable Flesh", "desc": "Acid eats the regrowing tissue: -20% maximum health.", "effect": {"hp_mult": 0.8}},
}

const FACTIONS := {
	"faction.order": {"name": "Order of Dawn", "desc": "They burn what they cannot understand and carry the light down into the dark."},
}

const ENEMIES := {
	"enemy.pilgrim": {"name": "Pilgrim", "desc": "Scouts the halls. Brings a mind worth keeping.",
		"faction": "faction.order", "goal": "heart", "stats": {"hp": 40, "atk": 3, "armor": 0, "speed": 0.9, "sight": 5.0}, "damage": "physical", "body": "body.pilgrim",
		"counters": [], "sees_hidden": false, "sentient": true},
	"enemy.knight": {"name": "Knight", "desc": "Hallowed blade. Cuts organs open.",
		"faction": "faction.order", "goal": "organ", "stats": {"hp": 110, "atk": 12, "armor": 4, "speed": 0.7, "sight": 5.0}, "damage": "holy", "body": "body.knight",
		"counters": ["holy"], "sees_hidden": false, "sentient": true},
	"enemy.burner": {"name": "Burner Priest", "desc": "Sets organs alight. Sees what hides in the dark.",
		"faction": "faction.order", "goal": "organ", "stats": {"hp": 60, "atk": 8, "armor": 1, "speed": 0.8, "sight": 6.0}, "damage": "fire", "body": "body.burner",
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
