#!/usr/bin/env python3
"""Asks an AI provider one question, letting it search and read the user's files.

Usage: ai-ask.py --provider ID --protocol anthropic|openai --url URL
                 --model MODEL [--folders "A,B"] [--exclude "C,D"] [--tools "A,B"]
                 [--language LANG] -- QUESTION
       ai-ask.py --provider ID --protocol anthropic|openai --url URL --list-models

ID is the provider's name in the secret keyring, where its API key is looked
up (see ai-key.py), so the key never shows on a command line. A provider
without a key is still asked without one (a local server such as Ollama
needs none).

The anthropic protocol is Anthropic's Messages API, the openai one the Chat
Completions API of OpenAI and of the many servers that copy it. URL is the
API's base address, ending with its version (https://api.anthropic.com/v1,
https://api.openai.com/v1, http://localhost:11434/v1 for Ollama...).

--list-models prints the provider's models, the newest first (for OpenAI
itself, only those that can answer through Chat Completions): {"models":
[{"id": ID, "name": NAME}, ...]}, or {"error": TEXT}.

The model is given four tools, all of them read-only: listing a folder,
finding files by name, searching text in files, and reading a file. They only
reach the home folder and the --folders added to it (comma-separated), and
never what is excluded: the built-in list of secrets below (keys, keyrings,
browser profiles, password stores...) and --exclude (comma-separated: a path,
or a file or folder name pattern such as "*.sqlite"). Every path is resolved
first (symbolic links and ".." included), so a link can't lead outside.
Nothing here writes a file or runs anything but ripgrep, fd and secret-tool.

--tools names the tools the model gets, comma-separated, among list_dir,
find_files, search_text and read_file (the four above; all of them by
default) and web_search and web_fetch: with the anthropic protocol, those
two are Anthropic's own web search and web fetch tools, which run on
Anthropic's servers (each search is billed by Anthropic). Web fetch only opens the addresses the searches found
or the question gives, never one the model makes up, so a page can't have
it send what it read from the user's files to an address of the page
author's. The other protocols have no web tools.

Prints one JSON object per line as it goes: {"event": "tool", "name": NAME,
"arg": TEXT, "path": PATH} for each tool the model uses (TEXT is the name
pattern or the text searched for, "" for the others; PATH the folder or
file, or the web address read, "" for a web search; a web search or fetch
is announced once the provider has done it), then {"event": "answer", "text":
MARKDOWN} or {"event": "error", "message": TEXT}.
"""

import argparse
import fnmatch
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

HOME = os.path.realpath(os.path.expanduser("~"))

# OpenAI lists every model it has; those named with one of these can't answer
# a question through Chat Completions (speech, pictures, embeddings, the
# Responses-only ones...).
OPENAI_SKIPPED = ("audio", "realtime", "tts", "transcribe", "image", "search", "embedding",
                  "moderation", "instruct", "codex", "-pro", "computer-use", "deep-research")

# Paths the model never sees, inside the home folder: keys, keyrings,
# password managers, cloud credentials and browser profiles (cookies, saved
# passwords).
DENIED_PATHS = [
    "~/.ssh", "~/.gnupg", "~/.pki", "~/.password-store", "~/.local/share/keyrings",
    "~/.local/share/kwalletd", "~/.aws", "~/.azure", "~/.kube", "~/.docker",
    "~/.config/gcloud", "~/.config/gh", "~/.netrc", "~/.git-credentials",
    "~/.mozilla", "~/.zen", "~/.librewolf", "~/.floorp", "~/.waterfox", "~/.thunderbird",
    "~/.config/mozilla", "~/.config/zen", "~/.config/google-chrome", "~/.config/chromium",
    "~/.config/BraveSoftware", "~/.config/vivaldi", "~/.config/Bitwarden",
    "~/.config/KeePassXC", "~/.local/share/fish/fish_history", "~/.bash_history",
    "~/.zsh_history", "~/.histfile", "~/.python_history", "~/.cache", "~/.claude.json",
    "~/.claude/.credentials.json", "~/.codex", "~/.gemini", "~/.copilot", "~/.config/github-copilot",
    "~/.claws-mail", "~/.steam", "~/.local/share/Steam", "~/.pulse-cookie",
]

