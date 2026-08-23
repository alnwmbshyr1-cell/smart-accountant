#!/usr/bin/env python3
"""Print the state of one alert from a Prometheus /api/v1/alerts response."""
import json
import sys

alert_name = sys.argv[1]
data = json.load(sys.stdin)
for alert in data.get("data", {}).get("alerts", []):
    if alert.get("labels", {}).get("alertname") == alert_name:
        print(alert.get("state", "unknown"))
        raise SystemExit(0)
print("inactive")
