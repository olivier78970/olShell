#!/usr/bin/env python3
"""Prints the ChatGPT plan of the Codex login and its Codex usage limits, for
the agent bar widget.

Usage: codex-usage.py

It reads the Codex CLI's login (~/.codex/auth.json, or the folder CODEX_HOME
names), whose token it sends only to ChatGPT's Codex usage endpoint, the one
Codex's /status asks. It never refreshes the token: Codex does that each
time it runs. Of the answer it keeps only the plan and the limits. It prints
one JSON object, as scripts/claude-usage.py does:
  {"plan": P, "limits": [{"minutes": W, "percent": N, "resetsAt": ISO}, ...]}
or {"error": R}, where R is "login" (no ChatGPT login, as with an API key,
or ChatGPT refused it: run codex to sign in again), "network" or "rateLimit" (the endpoint
refused for asking too often, with "retryAfter": the seconds it asks to
wait, when it says). P is the
plan ("Free", "Plus", "Pro"...), and the limits are the windows the plan
has, each W minutes long (a 5-hour and a weekly one, or a single 30-day one
on the free plan). Used by services/AgentUsage.qml.
"""

import datetime
import json
import os
import urllib.error
import urllib.request

URL = "https://chatgpt.com/backend-api/wham/usage"


# The ChatGPT tokens Codex keeps, or None (none, or an API key login).
def tokens():
    folder = os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
    try:
        with open(os.path.join(folder, "auth.json"), encoding="utf-8") as file:
            return json.load(file).get("tokens") or None
    except (OSError, ValueError):
        return None


# A window of the answer ({"used_percent", "limit_window_seconds",
# "reset_at"}) as the widget reads it.
def limit(window):
    if not isinstance(window, dict) or window.get("used_percent") is None:
        return None
    reset = window.get("reset_at")
    return {
        "minutes": round((window.get("limit_window_seconds") or 0) / 60),
        "percent": round(window["used_percent"]),
        "resetsAt": datetime.datetime.fromtimestamp(reset, datetime.timezone.utc).isoformat() if reset else None,
    }



# The answer when the endpoint refuses for asking too often: the error, with
# the seconds its Retry-After header asks to wait, when it gives a number.
def rate_limited(error):
    answer = {"error": "rateLimit"}
    try:
        answer["retryAfter"] = max(0, int(error.headers.get("Retry-After", "")))
    except ValueError:
        pass
    return answer


def main():
    login = tokens()
    if not login or not login.get("access_token"):
        return {"error": "login"}
    request = urllib.request.Request(URL, headers={
        "Authorization": "Bearer " + login["access_token"],
        "ChatGPT-Account-Id": login.get("account_id") or "",
        "User-Agent": "olShell",
    })
    try:
        with urllib.request.urlopen(request, timeout=15) as answer:
            usage = json.load(answer)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            return rate_limited(error)
        return {"error": "login" if error.code in (401, 403) else "network"}
    except (OSError, ValueError):
        return {"error": "network"}
    plan = usage.get("plan_type") or ""
    windows = usage.get("rate_limit") or {}
    limits = [limit(windows.get("primary_window")), limit(windows.get("secondary_window"))]
    return {"plan": plan[:1].upper() + plan[1:], "limits": [item for item in limits if item]}


if __name__ == "__main__":
    print(json.dumps(main()), flush=True)
