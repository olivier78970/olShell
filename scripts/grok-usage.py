#!/usr/bin/env python3
"""Prints the Grok plan of the Grok Build login and its usage limit, for the
agent bar widget.

Usage: grok-usage.py

It reads the Grok Build CLI's login (~/.grok/auth.json, or the file
GROK_AUTH_PATH names, or auth.json in the folder GROK_HOME names), whose
token it sends only to xAI's CLI proxy: its billing endpoint, the one Grok
Build's /usage asks, and its settings endpoint, which names the plan. It
never refreshes the token: Grok Build does that each time it runs. Of the
answers it keeps only the plan and the limit. It prints one JSON object, as
scripts/claude-usage.py does:
  {"plan": P, "limits": [{"minutes": W, "percent": N, "resetsAt": ISO}]}
or {"error": R}, where R is "login" (no grok.com login, as with an API key,
an expired one, or xAI refused it: run grok to sign in again), "network" or
"rateLimit" (the endpoint refused for asking too often, with "retryAfter":
the seconds it asks to wait, when it says). P is the plan ("SuperGrok",
"SuperGrok Heavy", "Free"...), and the limit is the plan's weekly or monthly
allowance, W minutes long. Used by services/AgentUsage.qml.
"""

import datetime
import json
import os
import urllib.error
import urllib.request

BASE = "https://cli-chat-proxy.grok.com/v1"
# The minutes of a period, when the answer gives its type but not its start.
PERIODS = {"USAGE_PERIOD_TYPE_WEEKLY": 10080, "USAGE_PERIOD_TYPE_MONTHLY": 43200}


# A timestamp of the answer as a datetime, or None.
def parse_time(text):
    try:
        return datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None


# The grok.com login Grok Build keeps, or None (none, an API key login, or an
# expired one). auth.json holds one login per sign-in scope: the latest one
# with a token that hasn't expired.
def login():
    path = os.environ.get("GROK_AUTH_PATH") or os.path.join(
        os.environ.get("GROK_HOME") or os.path.expanduser("~/.grok"), "auth.json")
    try:
        with open(path, encoding="utf-8") as file:
            store = json.load(file)
    except (OSError, ValueError):
        return None
    now = datetime.datetime.now(datetime.timezone.utc)
    logins = [entry for entry in store.values() if isinstance(entry, dict)
              and entry.get("key") and entry.get("user_id") and entry.get("auth_mode") != "api_key"
              and (parse_time(entry.get("expires_at")) or now) >= now]
    logins.sort(key=lambda entry: entry.get("create_time") or "")
    return logins[-1] if logins else None


# Asks the CLI proxy for `path` with the login, as Grok Build does.
def ask(auth, path):
    request = urllib.request.Request(BASE + path, headers={
        "Authorization": "Bearer " + auth["key"],
        "X-XAI-Token-Auth": "xai-grok-cli",
        "x-userid": auth["user_id"],
        "User-Agent": "olShell",
    })
    with urllib.request.urlopen(request, timeout=15) as answer:
        return json.load(answer)


# The answer when the endpoint refuses for asking too often: the error, with
# the seconds its Retry-After header asks to wait, when it gives a number.
def rate_limited(error):
    answer = {"error": "rateLimit"}
    try:
        answer["retryAfter"] = max(0, int(error.headers.get("Retry-After", "")))
    except ValueError:
        pass
    return answer


# The limit of the billing answer ({"creditUsagePercent", "currentPeriod":
# {"type", "start", "end"}}, or the older {"used", "monthlyLimit",
# "billingPeriodStart", "billingPeriodEnd"}) as the widget reads it, or None.
def limit(config):
    percent = config.get("creditUsagePercent")
    if percent is None:
        used = (config.get("used") or {}).get("val", 0)
        allowance = (config.get("monthlyLimit") or {}).get("val", 0)
        percent = 100 * used / allowance if allowance else None
    if percent is None:
        return None
    period = config.get("currentPeriod") or {}
    start = parse_time(period.get("start") or config.get("billingPeriodStart"))
    end = parse_time(period.get("end") or config.get("billingPeriodEnd"))
    minutes = round((end - start).total_seconds() / 60) if start and end else PERIODS.get(period.get("type"), 43200)
    return {"minutes": minutes, "percent": int(percent), "resetsAt": end.isoformat() if end else None}


def main():
    auth = login()
    if not auth:
        return {"error": "login"}
    try:
        billing = ask(auth, "/billing?format=credits")
    except urllib.error.HTTPError as error:
        if error.code == 429:
            return rate_limited(error)
        return {"error": "login" if error.code in (401, 403) else "network"}
    except (OSError, ValueError):
        return {"error": "network"}
    # The plan comes from the settings; without them, the limit still shows.
    try:
        settings = ask(auth, "/settings")
    except (OSError, ValueError):
        settings = {}
    plan = settings.get("subscription_tier_display") or settings.get("subscription_tier") or "?"
    found = limit(billing.get("config") or {})
    return {"plan": plan, "limits": [found] if found else []}


if __name__ == "__main__":
    print(json.dumps(main()), flush=True)
