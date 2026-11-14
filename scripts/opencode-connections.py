#!/usr/bin/env python3
"""Prints the services opencode is connected to, for the agent bar widget.

Usage: opencode-connections.py

opencode has no plan or limits of its own: it signs in to other makers'
accounts (an Anthropic API key, Claude Agent...), whose limits their own
agents' sections show. This reads opencode's database
(~/.local/share/opencode/opencode.db, or under XDG_DATA_HOME), opened read
only, and of each saved credential only its name and whether it is active,
never the key or token it holds. It sends nothing anywhere. It prints one
JSON object:
  {"connections": ["Anthropic", "Claude Agent", ...]}
the active connections, in the order they were added ([] when there is none
or opencode has never run), or {"error": "unreadable"} when the database
can't be read (locked, or laid out differently by a newer opencode). Used by
services/AgentUsage.qml.
"""

import json
import os
import sqlite3


def database():
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data, "opencode", "opencode.db")


def main():
    path = database()
    if not os.path.isfile(path):
        return {"connections": []}
    try:
        connection = sqlite3.connect("file:" + path + "?mode=ro", uri=True, timeout=5)
        try:
            rows = connection.execute(
                "SELECT label, integration_id FROM credential WHERE active ORDER BY time_created").fetchall()
        finally:
            connection.close()
    except sqlite3.Error:
        return {"error": "unreadable"}
    names = []
    for label, integration in rows:
        name = label or integration
        if name and name not in names:
            names.append(name)
    return {"connections": names}


if __name__ == "__main__":
    print(json.dumps(main()), flush=True)
