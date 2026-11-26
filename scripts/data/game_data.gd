extends RefCounted
## Static game data and tuning constants. Preload as `const D = preload(...)`.
##
## Concept: the dungeon is alive and hungry. It lures travelers below and never
## lets them leave. You build the halls; your Warden patrols them and fights.

# --- layout ---
const CELL := 48
const MAP_OFFSET := Vector2(16, 52)  # top bar above the map
const GRID_W := 19
const GRID_H := 11
const PANEL_X := 940.0            # right-hand panel starts here
const HAND_Y := 588.0

# --- pacing ---
const DAY_LENGTH := 20.0
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
const BOSS_HP := 420.0            # tuned with tests/bot.gd (lair none/mid/full)
const BOSS_HP_PER_LOOP := 60.0
const BOSS_DMG := 13.0
const BOSS_DMG_PER_LOOP := 2.5

# --- attention of the Order (boss meter) ---
# tuned with sim/balance.py: champion arrives around day 15-17
const THREAT_PER_CARD := 0.8
const THREAT_PER_KILL := 0.8
const THREAT_PER_ESCAPE := 6.0
const THREAT_PER_COMBO := 3.0
const MONSTER_LOOP_POWER := 0.12  # your monsters also grow stronger each loop

# --- sleeping (retreat) ---
const SEAL_EVERY := 5             # full payout on days divisible by this
const SEAL_WEEK_PCT := 1.0
const SEAL_EARLY_PCT := 0.6
const DEFEAT_PCT := 0.3
const VICTORY_BONUS := 25

# --- the Wardens (your monster). Each has its own gear slots, a passive and an active ability ---
const WARDENS := {
	"bone": {
		"name": "Marrowgrave", "title": "the Bone Warden", "color": Color(0.55, 0.85, 1.0),
		"xp_source": "Learns by devouring.",
		"hp": 70.0, "dmg": 6.0, "def": 0.0, "speed": 1.3,
		"slots": ["weapon", "shield", "armor", "amulet", "ring"],
		"passive": "Marrow Feast", "passive_desc": "Devouring heals 40% HP instead of 25%.",
		"active": "Bone Storm", "active_desc": "Deals double damage to every traveler on the Warden's tile and the tiles next to it.",
		"cooldown": 20.0,
		"style": "Balanced. Eats, wears heavy gear, holds the line.",
	},
	"brood": {
		"name": "Vesh'ka", "title": "Mother of Threads", "color": Color(0.45, 0.9, 0.4),
		"xp_source": "Learns when travelers die among her spiders.",
		"hp": 75.0, "dmg": 4.5, "def": 0.5, "speed": 1.1,
		"slots": ["armor", "amulet", "amulet", "ring", "ring"],
		"passive": "Brood", "passive_desc": "Every traveler she kills leaves a spider on that tile. Her spiders are 30% stronger. Spider Nests come twice as often.",
		"active": "Swarm", "active_desc": "Lays 3 spiders on her tile.",
		"cooldown": 22.0,
		"style": "No weapons. Fills the dungeon with her children.",
		"unlock_building": "brood_chamber",
	},
	"mimic": {
		"name": "Goldtooth", "title": "the Mimic King", "color": Color(1.0, 0.75, 0.25),
		"xp_source": "Learns from every coin of gold harvested.",
		"hp": 70.0, "dmg": 5.0, "def": 0.0, "speed": 1.5,
		"slots": ["weapon", "weapon", "ring", "ring", "ring"],
		"passive": "Hoard", "passive_desc": "+0.05 damage for every Gold in this run's harvest. Cursed Chests come twice as often.",
		"active": "Swallow", "active_desc": "Swallows a weakened traveler (below 40% HP) whole: devoured at once, double harvest.",
		"cooldown": 18.0,
		"style": "Two weapons, three rings. Grows rich, then grows cruel.",
		"unlock_building": "golden_hoard",
	},
	"saint": {
		"name": "Sister Ashen", "title": "the Hollow Saint", "color": Color(0.95, 0.9, 0.75),
		"xp_source": "Learns by raising the dead.",
		"hp": 85.0, "dmg": 5.0, "def": 0.5, "speed": 1.2,
		"slots": ["weapon", "armor", "amulet", "amulet", "ring"],
		"passive": "Shepherd of the Dead", "passive_desc": "+2 undead servant slots, servants rise with 50% more HP. Devouring heals only half.",
		"active": "Call the Dead", "active_desc": "Every servant heals 50%, and the Saint heals 5% for each servant.",
		"cooldown": 25.0,
		"style": "Raise, don't eat. Leads an army of the faithful dead.",
		"unlock_pages": 8,
	},
}
const DEVOUR_HEAL := 0.25         # share of max HP restored by devouring

