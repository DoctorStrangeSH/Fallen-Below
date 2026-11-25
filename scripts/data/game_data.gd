extends RefCounted
## Static game data and tuning constants. Preload as `const D = preload(...)`.
##
## Concept: the dungeon is alive and hungry. It lures travelers below and never
## lets them leave. You build the halls; your Warden patrols them and fights.

# --- layout ---
const CELL := 48
const MAP_OFFSET := Vector2(16, 16)
const GRID_W := 19
const GRID_H := 11
const PANEL_X := 945.0            # right-hand panel starts here
const HAND_Y := 556.0

# --- pacing ---
const DAY_LENGTH := 18.0
const COMBAT_TICK := 0.6
const HAND_MAX := 7
const BOSS_THREAT := 100.0
const ESCAPE_LAPS := 3            # travelers who complete this many laps find the way out
const BETRAY_CHANCE := 0.08
const TRAIT_CHANCE := 0.6
const ITEM_DROP_CHANCE := 0.45
const INVENTORY_MAX := 6
const CHEST_STUN := 1.5
const LURE_SHARE := 0.7           # share of each party that follows your lure
const RADIANCE_DMG := 4.0         # Champion burns undead nearby each combat tick

# --- attention of the Order (boss meter) ---
const THREAT_PER_CARD := 4.0
const THREAT_PER_KILL := 3.0
const THREAT_PER_ESCAPE := 15.0

# --- sleeping (retreat) ---
const SEAL_EVERY := 5             # full payout on days divisible by this
const SEAL_WEEK_PCT := 1.0
const SEAL_EARLY_PCT := 0.6
const DEFEAT_PCT := 0.3
const VICTORY_BONUS := 25

# --- the Warden (your monster) ---
const WARDEN := {"name": "The Bone Warden", "hp": 60.0, "dmg": 6.0, "speed": 1.3,
	"color": Color(0.55, 0.85, 1.0)}
const XP_PER_KILL := 10
const XP_LEVELS := [20, 45, 80, 125, 180, 250, 330, 420]
const DEVOUR_HEAL := 0.25         # share of max HP restored by devouring
const LEVEL_UP_HEAL := 0.3
const ABILITY_CHOICES := 3

const ABILITIES := {
	"thick_hide": {"name": "Thick Hide", "desc": "+25% max HP."},
	"brutal": {"name": "Brutal", "desc": "+3 damage."},
	"cleave": {"name": "Cleave", "desc": "Hits every traveler on the tile."},
	"vampiric": {"name": "Vampiric", "desc": "Heals 20% of damage dealt."},
	"dread": {"name": "Dread", "desc": "Travelers fighting the Warden deal 25% less damage."},
	"swift": {"name": "Swift", "desc": "Patrols 40% faster."},
	"commander": {"name": "Commander", "desc": "Your monsters on the Warden's tile deal +50% damage."},
	"glutton": {"name": "Glutton", "desc": "Devouring heals twice as much and gives +5 XP."},
	"spiked_bones": {"name": "Spiked Bones", "desc": "Travelers take 3 damage when they strike the Warden."},
	"undying": {"name": "Undying", "desc": "Once per run, rise again with 40% HP."},
}

# --- economy: resources harvested from the dead, paid out when the run ends ---
const RESOURCES := {
	"bones": {"name": "Bones", "color": Color(0.92, 0.88, 0.78)},
	"blood": {"name": "Blood", "color": Color(0.85, 0.15, 0.2)},
	"gold": {"name": "Gold", "color": Color(1.0, 0.8, 0.25)},
}
const BOSS_DROP := {"gold": 20, "blood": 10, "bones": 10}

# --- relics ---
const BASE_RELIC_SLOTS := 1
const VETERAN_RELIC_CHANCE := 0.12
const MAGE_RELIC_CHANCE := 0.06
const SEAL_RELIC_CHANCE := 0.5    # on a full (end of week) sleep
const DEFEAT_RELIC_KEEP := 0.5    # each relic found in a lost run survives with this chance