# File and folder names the model never sees, anywhere.
DENIED_NAMES = [
    ".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "*.kdbx", "*.gpg", "*.asc",
    "id_rsa*", "id_ecdsa*", "id_ed25519*", "id_dsa*", ".npmrc", ".pypirc",
    "credentials", "credentials.*", "*credential*", "*secret*", "*token*", "*cookie*", "*.keystore",
]

# How much a tool gives back at most, so one answer can't fill the model's
# context: characters of a result, lines read from a file, bytes of a file.
MAX_RESULT = 30000
MAX_LINES = 400
MAX_FILE = 5 * 1024 * 1024
MAX_MATCHES = 150

# How many rounds of tools the model gets for one question (each round, it
# asks for one or more tools and is given what they found): past that, it
# has to answer with what it has, which keeps a question's cost and time
# bounded and a model searching in circles from going on forever.
MAX_STEPS = 15

# How long a request to the provider may take, in seconds.
TIMEOUT = 180


def emit(event, **fields):
    print(json.dumps(dict(event=event, **fields)), flush=True)


class Guard:
    """Decides which paths the tools may reach."""

    def __init__(self, folders, exclude, tools=()):
        # The file tools that may be used.
        self.tools = set(tools)
        self.roots = [HOME]
        for folder in folders:
            path = os.path.realpath(os.path.expanduser(folder))
            if os.path.isdir(path) and path != "/" and path not in self.roots:
                self.roots.append(path)
        self.denied_paths = []
        self.denied_names = list(DENIED_NAMES)
        for entry in DENIED_PATHS + exclude:
            if "/" in entry or entry.startswith("~"):
                self.denied_paths.append(os.path.realpath(os.path.expanduser(entry)))
            else:
                self.denied_names.append(entry)

    def inside(self, path, folder):
        return path == folder or path.startswith(folder.rstrip("/") + "/")

    def denied(self, path):
        """Whether a path is excluded, wherever it is."""
        if any(self.inside(path, denied) for denied in self.denied_paths):
            return True
        # Names are matched below the folder it is in, not in that folder's own path.
        root = next((root for root in self.roots if self.inside(path, root)), None)
        parts = (os.path.relpath(path, root) if root else path).split(os.sep)
        return any(fnmatch.fnmatch(part, pattern) for part in parts for pattern in self.denied_names)

    def allowed(self, path):
        """Whether an absolute, already resolved path may be reached."""
        return any(self.inside(path, root) for root in self.roots) and not self.denied(path)

    def resolve(self, path):
        """The resolved path the model asked for (relative to the home folder
        if it isn't absolute), or raises PermissionError."""
        if not isinstance(path, str) or not path.strip():
            path = "~"
        path = os.path.expanduser(path.strip())
        if not os.path.isabs(path):
            path = os.path.join(HOME, path)
        # Where it really leads has to be allowed, and neither may be
        # excluded: a link to a secret is refused, and so is one named like one.
        written = os.path.normpath(path)
        real = os.path.realpath(path)
        if self.denied(written) or not self.allowed(real):
            raise PermissionError(f"Not allowed: {self.show(written)}")
        return real

    def show(self, path):
        """A path as the model is shown it: from ~ in the home folder."""
        return "~" + path[len(HOME):] if self.inside(path, HOME) else path


def list_dir(guard, args):
    path = guard.resolve(args.get("path"))
    if not os.path.isdir(path):
        return f"Not a folder: {guard.show(path)}"
    lines = []
    with os.scandir(path) as entries:
        for entry in sorted(entries, key=lambda entry: entry.name.lower()):
            full = os.path.join(path, entry.name)
            if not guard.allowed(os.path.realpath(full)) or not guard.allowed(full):
                continue
            try:
                if entry.is_dir():
                    lines.append(entry.name + "/")
                else:
                    lines.append(f"{entry.name}  ({entry.stat().st_size} bytes)")
            except OSError:
                lines.append(entry.name)
            if len(lines) >= 500:
                lines.append("... (more not listed)")
                break
    return f"{guard.show(path)}:\n" + ("\n".join(lines) if lines else "(empty)")


