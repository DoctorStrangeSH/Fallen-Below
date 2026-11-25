extends RefCounted
## Static game data and tuning constants. Preload as `const D = preload(...)`.

# --- layout ---
const CELL := 48
const MAP_OFFSET := Vector2(16, 16)
const GRID_W := 19
const GRID_H := 11
const PANEL_X := 945.0            # right-hand panel starts here
const HAND_Y := 556.0

# --- tuning ---
const DAY_LENGTH := 18.0
const COMBAT_TICK := 0.6
const HAND_MAX := 7
const HEART_BASE := 20
const BOSS_THREAT := 100.0
const FLEE_LOOT := 3
const BETRAY_CHANCE := 0.08
const RESTORE_COST := 10
const TRAIT_CHANCE := 0.6
const ITEM_DROP_CHANCE := 0.6
const INVENTORY_MAX := 8
const MELT_ESSENCE := 3
const CHEST_STUN := 1.5

# --- sealing (retreat) ---
const SEAL_EVERY := 5          # full payout on days divisible by this
const SEAL_WEEK_PCT := 1.0
const SEAL_EARLY_PCT := 0.6
const DEFEAT_PCT := 0.3
const VICTORY_BONUS := 25

# --- economy: resources harvested from heroes, paid out when the run ends ---
const RESOURCES := {
	"bones": {"name": "Bones", "color": Color(0.92, 0.88, 0.78), "desc": "From every hero you kill."},
	"blood": {"name": "Blood", "color": Color(0.85, 0.15, 0.2), "desc": "From absorbed souls and trap kills."},
	"gold": {"name": "Gold", "color": Color(1.0, 0.8, 0.25), "desc": "Stolen gold, taken back from dead thieves."},
}
const BONES_PER_KILL := 2
const BONES_PER_DAY := 2
const BLOOD_PER_ABSORB := 3
const BLOOD_PER_TRAP_KILL := 1
const GOLD_PER_LOOT := 3        # per theft the dead hero was carrying
const BOSS_GOLD := 20

# --- relics ---
const BASE_RELIC_SLOTS := 1
const VETERAN_RELIC_CHANCE := 0.12
const SEAL_RELIC_CHANCE := 0.5  # on a full (end of week) seal
const DEFEAT_RELIC_KEEP := 0.5  # each relic found in a lost run survives with this chance
const RADIANCE_DMG := 4.0       # Aurelia burns undead nearby each combat tick