const CARDS := {
	"crypt": {"name": "Crypt", "kind": "path", "color": Color(0.55, 0.5, 0.7), "desc": "Room. 2 Skeletons, respawn daily."},
	"spider": {"name": "Spider Nest", "kind": "path", "color": Color(0.4, 0.6, 0.35), "desc": "Room. 3 Spiders, +1 daily. 3 in a row: Queen!"},
	"queen": {"name": "Queen's Lair", "kind": "path", "color": Color(0.3, 0.75, 0.3), "desc": "Born from 3 nests."},
	"spikes": {"name": "Spikes", "kind": "path", "color": Color(0.7, 0.35, 0.3), "desc": "Trap. 5 dmg, +2 per adjacent Spikes."},
	"altar": {"name": "Dark Altar", "kind": "scenery", "color": Color(0.6, 0.2, 0.55), "desc": "Beside path. Nearby monsters +2 dmg."},
	"graveyard": {"name": "Graveyard", "kind": "scenery", "color": Color(0.35, 0.45, 0.4), "desc": "Beside path. Crypts +1 Skeleton, undead regen."},
	"chest": {"name": "Cursed Chest", "kind": "path", "color": Color(0.85, 0.65, 0.2), "desc": "Bait. Draws the greedy. 6 dmg + stun."},
	# combo results (never drawn)
	"grinder": {"name": "Meat Grinder", "kind": "path", "color": Color(0.85, 0.2, 0.2), "desc": "Combo. 14 dmg to each traveler passing."},
	"catacomb": {"name": "Catacombs", "kind": "path", "color": Color(0.5, 0.45, 0.8), "desc": "Combo. 3 Skeletons, respawn daily."},
	"necropolis": {"name": "Necropolis", "kind": "path", "color": Color(0.45, 0.8, 0.75), "desc": "Combo. 4 Skeletons + Bone Golem."},
	"mimic": {"name": "Mimic", "kind": "path", "color": Color(0.95, 0.5, 0.15), "desc": "Combo. Bait with teeth."},
	"spire": {"name": "Unholy Spire", "kind": "scenery", "color": Color(0.8, 0.15, 0.6), "desc": "Combo. Nearby monsters +5 dmg."},
	"jar": {"name": "Soul Jar", "kind": "instant", "color": Color(0.3, 0.55, 0.8), "desc": "Instant. +1 undead servant slot."},
}
## Skeleton cap per room card (graveyards nearby add +1 each).
const SKELETON_CAP := {"crypt": 2, "catacomb": 3, "necropolis": 4}
const TRAP_DMG := {"spikes": 5.0, "grinder": 14.0, "chest": 6.0}
const BAIT_CARDS := ["chest", "mimic"]

## Deck building: cards known from the start; the rest are unlocked in the Lair.
const START_CARDS := ["crypt", "spider", "spikes", "altar", "jar"]
const BASE_DECK_SLOTS := 5

## Draw weights for cards in the deck.
const CARD_WEIGHTS := {"crypt": 3, "spider": 3, "spikes": 3, "altar": 2, "graveyard": 2, "chest": 2, "jar": 1}

## Travelers the dungeon lures below. `drop` is what their bodies give you.
const HERO_CLASSES := {
	"seeker": {"name": "Treasure Seeker", "hp": 20, "dmg": 4.0, "speed": 2.4, "color": Color(1.0, 0.8, 0.3),
		"dark": "Shade", "drop": {"gold": 4, "bones": 1}},
	"pilgrim": {"name": "Pilgrim", "hp": 26, "dmg": 3.0, "speed": 1.6, "color": Color(1.0, 0.95, 0.75),
		"dark": "Hollow Saint", "drop": {"blood": 4, "bones": 1}},
	"hunter": {"name": "Monster Hunter", "hp": 32, "dmg": 5.0, "speed": 1.9, "color": Color(0.9, 0.55, 0.3),
		"dark": "Death Knight", "drop": {"bones": 4}},
	"mage": {"name": "Arcanist", "hp": 18, "dmg": 7.0, "speed": 1.8, "color": Color(0.4, 0.6, 1.0),
		"dark": "Lich", "drop": {"gold": 2, "blood": 2, "bones": 1}},
}

## Lures decide who answers the dungeon's call. Some are unlocked in the Lair.
const LURES := {
	"gold": {"name": "Glint of Gold", "traveler": "seeker", "desc": "Treasure seekers: fast and greedy, carry gold."},
	"rumors": {"name": "Monster Rumors", "traveler": "hunter", "desc": "Monster hunters: tough, carry bones and good gear."},
	"holy": {"name": "Holy Fire", "traveler": "pilgrim", "desc": "Pilgrims: heal each other, burn undead, carry blood.", "building": "shrine"},
	"arcane": {"name": "Arcane Signs", "traveler": "mage", "desc": "Arcanists: deadly, may carry relics.", "building": "stones"},
}

const MONSTERS := {
	"skeleton": {"name": "Skeleton", "hp": 12, "dmg": 3.0, "color": Color(0.85, 0.85, 0.78)},
	"spider": {"name": "Spider", "hp": 7, "dmg": 3.0, "color": Color(0.35, 0.3, 0.3)},
	"queen": {"name": "Spider Queen", "hp": 40, "dmg": 6.0, "color": Color(0.2, 0.9, 0.3)},
	"golem": {"name": "Bone Golem", "hp": 50, "dmg": 5.0, "color": Color(0.75, 0.95, 0.9)},
	"mimic": {"name": "Mimic", "hp": 30, "dmg": 8.0, "color": Color(0.95, 0.55, 0.15)},
}