# --- growth: unlocked by the Hungering Pit in the Lair ---
const XP_LEVELS := [35, 85, 150, 235, 340, 470, 620, 800]
const XP_DEVOUR := {"bone": 10, "brood": 4, "mimic": 4, "saint": 4}
const XP_BROOD_KILL := 10         # a traveler dies on a tile with Vesh'ka's spiders
const XP_PER_GOLD := 2            # Goldtooth
const XP_RAISE := 12              # Sister Ashen
const LEVEL_UP_HEAL := 0.25
const ABILITY_CHOICES := 3

## Each Warden has its own pool of 8 abilities. 1 of 3 is offered on every level up.
const ABILITIES := {
	"bone": {
		"thick_marrow": {"name": "Thick Marrow", "desc": "+25% max HP."},
		"bone_spurs": {"name": "Bone Spurs", "desc": "Travelers take 3 damage whenever they hit him."},
		"cleaving_arm": {"name": "Cleaving Arm", "desc": "His attacks hit every traveler on the tile."},
		"splinters": {"name": "Storm of Splinters", "desc": "Bone Storm reaches two tiles further and stuns for 1s."},
		"ossified": {"name": "Ossified", "desc": "+2 defense."},
		"gnaw": {"name": "Gnaw", "desc": "Devouring heals 10% more and gives +0.5 damage for the run."},
		"grave_call": {"name": "Grave Call", "desc": "Skeletons fighting beside him deal +50% damage."},
		"unbroken": {"name": "Unbroken", "desc": "Once per run, he rises again with 40% HP."},
	},
	"brood": {
		"venom": {"name": "Venom", "desc": "Her bite poisons: 2 damage per tick for 3 ticks."},
		"clutch": {"name": "Great Clutch", "desc": "Swarm lays 5 spiders instead of 3."},
		"silk_snare": {"name": "Silk Snare", "desc": "Travelers on tiles with her spiders move 35% slower."},
		"wrath": {"name": "Mother's Wrath", "desc": "+1 damage for every spider on her tile."},
		"hatchery": {"name": "Hatchery", "desc": "Spider Nests hatch one more spider every day."},
		"chitin": {"name": "Chitin", "desc": "+2 defense."},
		"cannibal": {"name": "Cannibal Mother", "desc": "When one of her spiders dies beside her, she heals 4."},
		"queens_blood": {"name": "Queen's Blood", "desc": "All her spiders are 50% stronger."},
	},
	"mimic": {
		"gilded_teeth": {"name": "Gilded Teeth", "desc": "Hoard gives 50% more damage per Gold."},
		"wide_jaw": {"name": "Wide Jaw", "desc": "Swallow works on travelers below 60% HP."},
		"coin_armor": {"name": "Coin Armor", "desc": "+1 defense for every 20 Gold harvested."},
		"golden_bait": {"name": "Golden Bait", "desc": "Cursed Chests and Mimics deal double damage."},
		"quick_hunger": {"name": "Quick Hunger", "desc": "Swallow recharges 40% faster."},
		"hoard_heal": {"name": "Hoard Healing", "desc": "Every Gold harvested heals him 1 HP."},
		"sharp_hinges": {"name": "Sharp Hinges", "desc": "+15% counter."},
		"second_mouth": {"name": "Second Mouth", "desc": "Each attack also bites a second traveler for half damage."},
	},
	"saint": {
		"choir": {"name": "Choir of the Dead", "desc": "Servants fighting beside her deal +50% damage."},
		"resurrection": {"name": "Resurrection", "desc": "Call the Dead also raises 2 Skeletons on her tile."},
		"martyrs_grace": {"name": "Martyr's Grace", "desc": "She heals 0.5 HP every time a servant strikes."},
		"faith": {"name": "Unbreakable Faith", "desc": "Servants never betray her."},
		"mass": {"name": "Mass", "desc": "+2 servant slots."},
		"halo": {"name": "Hollow Halo", "desc": "Travelers fighting her deal 25% less damage."},
		"last_rites": {"name": "Last Rites", "desc": "Servants burst when they fall: 6 damage to travelers on their tile."},
		"reliquary_bones": {"name": "Reliquary Bones", "desc": "+20% max HP and +1 defense."},
	},
}
const LOOP_HEAL := 0.15           # each completed patrol loop the dungeon feeds the Warden

## Warden stats. Gear and diet add to them.
## pct = shown as a percentage; cap = hard limit for chance stats.
const STATS := {
	"dmg": {"name": "Damage", "pct": false},
	"hp": {"name": "Max HP", "pct": false},
	"def": {"name": "Defense", "pct": false},      # flat damage removed from each hit
	"regen": {"name": "Regen", "pct": false},      # HP per second
	"vamp": {"name": "Vampirism", "pct": true, "cap": 40.0},
	"evade": {"name": "Evasion", "pct": true, "cap": 50.0},
	"counter": {"name": "Counter", "pct": true, "cap": 50.0},
}

