#!/usr/bin/env python3
"""Prints the services Kilo Code is connected to, for the agent bar widget.

Usage: kilo-connections.py

Kilo Code has no plan or limits of its own here: it signs in to other
makers' accounts (OpenAI, Anthropic, its own Kilo Gateway...). This reads its
login file (~/.local/share/kilo/auth.json, or under XDG_DATA_HOME), of which
it keeps only the name of each provider, never the key or token it holds. It
sends nothing anywhere. It prints one JSON object, as
scripts/opencode-connections.py does:
  {"connections": ["OpenAI", "Anthropic", ...]}
([] when there is none or Kilo Code has never run), or {"error": "unreadable"}
when the file can't be read. Used by services/AgentUsage.qml.
"""

import json
import os

# The names `kilo auth list` shows for the usual providers; any other is
# shown by its id.
NAMES = {
    "anthropic": "Anthropic",
    "openai": "OpenAI",
    "kilo": "Kilo Gateway",
    "openrouter": "OpenRouter",
    "google": "Google",
    "google-vertex": "Google Vertex AI",
    "github-copilot": "GitHub Copilot",
    "xai": "xAI",
    "deepseek": "DeepSeek",
    "mistral": "Mistral",
    "groq": "Groq",
    "amazon-bedrock": "Amazon Bedrock",
    "azure": "Azure",
    "opencode": "OpenCode Zen",
}


def login_file():
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data, "kilo", "auth.json")


def main():
    path = login_file()
    if not os.path.isfile(path):
        return {"connections": []}
    try:
        with open(path, encoding="utf-8") as file:
            logins = json.load(file)
    except (OSError, ValueError):
        return {"error": "unreadable"}
    if not isinstance(logins, dict):
        return {"error": "unreadable"}
    return {"connections": [NAMES.get(provider, provider) for provider in logins]}


if __name__ == "__main__":
    print(json.dumps(main()), flush=True)