def walk(guard, top):
    """The files under `top` that may be reached, without following links."""
    for folder, dirs, files in os.walk(top):
        dirs[:] = [name for name in dirs if not name.startswith(".") and guard.allowed(os.path.join(folder, name))]
        for name in files:
            full = os.path.join(folder, name)
            if guard.allowed(full):
                yield full


def find_files(guard, args):
    top = guard.resolve(args.get("path"))
    pattern = str(args.get("pattern") or "*")
    found = []
    if shutil.which("fd"):
        result = subprocess.run(
            ["fd", "--color", "never", "--glob", "--absolute-path", "--max-results", "2000", "--", pattern, top],
            capture_output=True, text=True, timeout=60)
        candidates = result.stdout.splitlines()
    else:
        candidates = (path for path in walk(guard, top) if fnmatch.fnmatch(os.path.basename(path), pattern))
    for path in candidates:
        path = path.rstrip("/")
        if guard.allowed(path) and guard.allowed(os.path.realpath(path)):
            found.append(guard.show(path) + ("/" if os.path.isdir(path) else ""))
            if len(found) >= 200:
                found.append("... (more not listed)")
                break
    return "\n".join(found) if found else "No file found."


def search_text(guard, args):
    top = guard.resolve(args.get("path"))
    query = str(args.get("query") or "")
    if not query:
        return "Nothing to search for."
    glob = args.get("glob")
    matches = []
    if shutil.which("rg"):
        command = ["rg", "--color", "never", "--line-number", "--no-heading", "--with-filename",
                   "--null", "--max-count", "5", "--max-columns", "300", "--max-filesize", "2M", "--ignore-case"]
        if not args.get("regex"):
            command.append("--fixed-strings")
        if isinstance(glob, str) and glob:
            command += ["--glob", glob]
        command += ["--", query, top]
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
        for line in result.stdout.splitlines():
            path, _, rest = line.partition("\0")
            if guard.allowed(path) and guard.allowed(os.path.realpath(path)):
                matches.append(guard.show(path) + ":" + rest)
                if len(matches) >= MAX_MATCHES:
                    break
    else:
        needle = query.lower()
        for path in walk(guard, top):
            if isinstance(glob, str) and glob and not fnmatch.fnmatch(os.path.basename(path), glob):
                continue
            try:
                if os.path.getsize(path) > 2 * 1024 * 1024:
                    continue
                with open(path, encoding="utf-8", errors="strict") as file:
                    for number, text in enumerate(file, 1):
                        if needle in text.lower():
                            matches.append(f"{guard.show(path)}:{number}:{text.rstrip()[:300]}")
            except (OSError, UnicodeDecodeError):
                continue
            if len(matches) >= MAX_MATCHES:
                break
    if not matches:
        return "No match."
    if len(matches) >= MAX_MATCHES:
        matches.append("... (more matches not listed)")
    return "\n".join(matches)


def read_file(guard, args):
    path = guard.resolve(args.get("path"))
    if not os.path.isfile(path):
        return f"Not a file: {guard.show(path)}"
    if os.path.getsize(path) > MAX_FILE:
        return f"Too big to read: {guard.show(path)}"
    with open(path, "rb") as file:
        data = file.read()
    if b"\0" in data[:8192]:
        return f"Not a text file: {guard.show(path)}"
    lines = data.decode("utf-8", errors="replace").splitlines()
    offset = max(1, int(args.get("offset") or 1))
    limit = max(1, min(MAX_LINES, int(args.get("limit") or MAX_LINES)))
    shown = lines[offset - 1:offset - 1 + limit]
    text = "\n".join(f"{number}\t{line}" for number, line in enumerate(shown, offset))
    rest = len(lines) - (offset - 1 + len(shown))
    if rest > 0:
        text += f"\n... ({rest} more lines: read again with offset {offset + len(shown)})"
    return f"{guard.show(path)} ({len(lines)} lines):\n{text}"


