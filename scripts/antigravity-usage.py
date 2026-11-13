#!/usr/bin/env python3
"""Prints the plan of the Antigravity login and its usage limits, for the
agent bar widget.

Usage: antigravity-usage.py

It reads the Google login the Antigravity CLI (agy) keeps in the session's
keyring (the Secret Service, through secret-tool), whose token it sends only
to Google: to Code Assist's loadCodeAssist (the plan and the Code Assist
project) and retrieveUserQuotaSummary (the quota of each model group), the
endpoints Antigravity asks. Google's access tokens last an hour and only
Antigravity renews the stored one, so when it has expired the script gets a
new one from Google's token endpoint with the stored refresh token (which
Google keeps as it is) and Antigravity's public client id, and keeps it in
memory: it never writes the login. Of the answers it keeps only the plan
and the limits. It prints one JSON object, as scripts/claude-usage.py does:
  {"plan": P, "limits": [{"minutes": W, "percent": N, "resetsAt": ISO, "name": G}, ...]}
or {"error": R}, where R is "login" (no login in the keyring, or Google
refused it: run agy to sign in again), "network" or "rateLimit" (the
endpoint refused for asking too often, with "retryAfter": the seconds it
asks to wait, when it says). P is the plan as Google names it, and each
model group G ("Gemini models", "Claude and GPT models") has a 5-hour
(W 300) and a weekly (W 10080) limit. Used by services/AgentUsage.qml.
"""

import json
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

LOAD_URL = "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist"
# The quota summary, from the host Antigravity asks first, then the main one.
SUMMARY_URLS = [
    "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
    "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
]
TOKEN_URL = "https://oauth2.googleapis.com/token"
# Antigravity's OAuth client, an installed application's (it is in the agy
# binary), whose secret Google documents as not secret.
CLIENT_ID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
CLIENT_SECRET = "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"
# The endpoints answer Antigravity's own version with every model group.
USER_AGENT = "antigravity/2.31.0 linux/amd64"
# The attributes of agy's login in the keyring, as `secret-tool lookup`
# takes them (its label: "Password for 'antigravity' on 'gemini'").
KEYRING = ["service", "gemini", "username", "antigravity"]
WINDOWS = {"5h": 300, "weekly": 10080}


# Raised when Google refuses the login, so agy has to sign in again.
class LoginError(Exception):
    pass


# The login agy keeps in the keyring, as a dict, or None.
def credentials():
    if not KEYRING:
        return None
    try:
        found = subprocess.run(["secret-tool", "lookup", *KEYRING], capture_output=True, text=True, timeout=10)
        return json.loads(found.stdout) if found.returncode == 0 and found.stdout.strip() else None
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


# A value of the login under any of `names` (its fields' spelling differs
# between Google's libraries), or None.
def field(creds, *names):
    for name in names:
        if creds.get(name):
            return creds[name]
    token = creds.get("token")
    return field(token, *names) if isinstance(token, dict) else None


# The login's expiry, in seconds since the epoch (0 when unknown).
def expiry(creds):
    value = field(creds, "expiry_date", "expiryDate", "expiry", "expires_at", "expiresAt")
    if isinstance(value, (int, float)):
        return value / 1000 if value > 1e11 else value
    try:
        return time.mktime(time.strptime(str(value)[:19], "%Y-%m-%dT%H:%M:%S")) - time.timezone
    except ValueError:
        return 0


# An access token of the login: the stored one while it lasts another
# minute, else a new one from the refresh token (kept in memory only).
def access_token(creds):
    token = field(creds, "access_token", "accessToken")
    if token and expiry(creds) > time.time() + 60:
        return token
    refresh = field(creds, "refresh_token", "refreshToken")
    if not refresh:
        raise LoginError()
    body = urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "refresh_token": refresh,
        "grant_type": "refresh_token",
    }).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(TOKEN_URL, data=body), timeout=15) as answer:
            token = json.load(answer).get("access_token")
    except urllib.error.HTTPError as error:
        if error.code in (400, 401):
            raise LoginError()
        raise
    if not token:
        raise LoginError()
    return token


# Posts `body` to `url` with the token, as Antigravity does.
def post(url, token, body):
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers={
        "Authorization": "Bearer " + token,
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
    })
    with urllib.request.urlopen(request, timeout=15) as answer:
        return json.load(answer)


# The answer when an endpoint refuses for asking too often: the error, with
# the seconds its Retry-After header asks to wait, when it gives a number.
def rate_limited(error):
    answer = {"error": "rateLimit"}
    try:
        answer["retryAfter"] = max(0, int(error.headers.get("Retry-After", "")))
    except ValueError:
        pass
    return answer


# The limits of the summary ({"groups": [{"displayName", "buckets":
# [{"window", "remainingFraction", "resetTime", "disabled"}]}]}). A used-up
# bucket has no remainingFraction (proto3 JSON leaves zeros out), only its
# resetTime.
def limits(summary):
    found = []
    for group in summary.get("groups") or []:
        for bucket in group.get("buckets") or []:
            minutes = WINDOWS.get(str(bucket.get("window", "")).lower())
            fraction = bucket.get("remainingFraction")
            if bucket.get("disabled") or not minutes or (fraction is None and not bucket.get("resetTime")):
                continue
            found.append({
                "minutes": minutes,
                "percent": max(0, min(100, round((1 - (fraction or 0)) * 100))),
                "resetsAt": bucket.get("resetTime"),
                "name": group.get("displayName") or "",
            })
    return found


def main():
    creds = credentials()
    if not creds:
        return {"error": "login"}
    try:
        token = access_token(creds)
        load = post(LOAD_URL, token, {"metadata": {"ideType": "ANTIGRAVITY"}})
        project = load.get("cloudaicompanionProject")
        if isinstance(project, dict):
            project = project.get("id")
        summary = None
        for url in SUMMARY_URLS:
            try:
                summary = post(url, token, {"project": project} if project else {})
                break
            except urllib.error.HTTPError as error:
                # Another host may answer where this one refuses.
                if error.code in (401, 429) or url == SUMMARY_URLS[-1]:
                    raise
    except LoginError:
        return {"error": "login"}
    except urllib.error.HTTPError as error:
        if error.code == 429:
            return rate_limited(error)
        return {"error": "login" if error.code in (401, 403) else "network"}
    except (OSError, ValueError):
        return {"error": "network"}
    tier = load.get("paidTier") or load.get("currentTier") or {}
    return {"plan": tier.get("name") or tier.get("id") or "?", "limits": limits(summary or {})}


if __name__ == "__main__":
    print(json.dumps(main()), flush=True)
