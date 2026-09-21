#!/usr/bin/env python3
"""Local initialization fixture; never runs a model or a tool."""

import json
import os
import sys
import time


def emit(value):
    print(json.dumps(value), flush=True)


for line in sys.stdin:
    value = json.loads(line)
    if value.get("type") != "control_request":
        continue
    if value["request"]["subtype"] != "initialize":
        continue
    mode = os.environ.get("SDK_INIT_MODE", "ok")
    if mode == "exit":
        raise SystemExit(0)
    time.sleep(float(os.environ.get("SDK_INIT_DELAY", "0.2")))
    response = {
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": value["request_id"],
            "response": {"commands": [{"name": "fixture", "description": "Local"}]},
        },
    }
    if mode == "error":
        response["response"] = {
            "subtype": "error", "request_id": value["request_id"],
            "error": "Synthetic initialization refusal",
        }
    before = {"type": "system", "subtype": "status", "status": "before-init"}
    after = {"type": "system", "subtype": "status", "status": "after-init"}
    sys.stdout.write("\n".join(json.dumps(frame) for frame in (before, response, after)) + "\n")
    sys.stdout.flush()
