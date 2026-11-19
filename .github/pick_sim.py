"""Prints the UDID of an available iPhone simulator: pro | max | small."""
import json, subprocess, sys
want = sys.argv[1]
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]
found = []
for runtime, ds in devices.items():
    if "iOS" not in runtime:
        continue
    for d in ds:
        n = d["name"]
        if not n.startswith("iPhone"):
            continue
        ok = {"pro": "Pro" in n and "Max" not in n,
              "max": "Pro Max" in n,
              "small": any(k in n for k in ("SE", "mini", "16e", "17e"))}[want]
        if ok:
            found.append((runtime, n, d["udid"]))
found.sort()
print(found[-1][2] if found else "")