# The tools, by name: what they do for the model, their arguments (JSON
# Schema), and the function running them.
TOOLS = {
    "list_dir": (
        "List the files and folders in a folder. Paths may start with ~ (the home folder).",
        {"path": {"type": "string", "description": "The folder, e.g. ~/Documents"}},
        ["path"], list_dir),
    "find_files": (
        "Find files and folders by name under a folder (recursive; hidden and git-ignored files are skipped).",
        {"pattern": {"type": "string", "description": "A glob matched against the file name, e.g. *.pdf or *invoice*"},
         "path": {"type": "string", "description": "The folder to search in (default ~)"}},
        ["pattern"], find_files),
    "search_text": (
        "Search for text inside files under a folder or in one file (case-insensitive). "
        "Gives file:line:text for each match.",
        {"query": {"type": "string", "description": "The text to find"},
         "path": {"type": "string", "description": "The folder or file to search in (default ~)"},
         "glob": {"type": "string", "description": "Only files whose name matches this glob, e.g. *.md"},
         "regex": {"type": "boolean", "description": "Whether query is a regular expression"}},
        ["query"], search_text),
    "read_file": (
        f"Read a text file, with line numbers, {MAX_LINES} lines at most at a time.",
        {"path": {"type": "string", "description": "The file"},
         "offset": {"type": "integer", "description": "The first line to read, from 1"},
         "limit": {"type": "integer", "description": f"How many lines (at most {MAX_LINES})"}},
        ["path"], read_file),
}

# Anthropic's web tools, by name, each tried in its newest version first
# (with dynamic filtering), then its basic one, for the models that don't
# have the newest; and how many times each may be used for one question.
WEB_TOOL_VERSIONS = [{"web_search": "web_search_20260209", "web_fetch": "web_fetch_20260209"},
                     {"web_search": "web_search_20250305", "web_fetch": "web_fetch_20250910"}]
WEB_MAX_USES = 5


def run_tool(guard, name, args):
    # (A tool that is off is refused even if the model asks for it anyway.)
    if name not in TOOLS or name not in guard.tools:
        return f"Unknown tool: {name}"
    if not isinstance(args, dict):
        args = {}
    emit("tool", name=name, arg=str(args.get("pattern") or args.get("query") or ""), path=str(args.get("path") or "~"))
    try:
        result = TOOLS[name][3](guard, args)
    except PermissionError as error:
        result = str(error)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result = f"Error: {error}"
    if len(result) > MAX_RESULT:
        result = result[:MAX_RESULT] + "\n... (cut)"
    return result


def send(url, headers, body=None):
    """The provider's JSON answer to a POST of `body`, or to a GET without."""
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method="POST" if data else "GET",
                                     headers={"content-type": "application/json", **headers})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        text = error.read().decode(errors="replace")
        try:
            detail = json.loads(text)
            detail = detail.get("error", detail)
            message = detail.get("message") if isinstance(detail, dict) else str(detail)
        except ValueError:
            message = text.strip()[:500]
        raise RuntimeError(f"HTTP {error.code}: {message or error.reason}") from None
    except urllib.error.URLError as error:
        raise RuntimeError(f"Can't reach {url}: {error.reason}") from None
    except TimeoutError:
        raise RuntimeError(f"No answer from {url} in {TIMEOUT} s") from None


def headers_for(protocol, key):
    if protocol == "anthropic":
        return {"anthropic-version": "2023-06-01", **({"x-api-key": key} if key else {})}
    return {"authorization": f"Bearer {key}"} if key else {}


