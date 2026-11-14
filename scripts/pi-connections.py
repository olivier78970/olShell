#!/usr/bin/env python3
"""Prints the services pi is connected to, for the agent bar widget.

Usage: pi-connections.py

pi (the pi coding agent) has no plan or limits of its own here: it signs in
to other makers' accounts (Anthropic, ChatGPT, GitHub Copilot...). This reads
its login file (~/.pi/agent/auth.json, or in the folder PI_CODING_AGENT_DIR
names), of which it keeps only the name of each provider, never the key or
token it holds. It sends nothing anywhere. It prints one JSON object, as
scripts/opencode-connections.py does:
  {"connections": ["Anthropic", "ChatGPT", ...]}
([] when there is none or pi has never run), or {"error": "unreadable"} when
the file can't be read. Used by services/AgentUsage.qml.
"""

import json
import os

# Names for the usual providers of `pi auth login`; any other is shown by
# its id.
NAMES = {
    "anthropic": "Anthropic",
    "openai": "OpenAI",
    "openai-codex": "ChatGPT",
    "github-copilot": "GitHub Copilot",
    "google": "Google",
    "google-gemini-cli": "Gemini CLI",
    "google-antigravity": "Antigravity",
    "google-vertex": "Google Vertex AI",
    "openrouter": "OpenRouter",
    "xai": "xAI",
    "deepseek": "DeepSeek",
    "mistral": "Mistral",
    "groq": "Groq",
    "cerebras": "Cerebras",
    "amazon-bedrock": "Amazon Bedrock",
    "azure-openai": "Azure OpenAI",
}


def login_file():
    folder = os.environ.get("PI_CODING_AGENT_DIR") or os.path.expanduser("~/.pi/agent")
    return os.path.join(folder, "auth.json")


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