# --- loot: gear for the Warden ---
const GEAR_SLOTS := ["weapon", "armor", "amulet", "ring"]
const ITEM_SLOTS := {
	"seeker": [["ring", "Signet"], ["weapon", "Dagger"]],
	"pilgrim": [["amulet", "Relic Pendant"], ["armor", "Robe"]],
	"hunter": [["weapon", "Greatsword"], ["armor", "Plate"]],
	"mage": [["amulet", "Orb"], ["ring", "Band"]],
}
const RARITIES := [
	{"name": "Common", "mult": 1.0, "weight": 60, "color": Color(0.8, 0.8, 0.8)},
	{"name": "Rare", "mult": 1.6, "weight": 28, "color": Color(0.4, 0.65, 1.0)},
	{"name": "Epic", "mult": 2.4, "weight": 10, "color": Color(0.75, 0.4, 1.0)},
	{"name": "Legendary", "mult": 3.5, "weight": 2, "color": Color(1.0, 0.6, 0.15)},
]
const AFFIXES := {
	"lifesteal": {"name": "Lifesteal", "desc": "heals 15% of damage dealt"},
	"thorns": {"name": "Thorns", "desc": "hurts travelers who strike"},
	"regen": {"name": "Regeneration", "desc": "heals 1 HP every tick"},
	"crit": {"name": "Cruelty", "desc": "20% chance to deal double damage"},
}

# --- secret combos (discovery is saved in Meta) ---
const COMBOS := {
	"queen": {"name": "Spider Queen", "hint": "Three nests, side by side...", "desc": "3 Spider Nests in a row become Queen's Lair."},
	"grinder": {"name": "Meat Grinder", "hint": "Pain, then more pain, then more.", "desc": "3 Spikes in a row become a Meat Grinder."},
	"catacombs": {"name": "Catacombs", "hint": "The dead like company.", "desc": "2 Crypts next to each other become Catacombs."},
	"necropolis": {"name": "Necropolis", "hint": "A crypt among many graves.", "desc": "A Crypt touching 2 Graveyards becomes a Necropolis with a Bone Golem."},
	"spire": {"name": "Unholy Spire", "hint": "Darkness gathers where altars meet.", "desc": "An Altar touching 2 other Altars becomes an Unholy Spire."},
	"mimic": {"name": "Mimic", "hint": "A chest guarded by blades on both sides.", "desc": "A Cursed Chest between two Spikes becomes a Mimic."},
}

const TRAITS := {
	"coward": {"name": "Coward", "desc": "flees for the exit at 30% HP"},
	"greedy": {"name": "Greedy", "desc": "goes for chests, moves faster"},
	"loyal": {"name": "Loyal", "desc": "grows stronger when companions fall"},
	"zealot": {"name": "Zealot", "desc": "x1.5 damage vs undead"},
	"veteran": {"name": "Veteran", "desc": "+30% HP, always carries gear"},
}

const FIRST_NAMES := ["Alric", "Brann", "Cedric", "Dara", "Elowen", "Finn", "Greta", "Hector",
	"Isolde", "Jorah", "Kael", "Lyra", "Mira", "Nolan", "Orin", "Petra", "Quinn", "Rowan",
	"Sable", "Tamsin", "Ulric", "Vera", "Wren", "Yorick"]

## Lair buildings. `cost` has one Dictionary of resources per level.
## `unlock` adds a card, `lure` makes a lure available.
const BUILDINGS := {
	"den": {"name": "Warden's Den", "desc": "+10 Warden max HP per level.",
		"cost": [{"bones": 20}, {"bones": 40, "blood": 10}, {"bones": 70, "blood": 25}]},
	"forge": {"name": "Bone Forge", "desc": "+1 Warden damage per level.",
		"cost": [{"bones": 25, "gold": 10}, {"bones": 50, "gold": 30}]},
	"archive": {"name": "Memory Archive", "desc": "+1 card type in your deck per level.",
		"cost": [{"bones": 30}, {"bones": 60, "gold": 20}]},
	"reliquary": {"name": "Reliquary", "desc": "+1 relic slot per level.",
		"cost": [{"gold": 25, "blood": 10}, {"gold": 60, "blood": 30}]},
	"shrine": {"name": "Shrine of Lies", "desc": "Unlocks the Holy Fire lure (pilgrims).",
		"cost": [{"gold": 20}]},
	"stones": {"name": "Whispering Stones", "desc": "Unlocks the Arcane Signs lure (arcanists).",
		"cost": [{"blood": 20, "gold": 20}]},
	"treasury": {"name": "False Treasury", "desc": "Unlocks the Cursed Chest card.", "unlock": "chest",
		"cost": [{"gold": 15, "bones": 10}]},
	"library": {"name": "Forbidden Library", "desc": "Unlocks the Graveyard card.", "unlock": "graveyard",
		"cost": [{"bones": 25, "blood": 15}]},
	"jars": {"name": "Trophy Hall", "desc": "+1 undead servant slot per level.",
		"cost": [{"bones": 25, "blood": 5}, {"bones": 55, "blood": 20}]},
}