def list_models(options, key):
    url = options.url + "/models"
    headers = headers_for(options.protocol, key)
    if options.protocol == "anthropic":
        models, after = [], None
        while True:
            reply = send(url + "?limit=1000" + (f"&after_id={after}" if after else ""), headers)
            models += [{"id": model["id"], "name": model.get("display_name") or model["id"]} for model in reply.get("data", [])]
            if not reply.get("has_more") or not reply.get("last_id"):
                return models
            after = reply["last_id"]
    models = [model for model in send(url, headers).get("data", []) if isinstance(model.get("id"), str)]
    if "api.openai.com" in url:
        models = [model for model in models if model["id"].startswith(("gpt-", "chatgpt-", "o1", "o3", "o4"))
                  and not any(word in model["id"] for word in OPENAI_SKIPPED)]
    models.sort(key=lambda model: model.get("created") or 0, reverse=True)
    return [{"id": model["id"], "name": model.get("name") or model["id"]} for model in models]


def anthropic_answer(content):
    """The answer's text, then the web pages it cites, a link each."""
    # A cited answer comes in pieces, a text block per citation: one text.
    text = "".join(block.get("text", "") for block in content if block.get("type") == "text").strip()
    sources = {}
    for block in content:
        for citation in block.get("citations") or []:
            url = citation.get("url")
            if url and url not in sources and url not in text:
                sources[url] = (citation.get("title") or url).replace("[", "(").replace("]", ")")
    if sources:
        text += "\n\n" + "\n".join(f"- [{title}]({url})" for url, title in sources.items())
    return text


def ask_anthropic(options, key, system, question, guard, names):
    url = options.url + "/messages"
    headers = headers_for("anthropic", key)
    tools = [{"name": name, "description": description,
              "input_schema": {"type": "object", "properties": properties, "required": required}}
             for name, (description, properties, required, _) in TOOLS.items() if name in names]
    # The web tools asked for, and their versions still to try: a model that doesn't have the
    # newest gets the basic ones, and one that has neither (or an
    # organization that turned them off) goes without.
    web = [name for name in ("web_search", "web_fetch") if name in names]
    versions = list(WEB_TOOL_VERSIONS) + [None] if web else [None]
    messages = [{"role": "user", "content": question}]
    step = 0
    while step <= MAX_STEPS:
        web_tools = [{"type": versions[0][name], "name": name, "max_uses": WEB_MAX_USES}
                     for name in web] if versions[0] else []
        body = {"model": options.model, "max_tokens": 8192, "system": system, "messages": messages}
        # (No tool at all: the APIs refuse an empty list.)
        if tools or web_tools:
            body["tools"] = tools + web_tools
            # Out of steps: an answer from what it has read so far.
            if step == MAX_STEPS:
                body["tool_choice"] = {"type": "none"}
        try:
            reply = send(url, headers, body)
        except RuntimeError as error:
            if web_tools and str(error).startswith("HTTP 400") and "web_" in str(error):
                versions.pop(0)
                continue
            raise
        step += 1
        content = reply.get("content") or []
        # What Anthropic's servers searched and fetched, as the file tools are
        # announced.
        for block in content:
            if block.get("type") == "server_tool_use":
                given = block.get("input") or {}
                emit("tool", name=block.get("name"), arg=str(given.get("query") or ""), path=str(given.get("url") or ""))
        # Its servers stopped the searches midway: sent back as is, they go on.
        if reply.get("stop_reason") == "pause_turn" and step <= MAX_STEPS:
            messages.append({"role": "assistant", "content": content})
            continue
        calls = [block for block in content if block.get("type") == "tool_use"]
        if not calls or reply.get("stop_reason") != "tool_use" or step > MAX_STEPS:
            return anthropic_answer(content)
        messages.append({"role": "assistant", "content": content})
        messages.append({"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": call["id"], "content": run_tool(guard, call.get("name"), call.get("input"))}
            for call in calls]})
    return ""


