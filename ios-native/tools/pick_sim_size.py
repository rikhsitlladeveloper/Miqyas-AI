# Picks an iPhone simulator for the tour (.github/workflows/ios-tour.yml) and prints udid=... and name=... for GitHub
# outputs. "big": the newest iPhone N Pro Max; "small": the smallest screen there is (iPhone SE, then a mini, then
# iPhone 16e or a plain iPhone N). One is made when the runner has the device type but no simulator of it.
import json, re, subprocess, sys

want = sys.argv[1] if len(sys.argv) > 1 else "big"

def j(*a):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *a, "-j"]))

def ver(rt):
    m = re.search(r"iOS-(\d+)-(\d+)", rt)
    return (int(m.group(1)), int(m.group(2))) if m else None

# lower is better
def rank(name):
    if want == "big":
        m = re.fullmatch(r"iPhone (\d+) Pro Max", name)
        return (0, -int(m.group(1))) if m else None
    if re.fullmatch(r"iPhone SE \(3rd generation\)", name): return (0, 0)
    if re.fullmatch(r"iPhone SE.*", name): return (1, 0)
    m = re.fullmatch(r"iPhone (\d+) mini", name)
    if m: return (2, -int(m.group(1)))
    m = re.fullmatch(r"iPhone (\d+)e", name)
    if m: return (3, -int(m.group(1)))
    m = re.fullmatch(r"iPhone (\d+)", name)
    if m: return (4, -int(m.group(1)))
    return None

best = None
for rt, devs in j("devices", "available")["devices"].items():
    v = ver(rt)
    if not v:
        continue
    for d in devs:
        r = rank(d["name"])
        if r is None:
            continue
        key = (r, (-v[0], -v[1]))
        if best is None or key < best[0]:
            best = (key, d["udid"], d["name"], rt)

# a better device type without a simulator: made on the newest runtime that takes it
rts = sorted([r for r in j("runtimes")["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")],
             key=lambda r: ver(r["identifier"]) or (0, 0), reverse=True)
types = sorted([t for t in j("devicetypes")["devicetypes"] if rank(t["name"]) is not None], key=lambda t: rank(t["name"]))
for t in types:
    if best is not None and rank(t["name"]) >= best[0][0]:
        break
    made = False
    for r in rts:
        try:
            udid = subprocess.check_output(["xcrun", "simctl", "create", "Tour " + t["name"], t["identifier"], r["identifier"]],
                                           stderr=subprocess.DEVNULL).decode().strip()
        except subprocess.CalledProcessError:
            continue
        best = ((rank(t["name"]), (0, 0)), udid, t["name"], r["identifier"])
        made = True
        break
    if made:
        break

if best is None:
    raise SystemExit("no iPhone simulator for " + want)
print(f"udid={best[1]}")
print(f"name={best[2]} ({best[3].split('.')[-1]})")
