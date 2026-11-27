"""Narrative logic check for ABYSSAL GENESIS (Narrative Bible 1.1, sections 11-12).

Enumerates every combination of the player's key decisions, derives the relationship
states and the endings offered at the Heart, and checks the invariants:

  1. every ending is reachable;
  2. every playthrough offers at least 2 endings at the final choice;
  3. every relationship state is reachable;
  4. no ending depends on contradictory states;
  5. the "Lullaby" is always a choice, never forced.

The rules here are the single source of truth mirrored in the Bible; the game's
EndingEvaluator (TECH_SPEC.md, NARR-04) must implement the same rules and is tested
against this script's table.

Run: python3 tools/narrative_check.py [--table]
"""
import itertools
import sys
from collections import Counter

# ---------------------------------------------------------------- key decisions
# Each decision is a scene choice the player makes once in the campaign (see Bible 11.1).
DECISIONS = {
    # Aurelia
    "A1": ["spare", "use"],                 # Act II: spare her expedition / use it as bait
    "A2": ["show", "hide"],                 # Act III: show her the memory refinery / hide it
    "A3": ["gentle", "crystal", "hide"],    # Act IV: let the truth come through Ren / force the crystal on her / hide the truth
    "A5": ["spare", "kill"],                # Act V (only if she fights beside the Archon): spare or kill her
    # Zero (Ren)
    "Z1": ["let_speak", "silence"],         # Act I: let Ren speak to Aurelia through the wall / silence him
    "Z2": ["ren", "voss", "own"],           # Act III: whose voice the Abyss takes
    "Z3": ["door", "recording", "lie"],     # Act IV: how Ren learns about Lia: Aurelia's "let go of the door" / Voss-omega recording / keep him in the illusion
    "ZF": ["starved", "balanced", "gorged"],  # tendency: share of minds given to Zero over the campaign
    # Voss
    "V1": ["accept", "refuse"],             # Act II: accept her laboratory recipes
    "V2": ["protect", "abandon"],           # Act III: protect her fragments from the Archivists
    "V3": ["body", "archive", "erase"],     # Act IV, after Voss-omega: promise her a body / keep her as an archive / erase her
    # Archon evidence (three independent sources, Act I-III)
    "E1": ["spare", "devour"],              # Brann the foreman
    "E2": ["archive", "digest"],            # Kassian's mind after the Act I boss
    "E3": ["spare", "kill"],                # Magister Tessen after the White Labs boss
    # Humanity tendency: share of minds kept in the Archive
    "H": ["low", "mid", "high"],
}


def aurelia_state(d):
    if d["A3"] == "hide" or (d["A1"] == "use" and d["A2"] == "hide"):
        state = "archon_daughter"
    elif d["A3"] == "gentle":
        state = "ally"
    else:
        state = "estranged"
    if state == "archon_daughter" and d["A5"] == "kill":
        state = "dead"
    return state


def zero_state(d):
    if d["Z3"] == "recording" and d["Z1"] == "silence":
        return "rival"
    if d["ZF"] == "starved" and d["Z2"] != "ren":
        return "rival"
    if d["Z3"] == "door" and d["ZF"] != "starved" and (d["Z1"] == "let_speak" or d["Z2"] == "ren"):
        return "brother"
    return "stranger"


def zero_form(d):
    if d["ZF"] == "gorged":
        return "devourer"
    if d["ZF"] == "balanced" and d["H"] != "low":
        return "shepherd"
    if d["Z2"] == "ren":
        return "echo"
    return "vessel"


def voss_state(d):
    if d["V3"] == "erase":
        return "erased"
    if d["V3"] == "body" and d["V1"] == "accept":
        return "claimant"
    return "keeper"


def archon_exposed(d):
    evidence = (d["E1"] == "spare") + (d["E2"] == "archive") + (d["E3"] == "spare")
    return evidence >= 2


def endings(d):
    a, z, f, v = aurelia_state(d), zero_state(d), zero_form(d), voss_state(d)
    out = ["perfect_organism", "last_humanity"]  # always offered; their variant depends on state
    if a == "ally" and archon_exposed(d) and z != "rival":
        out.append("eternal_cycle")
    if v == "claimant":
        out.append("original_sin")
    if z == "brother" and f == "shepherd":
        out.append("second_heart")
    if a != "dead":
        out.append("lullaby")  # always a deliberate choice: let her sing
    return out


def bosses(d):
    """Act V bosses that depend on decisions (Bible 7, Act V)."""
    out = ["archon"]
    if zero_state(d) == "rival":
        out.append("void_king")
    if d["V2"] == "abandon" and d["V3"] != "body":
        out.append("voss_reborn")
    if aurelia_state(d) in ("archon_daughter", "dead"):
        out.append("aurelia_at_archon_side")
    return out