def ask_openai(options, key, system, question, guard, names):
    url = options.url + "/chat/completions"
    headers = headers_for("openai", key)
    tools = [{"type": "function", "function": {"name": name, "description": description,
              "parameters": {"type": "object", "properties": properties, "required": required}}}
             for name, (description, properties, required, _) in TOOLS.items() if name in names]
    messages = [{"role": "system", "content": system}, {"role": "user", "content": question}]
    for step in range(MAX_STEPS + 1):
        body = {"model": options.model, "messages": messages}
        if tools:
            body["tools"] = tools
            if step == MAX_STEPS:
                body["tool_choice"] = "none"
        reply = send(url, headers, body)
        choices = reply.get("choices") or []
        if not choices:
            raise RuntimeError("Empty answer")
        message = choices[0].get("message") or {}
        calls = message.get("tool_calls") or []
        if not calls or step == MAX_STEPS:
            return (message.get("content") or "").strip()
        messages.append({"role": "assistant", "content": message.get("content"), "tool_calls": calls})
        for call in calls:
            function = call.get("function") or {}
            try:
                args = json.loads(function.get("arguments") or "{}")
            except ValueError:
                args = {}
            messages.append({"role": "tool", "tool_call_id": call.get("id"),
                             "content": run_tool(guard, function.get("name"), args)})
    return ""


def lookup_key(provider):
    """The provider's API key from the secret keyring, "" if it has none."""
    if not shutil.which("secret-tool"):
        return ""
    result = subprocess.run(["secret-tool", "lookup", "service", "olshell-ai", "provider", provider],
                            capture_output=True, text=True, timeout=30)
    return result.stdout.strip() if result.returncode == 0 else ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", required=True)
    parser.add_argument("--protocol", required=True, choices=("anthropic", "openai"))
    parser.add_argument("--url", required=True)
    parser.add_argument("--model", default="")
    parser.add_argument("--list-models", action="store_true")
    parser.add_argument("--folders", default="")
    parser.add_argument("--exclude", default="")
    parser.add_argument("--tools", default=",".join(TOOLS))
    parser.add_argument("--language", default="en")
    parser.add_argument("question", nargs="*")
    options = parser.parse_args()
    options.url = options.url.strip().rstrip("/")
    key = lookup_key(options.provider)

    if options.list_models:
        try:
            print(json.dumps({"models": list_models(options, key)}))
        except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            print(json.dumps({"error": str(error)}))
        return

    split = lambda text: [part.strip() for part in text.split(",") if part.strip()]
    question = " ".join(options.question).strip()
    # The tools asked for (the web ones only exist with the anthropic protocol).
    names = {name for name in split(options.tools) if name in TOOLS
             or (name in ("web_search", "web_fetch") and options.protocol == "anthropic")}
    guard = Guard(split(options.folders), split(options.exclude), names & set(TOOLS))
    files = names & set(TOOLS)
    web = names - set(TOOLS)
    folders = ", ".join(guard.show(root) for root in guard.roots)
    system = (
        "You answer a single question from the user of a Linux desktop; there is no follow-up. "
        + (f"With the tools, you can {', '.join(sorted(files))} (read-only) in their files, within: {folders}; "
           f"the home folder is {HOME}. Look at their files only when the question is about them. "
           if files else "You can't see their files. ")
        + (f"You can also use {' and '.join(sorted(web))}, for what their files don't say "
           "or what may have changed since your training; never put anything from their files in a search. "
           if web else "You can't reach the web. ")
        + f"Today is {time.strftime('%A %Y-%m-%d, %H:%M')}. "
        "Answer concisely in Markdown, and name the files and web pages you used by their path or address. "
        "Your answer is shown with its images: to show one (a picture file of theirs, or one on the web), "
        "write it as ![description](its absolute path or web address), the path as it is, not encoded "
        "(spaces as spaces, not %20). "
        f"Answer in the language of the question (the desktop's is '{options.language}')."
    )
    try:
        if not options.model or not question:
            raise RuntimeError("No model or no question")
        answer = ask_anthropic(options, key, system, question, guard, names) if options.protocol == "anthropic" \
            else ask_openai(options, key, system, question, guard, names)
        if not answer:
            raise RuntimeError("The model gave no answer")
        emit("answer", text=answer)
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        emit("error", message=str(error))
        sys.exit(1)


if __name__ == "__main__":
    main()
