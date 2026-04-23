"""
Send one event to a Tiler data source via webhook.
Run: BASE_URL=https://your-app.example.com TILER_TOKEN=xxx SOURCE_SLUG=checkout_events python python-ingest.py
"""

import os
import sys
import time
import json
import urllib.request

base_url = os.environ.get("BASE_URL", "http://127.0.0.1:3131")
token = os.environ.get("TILER_TOKEN")
slug = os.environ.get("SOURCE_SLUG", "demo_requests")

if not token:
    print("Missing TILER_TOKEN env var", file=sys.stderr)
    sys.exit(1)

payload = {
    "status": "ok",
    "duration": 142.3,
    "source_ref": f"evt_{int(time.time())}",
}

req = urllib.request.Request(
    f"{base_url}/tiler/ingest/{slug}",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "X-Tiler-Token": token,
        "Content-Type": "application/json",
    },
    method="POST",
)

try:
    with urllib.request.urlopen(req, timeout=10) as res:
        print(f"HTTP {res.status}")
        print(res.read().decode("utf-8"))
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}")
    print(e.read().decode("utf-8"))
    sys.exit(1)
