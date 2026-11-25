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
const BOSS_HP := 260.0            # tuned with tests/bot.gd
const BOSS_HP_PER_LOOP := 50.0
const BOSS_DMG := 10.0
const BOSS_DMG_PER_LOOP := 2.0

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
		"hp": 110.0, "dmg": 8.0, "def": 1.0, "speed": 1.3,
		"slots": ["weapon", "shield", "armor", "amulet", "ring"],
		"passive": "Marrow Feast", "passive_desc": "Devouring heals 40% HP instead of 25%.",
		"active": "Bone Storm", "active_desc": "Deals double damage to every traveler on the Warden's tile and the tiles next to it.",
		"cooldown": 20.0,
		"style": "Balanced. Eats, wears heavy gear, holds the line.",
	},
	"brood": {
		"name": "Vesh'ka", "title": "Mother of Threads", "color": Color(0.45, 0.9, 0.4),
		"xp_source": "Learns when travelers die among her spiders.",
		"hp": 110.0, "dmg": 6.0, "def": 1.5, "speed": 1.1,
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
		"hp": 100.0, "dmg": 7.0, "def": 0.5, "speed": 1.5,
		"slots": ["weapon", "weapon", "ring", "ring", "ring"],
		"passive": "Hoard", "passive_desc": "+0.1 damage for every Gold in this run's harvest. Cursed Chests come twice as often.",
		"active": "Swallow", "active_desc": "Swallows a weakened traveler (below 40% HP) whole: devoured at once, double harvest.",
		"cooldown": 18.0,
		"style": "Two weapons, three rings. Grows rich, then grows cruel.",
		"unlock_building": "golden_hoard",
	},
	"saint": {
		"name": "Sister Ashen", "title": "the Hollow Saint", "color": Color(0.95, 0.9, 0.75),
		"xp_source": "Learns by raising the dead.",
		"hp": 125.0, "dmg": 7.0, "def": 1.5, "speed": 1.2,
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
}

# --- loop scaling (like Loop Hero): every patrol loop the Warden completes
#     makes new travelers stronger and their gear better ---
const LOOP_POWER := 0.15          # +15% traveler HP/damage per loop
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
	"jar": {"name": "Soul Jar", "kind": "instant", "color": Color(0.3, 0.55, 0.8), "desc": "Instant. +1 undead servant slot."},
}
## Skeleton cap per room card (graveyards nearby add +1 each).
const SKELETON_CAP := {"crypt": 2, "catacomb": 3, "necropolis": 4}
const TRAP_DMG := {"spikes": 5.0, "grinder": 14.0, "chest": 6.0}
const BAIT_CARDS := ["chest", "mimic"]
const LURE_SHARE_LANTERN := 0.9

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
	"pit": {"name": "The Hungering Pit", "desc": "Your Wardens gain experience and choose 1 of 3 of their own abilities on every level up.",
		"cost": [{"bones": 30, "blood": 10}]},
	"jars": {"name": "Trophy Hall", "desc": "+1 undead servant slot per level.",
		"cost": [{"bones": 25, "blood": 5}, {"bones": 55, "blood": 20}]},
	"brood_chamber": {"name": "Brood Chamber", "desc": "A new Warden: the Broodmother.",
		"cost": [{"bones": 40, "blood": 20}]},
	"golden_hoard": {"name": "Golden Hoard", "desc": "A new Warden: the Mimic King.",
		"cost": [{"gold": 50, "bones": 20}]},
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
const ACTS := {
	1: {"name": "Act I: The Crypts", "boss": "Aurelia", "boss_title": "the Lightbringer",
		"end_story": "act1_end"},
}

## The Warden remembers its name after Act I.
const WARDEN_TRUE_NAME := "Ren"

const STORY := {
	"intro": [
		"There is a door in the mountain that was not there yesterday.\n\nThere never is.",
		"Behind it, stairs. At the bottom, a glimmer of gold, a whisper of treasure, a rumour of a beast worth killing.\n\nTravelers always go down. None of them come back up.",
		"The dungeon is alive. It does not hate them. It is simply, endlessly hungry.\n\nYou are its will. You shape its halls, its traps, the crawling things in its walls.",
		"And you are its Warden: old bones knitted around a hollow where a heart should be.\n\nYou do not remember who you were. You only know that you must not let them leave.",
		"Far above, in white towers, the Order of Dawn counts the missing. They call you a monster.\n\nThey keep sending people anyway.",
	],
	"memory_sword": [
		"Among the bones of the Lair, the Warden finds a small thing. A child's wooden sword, worn smooth by a small hand.",
		"It does not know why it keeps it. It does not know why holding it hurts.",
		"Somewhere very far away, a girl's voice:\n\n\"Ren, wait for me! Don't go in without me!\"",
	],
	"memory_feast": [
		"At night the raised dead murmur to each other in the dark. Each of them knew a little. Together they know a lot.",
		"The Order draws the treasure maps. The Order lights the holy fire at the door. The Order pays the hunters half up front, and never the rest.",
		"They are not trying to kill the dungeon.\n\nThey are feeding it.",
		"And an old scholar among the dead says what none of them wants to hear:\n\nevery time the dungeon eats, the sun above burns a little brighter.",
	],
	"act1_end": [
		"Aurelia falls. Her light gutters on the stones.\n\nThe Warden kneels over her, and for the first time, it does not want to eat.",
		"\"Ren,\" she whispers. \"It's me. It's Lia.\"\n\nAnd the bones remember.",
		"Two children, lost in the dark, thirty years ago. A door that should not have opened. A dungeon that wanted one of them.",
		"The boy said: take me. Let her go.\n\nAnd the dungeon, which had never let anyone go, did.",
		"She grew up in the white towers. They made her a saint. They told her the monster ate her brother.\n\nThey never told her what he became.",
		"Her last breath rises through the rock like a small, warm light. Far above, for one morning, the sun shines a little brighter.\n\nRen does not understand why. Not yet.\n\n(Act II: The Drowned Mines is coming soon.)",
	],
}