## "You are what you eat": every devoured traveler permanently feeds one stat for this run.
const DIET := {
	"hunter": {"stat": "hp", "amount": 2.0, "desc": "Hunters make the Warden tougher (+2 max HP)"},
	"seeker": {"stat": "evade", "amount": 1.0, "desc": "Seekers make it quicker (+1% evasion)"},
	"pilgrim": {"stat": "regen", "amount": 0.1, "desc": "Pilgrims make it mend (+0.1 regen)"},
	"mage": {"stat": "dmg", "amount": 0.3, "desc": "Arcanists make it crueler (+0.3 damage)"},
	"miner": {"stat": "def", "amount": 0.15, "desc": "Miners make it harder (+0.15 defense)"},
	"sapper": {"stat": "counter", "amount": 1.0, "desc": "Sappers make it quicker to strike back (+1% counter)"},
}

# --- loop scaling (like Loop Hero): every patrol loop the Warden completes
#     makes new travelers stronger and their gear better ---
const LOOP_POWER := 0.18          # +18% traveler HP/damage per loop
const ITEM_LEVEL_PER_LOOP := 1

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
	# Act II cards (added to every deck in the Drowned Mines)
	"cavein": {"name": "Cave-in", "kind": "path", "color": Color(0.55, 0.45, 0.35), "desc": "Trap. Collapses once: 15 dmg to the traveler and 2s stun. Then rubble."},
	"drowned": {"name": "Drowned Crypt", "kind": "path", "color": Color(0.3, 0.55, 0.65), "desc": "Room. 2 Drowned, tougher than skeletons. Respawn daily."},
	"jar": {"name": "Soul Jar", "kind": "instant", "color": Color(0.3, 0.55, 0.8), "desc": "Instant. +1 undead servant slot."},
}
## Skeleton cap per room card (graveyards nearby add +1 each).
const SKELETON_CAP := {"crypt": 2, "catacomb": 3, "necropolis": 4}
const TRAP_DMG := {"spikes": 5.0, "grinder": 14.0, "chest": 6.0, "cavein": 15.0}
const CAVEIN_STUN := 2.0
const BAIT_CARDS := ["chest", "mimic"]
const LURE_SHARE_LANTERN := 0.9

## Deck building: cards known from the start; the rest are unlocked in the Lair.
const START_CARDS := ["crypt", "spider", "spikes", "altar", "jar"]
const BASE_DECK_SLOTS := 5

## Draw weights for cards in the deck.
const CARD_WEIGHTS := {"crypt": 3, "spider": 3, "spikes": 3, "altar": 2, "graveyard": 2, "chest": 2, "jar": 1,
	"cavein": 2, "drowned": 2}

## Travelers the dungeon lures below. `drop` is what their bodies give you.
const HERO_CLASSES := {
	"seeker": {"name": "Treasure Seeker", "hp": 24, "dmg": 4.5, "speed": 2.4, "color": Color(1.0, 0.8, 0.3),
		"dark": "Shade", "drop": {"gold": 4, "bones": 1}},
	"pilgrim": {"name": "Pilgrim", "hp": 26, "dmg": 3.0, "speed": 1.6, "color": Color(1.0, 0.95, 0.75),
		"dark": "Hollow Saint", "drop": {"blood": 4, "bones": 1}},
	"hunter": {"name": "Monster Hunter", "hp": 32, "dmg": 5.0, "speed": 1.9, "color": Color(0.9, 0.55, 0.3),
		"dark": "Death Knight", "drop": {"bones": 4}},
	"mage": {"name": "Arcanist", "hp": 18, "dmg": 7.0, "speed": 1.8, "color": Color(0.4, 0.6, 1.0),
		"dark": "Lich", "drop": {"gold": 2, "blood": 2, "bones": 1}},
	# Act II
	"miner": {"name": "Dwarf Miner", "hp": 40, "dmg": 5.0, "speed": 1.5, "color": Color(0.75, 0.6, 0.45),
		"dark": "Drowned Miner", "drop": {"gold": 3, "bones": 3}, "armor": 2.0, "act": 2},
	"sapper": {"name": "Sapper", "hp": 22, "dmg": 6.0, "speed": 2.2, "color": Color(0.95, 0.45, 0.25),
		"dark": "Blast Wraith", "drop": {"blood": 2, "gold": 2}, "disarms": true, "act": 2},
}
const SAPPER_DISARM_CHANCE := 0.6

