# Abstract balance model of a Fallen Below run. Rough: assumes the player softens travelers
# a bit more each day with cards and gear arrives at a steady rate.
# Abstract balance model of a Fallen Below run (mirrors game_data.gd formulas).
import random, statistics, sys

CLASSES = {  # hp, dmg
 "seeker": (20, 4.0), "pilgrim": (26, 3.0), "hunter": (32, 5.0), "mage": (18, 7.0)}
DIET = {"hunter": ("hp", 2.0), "seeker": ("evade", 1.0), "pilgrim": ("regen", 0.1), "mage": ("dmg", 0.3)}
TICK = 0.6

def run(p, lure="hunter", seed=None):
    rng = random.Random(seed)
    w = dict(hp=p["w_hp"], max=p["w_hp"], dmg=p["w_dmg"], dfn=p["w_def"], evade=0.0, regen=0.0)
    gear = dict(dmg=0.0, hp=0.0, dfn=0.0)
    loop = 1; day = 1; kills = 0; escapes = 0; threat = 0.0; boss = False
    days_per_loop = p["days_per_loop"]
    while day <= 40:
        loop = 1 + int((day - 1) / days_per_loop)
        size = min(4, 1 + day // 3)
        mult = 1 + p["loop_power"] * (loop - 1)
        party = []
        for i in range(size):
            c = lure if rng.random() < 0.7 else rng.choice(list(CLASSES))
            hp, dmg = CLASSES[c]
            party.append([c, hp * mult, dmg * mult])
        # the dungeon softens them before the Warden meets them (more cards each day)
        soften = min(p["soften_max"], p["soften_per_day"] * day)
        for t in party:
            t[1] *= (1 - soften)
        # some escape through side passages / never meet the Warden
        meet = [t for t in party if rng.random() > p["miss_chance"]]
        escapes += len(party) - len(meet)
        threat += p["t_esc"] * (len(party) - len(meet)) + p["t_kill"] * len(meet) + p["t_card"] * (1 + 0.45*len(meet))
        # fight
        alive = meet
        while alive:
            # warden strikes one target
            tgt = rng.choice(alive)
            tgt[1] -= w["dmg"] + gear["dmg"]
            if tgt[1] <= 0:
                alive.remove(tgt)
                kills += 1
                # devour: heal + diet
                w["hp"] = min(w["max"] + gear["hp"], w["hp"] + p["devour_heal"] * (w["max"] + gear["hp"]))
                st, amt = DIET[tgt[0]]
                if st == "hp": w["max"] += amt; w["hp"] += amt
                elif st == "dmg": w["dmg"] += amt
                elif st == "evade": w["evade"] = min(50, w["evade"] + amt)
                else: w["regen"] += amt
                if rng.random() < 0.45:  # a drop; better each loop
                    gear["dmg"] += p["gear_dmg"] * loop / 5
                    gear["hp"] += p["gear_hp"] * loop / 5
                    gear["dfn"] += p["gear_def"] * loop / 5
            for t in alive:
                if rng.random() * 100 < w["evade"]: continue
                d = t[2]
                w["hp"] -= max(d - (w["dfn"] + gear["dfn"]), d * 0.2)
            w["hp"] = min(w["max"] + gear["hp"], w["hp"] + w["regen"] * TICK)
            if w["hp"] <= 0:
                return day, kills, loop, "dead"
        # loop heal approximated per day
        w["hp"] = min(w["max"] + gear["hp"], w["hp"] + p["loop_heal"] * (w["max"] + gear["hp"]) / days_per_loop)
        if threat >= 100 and not boss:
            boss = True
            bhp = p["b_hp"] + loop * p["b_hp_l"]; bdmg = p["b_dmg"] + loop * p["b_dmg_l"]
            while bhp > 0:
                bhp -= w["dmg"] + gear["dmg"]
                if bhp <= 0: return day, kills, loop, "WIN"
                w["hp"] -= max(bdmg - (w["dfn"] + gear["dfn"]), bdmg * 0.2)
                if w["hp"] <= 0: return day, kills, loop, "dead(boss)"
        day += 1
    return day, kills, loop, "alive"

def report(name, p, lure):
    res = [run(p, lure, s) for s in range(400)]
    days = [r[0] for r in res]
    outs = {}
    for r in res: outs[r[3]] = outs.get(r[3], 0) + 1
    print(f"{name:10s} lure={lure:8s} median death day {statistics.median(days):5.1f}  p10 {sorted(days)[40]:3d}  p90 {sorted(days)[360]:3d}  outcomes {outs}")

# Values mirror scripts/data/game_data.gd (Bone Warden). Run: python3 tools/balance_sim.py
GAME = dict(w_hp=110, w_dmg=8, w_def=1, loop_power=0.15, days_per_loop=2.5, soften_per_day=0.03,
            soften_max=0.45, miss_chance=0.15, devour_heal=0.40, loop_heal=0.15,
            gear_dmg=1.5, gear_hp=8, gear_def=0.4, t_esc=6, t_kill=0.8, t_card=0.8,
            b_hp=200, b_hp_l=40, b_dmg=8, b_dmg_l=2.0)
for lure in ["hunter", "seeker", "mage", "pilgrim"]:
    report("game", GAME, lure)
