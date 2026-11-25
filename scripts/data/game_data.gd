extends RefCounted
## Static game data and tuning constants. Preload as `const D = preload(...)`.

# --- layout ---
const CELL := 48
const MAP_OFFSET := Vector2(40, 70)
const LOOP_MIN := Vector2i(1, 0)
const LOOP_MAX := Vector2i(23, 9)

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

## Cards that can be drawn. Locked cards are removed by Meta.
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

## Lair buildings bought with Bones between runs. `cost` has one entry per level.
const BUILDINGS := {
	"heart": {"name": "Blood Vault", "desc": "+5 max Heart HP per level.", "cost": [20, 45, 80]},
	"jars": {"name": "Trophy Hall", "desc": "+1 starting soul jar per level.", "cost": [30, 70]},
	"crypt": {"name": "Ancestral Crypt", "desc": "+1 starting card per level.", "cost": [25, 60]},
	"well": {"name": "Soul Well", "desc": "+5 starting essence per level.", "cost": [15, 35, 60]},
	"library": {"name": "Forbidden Library", "desc": "Unlocks the Graveyard card.", "cost": [40]},
}
