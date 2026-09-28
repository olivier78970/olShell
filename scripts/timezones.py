#!/usr/bin/env python3
"""Prints the UTC offset each time zone given has right now, as JSON.

Usage: timezones.py ZONE...   (IANA names, such as Asia/Tokyo)

Prints {"Asia/Tokyo": {"offset": 32400, "abbrev": "JST"}, ...}: the offset in
seconds east of UTC, daylight saving time included, and the zone's
abbreviation then. A zone the system doesn't know is left out. The shell's
JavaScript can't convert between time zones, so the clocks tab asks this
(from the system's time zone data) and works the times out from it.
"""

import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

zones = {}
for name in sys.argv[1:]:
    try:
        now = datetime.now(ZoneInfo(name))
    except Exception:
        continue
    zones[name] = {"offset": int(now.utcoffset().total_seconds()), "abbrev": now.tzname() or ""}
print(json.dumps(zones))
