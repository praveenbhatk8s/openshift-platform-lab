#!/usr/bin/env python3
"""Read `oc get secret -A -o json` on stdin; print TLS secrets by expiry date, soonest first."""
import base64
import datetime as dt
import json
import subprocess
import sys

rows = []
for s in json.load(sys.stdin)["items"]:
    crt = s.get("data", {}).get("tls.crt")
    if not crt:
        continue
    out = subprocess.run(
        ["openssl", "x509", "-noout", "-enddate"],
        input=base64.b64decode(crt), capture_output=True,
    ).stdout.decode().strip()
    if not out.startswith("notAfter="):
        continue
    # e.g. "notAfter=Nov 10 12:00:00 2027 GMT" (first certificate in the bundle)
    end = dt.datetime.strptime(out[len("notAfter="):], "%b %d %H:%M:%S %Y %Z")
    rows.append((end, f'{s["metadata"]["namespace"]}/{s["metadata"]["name"]}'))

now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
for end, name in sorted(rows):
    print(f"{end:%Y-%m-%d}  {(end - now).days:>5} days  {name}")
