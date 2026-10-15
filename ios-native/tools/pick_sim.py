# Picks the newest plain iPhone simulator (iPhone 16, 17 ...) on the runner and prints udid=... for GitHub outputs.
import json, re, subprocess
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
best = None
for runtime, devs in data["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    ver = (int(m.group(1)), int(m.group(2)))
    for d in devs:
        n = re.fullmatch(r"iPhone (\d+)", d["name"])
        if n:
            key = (ver, int(n.group(1)))
            if best is None or key > best[0]:
                best = (key, d["udid"], d["name"], runtime)
if best is None:
    raise SystemExit("no iPhone simulator found")
print(f"udid={best[1]}")
print(f"name={best[2]} ({best[3].split('.')[-1]})")