## Lures decide who answers the dungeon's call. Some are unlocked in the Lair.
const LURES := {
	"gold": {"name": "Glint of Gold", "traveler": "seeker", "desc": "Treasure seekers: fast and greedy, carry gold."},
	"rumors": {"name": "Monster Rumors", "traveler": "hunter", "desc": "Monster hunters: tough, carry bones and good gear."},
	"holy": {"name": "Holy Fire", "traveler": "pilgrim", "desc": "Pilgrims: heal each other, burn undead, carry blood.", "building": "shrine"},
	"arcane": {"name": "Arcane Signs", "traveler": "mage", "desc": "Arcanists: deadly, may carry relics.", "building": "stones"},
	"vein": {"name": "Rich Vein", "traveler": "miner", "desc": "Dwarf miners: armoured and slow, carry gold and bones.", "act": 2},
	"shaft": {"name": "Open Shaft", "traveler": "sapper", "desc": "Sappers: disarm your traps, carry blood and gold.", "act": 2},
}

const MONSTERS := {
	"skeleton": {"name": "Skeleton", "hp": 12, "dmg": 3.0, "color": Color(0.85, 0.85, 0.78)},
	"spider": {"name": "Spider", "hp": 7, "dmg": 3.0, "color": Color(0.35, 0.3, 0.3)},
	"queen": {"name": "Spider Queen", "hp": 40, "dmg": 6.0, "color": Color(0.2, 0.9, 0.3)},
	"golem": {"name": "Bone Golem", "hp": 50, "dmg": 5.0, "color": Color(0.75, 0.95, 0.9)},
	"mimic": {"name": "Mimic", "hp": 30, "dmg": 8.0, "color": Color(0.95, 0.55, 0.15)},
	"drowned": {"name": "Drowned", "hp": 22, "dmg": 4.5, "color": Color(0.35, 0.6, 0.7)},
}

# --- loot: gear for the Warden (Loop Hero style) ---
## Each slot has several item types: a main stat, a fixed secondary stat,
## plus random extra stats depending on rarity. Values grow with item level (= loop).
const GEAR_SLOTS := ["weapon", "shield", "armor", "amulet", "ring"]
const ITEM_TYPES := {
	"weapon": [
		{"name": "Rusted Cleaver", "main": "dmg", "second": "counter"},
		{"name": "Hunter's Spear", "main": "dmg", "second": "evade"},
		{"name": "Bone Saw", "main": "dmg", "second": "vamp"},
		{"name": "Pilgrim's Mace", "main": "dmg", "second": "def"},
		{"name": "Arcane Rod", "main": "dmg", "second": "regen"},
	],
	"shield": [
		{"name": "Tower Shield", "main": "def", "second": "hp"},
		{"name": "Buckler", "main": "def", "second": "evade"},
		{"name": "Spiked Shield", "main": "def", "second": "counter"},
		{"name": "Holy Aegis", "main": "def", "second": "regen"},
		{"name": "Bone Ward", "main": "def", "second": "vamp"},
	],
	"armor": [
		{"name": "Chainmail", "main": "hp", "second": "def"},
		{"name": "Leather Coat", "main": "hp", "second": "evade"},
		{"name": "Pilgrim Robe", "main": "hp", "second": "regen"},
		{"name": "Hide Cloak", "main": "hp", "second": "counter"},
		{"name": "Blood-soaked Vest", "main": "hp", "second": "vamp"},
	],
	"amulet": [
		{"name": "Saint's Pendant", "main": "regen", "second": "hp"},
		{"name": "Blood Charm", "main": "regen", "second": "vamp"},
		{"name": "Fang Necklace", "main": "regen", "second": "dmg"},
		{"name": "Moon Locket", "main": "regen", "second": "evade"},
	],
	"ring": [
		{"name": "Signet of Wrath", "main": "counter", "second": "dmg"},
		{"name": "Thief's Band", "main": "evade", "second": "def"},
		{"name": "Leech Ring", "main": "vamp", "second": "hp"},
		{"name": "Iron Loop", "main": "def", "second": "regen"},
	],
}
## Base value of a stat on an item of level L: base + per_level * L.
const STAT_ROLL := {
	"dmg": [1.0, 0.6], "hp": [6.0, 4.0], "def": [0.5, 0.3], "regen": [0.3, 0.15],
	"vamp": [3.0, 1.0], "evade": [3.0, 1.0], "counter": [4.0, 1.0],
}
## Which slots each kind of traveler tends to carry.
const ITEM_SLOTS := {
	"seeker": ["ring", "weapon", "armor"],
	"pilgrim": ["amulet", "shield", "armor"],
	"hunter": ["weapon", "shield", "armor"],
	"mage": ["amulet", "ring", "weapon"],
	"miner": ["armor", "shield", "weapon"],
	"sapper": ["weapon", "ring", "amulet"],
}
const RARITIES := [
	{"name": "Common", "mult": 1.0, "extras": 0, "weight": 60, "color": Color(0.8, 0.8, 0.8)},
	{"name": "Rare", "mult": 1.15, "extras": 1, "weight": 28, "color": Color(0.4, 0.65, 1.0)},
	{"name": "Epic", "mult": 1.3, "extras": 2, "weight": 10, "color": Color(0.75, 0.4, 1.0)},
	{"name": "Legendary", "mult": 1.5, "extras": 3, "weight": 2, "color": Color(1.0, 0.6, 0.15)},
]

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

