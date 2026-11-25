"""Builds locale/ru.json from tools/ru_strings.py and reports untranslated strings.

Usage: python3 tools/build_locale.py [path/to/godot]
With a Godot binary it also dumps every string from game_data.gd and the code
(Loc.t("...") literals) and lists what is still missing.
"""
import json, os, re, glob, subprocess, sys
ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.dirname(__file__))
from ru_strings import RU

os.makedirs(os.path.join(ROOT, "locale"), exist_ok=True)
with open(os.path.join(ROOT, "locale", "ru.json"), "w", encoding="utf-8") as f:
    json.dump(RU, f, ensure_ascii=False, indent=1, sort_keys=True)
print(f"locale/ru.json: {len(RU)} strings")

keys = set()
for path in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
    for lit in re.findall(r'Loc\.t\("((?:[^"\\]|\\.)*)"\)', open(path, encoding="utf-8").read()):
        keys.add(json.loads('"' + lit + '"'))
if len(sys.argv) > 1:
    out = subprocess.run([sys.argv[1], "--headless", "--path", ROOT, "--script", "res://tests/dump_strings.gd"],
                         capture_output=True, text=True).stdout
    m = re.search(r"JSONSTART(.*)JSONEND", out, re.S)
    if m:
        keys |= set(json.loads(m.group(1)))
skip = {"\n", "   ", "     ", "\"%s\"", "%s\n\n%s", "%s  %s", "%s  —  %s", "%s %s", "%s, %s%s", "%s: %s!", "???"}
missing = sorted(k for k in keys if k not in RU and k not in skip)
print(f"missing: {len(missing)}")
for k in missing:
    print("  ", json.dumps(k, ensure_ascii=False))