## Lair memories unlock as the Book of the Fallen fills up.
const MEMORIES := [
	{"id": "memory_sword", "pages": 4},
	{"id": "memory_feast", "pages": 10},
]

## One-time story moments during runs, shown as narration over the map.
const BEATS := {
	"first_kill": "The first one falls. Something in the dark goes quiet, almost content. Almost.",
	"first_raise": "The dead traveler stands, and looks at the Warden for a long moment, as if trying to remember where it has seen that face before.",
	"first_escape": "One got away. Tonight a tavern will hear the story. By morning, so will the Order.",
	"first_loop": "The Warden completes its round. The dungeon grows deeper, and whatever comes down next will be stronger. So will what they carry.",
	"first_devour": "The Warden eats. Its bones crack and grow. For a moment a name almost rises to the surface. Then it is gone.",
	"first_level": "Something old wakes in the Warden. It remembers a way to kill it had forgotten.",
	"attention_half": "Bells ring in the white towers. The Order has noticed you. Something bright is being prepared.",
	"first_sleep": "The door in the mountain closes. The dungeon curls around its full belly and dreams of the next door.",
	# tutorial hints (first run)
	"tut_start": "Pick a card at the bottom, then a tile. Rooms and traps go on the path; altars and graveyards go beside it.",
	"tut_warden": "The glowing shape is your Warden. It walks against the travelers and fights whoever it meets. Press Q for its ability. If it falls, the run is over.",
	"tut_souls": "The dead are yours. Press R to switch between devouring them (the Warden grows) and raising them (servants that whisper the truth).",
	"tut_loot": "They dropped something. Click it on the right and the Warden will wear it. Hover to compare with what it wears now.",
	"tut_lure": "The lure on the right decides who comes down tomorrow, and what you harvest from them.",
	"tut_escape": "Travelers who survive three loops find the way out. Watch the red dots under them.",
	"tut_week": "The week ends. Sleep now to keep the whole harvest, or risk another week for more.",
}

## What the act champion says, and when.
const BOSS_LINES := {
	"arrive": [
		"A light comes down the stairs, and the whole dungeon flinches.",
		"Aurelia: \"I know these halls. I swore I would never come back.\"",
		"Aurelia: \"Warden! I have come for what you took from me.\"",
	],
	"half": ["Aurelia: \"Your eyes... No. It can't be. ...Ren?\""],
	"death": ["Aurelia: \"I'm sorry I left you down here...\""],
}

## The Book of the Fallen: raised travelers give these pages in order, 4 per kind.
const FRAGMENTS := {
	"seeker": [
		"The map said treasure. I bought it from a priest. Why would a priest sell a treasure map?",
		"Every map has a mark in the corner. A little sun. I thought it was the mapmaker's sign.",
		"The priest asked my name and wrote it in a book. Like a ledger. Like a bill of sale.",
		"We weren't seeking treasure. We were the treasure. Somebody up there is paid in us.",
	],
	"hunter": [
		"They paid us to kill a beast. Half up front. They never expected to pay the other half.",
		"My captain has sent eleven companies down here. He has never once come down himself.",
		"Every Order blade bears the same rune. It glows when it's near you. Like it's homesick.",
		"If they wanted you dead they would send an army. They send us. A few at a time. Like rationing.",
	],
	"pilgrim": [
		"The priests lit the holy fire at the door themselves. They said it would guide us. It guided us here.",
		"The hymns say Saint Aurelia came out of the dark as a child. They never say what she left behind.",
		"At dawn mass the priests face the mountain, not the sun. I always wondered why.",
		"We were not sent to cleanse the dark. We were sent to feed it. A pilgrimage is just a longer word for a meal.",
	],
	"mage": [
		"The Dawn's light is not theirs. My instruments say it rises through the rock. From below.",
		"Each time a traveler dies down here, the sun above flickers brighter. Forty years of measurements.",
		"The archives were sealed after the Founding. I broke the seal. One word was written there: FED.",
		"Long ago there was no morning. They buried something beneath this mountain and made it hungry, so the sun would rise. You are what they buried.",
	],
}

## Once a kind's pages are all collected, raised travelers mutter one of these.
const WHISPERS := {
	"seeker": ["Someone up there sells these maps. Ask who.", "I picked the wrong door."],
	"pilgrim": ["We were an offering, not a cure.", "The fire was lit for us, not for you."],
	"hunter": ["The Order counts the missing. It never comes to look.", "The other half was never coming."],
	"mage": ["Their light flickers when you starve.", "The archives were sealed for a reason."],
}