const FIRST_NAMES := ["Alric", "Corwin", "Cedric", "Dara", "Elowen", "Finn", "Greta", "Hector",
	"Isolde", "Jorah", "Kael", "Lyra", "Mira", "Nolan", "Orin", "Petra", "Quinn", "Rowan",
	"Sable", "Tamsin", "Ulric", "Vera", "Wren", "Yorick"]

## Lair buildings. `cost` has one Dictionary of resources per level.
## `requires` = {building: level} that must be built first. `pos` = spot on the Lair map (0..1).
## `unlock` adds a card, lures and Wardens reference buildings by id.
const BUILDINGS := {
	"den": {"name": "Warden's Den", "desc": "Where the Warden sleeps. +15 Warden max HP per level.", "pos": Vector2(0.5, 0.52),
		"cost": [{"bones": 15}, {"bones": 35}, {"bones": 60, "blood": 10}, {"bones": 90, "blood": 25}, {"bones": 130, "blood": 45}]},
	"forge": {"name": "Bone Forge", "desc": "Sharpens claws and bones. +1.5 Warden damage per level.", "pos": Vector2(0.33, 0.4),
		"requires": {"den": 1},
		"cost": [{"bones": 25, "gold": 5}, {"bones": 50, "gold": 20}, {"bones": 80, "gold": 40}, {"bones": 120, "gold": 70}]},
	"walls": {"name": "Ossuary Walls", "desc": "Bones fused into armour. +0.5 Warden defense per level.", "pos": Vector2(0.18, 0.28),
		"requires": {"forge": 1},
		"cost": [{"bones": 40, "blood": 10}, {"bones": 80, "blood": 30}, {"bones": 130, "blood": 60}]},
	"larder": {"name": "Larder of Flesh", "desc": "Devouring heals 5% more per level.", "pos": Vector2(0.66, 0.66),
		"requires": {"den": 1},
		"cost": [{"bones": 20, "blood": 10}, {"bones": 45, "blood": 25}, {"bones": 80, "blood": 50}]},
	"pit": {"name": "The Hungering Pit", "desc": "Level 1: the Warden gains experience and picks 1 of 3 of its own abilities on level up. Further levels: +25% experience.", "pos": Vector2(0.82, 0.8),
		"requires": {"larder": 1},
		"cost": [{"bones": 30, "blood": 15}, {"bones": 70, "blood": 40}, {"bones": 120, "blood": 80}]},
	"pens": {"name": "Monster Pens", "desc": "Your skeletons, spiders and golems are 12% stronger per level.", "pos": Vector2(0.3, 0.72),
		"requires": {"den": 1},
		"cost": [{"bones": 25}, {"bones": 55, "blood": 15}, {"bones": 95, "blood": 35}]},
	"traps": {"name": "Trap Workshop", "desc": "Spikes, Grinders and Chests deal 20% more damage per level.", "pos": Vector2(0.12, 0.58),
		"requires": {"pens": 1},
		"cost": [{"bones": 30, "gold": 10}, {"bones": 60, "gold": 25}, {"bones": 100, "gold": 50}]},
	"archive": {"name": "Memory Archive", "desc": "+1 card type in your deck per level.", "pos": Vector2(0.64, 0.3),
		"requires": {"den": 1},
		"cost": [{"bones": 30}, {"bones": 70, "gold": 25}]},
	"reliquary": {"name": "Reliquary", "desc": "+1 relic slot per level.", "pos": Vector2(0.8, 0.16),
		"requires": {"archive": 1},
		"cost": [{"gold": 25, "blood": 10}, {"gold": 70, "blood": 35}]},
	"library": {"name": "Forbidden Library", "desc": "Unlocks the Graveyard card.", "unlock": "graveyard", "pos": Vector2(0.5, 0.14),
		"requires": {"archive": 1},
		"cost": [{"bones": 25, "blood": 15}]},
	"treasury": {"name": "False Treasury", "desc": "Unlocks the Cursed Chest card.", "unlock": "chest", "pos": Vector2(0.9, 0.42),
		"requires": {"archive": 1},
		"cost": [{"gold": 15, "bones": 10}]},
	"golden_hoard": {"name": "Golden Hoard", "desc": "A new Warden: Goldtooth, the Mimic King.", "pos": Vector2(0.93, 0.66),
		"requires": {"treasury": 1},
		"cost": [{"gold": 60, "bones": 30}]},
	"shrine": {"name": "Shrine of Lies", "desc": "Unlocks the Holy Fire lure (pilgrims).", "pos": Vector2(0.36, 0.12),
		"requires": {"archive": 1},
		"cost": [{"gold": 20}]},
	"stones": {"name": "Whispering Stones", "desc": "Unlocks the Arcane Signs lure (arcanists).", "pos": Vector2(0.16, 0.1),
		"requires": {"shrine": 1},
		"cost": [{"blood": 25, "gold": 25}]},
	"jars": {"name": "Trophy Hall", "desc": "+1 undead servant slot per level.", "pos": Vector2(0.5, 0.86),
		"requires": {"den": 1},
		"cost": [{"bones": 25, "blood": 5}, {"bones": 60, "blood": 25}]},
	"brood_chamber": {"name": "Brood Chamber", "desc": "A new Warden: Vesh'ka, Mother of Threads.", "pos": Vector2(0.14, 0.86),
		"requires": {"pens": 1},
		"cost": [{"bones": 50, "blood": 25}]},
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
	"blood_price": {"name": "Blood Price", "desc": "The Warden deals +3 damage but has 25 less max HP."},
	"slow_dawn": {"name": "Slow Dawn", "desc": "The Order's attention grows 25% slower."},
	"grave_robber": {"name": "Grave Robber", "desc": "Travelers always drop gear."},
	"ravenous_maw": {"name": "Ravenous Maw", "desc": "Everything the Warden devours feeds it 50% more."},
	"deep_roots": {"name": "Deep Roots", "desc": "Each completed loop gives the Warden +3 max HP."},
	"cracked_hourglass": {"name": "Cracked Hourglass", "desc": "The Warden's ability recharges 30% faster."},
	"gilded_cage": {"name": "Gilded Cage", "desc": "Epic and Legendary gear drops twice as often."},
	"patient_hunger": {"name": "Patient Hunger", "desc": "Travelers need 4 loops instead of 3 to find the way out."},
	"sweet_rot": {"name": "Sweet Rot", "desc": "Your undead servants burst when they fall: 6 damage to travelers on their tile."},
	"lantern_of_lies": {"name": "Lantern of Lies", "desc": "90% of each party follows your lure instead of 70%."},
	"hollow_echo": {"name": "Hollow Echo", "desc": "+0.2 Warden damage for every page in the Book of the Fallen."},
}

