#!/usr/bin/env python3
"""Prints the Claude plan and its usage limits, for the agent bar widget.

Usage: claude-usage.py

It reads the Claude Code login (~/.claude/.credentials.json, or the folder
CLAUDE_CONFIG_DIR names), whose token it sends only to Anthropic's usage
endpoint, the one Claude Code's /usage asks. It never refreshes the token:
Claude Code does that each time it runs. It prints one JSON object, as scripts/codex-usage.py does:
  {"plan": P, "limits": [{"minutes": W, "percent": N, "resetsAt": ISO}, ...]}
or {"error": R}, where R is "login" (no login, or Claude refused it: run
claude to sign in again) or "network". P is the plan as Anthropic names it
("Pro", "Max 5x"...), and the limits are the 5-hour session's (W 300) and the
week's (W 10080), those the plan has. Used by services/AgentUsage.qml.
"""

import json
import os
import re
import urllib.error
import urllib.request

URL = "https://api.anthropic.com/api/oauth/usage"


# The login Claude Code keeps, or None.
def credentials():
    folder = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    try:
        with open(os.path.join(folder, ".credentials.json"), encoding="utf-8") as file:
            return json.load(file).get("claudeAiOauth") or None
    except (OSError, ValueError):
        return None


# A limit of the answer ({"utilization", "resets_at"}), over `minutes`, as
# the widget reads it.
def limit(window, minutes):
    if not isinstance(window, dict) or window.get("utilization") is None:
        return None
    return {"minutes": minutes, "percent": round(window["utilization"]), "resetsAt": window.get("resets_at")}


# The plan as Anthropic names it: the subscription ("pro", "max"...), with
# the Max multiplier taken from the rate limit tier ("default_claude_max_5x").
def plan_name(login):
    plan = login.get("subscriptionType") or ""
    name = plan[:1].upper() + plan[1:]
    multiplier = re.search(r"max_(\d+x)", login.get("rateLimitTier") or "")
    return name + " " + multiplier.group(1) if name and multiplier else name


def main():
    login = credentials()
    if not login or not login.get("accessToken"):
        return {"error": "login"}
    request = urllib.request.Request(URL, headers={
        "Authorization": "Bearer " + login["accessToken"],
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": "olShell",
    })
    try:
        with urllib.request.urlopen(request, timeout=15) as answer:
            usage = json.load(answer)
    except urllib.error.HTTPError as error:
        return {"error": "login" if error.code in (401, 403) else "network"}
    except (OSError, ValueError):
        return {"error": "network"}
    limits = [limit(usage.get("five_hour"), 300), limit(usage.get("seven_day"), 10080)]
    return {"plan": plan_name(login), "limits": [item for item in limits if item]}


if __name__ == "__main__":
    print(json.dumps(main()), flush=True)