# Typical ways to play, to check that different play styles meet different finales.
ARCHETYPES = {
    "keeper of promises": dict(A1="spare", A2="show", A3="gentle", A5="spare", Z1="let_speak", Z2="own", Z3="door",
                               ZF="balanced", V1="accept", V2="protect", V3="archive", E1="spare", E2="archive", E3="spare", H="high"),
    "predator": dict(A1="use", A2="hide", A3="hide", A5="kill", Z1="silence", Z2="own", Z3="lie",
                     ZF="starved", V1="refuse", V2="abandon", V3="erase", E1="devour", E2="digest", E3="kill", H="low"),
    "scientist": dict(A1="spare", A2="hide", A3="crystal", A5="spare", Z1="silence", Z2="voss", Z3="recording",
                      ZF="balanced", V1="accept", V2="protect", V3="body", E1="spare", E2="archive", E3="kill", H="mid"),
    "Ren's keeper": dict(A1="use", A2="show", A3="gentle", A5="spare", Z1="let_speak", Z2="ren", Z3="door",
                         ZF="gorged", V1="refuse", V2="abandon", V3="archive", E1="devour", E2="archive", E3="spare", H="mid"),
    "does nothing special": dict(A1="spare", A2="hide", A3="gentle", A5="spare", Z1="let_speak", Z2="own", Z3="door",
                                 ZF="balanced", V1="refuse", V2="protect", V3="archive", E1="devour", E2="digest", E3="kill", H="mid"),
}


def main():
    keys = list(DECISIONS)
    total = 0
    reach = Counter()
    states = {"aurelia": Counter(), "zero": Counter(), "form": Counter(), "voss": Counter(), "archon_exposed": Counter()}
    option_counts = Counter()
    boss_counts = Counter()
    min_options = 99
    for combo in itertools.product(*(DECISIONS[k] for k in keys)):
        d = dict(zip(keys, combo))
        # A5 only exists when Aurelia fights at the Archon's side: skip duplicate branches
        if d["A5"] == "kill" and not (d["A3"] == "hide" or (d["A1"] == "use" and d["A2"] == "hide")):
            continue
        total += 1
        e = endings(d)
        for x in e:
            reach[x] += 1
        option_counts[len(e)] += 1
        min_options = min(min_options, len(e))
        states["aurelia"][aurelia_state(d)] += 1
        states["zero"][zero_state(d)] += 1
        states["form"][zero_form(d)] += 1
        states["voss"][voss_state(d)] += 1
        states["archon_exposed"][archon_exposed(d)] += 1
        for b in bosses(d):
            boss_counts[b] += 1
        # invariants on single playthroughs
        assert not ("second_heart" in e and zero_state(d) == "rival"), d
        assert not ("eternal_cycle" in e and aurelia_state(d) == "dead"), d
        assert not ("lullaby" in e and aurelia_state(d) == "dead"), d

    print(f"playthrough combinations: {total}")
    print("\nendings: share of playthroughs where the ending is offered")
    all_endings = ["perfect_organism", "last_humanity", "eternal_cycle", "original_sin", "second_heart", "lullaby"]
    for x in all_endings:
        print(f"  {x:17s} {100.0 * reach[x] / total:5.1f}%")
    print("\nnumber of endings offered at the Heart:")
    for n in sorted(option_counts):
        print(f"  {n} options: {100.0 * option_counts[n] / total:5.1f}%")
    print("\nrelationship states:")
    for k, c in states.items():
        print(f"  {k:15s} " + ", ".join(f"{s}={100.0 * n / total:.1f}%" for s, n in c.most_common()))
    print("\nAct V bosses (share of playthroughs):")
    for b, n in boss_counts.most_common():
        print(f"  {b:23s} {100.0 * n / total:5.1f}%")

    ok = True
    for x in all_endings:
        if reach[x] == 0:
            print(f"FAIL: ending {x} is unreachable")
            ok = False
    if min_options < 2:
        print("FAIL: some playthrough offers fewer than 2 endings")
        ok = False
    for name, expected in [("aurelia", ["ally", "estranged", "archon_daughter", "dead"]),
                           ("zero", ["brother", "stranger", "rival"]),
                           ("form", ["vessel", "shepherd", "devourer", "echo"]),
                           ("voss", ["keeper", "claimant", "erased"])]:
        for s in expected:
            if states[name][s] == 0:
                print(f"FAIL: state {name}={s} is unreachable")
                ok = False
    print("\narchetypes:")
    for name, d in ARCHETYPES.items():
        print(f"  {name:22s} aurelia={aurelia_state(d):15s} zero={zero_state(d):8s}/{zero_form(d):9s} voss={voss_state(d):8s}"
              f" exposed={archon_exposed(d)!s:5s} -> {', '.join(endings(d))}")
    for need, name in [("eternal_cycle", "keeper of promises"), ("second_heart", "keeper of promises"),
                       ("original_sin", "scientist"), ("perfect_organism", "predator")]:
        if need not in endings(ARCHETYPES[name]):
            print(f"FAIL: archetype '{name}' should be offered {need}")
            ok = False
    print("\nRESULT:", "OK" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