## Relics change the rules of a run. Earned in runs, equipped before descending.
const RELICS := {
	"brittle_bones": {"name": "Brittle Bones", "desc": "Skeletons explode when they die: 4 dmg to travelers on their tile."},
	"gilded_bait": {"name": "Gilded Bait", "desc": "Travelers caught by a Cursed Chest drop 2 extra gold when they die."},
	"iron_chains": {"name": "Iron Chains", "desc": "Your undead never betray you, but deal 20% less damage."},
	"hungry_dark": {"name": "Hungry Dark", "desc": "Devouring heals 50% more and gives +2 Blood."},
	"mass_grave": {"name": "Mass Grave", "desc": "+1 undead servant slot."},
	"second_heartbeat": {"name": "Second Heartbeat", "desc": "Once per run, the Warden rises again with 50% HP."},
	"thorned_halls": {"name": "Thorned Halls", "desc": "Spikes and Meat Grinders deal +3 damage."},
	"brood_eye": {"name": "Broodmother's Eye", "desc": "Spider Nests hatch 2 spiders a day instead of 1."},
	"whispering_skull": {"name": "Whispering Skull", "desc": "Escaped travelers raise half as much attention."},
	"blood_price": {"name": "Blood Price", "desc": "The Warden deals +3 damage but has 15 less max HP."},
	"slow_dawn": {"name": "Slow Dawn", "desc": "The Order's attention grows 25% slower."},
	"grave_robber": {"name": "Grave Robber", "desc": "Travelers always drop gear."},
}

# --- acts & story ---
const ACTS := {
	1: {"name": "Act I: The Crypts", "boss": "Aurelia", "boss_title": "the Lightbringer",
		"boss_intro": "\"Too many have vanished down here. I have come to end your hunger.\"",
		"end_story": "act1_end"},
}

const STORY := {
	"intro": [
		"There is a door in the mountain that was not there yesterday.\n\nBehind it, stairs. Below the stairs, a glimmer of gold. A whisper of treasure. A rumour of a beast worth hunting.",
		"Travelers always go down. Treasure seekers. Pilgrims. Monster hunters. Scholars of forbidden things.\n\nNone of them come back up.",
		"The dungeon is alive, and it is hungry. You are its will: you shape its halls, its traps, its crawling things.",
		"And you are its Warden. Bones bound around an old, starving heart. You walk the halls and finish what the traps begin.",
		"But every traveler who finds the way out tells the tale. And far above, the Order of Dawn is listening.\n\nLure them in. Let none of them leave.",
	],
	"act1_end": [
		"Aurelia falls. Her light gutters and dies on your stones.",
		"As the Warden devours her, a memory surfaces. Not yours. Hers.\n\nA little girl, lost in these very halls. A door that should not have opened for her... and did.",
		"The dungeon let her go, once. The only one it ever let go.\n\nNow she has come home.",
		"Far above, the bells are ringing. The Order knows its champion is gone.\n\nNext time, they will send the miners to dig you out.\n\n(Act II is coming soon.)",
	],
}

## Raised travelers whisper fragments of the truth.
const WHISPERS := {
	"seeker": [
		"The map said treasure. The map was drawn by the Order.",
		"I came for gold. Turns out the gold was bait. Turns out I was too.",
		"Someone up there sells these maps. Ask who.",
	],
	"pilgrim": [
		"The priests said a saint was born down here. They did not say she escaped.",
		"Holy fire... they lit it at the door themselves. Why?",
		"We were sent as an offering, I think. Not as a cure.",
	],
	"hunter": [
		"They paid us to kill a beast. Nobody said the beast was the dungeon.",
		"The Order counts the missing. It never comes to look.",
		"My captain never came down. He only sends the next ones.",
	],
	"mage": [
		"Your hunger feeds something above. Their light flickers when you starve.",
		"The archives were sealed. Now I understand why.",
		"The Order needs you hungry. They just need you a little less hungry.",
	],
}
