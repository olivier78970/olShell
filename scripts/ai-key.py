#!/usr/bin/env python3
"""Keeps the chat AI providers' API keys in the secret keyring.

Usage: ai-key.py set NAME      (the key is read from stdin)
       ai-key.py clear NAME
       ai-key.py has NAME...

The keys are stored with secret-tool (GNOME Keyring, KWallet or any other
Secret Service) under service=olshell-ai and provider=NAME, the provider's
id in the settings, so they never go in a settings file or on a command
line; ai-ask.py looks them up there. `set` with an empty key clears it. A
keyring without a default collection (no "login" keyring) gets the key in
its first collection that outlives the session.

`has` prints {"NAME": true|false, ...}: which of the providers have a key.
`set` and `clear` print {"ok": true} or {"ok": false, "message": TEXT}.
"""

import json
import shutil
import subprocess
import sys

ATTRIBUTES = ["service", "olshell-ai", "provider"]


def run(command, stdin=None):
    return subprocess.run(command, input=stdin, capture_output=True, text=True, timeout=60)


def kept_collection():
    """The first collection of the keyring that isn't the session's (which is
    forgotten at logout), or None."""
    result = run(["busctl", "--user", "--json=short", "get-property", "org.freedesktop.secrets",
                  "/org/freedesktop/secrets", "org.freedesktop.Secret.Service", "Collections"])
    try:
        paths = json.loads(result.stdout)["data"]
    except (ValueError, KeyError, TypeError):
        return None
    return next((path for path in paths if not path.endswith("/session")), None)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("set", "clear", "has"):
        sys.exit(__doc__)
    action, names = sys.argv[1], sys.argv[2:]
    if not shutil.which("secret-tool"):
        print(json.dumps({"ok": False, "message": "secret-tool is not installed (libsecret)"} if action != "has"
                         else {name: False for name in names}))
        return
    if action == "has":
        print(json.dumps({name: run(["secret-tool", "lookup"] + ATTRIBUTES + [name]).returncode == 0 for name in names}))
        return
    name = names[0]
    key = sys.stdin.read().strip() if action == "set" else ""
    if key:
        store = ["secret-tool", "store", "--label", f"olShell chat AI: {name}"]
        result = run(store + ATTRIBUTES + [name], key)
        collection = kept_collection() if result.returncode != 0 else None
        if collection:
            result = run(store + ["--collection", collection] + ATTRIBUTES + [name], key)
    else:
        result = run(["secret-tool", "clear"] + ATTRIBUTES + [name])
    print(json.dumps({"ok": True} if result.returncode == 0 else {"ok": False, "message": result.stderr.strip()}))


if __name__ == "__main__":
    main()
