#!/usr/bin/env python3
"""
Owner-Only City of Burlingame Court Usage & Wait-Time Export Script (osodoso)
------------------------------------------------------------------------------
Pulls 100% real player-submitted Washington Park court & paddle-queue telemetry
from the PicklePark cloud store and exports a clean CSV + Executive Summary
for the City of Burlingame Parks & Recreation Department.

Usage:
    python3 scripts/export_city_telemetry.py
"""

import csv
import json
import os
import urllib.request
from datetime import datetime

TELEMETRY_URL = "https://picklepark-sync.cf-watcher.workers.dev/wp_city_telemetry_osodoso_v1"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "exports")
CSV_PATH = os.path.join(OUTPUT_DIR, "WashingtonPark_City_Usage_Report.csv")
SUMMARY_PATH = os.path.join(OUTPUT_DIR, "WashingtonPark_City_Executive_Summary.txt")


def fetch_telemetry_logs():
    req = urllib.request.Request(
        TELEMETRY_URL,
        headers={"Accept": "application/json", "User-Agent": "PicklePark-Owner-Exporter/1.0"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status == 200:
                raw = resp.read().decode("utf-8").strip()
                if raw:
                    data = json.loads(raw)
                    if isinstance(data, list):
                        return data
    except Exception:
        pass
    return []


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    logs = fetch_telemetry_logs()

    # Sort newest first
    logs.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

    headers = [
        "Timestamp_ISO8601",
        "Day_Of_Week",
        "Is_Weekend",
        "Hour_24h",
        "Permanent_Courts_In_Use_Max4",
        "Players_In_Paddle_Queue",
        "WalkOn_PB_Courts_Open_Max4",
        "Court2_Status",
        "Court3_Status",
        "Estimated_Wait_Minutes_15mGameModel",
        "Estimated_Total_Players_At_Park",
        "Reporter",
    ]

    with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        for entry in logs:
            writer.writerow([
                entry.get("timestamp", ""),
                entry.get("dayOfWeek", ""),
                entry.get("isWeekend", False),
                entry.get("hourOfDay", ""),
                entry.get("courtsInUse", 0),
                entry.get("peopleInQueue", 0),
                entry.get("walkOnCourtsOpen", 0),
                entry.get("court2State", "Free"),
                entry.get("court3State", "Free"),
                entry.get("estimatedWaitMinutes", 0),
                entry.get("estimatedTotalPlayers", 0),
                entry.get("reporterTag", "Player"),
            ])

    count = len(logs)
    avg_wait = round(sum(x.get("estimatedWaitMinutes", 0) for x in logs) / count) if count > 0 else 0
    max_wait = max((x.get("estimatedWaitMinutes", 0) for x in logs), default=0)
    full_courts = sum(1 for x in logs if x.get("courtsInUse", 0) >= 4)
    saturation = round((full_courts / count) * 100) if count > 0 else 0

    summary = f"""WASHINGTON PARK PICKLEBALL — CITY OF BURLINGAME REAL USAGE & WAIT TIME REPORT
Generated: {datetime.now().strftime('%Y-%m-%d %I:%M %p')}
=============================================================================
• Total Real Player Check-Ins Logged: {count}
• Average Recorded Court Wait Time:   {avg_wait} mins (based on 15-min avg pickleball game)
• Peak Recorded Wait Time:            {max_wait} mins
• Permanent Court 1 Full-Capacity:    {saturation}% of reports show all 4 courts full
=============================================================================
CSV File Saved To:     {CSV_PATH}
Summary File Saved To: {SUMMARY_PATH}
"""

    with open(SUMMARY_PATH, "w", encoding="utf-8") as f:
        f.write(summary)

    print(summary)


if __name__ == "__main__":
    main()
