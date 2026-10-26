"""Resolve a git conflict in the one-line strings.json by a key union.

Run from the repo root while strings.json is conflicted (merge or rebase):
    python design/tools/merge_strings.py
Keys from both sides are kept; when both sides changed the same key, "ours" (stage 2) wins.
"""
import json, subprocess

PATH = "android-native/app/src/main/assets/strings.json"

def stage(n):
    out = subprocess.run(["git", "show", f":{n}:{PATH}"], capture_output=True, check=True).stdout
    return json.loads(out.decode("utf-8"))

ours, theirs = stage(2), stage(3)
merged = dict(theirs)
merged.update(ours)
with open(PATH, "w", encoding="utf-8", newline="") as f:
    f.write(json.dumps(merged, ensure_ascii=False, separators=(",", ":")))
json.loads(open(PATH, encoding="utf-8").read())
subprocess.run(["git", "add", PATH], check=True)
print(f"merged {len(ours)} + {len(theirs)} -> {len(merged)} keys")