# --- acts & story ---
## power: traveler strength multiplier; harvest: resources multiplier; item_bonus: extra item levels.
const ACTS := {
	1: {"name": "Act I: The Crypts", "boss": "Aurelia", "boss_title": "the Lightbringer", "boss_cls": "pilgrim",
		"end_story": "act1_end", "power": 1.0, "boss_mult": 1.0, "harvest": 1.0, "item_bonus": 0},
	2: {"name": "Act II: The Drowned Mines", "boss": "Brann", "boss_title": "the Delver King", "boss_cls": "miner",
		"intro_story": "act2_intro", "end_story": "act2_end", "power": 1.45, "boss_mult": 1.3, "harvest": 1.6, "item_bonus": 2},
}
const BRANN_CHARGE_EVERY := 6.0   # seconds between Brann's charges
const BRANN_FUSE := 2.0           # warning time before a charge goes off
const BRANN_BLAST := 30.0         # damage to everything on the tile

## The Warden remembers its name after Act I.
const WARDEN_TRUE_NAME := "Ren"

const STORY := {
	"intro": [
		"There is a door in the mountainside. Yesterday it was not there.\n\nIt never is, until the morning someone finds it.",
		"Beyond it, steps worn hollow by a thousand feet. Below, the glint of gold and the rustle of a rumour: treasure, or a beast whose head is worth a fortune.\n\nTravelers always go down. No one ever climbs back up.",
		"The dungeon is alive. It bears them no hatred, any more than winter hates the ones who freeze. It is simply hungry, as it has always been.\n\nYou are its will. You carve its halls, set its traps, wake the things that stir inside its walls.",
		"And you are its Warden: old bones grown together around the hollow where a heart once beat.\n\nYou do not remember who you were. You remember only this: no one may leave.",
		"Far above, in the white towers, the Order of Dawn keeps count of the missing. From the pulpits they call you a monster, and the faithful trace the sign of the sun.\n\nAnd still the Order sends people down to you. Again, and again.",
	],
	"memory_sword": [
		"Among the bones of the Lair the Warden finds a small thing: a wooden sword. The grip is worn glossy by a child's palm, and a clumsy letter R is carved into the blade.",
		"It does not know why it keeps it. It does not know why the touch aches in the place where nothing is left.",
		"And somewhere very far away, through the depth of years and stone, a girl's voice rings out:\n\n\"Ren, wait! Don't go in without me!\"",
	],
	"memory_feast": [
		"At night the raised dead talk among themselves in the dark: a rustle, a click, a dry whisper. Each of them knew a little. Together they know too much.",
		"The Order draws the treasure maps. The Order lights the holy fire at the door. The Order pays the hunters half in advance, and has never once paid the rest.",
		"They are not trying to kill the dungeon.\n\nThey are feeding it.",
		"And an old scholar, his fingers still stained with ink, says what none of them wants to hear:\n\n\"Every time the dungeon eats, the sun above us burns a little brighter.\"",
	],
	"act1_end": [
		"Aurelia falls. Her light gutters across the stones like a candle in a draught.\n\nThe Warden bends over her, and for the first time in all its long dark, it does not want to eat.",
		"\"Ren,\" she whispers. \"It's me. It's Lia.\"\n\nAnd the bones remember.",
		"Thirty years ago two children, lost in the woods below the mountain, found a door that had not been there the day before. The dungeon wanted one of them. Only one.",
		"The boy said: \"Take me. Let her go.\"\n\nAnd the dungeon, which had never let anyone go, let her go.",
		"She grew up in the white towers. They made a saint of her. They told her the monster had eaten her brother.\n\nThey never told her what he became.",
		"Her last breath rises through the rock, a small warm light. Next morning the sun over the world shines a little brighter than the day before.\n\nRen does not understand why. Not yet.",
	],
	"act2_intro": [
		"The Order did not send another saint. It sent miners.\n\nDwarves with picks and kegs of powder, and a contract sealed in wax stamped with a little sun.",
		"They have not come for your head. They have come to dig. Somewhere beneath your halls lies dawnstone: pale crystal that glows like the sky a minute before morning.",
		"Ren remembers Lia's last breath sinking into the stone and rising through it as light. He begins to guess what dawnstone is made of, and the guess chills even him, who long ago forgot what warmth was.",
		"The shafts are flooded; the water is black and still.\n\nLead them deeper. Let the water close over them.",
	],
	"act2_end": [
		"Brann the Delver King sinks beneath the black water, his last charge clenched in his fist, the fuse never lit.",
		"His pockets are full of dawnstone. In the dark it glows, and in the glow there are faces.\n\nPilgrims. Hunters. Children who followed a map with a little sun in the corner.",
		"The sun of this world is not a star. It is a furnace. And every soul the dungeon has swallowed is coal the Order mines, weighs, and throws on the fire.",
		"Far above, Inquisitor Vael turns the last page of the mine ledgers. She does not want to put out the furnace.\n\nShe wants to feed it everything beneath the mountain.\n\n(Act III: The Ash Cathedral is coming soon.)",
	],
}