const CARDS := {
	"crypt": {"name": "Crypt", "kind": "path", "color": Color(0.55, 0.5, 0.7), "desc": "Room. 2 Skeletons, respawn daily."},
	"spider": {"name": "Spider Nest", "kind": "path", "color": Color(0.4, 0.6, 0.35), "desc": "Room. 3 Spiders, +1 daily. 3 in a row: Queen!"},
	"queen": {"name": "Queen's Lair", "kind": "path", "color": Color(0.3, 0.75, 0.3), "desc": "Born from 3 nests."},
	"spikes": {"name": "Spikes", "kind": "path", "color": Color(0.7, 0.35, 0.3), "desc": "Trap. 5 dmg, +2 per adjacent Spikes."},
	"altar": {"name": "Dark Altar", "kind": "scenery", "color": Color(0.6, 0.2, 0.55), "desc": "Beside path. Nearby units +2 dmg."},
	"graveyard": {"name": "Graveyard", "kind": "scenery", "color": Color(0.35, 0.45, 0.4), "desc": "Beside path. Crypts +1 Skeleton, undead regen."},
	"chest": {"name": "Cursed Chest", "kind": "path", "color": Color(0.85, 0.65, 0.2), "desc": "Bait. Lures the greedy. 6 dmg + stun."},
	# combo results (never drawn)
	"grinder": {"name": "Meat Grinder", "kind": "path", "color": Color(0.85, 0.2, 0.2), "desc": "Combo. 14 dmg to each hero passing."},
	"catacomb": {"name": "Catacombs", "kind": "path", "color": Color(0.5, 0.45, 0.8), "desc": "Combo. 3 Skeletons, respawn daily."},
	"necropolis": {"name": "Necropolis", "kind": "path", "color": Color(0.45, 0.8, 0.75), "desc": "Combo. 4 Skeletons + Bone Golem."},
	"mimic": {"name": "Mimic", "kind": "path", "color": Color(0.95, 0.5, 0.15), "desc": "Combo. Bait with teeth."},
	"spire": {"name": "Unholy Spire", "kind": "scenery", "color": Color(0.8, 0.15, 0.6), "desc": "Combo. Nearby units +5 dmg."},
	"jar": {"name": "Soul Jar", "kind": "instant", "color": Color(0.3, 0.55, 0.8), "desc": "Instant. +1 undead capacity."},
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

const HERO_CLASSES := {
	"warrior": {"name": "Warrior", "hp": 30, "dmg": 4.0, "speed": 1.8, "greed": 1, "color": Color(0.9, 0.6, 0.3), "dark": "Death Knight"},
	"mage": {"name": "Mage", "hp": 18, "dmg": 7.0, "speed": 1.8, "greed": 1, "color": Color(0.35, 0.55, 1.0), "dark": "Lich"},
	"rogue": {"name": "Rogue", "hp": 20, "dmg": 5.0, "speed": 2.6, "greed": 2, "color": Color(0.4, 0.85, 0.45), "dark": "Shade"},
	"paladin": {"name": "Paladin", "hp": 38, "dmg": 3.0, "speed": 1.6, "greed": 1, "color": Color(1.0, 0.92, 0.5), "dark": "Fallen Paladin"},
}

const MONSTERS := {
	"skeleton": {"name": "Skeleton", "hp": 12, "dmg": 3.0, "color": Color(0.85, 0.85, 0.78)},
	"spider": {"name": "Spider", "hp": 7, "dmg": 3.0, "color": Color(0.35, 0.3, 0.3)},
	"queen": {"name": "Spider Queen", "hp": 40, "dmg": 6.0, "color": Color(0.2, 0.9, 0.3)},
	"golem": {"name": "Bone Golem", "hp": 50, "dmg": 5.0, "color": Color(0.75, 0.95, 0.9)},
	"mimic": {"name": "Mimic", "hp": 30, "dmg": 8.0, "color": Color(0.95, 0.55, 0.15)},
}

# --- loot ---
const ITEM_SLOTS := {
	"warrior": [["weapon", "Sword"], ["armor", "Plate"]],
	"mage": [["weapon", "Staff"], ["amulet", "Orb"]],
	"rogue": [["weapon", "Dagger"], ["amulet", "Ring"]],
	"paladin": [["armor", "Shield"], ["amulet", "Holy Symbol"]],
}
const RARITIES := [
	{"name": "Common", "mult": 1.0, "weight": 60, "color": Color(0.8, 0.8, 0.8)},
	{"name": "Rare", "mult": 1.6, "weight": 28, "color": Color(0.4, 0.65, 1.0)},
	{"name": "Epic", "mult": 2.4, "weight": 10, "color": Color(0.75, 0.4, 1.0)},
	{"name": "Legendary", "mult": 3.5, "weight": 2, "color": Color(1.0, 0.6, 0.15)},
]
const AFFIXES := {
	"lifesteal": {"name": "Lifesteal", "desc": "heals 25% of damage dealt"},
	"chains": {"name": "Chains", "desc": "can never betray you"},
	"thorns": {"name": "Thorns", "desc": "hurts heroes who strike it"},
	"regen": {"name": "Regeneration", "desc": "heals 2 HP every tick"},
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
	"coward": {"name": "Coward", "desc": "flees at 30% HP"},
	"greedy": {"name": "Greedy", "desc": "steals more, moves faster"},
	"loyal": {"name": "Loyal", "desc": "grows stronger when allies fall"},
	"zealot": {"name": "Zealot", "desc": "x1.5 damage vs undead"},
	"veteran": {"name": "Veteran", "desc": "+30% HP, drops an extra card"},
}

const FIRST_NAMES := ["Alric", "Brann", "Cedric", "Dara", "Elowen", "Finn", "Greta", "Hector",
	"Isolde", "Jorah", "Kael", "Lyra", "Mira", "Nolan", "Orin", "Petra", "Quinn", "Rowan",
	"Sable", "Tamsin", "Ulric", "Vera", "Wren", "Yorick"]

## Lair buildings. `cost` has one Dictionary of resources per level.
## `unlock` (optional) adds a card to the collection when built.
const BUILDINGS := {
	"heart": {"name": "Blood Vault", "desc": "+5 max Heart HP per level.",
		"cost": [{"bones": 20}, {"bones": 40, "blood": 10}, {"bones": 70, "blood": 25}]},
	"archive": {"name": "Memory Archive", "desc": "+1 card type in your deck per level.",
		"cost": [{"bones": 30}, {"bones": 60, "gold": 20}]},
	"reliquary": {"name": "Reliquary", "desc": "+1 relic slot per level.",
		"cost": [{"gold": 25, "blood": 10}, {"gold": 60, "blood": 30}]},
	"treasury": {"name": "False Treasury", "desc": "Unlocks the Cursed Chest card.", "unlock": "chest",
		"cost": [{"gold": 15, "bones": 10}]},
	"library": {"name": "Forbidden Library", "desc": "Unlocks the Graveyard card.", "unlock": "graveyard",
		"cost": [{"bones": 25, "blood": 15}]},
	"jars": {"name": "Trophy Hall", "desc": "+1 starting soul jar per level.",
		"cost": [{"bones": 25, "blood": 5}, {"bones": 55, "blood": 20}]},
	"well": {"name": "Soul Well", "desc": "+5 starting essence per level.",
		"cost": [{"blood": 8}, {"blood": 20}, {"blood": 40}]},
}

## Relics change the rules of a run. Earned in runs, equipped before descending.
const RELICS := {
	"brittle_bones": {"name": "Brittle Bones", "desc": "Skeletons explode when they die: 4 dmg to heroes on their tile."},
	"gilded_bait": {"name": "Gilded Bait", "desc": "Cursed Chests heal your Heart by 1 when they catch a hero."},
	"iron_chains": {"name": "Iron Chains", "desc": "Your undead never betray you, but deal 20% less damage."},
	"hungry_dark": {"name": "Hungry Dark", "desc": "Absorbing a soul gives +3 essence and +2 Blood more."},
	"mass_grave": {"name": "Mass Grave", "desc": "+1 soul jar."},
	"second_heartbeat": {"name": "Second Heartbeat", "desc": "Once per run, when your Heart would fall, it beats again with 5 HP."},
	"thorned_halls": {"name": "Thorned Halls", "desc": "Spikes and Meat Grinders deal +3 damage."},
	"brood_eye": {"name": "Broodmother's Eye", "desc": "Spider Nests hatch 2 spiders a day instead of 1."},
	"whispering_skull": {"name": "Whispering Skull", "desc": "Interrogation gives 1 more card."},
	"blood_price": {"name": "Blood Price", "desc": "Start with +15 essence, but your Heart has 5 less HP."},
	"slow_dawn": {"name": "Slow Dawn", "desc": "The Order's attention grows 25% slower."},
	"grave_robber": {"name": "Grave Robber", "desc": "Heroes always drop a trophy."},
}


# --- acts & story ---
const ACTS := {
	1: {"name": "Act I: The Crypts", "boss": "Aurelia", "boss_title": "the Lightbringer",
		"boss_intro": "\"Your light was stolen long ago. I have come to return it to the sun.\"",
		"end_story": "act1_end"},
}

const STORY := {
	"intro": [
		"Once, the world below was alive. Halls of bone and crystal, rivers of black water, and a heart that beat beneath the mountains.",
		"Then the Order of Dawn came down with fire and hymns. They burned the deep places clean, and called it salvation.",
		"You are what remains. A single heart in the dark. You remember almost nothing. Only fragments: a hall, a trap, the things that once lived here.",
		"And they are coming again. Heroes of the Dawn, sent down to finish the work.",
		"Rebuild yourself from memory. Let them walk your halls. Let none of them leave.\n\nAnd those who fall... will be yours.",
	],
	"act1_end": [
		"Aurelia falls. Her light gutters and dies on your stones.",
		"As her soul sinks into you, a memory surfaces. Not yours. Hers.\n\nA little girl, kneeling in these very halls. Long before the Order. Long before the fire.",
		"She was born down here. She was one of yours.",
		"Far above, the bells are ringing. The Order knows its champion is gone.\n\nNext time, they will send the miners to dig you out.\n\n(Act II is coming soon.)",
	],
}

## Raised heroes whisper fragments of the truth.
const WHISPERS := {
	"warrior": [
		"They paid us in gold to come here. Nobody asked what you were.",
		"My captain said the Abyss eats children. I see no children here.",
		"The Order keeps the gold. We keep the scars.",
	],
	"mage": [
		"The Dawn's light is not theirs. They draw it from below... from you.",
		"Every spell I cast up there burned with your colour.",
		"The archives were sealed. Now I understand why.",
	],
	"rogue": [
		"I came for treasure. Turns out the treasure was you.",
		"The Order pays double for heart-shards. Funny, that.",
		"Picked the wrong lock this time.",
	],
	"paladin": [
		"I swore to burn you. I never asked why you still beat.",
		"The hymns speak of a first saint who came from the dark.",
		"Aurelia prays alone at night. She weeps toward the deep.",
	],
}