## Lair memories unlock as the Book of the Fallen fills up.
const MEMORIES := [
	{"id": "memory_sword", "pages": 4},
	{"id": "memory_feast", "pages": 10},
]

## One-time story moments during runs, shown as narration over the map.
const BEATS := {
	"first_kill": "The first one falls. Somewhere deep below, the dark grows still, almost content. Almost.",
	"first_raise": "The dead traveler rises and looks at the Warden for a long time, as if straining to remember where it has seen that face before.",
	"first_escape": "One got away. Tonight a tavern will hear his tale. By morning, so will the Order.",
	"first_loop": "The Warden closes its round. The dungeon sinks deeper; whatever comes down next will be stronger, and so will what they carry.",
	"first_devour": "The Warden eats. Its bones crack and lengthen. For a moment a name rises from the depths, short and warm, and sinks again.",
	"first_level": "Something ancient stirs in the Warden. It remembers a way to kill that it had long forgotten.",
	"attention_half": "Bells toll in the white towers. The Order has noticed you. Up there, something blinding is being prepared.",
	"first_sleep": "The door in the mountain swings shut. The dungeon curls around its full belly and dreams of the next door.",
	# tutorial hints (first run)
	"tut_start": "Pick a card at the bottom, then a tile. Rooms and traps go on the path; altars and graveyards go beside it.",
	"tut_warden": "The glowing shape is your Warden. It walks against the travelers and fights whoever it meets. Press Q for its ability. If it falls, the run is over.",
	"tut_souls": "The dead are yours. Press R to switch between devouring them (the Warden grows) and raising them (servants that whisper the truth).",
	"tut_loot": "They dropped something. Click it on the right and the Warden will wear it. Hover to compare with what it wears now.",
	"tut_lure": "The lure on the right decides who comes down tomorrow, and what you harvest from them.",
	"tut_escape": "Travelers who survive three loops find the way out. Watch the red dots under them.",
	"tut_week": "The week ends. Sleep now to keep the whole harvest, or risk another week for more.",
}

## What the act champion says, and when (arrive / below half / below a quarter / death).
const BOSS_LINES := {
	"arrive": [
		"A light comes down the stairs, and the whole dungeon flinches like a beast under the lash.",
		"Aurelia: \"I remember these vaults. I swore I would never see them again.\"",
		"Aurelia: \"Warden! For thirty years I have prayed for the day I take back what you stole from me.\"",
	],
	"half": [
		"Aurelia: \"Your eyes... No. It cannot be. ...Ren?\"",
	],
	"low": [
		"Aurelia: \"They told me you screamed when it took you. You didn't. You held the door so I could run.\"",
	],
	"death": [
		"Aurelia: \"Forgive me for leaving you down here... alone in the dark...\"",
	],
}
const BRANN_LINES := {
	"arrive": [
		"The walls shudder. Somewhere above, powder kegs thunder down the stairs.",
		"Brann: \"The contract says dig till we strike light. Not a line about monsters. So monsters cost extra.\"",
		"Brann: \"Lads, a charge in every hall! Anything that moves goes to gravel. Leave the heart be, it's in the estimate.\"",
	],
	"half": [
		"Brann: \"Hold on... the stone's warm. Like it's breathing. Forty years I've been splitting it, and never once asked what was inside.\"",
	],
	"low": [
		"Brann: \"My grandfather used to say the mountain gives back only what was put into it. I thought he meant gold.\"",
	],
	"death": [
		"Brann: \"Should've stayed up top... in the sunshine... Only the sunshine's made of us...\"",
	],
}

## The Book of the Fallen: raised travelers give these pages in order, 4 per kind.
const FRAGMENTS := {
	"seeker": [
		"I bought the map from a priest for three silver. It never crossed my mind to ask why a servant of the sun would sell the way to treasure.",
		"Every map has a little sun drawn in the corner. I took it for the mapmaker's mark. Now I think it is the seal on a bill of sale.",
		"The priest asked my name and wrote it in a thick book. Neatly, without a blot. The way a clerk enters sold goods into a ledger.",
		"We weren't after treasure. We were the treasure. Up there someone is paid in us, and judging by the towers, paid well.",
	],
	"hunter": [
		"We were paid for a beast. Half up front. No one ever meant to pay the rest; I knew it the moment I saw how easily they parted with the first.",
		"My captain has sent eleven companies down here. He himself has never gone lower than the tavern at the foot of the mountain.",
		"Every Order blade bears the same rune. Near you it glows, wistfully, like something that has come home.",
		"If they wanted you dead, they'd send an army. Instead they send us, three or four at a time. That isn't war. That's rationing.",
	],
	"pilgrim": [
		"The priests lit the holy fire at the door with their own hands. They said it would show us the way. It did. It showed us here.",
		"The hymns sing of how Saint Aurelia walked out of the dark as a little girl. Not one hymn tells whom she left behind.",
		"At dawn mass the priests turn their faces not to the sun but to the mountain. I always wondered why. Now I know to whom they pray.",
		"We were not sent to cleanse the dark. We were sent to feed it. A pilgrimage is only a very long road to someone else's table.",
	],
	"miner": [
		"In the white towers dawnstone sells by the ounce, dearer than gold. They told us it was crystal. But crystal doesn't moan under the pick.",
		"Brann's contract pays double for stone with a golden sheen. The golden ones are the fresh ones. We worked that out later.",
		"The lower drifts were flooded on purpose. In dry rock the stone goes dark within a week; under water it keeps for years.",
		"Every cart we haul up, the Order weighs and writes down a number. And beside the number, a column of names, in small handwriting.",
	],
	"sapper": [
		"The orders were simple: blow the halls, leave the heart. Bring the whole mountain down if you must, but leave the heart alone.",
		"They need you alive. Hungry, but alive. A dead furnace warms no one.",
		"Once, by mistake, I set a charge right by the heart. The captain beat me till his arm gave out, then dug the fuse out himself, on his knees.",
		"They aren't afraid of you. They're afraid of the day you finally have enough.",
	],
	"mage": [
		"The light of Dawn does not belong to the Order. My instruments do not lie: it rises through the rock. From below.",
		"Each time someone dies down here, the sun above flares brighter. Forty years of observations. Not one exception.",
		"The archives were sealed right after the Founding. I broke the seal. Inside lay a single sheet, and on it a single word: FED.",
		"Once this world knew no morning. The Founders buried something living beneath this mountain and left it to starve, so that the sun would rise. What they buried is you.",
	],
}

## Once a kind's pages are all collected, raised travelers mutter one of these.
const WHISPERS := {
	"seeker": [
		"Ask who sells the maps up there.",
		"I chose the wrong door. Then again, there was no other.",
	],
	"pilgrim": [
		"We were an offering, not a cure.",
		"The fire was lit for us, not against you.",
	],
	"hunter": [
		"The Order counts the missing. It never searches for them.",
		"The second half was never coming.",
	],
	"mage": [
		"When you starve, their light trembles.",
		"The archives were sealed for a reason.",
	],
	"miner": [
		"The stone was warm...",
		"We were digging up the dead.",
	],
	"sapper": [
		"Not the heart...",
		"Blow it all. All but the heart.",
	],
}
