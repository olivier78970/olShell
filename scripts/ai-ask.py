#!/usr/bin/env python3
"""Asks an AI provider one question, letting it search and read the user's files.

Usage: ai-ask.py --provider ID --protocol anthropic|openai --url URL
                 --model MODEL [--folders "A,B"] [--exclude "C,D"] [--tools "A,B"]
                 [--shell FOLDER] [--language LANG] -- QUESTION
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
reach the home folder and the --folders added to it (comma-separated: a folder
or file path, with wildcards such as "/data/*/docs"; a bare name is looked for
in the home folder), and never what is excluded: the built-in list of secrets
below (keys, keyrings, browser profiles, password stores...) and --exclude
(comma-separated: a path, with wildcards too, or a file or folder name pattern
such as "*.sqlite"). Every path is resolved
first (symbolic links and ".." included), so a link can't lead outside.
Nothing here writes a file or runs anything but ripgrep, fd, secret-tool and
the shell's own IPC calls (below).

More tools are about olShell itself, whose folder --shell gives:
shell_docs_search and shell_docs_read search and read its documentation (README.md and docs/)
(read-only, a passage or a section at a time, since its paragraphs are long),
shell_settings reads its current settings, theme and language from its
config/ files (read-only),
and shell_ipc_list and shell_ipc_call list and run the running shell's IPC
calls (`quickshell ipc -p FOLDER call ...`), except those in IPC_BLOCKED
below: the ones that can't be undone and the chat's own. shell_ipc_propose
checks a call the same way without running it, and prints {"event":
"action", "label": TEXT, "target": T, "function": F, "args": [TEXT, ...]}:
a button the panel shows under the answer, running the call when clicked.

--tools names the tools the model gets, comma-separated, among list_dir,
find_files, search_text and read_file (the four above; all of them by
default), the four shell ones, and web_search and web_fetch: with the anthropic protocol, those
two are Anthropic's own web search and web fetch tools, which run on
Anthropic's servers (each search is billed by Anthropic). For OpenAI's own API
(--provider openai) and xAI's (--provider xai), the question goes through the
provider's Responses API, and web_search is its built-in web search tool (billed
per search by the provider; there is no fetch).
Anthropic's web fetch only opens the addresses the searches found
or the question gives, never one the model makes up, so a page can't have
it send what it read from the user's files to an address of the page
author's. Other providers have no web tools.

Prints one JSON object per line as it goes: {"event": "tool", "name": NAME,
"arg": TEXT, "path": PATH} for each tool the model uses (TEXT is the name
pattern or the text searched for, "" for the others; PATH the folder or
file, or the web address read, "" for a web search; a web search or fetch
is announced once the provider has done it), {"event": "usage", "requests": N,
"input": N, "output": N, "cached": N, "reasoning": N, "searches": N} after each
request to the provider (the totals so far for the question: the tokens sent
and received, those of the input read from its cache, those of the output spent
reasoning, and the web searches the provider made), then {"event": "answer", "text":
MARKDOWN} or {"event": "error", "message": TEXT}.
"""

import argparse
import fnmatch
import glob
import json
import os
import re
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

# The shell's IPC calls the model may not run, by target ("*" for all of a
# target's): the ones that can't be undone (logging out, shutting down,
# locking the screen, putting every setting back) and the chat's own, which
# would ask or clear the very question being answered.
IPC_BLOCKED = {
    "chatai": {"*"},
    "power": {"restart", "shutdown", "suspend", "logout", "firmware"},
    "lock": {"lock"},
    "settings": {"factoryReset", "reset", "resetPage"},
    "profiles": {"apply", "remove", "save"},
}

# How long an IPC call may take, in seconds.
IPC_TIMEOUT = 15

# The shell's documentation: how many matches a search gives at most, how
# many characters it shows on each side of a match (a paragraph is one line
# of up to thousands of characters), and how many lines a read by line
# numbers gives at most.
MAX_DOC_MATCHES = 40
DOC_CONTEXT = 200
MAX_DOC_LINES = 60

# How many actions the model may propose under one answer.
MAX_PROPOSALS = 3


def emit(event, **fields):
    print(json.dumps(dict(event=event, **fields)), flush=True)


# What the question has used so far (see track).
USAGE = {"requests": 0, "input": 0, "output": 0, "cached": 0, "reasoning": 0, "searches": 0}


def track(input=0, output=0, cached=0, reasoning=0, searches=0):
    """Adds one request's usage to the question's and announces the totals."""
    USAGE["requests"] += 1
    for name, value in (("input", input), ("output", output), ("cached", cached),
                        ("reasoning", reasoning), ("searches", searches)):
        USAGE[name] += value if isinstance(value, int) else 0
    emit("usage", **USAGE)


class Guard:
    """Decides which paths the tools may reach."""

    def __init__(self, folders, exclude, tools=(), shell=""):
        # The file and shell tools that may be used, and the shell's folder.
        self.tools = set(tools)
        self.shell = os.path.realpath(shell) if shell else ""
        # The settings panel's map, once read (see shell_map).
        self.map = None
        # How many actions have been proposed (see shell_ipc_propose), and
        # whether a shell tool was used (see remind).
        self.proposed = 0
        self.used_shell = False
        # What the tools may reach besides the home folder: folders and files,
        # each entry a path (~ and wildcards allowed; a name alone is looked
        # for in the home folder).
        self.roots = [HOME]
        for entry in folders:
            for path in self.expand(entry, relative=True):
                if os.path.exists(path) and path != "/" and path not in self.roots:
                    self.roots.append(path)
        self.denied_paths = []
        self.denied_names = list(DENIED_NAMES)
        for entry in DENIED_PATHS + exclude:
            if "/" in entry or entry.startswith("~"):
                self.denied_paths.extend(self.expand(entry))
            else:
                self.denied_names.append(entry)

    @staticmethod
    def expand(entry, relative=False):
        """The resolved paths an entry of the settings stands for: ~ and
        wildcards expanded, a bare name (with `relative`) taken from the home folder."""
        path = os.path.expanduser(entry)
        if relative and not os.path.isabs(path):
            path = os.path.join(HOME, path)
        matches = glob.glob(path, recursive=True) if glob.has_magic(path) else [path]
        return [os.path.realpath(match) for match in matches]

    def inside(self, path, folder):
        return path == folder or path.startswith(folder.rstrip("/") + "/")

    def denied(self, path):
        """Whether a path is excluded, wherever it is."""
        if any(self.inside(path, denied) for denied in self.denied_paths):
            return True
        # Names are matched below the folder it is in, not in that folder's own path.
        root = next((root for root in self.roots if self.inside(path, root)), None)
        # (a file added on its own is checked by the names above it, not its own).
        if root and not os.path.isdir(root):
            root = os.path.dirname(root)
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


def readme_lines(guard):
    """The lines of the shell's documentation: its README.md, then each file of
    its docs/ folder (by name), as one text, so the section headings and line
    numbers run on from file to file."""
    path = os.path.join(guard.shell, "README.md")
    if not guard.shell or not os.path.isfile(path):
        raise OSError("The shell's documentation (README.md) isn't there")
    names = [path] + sorted(glob.glob(os.path.join(guard.shell, "docs", "*.md")))
    lines = []
    for name in names:
        with open(name, encoding="utf-8", errors="replace") as file:
            lines += file.read().splitlines() + [""]
    return lines


def headings_of(lines):
    """The headings, as (line number, level, text), outside code blocks."""
    headings, fenced = [], False
    for number, line in enumerate(lines, 1):
        if line.startswith("```"):
            fenced = not fenced
        match = None if fenced else re.match(r"^(#{1,6})\s+(.+)", line)
        if match:
            headings.append((number, len(match.group(1)), match.group(2).strip()))
    return headings


def section_names(lines, headings):
    """Each line's section, as its headings from the second level down ("Settings > From a script")."""
    names, trail, at = [], [], 0
    for number in range(1, len(lines) + 1):
        while at < len(headings) and headings[at][0] == number:
            _, level, text = headings[at]
            trail = [entry for entry in trail if entry[0] < level] + [(level, text)]
            at += 1
        names.append(" > ".join(text for level, text in trail if level >= 2))
    return names


def numbered(lines, first):
    """Lines from line `first` on, numbered, up to MAX_RESULT characters, saying where to read on."""
    out, size = [], 0
    for number, line in enumerate(lines, first):
        if out and size + len(line) > MAX_RESULT - 500:
            out.append(f"... (goes on: read again with offset {number})")
            break
        out.append(f"{number}\t{line}")
        size += len(line) + 8
    return "\n".join(out)


def shell_docs_search(guard, args):
    query = str(args.get("query") or "").strip()
    if not query:
        return "Nothing to search for."
    try:
        pattern = re.compile(query if args.get("regex") else re.escape(query), re.IGNORECASE)
    except re.error as error:
        return f"Not a valid regular expression: {error}"
    lines = readme_lines(guard)
    sections = section_names(lines, headings_of(lines))
    matches = []
    for number, line in enumerate(lines, 1):
        # Only the text around the first few matches of the line: the parts
        # overlapping merged, each cut part marked with "…".
        parts = []
        for found in list(pattern.finditer(line))[:3]:
            start, end = max(0, found.start() - DOC_CONTEXT), min(len(line), found.end() + DOC_CONTEXT)
            if parts and start <= parts[-1][1]:
                parts[-1] = (parts[-1][0], end)
            else:
                parts.append((start, end))
        if not parts:
            continue
        text = " ".join(("…" if start > 0 else "") + line[start:end] + ("…" if end < len(line) else "")
                        for start, end in parts)
        matches.append(f"line {number} [{sections[number - 1] or 'top'}]: {text}")
        if len(matches) >= MAX_DOC_MATCHES:
            matches.append("... (more matches not listed: search for something more precise)")
            break
    return "\n".join(matches) if matches else "No match."


def shell_docs_read(guard, args):
    lines = readme_lines(guard)
    headings = headings_of(lines)
    section = str(args.get("section") or "").strip().lstrip("#").strip().lower()
    if section:
        # The heading named so, else the first one containing the name, down
        # to the next heading of its level or above.
        found = next((h for h in headings if h[2].lower() == section), None) \
            or next((h for h in headings if section in h[2].lower()), None)
        if not found:
            return f"No section named like that. The sections:\n{shell_docs_read(guard, {})}"
        number, level, _ = found
        end = next((h[0] for h in headings if h[0] > number and h[1] <= level), len(lines) + 1)
        return numbered(lines[number - 1:end - 1], number)
    if args.get("offset"):
        offset = max(1, int(args.get("offset")))
        limit = max(1, min(MAX_DOC_LINES, int(args.get("limit") or 20)))
        return f"The documentation ({len(lines)} lines):\n" + numbered(lines[offset - 1:offset - 1 + limit], offset)
    # Neither: the table of contents.
    return "\n".join(f"{number}\t{'  ' * max(0, level - 2)}{text}" for number, level, text in headings)


def shell_state(guard):
    """The running shell's current state, by name: every setting (its
    config/Settings.json, which the shell keeps whole and up to date), the
    selected theme and wallpaper, and the language."""
    if not guard.shell:
        raise OSError("The shell's settings can't be reached")
    def load(name):
        try:
            with open(os.path.join(guard.shell, "config", name), encoding="utf-8") as file:
                value = json.load(file)
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError):
            return {}
    state = dict(load("Settings.json"))
    theme = load("ThemeState.json")
    # (Not settings, but what the theme panel and the language menu set.)
    state["theme (the theme panel's pick: auto follows the wallpaper)"] = theme.get("selected", "auto")
    state["wallpaper"] = theme.get("wallpaper", "")
    state["language (auto: the desktop's)"] = load("LocaleState.json").get("setting", "auto")
    return state


def shell_map(guard):
    """The settings panel's map, from the running shell (its `settings map`
    IPC call): {"pages": [{id, name}], "settings": {key: {page, name, kind, range}},
    "widgets": {id: name}}, names as the panel shows them. Read once."""
    if guard.map is None:
        guard.map = {}
        try:
            result = ipc_run(guard, "call", "settings", "map")
            value = json.loads(result.stdout) if result.returncode == 0 else {}
            guard.map = value if isinstance(value, dict) else {}
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    return guard.map


def bar_widgets(state, widget_names):
    """Where each bar widget is, in words: its lane of the bar's layout, its
    group (a group starts at a pill's first widget and at each widget with a
    divider before it) and whether that group is shown, shown only on hover,
    or turned off; or that it is off the bar. {id: text}."""
    lanes = {"barLeft": "the Left lane (the left end of the bar, or its top on a side bar)",
             "barCenter": "the Center lane (the middle of the bar)",
             "barRight": "the Right lane (the right end of the bar, or its bottom on a side bar)"}
    dividers = set(state.get("barDividers") or [])
    hover, off = set(state.get("barCollapsed") or []), set(state.get("barGroupsOff") or [])
    disabled = set(state.get("barDisabled") or [])
    name = lambda id: widget_names.get(id, id)
    where = {}
    for lane, words in lanes.items():
        groups = []
        for id in state.get(lane) or []:
            if not groups or id in dividers:
                groups.append([])
            groups[-1].append(id)
        for group in groups:
            mode = ("off: hidden, though its widgets stay in the group" if group[0] in off
                    else "hover: shown only while the pointer is over its pill, hidden otherwise"
                    if group[0] in hover else "on: always shown")
            members = ", ".join(name(id) for id in group)
            for id in group:
                where[id] = (f"in {words}, in the group {members}; that group's mode is {mode} "
                             f"(the modes are on, hover and off: settings group {id} <mode> changes it)")
    for id in widget_names:
        where.setdefault(id, "disabled: off the bar and not loaded at all, with its feature and IPC calls (settings widgetEnabled " + id + " 1 loads it again)"
                         if id in disabled else "off: not on the bar (in the Off lane of the layout)")
    return where


def shell_settings(guard, args):
    state = shell_state(guard)
    shell = shell_map(guard)
    places = shell.get("settings") or {}
    widget_names = shell.get("widgets") or {}
    choices = shell.get("choices") or {}
    # Each bar widget's place in words, as if it were a setting.
    for id, text in bar_widgets(state, widget_names).items():
        state[f"widget {widget_names.get(id, id)} ({id})"] = text
    keys = args.get("keys") if isinstance(args.get("keys"), list) else []
    search = str(args.get("search") or "").strip().lower()
    if keys:
        # (A widget's id finds its line too.)
        wanted = {str(key) for key in keys}
        wanted |= {name for name in state if name.startswith("widget ") and name.rsplit("(", 1)[-1].rstrip(")") in wanted}
        names = [name for name in state if name in wanted or name.split(" (")[0] in wanted]
        found = {name.split(" (")[0] for name in names} | set(names) \
            | {name.rsplit("(", 1)[-1].rstrip(")") for name in names if name.startswith("widget ")}
        unknown = sorted({str(key) for key in keys} - found)
    else:
        # (By name or by value: "chat" also finds the bar zone holding chatAi.)
        names = [name for name in state if search in name.lower()
                 or search in json.dumps(state[name], ensure_ascii=False).lower()] if search else list(state)
        unknown = []
    lines = []
    for name in names:
        value = json.dumps(state[name], ensure_ascii=False) if not name.startswith("widget ") else state[name]
        value = value if len(value) <= 300 else value[:300] + "... (cut)"
        place = places.get(name)
        where = f"  [in the settings panel: {place['name']}; page {place['page']}]" if place else ""
        if name in choices:
            where += f"  [takes: {', '.join(map(str, choices[name]))}]"
        lines.append(f"{name} = {value}{where}")
    if unknown:
        lines.append("No such setting: " + ", ".join(unknown))
    return "\n".join(lines) if lines else f"No setting named like {search!r}."


def ipc_blocked(target, function):
    names = IPC_BLOCKED.get(target, set())
    return "*" in names or function in names


def ipc_run(guard, *words):
    """Runs `quickshell ipc -p SHELL <words>` against the running shell."""
    if not guard.shell or not shutil.which("quickshell"):
        raise OSError("The shell can't be reached")
    # (The shell exports QS_CONFIG_PATH; -p names the shell anyway.)
    env = {name: value for name, value in os.environ.items() if name != "QS_CONFIG_PATH"}
    return subprocess.run(["quickshell", "ipc", "-p", guard.shell, *words],
                          capture_output=True, text=True, timeout=IPC_TIMEOUT, env=env)


def ipc_catalog(guard):
    """The running shell's IPC calls the model may run: {target: {function: (parameters, return type)}}."""
    result = ipc_run(guard, "show")
    if result.returncode != 0:
        raise OSError((result.stderr or result.stdout).strip() or "The shell didn't answer")
    catalog, target = {}, None
    for line in result.stdout.splitlines():
        match = re.match(r"^target (\S+)", line)
        if match:
            target = match.group(1)
            continue
        match = re.match(r"^\s+function (\w+)\((.*)\): (\S+)", line)
        if match and target and not ipc_blocked(target, match.group(1)):
            catalog.setdefault(target, {})[match.group(1)] = (match.group(2), match.group(3))
    return catalog


def shell_ipc_list(guard, args):
    catalog = ipc_catalog(guard)
    calls = [f"{target} {function}({parameters}): {returns}"
             for target in sorted(catalog) for function, (parameters, returns) in sorted(catalog[target].items())]
    return "\n".join(calls) if calls else "No call can be run."


def ipc_checked(guard, args):
    """(target, function, values as text, None) for a call the model may run, or (..., the reason it may not)."""
    target, function = str(args.get("target") or "").strip(), str(args.get("function") or "").strip()
    values = args.get("args")
    values = [] if values is None else values if isinstance(values, list) else [values]
    # Yes/no arguments are 1 or 0 for the shell.
    values = [("1" if value else "0") if isinstance(value, bool) else str(value) for value in values]
    if ipc_blocked(target, function):
        return target, function, values, f"Not allowed: {target} {function} is kept for the user to do themselves."
    catalog = ipc_catalog(guard)
    if function not in catalog.get(target, {}):
        return target, function, values, f"No such call: {target} {function}. shell_ipc_list lists them."
    parameters = [part.strip() for part in catalog[target][function][0].split(",") if part.strip()]
    if len(values) != len(parameters):
        return target, function, values, f"{target} {function} takes {len(parameters)} argument(s): ({', '.join(parameters)})."
    # (A value starting with a dash other than a number would be read as an option.)
    for value in values:
        if value.startswith("-") and not re.fullmatch(r"-\d+(\.\d+)?", value):
            return target, function, values, f"Can't pass {value!r}: a value may not start with '-' unless it is a number."
    return target, function, values, settings_refused(guard, target, function, values)


# The `settings` calls taking a bar widget first, and what their second
# argument may be where it is one of a few words.
WIDGET_CALLS = {"place": ("left", "center", "right", "off"), "group": ("on", "hover", "off"),
                "widgetShown": None, "move": None, "divider": None, "moveGroup": None}


def settings_refused(guard, target, function, values):
    """Why a `settings` call would do nothing, or None: the shell ignores an
    unknown setting, a value that isn't one of a setting's choices, an
    unknown widget, zone or group mode without a word, so they are caught
    here (against the running shell's own lists), with what it takes."""
    if target != "settings":
        return None
    shell = shell_map(guard)
    known, choices, widgets = shell.get("settings") or {}, shell.get("choices") or {}, shell.get("widgets") or {}
    if function in ("set", "choose", "get", "getChoice") and known and values:
        key = values[0]
        # (Every panel's placement at once: a choice, not a setting of its own.)
        if key not in known and key not in choices:
            near = [name for name in known if key.lower() in name.lower() or name.lower() in key.lower()][:8]
            return f"No such setting: {key}." + (f" Close ones: {', '.join(near)}." if near else " shell_settings lists them.")
        if function == "choose" and key in choices and values[1] not in choices[key]:
            return f"{key} takes one of: {', '.join(map(str, choices[key]))}."
        if function == "set" and key in choices:
            return f"{key} is a choice: use settings choose {key} <{'|'.join(map(str, choices[key]))}>."
    if function in WIDGET_CALLS and widgets and values:
        if values[0] not in widgets:
            return f"No such widget: {values[0]}. The widgets: {', '.join(widgets)}."
        words = WIDGET_CALLS[function]
        if words and values[1] not in words:
            return f"settings {function} takes one of: {', '.join(words)}."
    if function == "open" and values and shell.get("pages"):
        pages = [page.get("id") for page in shell["pages"]]
        if values[0] not in pages:
            return f"No such page: {values[0]}. The pages: {', '.join(pages)}."
    return None


def shell_ipc_call(guard, args):
    target, function, values, refused = ipc_checked(guard, args)
    if refused:
        return refused
    result = ipc_run(guard, "call", target, function, *values)
    output = (result.stdout or "").strip()
    if result.returncode != 0:
        return f"Failed: {(result.stderr or output).strip()}"
    return output or "Done."


def shell_ipc_propose(guard, args):
    label = " ".join(str(args.get("label") or "").split())[:80]
    if not label:
        return "Give the button a label."
    if guard.proposed >= MAX_PROPOSALS:
        return f"No more: {MAX_PROPOSALS} actions at most per answer."
    target, function, values, refused = ipc_checked(guard, args)
    if refused:
        return refused
    guard.proposed += 1
    emit("action", label=label, target=target, function=function, args=values)
    return ("Proposed: its button shows under your answer and runs the call when the user clicks it. "
            "Now write your answer, as if the button weren't there.")


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
    "shell_docs_search": (
        "Search the documentation of olShell, the desktop shell this chat is part of (its README.md and docs/: "
        "its features, settings, keys, IPC calls and files), case-insensitive. Gives each matching line's "
        "number, its section and the text around the match.",
        {"query": {"type": "string", "description": "The text to find, e.g. a setting's name or a key"},
         "regex": {"type": "boolean", "description": "Whether query is a regular expression"}},
        ["query"], shell_docs_search),
    "shell_docs_read": (
        "Read olShell's documentation: with no argument, its table of contents (headings with line "
        "numbers); with section, that section (by heading, e.g. \"Launcher\"); with offset, those lines "
        f"(at most {MAX_DOC_LINES}). Its paragraphs are long single lines: search first, then read what you need.",
        {"section": {"type": "string", "description": "A heading's text"},
         "offset": {"type": "integer", "description": "The first line to read, from 1"},
         "limit": {"type": "integer", "description": f"How many lines (at most {MAX_DOC_LINES})"}},
        [], shell_docs_read),
    "shell_settings": (
        "Read olShell's current state: its settings' values (the keys the documentation names, "
        "e.g. barPosition, radius), each with where it is in the settings panel (its page and name there, "
        "to tell the user and to open with settings open <page>), the theme and wallpaper picked, the "
        "language, and where each bar widget is, in words (\"widget <name> (<id>)\": its lane, its group and "
        "whether that group shows, shows only on hover or is off). With keys, those; "
        "with search, those whose name or value contains it (e.g. \"bar\", \"theme\", \"chatAi\": the bar's zones "
        "list the widgets they hold); with neither, all.",
        {"keys": {"type": "array", "items": {"type": "string"}, "description": "Setting keys, e.g. [\"barPosition\"]"},
         "search": {"type": "string", "description": "Part of the names wanted, e.g. theme"}},
        [], shell_settings),
    "shell_ipc_list": (
        "List the IPC calls of the running olShell you may run: one per line, "
        "\"target function(parameters): return type\".",
        {}, [], shell_ipc_list),
    "shell_ipc_call": (
        "Run one of olShell's IPC calls (see shell_ipc_list; the documentation says what they do): "
        "it acts on the user's shell at once, e.g. settings choose barPosition bottom, volume increase 0.05, "
        "settings get radius. Gives what the call returns, or Done.",
        {"target": {"type": "string", "description": "The target, e.g. settings"},
         "function": {"type": "string", "description": "The function, e.g. choose"},
         "args": {"type": "array", "items": {"type": ["string", "number", "boolean"]},
                  "description": "Its arguments, in order (yes/no ones as 1 or 0)"}},
        ["target", "function"], shell_ipc_call),
    "shell_ipc_propose": (
        "Propose one of olShell's IPC calls as a button under your answer, which the user can click to run "
        f"it (at most {MAX_PROPOSALS} per answer); nothing runs now. Checked like shell_ipc_call.",
        {"label": {"type": "string", "description": "The button's text, short, in the question's language, "
                                                    "e.g. \"Put the bar at the bottom\""},
         "target": {"type": "string", "description": "The target, e.g. settings"},
         "function": {"type": "string", "description": "The function, e.g. choose"},
         "args": {"type": "array", "items": {"type": ["string", "number", "boolean"]},
                  "description": "Its arguments, in order (yes/no ones as 1 or 0)"}},
        ["label", "target", "function"], shell_ipc_propose),
}

# The tools about the shell itself, as opposed to the user's files.
SHELL_TOOLS = {"shell_docs_search", "shell_docs_read", "shell_settings", "shell_ipc_list", "shell_ipc_call",
               "shell_ipc_propose"}

# Anthropic's web tools, by name, each tried in its newest version first
# (with dynamic filtering), then its basic one, for the models that don't
# have the newest; and how many times each may be used for one question.
WEB_TOOL_VERSIONS = [{"web_search": "web_search_20260209", "web_fetch": "web_fetch_20260209"},
                     {"web_search": "web_search_20250305", "web_fetch": "web_fetch_20250910"}]
WEB_MAX_USES = 5


# Sent once the model has answered a question about the shell without
# proposing an action it could have (see remind).
REMINDER = ("Before you finish: your answer is about something in the shell. Propose the next steps now as "
            f"buttons with shell_ipc_propose (up to {MAX_PROPOSALS}): e.g. open the settings on the page "
            "holding what you talked about (settings open <page>), open the panel, or set the setting to "
            "what they seem to want. Don't write your answer again; if no call fits, reply with nothing.")


def remind(guard, names, reminded):
    """Whether to ask the model for action buttons once more: it used the
    shell's tools, could propose, proposed none, and wasn't asked yet."""
    return not reminded and guard.used_shell and guard.proposed == 0 and "shell_ipc_propose" in names


# How many steps before the last the tools are narrowed to shell_ipc_propose
# (see wrapping_up).
WRAP_UP_STEPS = 2


def wrapping_up(step, names):
    """Whether the model is near the end of its steps and can only propose
    action buttons now (when it has that tool): it writes its answer with
    them, and the reminder (see remind) still has a step left when it
    proposes none."""
    return "shell_ipc_propose" in names and step >= MAX_STEPS - WRAP_UP_STEPS


def run_tool(guard, name, args):
    # (A tool that is off is refused even if the model asks for it anyway.)
    if name not in TOOLS or name not in guard.tools:
        return f"Unknown tool: {name}"
    if not isinstance(args, dict):
        args = {}
    if name in SHELL_TOOLS:
        guard.used_shell = True
    if name == "shell_ipc_propose":
        # (Shown as its button, not as a step.)
        pass
    elif name == "shell_ipc_call":
        values = args.get("args") if isinstance(args.get("args"), list) else []
        arg = " ".join([str(args.get("target") or ""), str(args.get("function") or "")] + [str(value) for value in values])
        emit("tool", name=name, arg=arg, path="")
    elif name in SHELL_TOOLS:
        keys = args.get("keys") if isinstance(args.get("keys"), list) else []
        arg = args.get("query") or args.get("section") or args.get("offset") or args.get("search") or ", ".join(map(str, keys))
        emit("tool", name=name, arg=str(arg or ""), path="")
    else:
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


# How many times a request is made again, and after how many seconds, when
# the provider is overloaded for a moment (HTTP 503, or Anthropic's 529).
RETRIES = 2
RETRY_DELAY = 3


def send(url, headers, body=None):
    """The provider's JSON answer to a POST of `body`, or to a GET without;
    made again a few times if the provider says it is overloaded."""
    for attempt in range(RETRIES + 1):
        try:
            return send_once(url, headers, body)
        except RuntimeError as error:
            if attempt == RETRIES or not str(error).startswith(("HTTP 503", "HTTP 529")):
                raise
            time.sleep(RETRY_DELAY)


def send_once(url, headers, body=None):
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
            # (Google's error comes in a list.)
            if isinstance(detail, list) and detail:
                detail = detail[0]
            detail = detail.get("error", detail) if isinstance(detail, dict) else detail
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
    elif "generativelanguage.googleapis.com" in url:
        # (Its list has embedding, image, speech and live models too; an id may come as "models/gemini-...".)
        for model in models:
            model["id"] = model["id"].removeprefix("models/")
        models = [model for model in models if model["id"].startswith("gemini")
                  and not any(word in model["id"] for word in ("image", "embedding", "tts", "live", "audio", "robotics", "computer-use", "transcribe"))]
        # (Its list is in no order and has old models that new users can't use
        # any more, and no creation date: the highest version first, a plain
        # name before its variants.)
        def newest(model):
            found = re.search(r"gemini-(\d+(?:\.\d+)*)", model["id"])
            parts = [int(part) for part in found.group(1).split(".")] if found else []
            return ([-part for part in parts + [0] * (4 - len(parts))], len(model["id"]))
        models.sort(key=newest)
    elif "api.x.ai" in url:
        # (Its list has the image and video models too.)
        models = [model for model in models if model["id"].startswith("grok")
                  and not any(word in model["id"] for word in ("image", "imagine", "video", "embedding"))]
    models.sort(key=lambda model: model.get("created") or 0, reverse=True)
    return [{"id": model["id"], "name": model.get("name") or model.get("display_name") or model["id"]} for model in models]


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
    # The latest text the model wrote alongside tool calls: its answer when
    # it wrote it there and ends with nothing more (as after proposing an
    # action).
    written = ""
    # The answer given before the reminder (see remind), kept as the answer.
    kept, reminded = "", False
    step = 0
    while step <= MAX_STEPS:
        web_tools = [{"type": versions[0][name], "name": name, "max_uses": WEB_MAX_USES}
                     for name in web] if versions[0] else []
        body = {"model": options.model, "max_tokens": 8192, "system": system, "messages": messages}
        if wrapping_up(step, names):
            step_tools, web_tools = [tool for tool in tools if tool["name"] == "shell_ipc_propose"], []
        else:
            step_tools = tools
        # (No tool at all: the APIs refuse an empty list.)
        if step_tools or web_tools:
            body["tools"] = step_tools + web_tools
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
        used = reply.get("usage") or {}
        track(input=(used.get("input_tokens") or 0) + (used.get("cache_creation_input_tokens") or 0)
              + (used.get("cache_read_input_tokens") or 0),
              output=used.get("output_tokens") or 0, cached=used.get("cache_read_input_tokens") or 0,
              searches=(used.get("server_tool_use") or {}).get("web_search_requests") or 0)
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
            answer = kept or anthropic_answer(content) or written
            if step < MAX_STEPS and remind(guard, names, reminded):
                kept, reminded = answer, True
                messages.append({"role": "assistant", "content": content or answer or "(no answer)"})
                messages.append({"role": "user", "content": REMINDER})
                continue
            return answer
        written = anthropic_answer(content) or written
        messages.append({"role": "assistant", "content": content})
        messages.append({"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": call["id"], "content": run_tool(guard, call.get("name"), call.get("input"))}
            for call in calls]})
    return kept or written


def openai_responses(options):
    """Whether the question goes through a Responses API rather than Chat
    Completions: OpenAI's own, and xAI's, which speaks the same. It has the
    web search tool, which runs on the provider's servers, and function tools
    and reasoning go together there."""
    url = options.url.rstrip("/")
    return (options.provider == "openai" and url.startswith("https://api.openai.com")) \
        or (options.provider == "xai" and url.startswith("https://api.x.ai"))


def openai_answer(output):
    """The answer's text from a Responses API reply's output, then the web
    pages it cites, a link each (as anthropic_answer does)."""
    text, sources = "", {}
    for item in output:
        if item.get("type") != "message":
            continue
        for block in item.get("content") or []:
            if block.get("type") != "output_text":
                continue
            text += block.get("text") or ""
            for note in block.get("annotations") or []:
                url = re.sub(r"[?&]utm_source=openai$", "", note.get("url") or "")
                if url and url not in sources and url not in text:
                    sources[url] = (note.get("title") or url).replace("[", "(").replace("]", ")")
    text = text.replace("?utm_source=openai)", ")").replace("&utm_source=openai)", ")").strip()
    if sources:
        text += "\n\n" + "\n".join(f"- [{title}]({url})" for url, title in sources.items())
    return text


def ask_openai_responses(options, key, system, question, guard, names):
    url = options.url + "/responses"
    headers = headers_for("openai", key)
    # (Not strict: the tools' optional parameters would be refused.)
    tools = [{"type": "function", "name": name, "description": description, "strict": False,
              "parameters": {"type": "object", "properties": properties, "required": required}}
             for name, (description, properties, required, _) in TOOLS.items() if name in names]
    if "web_search" in names:
        tools.append({"type": "web_search"})
    # Each request continues the one before (previous_response_id), so it
    # only carries what is new: the question, then the tools' results. xAI
    # refuses `instructions` with previous_response_id, so there the system
    # prompt is the first message of the input instead (the continuation
    # keeps it); OpenAI wants the instructions again with each request.
    instructions_in_input = options.provider == "xai"
    new_input = [{"role": "user", "content": question}]
    if instructions_in_input:
        new_input.insert(0, {"role": "system", "content": system})
    previous = None
    written = ""
    kept, reminded = "", False
    for step in range(MAX_STEPS + 1):
        body = {"model": options.model, "input": new_input}
        if not instructions_in_input:
            body["instructions"] = system
        if previous:
            body["previous_response_id"] = previous
        if tools:
            body["tools"] = [tool for tool in tools if tool.get("name") == "shell_ipc_propose"] \
                if wrapping_up(step, names) else tools
            if step == MAX_STEPS:
                body["tool_choice"] = "none"
        try:
            reply = send(url, headers, body)
        except RuntimeError as error:
            # A model without the search tool refuses the request: asked again without it.
            if step > 0 or not any(tool.get("type") == "web_search" for tool in tools) \
                    or not str(error).startswith("HTTP 400") or "search" not in str(error).lower():
                raise
            tools = [tool for tool in tools if tool.get("type") != "web_search"]
            body["tools"] = tools
            reply = send(url, headers, body)
        previous = reply.get("id")
        used = reply.get("usage") or {}
        output = reply.get("output") or []
        calls_made = [item for item in output if item.get("type") == "web_search_call"]
        track(input=used.get("input_tokens") or 0, output=used.get("output_tokens") or 0,
              cached=(used.get("input_tokens_details") or {}).get("cached_tokens") or 0,
              reasoning=(used.get("output_tokens_details") or {}).get("reasoning_tokens") or 0,
              searches=((reply.get("tool_usage") or {}).get("web_search") or {}).get("num_requests") or len(calls_made))
        # What the provider's servers searched and opened, as the file tools are announced.
        for item in calls_made:
            action = item.get("action") or {}
            if action.get("type") == "open_page" or (action.get("url") and not action.get("query")):
                emit("tool", name="web_fetch", arg="", path=str(action.get("url") or ""))
            elif action.get("type") in (None, "search"):
                emit("tool", name="web_search", arg=str(action.get("query") or item.get("query") or ""), path="")
        calls = [item for item in output if item.get("type") == "function_call"]
        if not calls or step == MAX_STEPS:
            answer = kept or openai_answer(output) or written
            if step < MAX_STEPS and previous and remind(guard, names, reminded):
                kept, reminded = answer, True
                new_input = [{"role": "user", "content": REMINDER}]
                continue
            return answer
        written = openai_answer(output) or written
        new_input = []
        for call in calls:
            try:
                args = json.loads(call.get("arguments") or "{}")
            except ValueError:
                args = {}
            new_input.append({"type": "function_call_output", "call_id": call.get("call_id"),
                              "output": run_tool(guard, call.get("name"), args)})
    return kept or written


def ask_openai(options, key, system, question, guard, names):
    url = options.url + "/chat/completions"
    headers = headers_for("openai", key)
    tools = [{"type": "function", "function": {"name": name, "description": description,
              "parameters": {"type": "object", "properties": properties, "required": required}}}
             for name, (description, properties, required, _) in TOOLS.items() if name in names]
    messages = [{"role": "system", "content": system}, {"role": "user", "content": question}]
    # (As with Anthropic: the latest text written alongside tool calls, and
    # the answer given before the reminder.)
    written = ""
    kept, reminded = "", False
    # Whether reasoning has to be turned off to use the tools: some models
    # reason by default and refuse function tools on Chat Completions then
    # ("Function tools with reasoning_effort are not supported"), which they
    # say in an error; the request is made again with reasoning_effort "none"
    # (not sent otherwise: other models don't know it).
    no_reasoning = False
    for step in range(MAX_STEPS + 1):
        body = {"model": options.model, "messages": messages}
        if tools:
            body["tools"] = [tool for tool in tools if tool["function"]["name"] == "shell_ipc_propose"] \
                if wrapping_up(step, names) else tools
            if step == MAX_STEPS:
                body["tool_choice"] = "none"
        if no_reasoning:
            body["reasoning_effort"] = "none"
        try:
            reply = send(url, headers, body)
        except RuntimeError as error:
            if not tools or no_reasoning or "reasoning_effort" not in str(error):
                raise
            no_reasoning = True
            body["reasoning_effort"] = "none"
            reply = send(url, headers, body)
        used = reply.get("usage") or {}
        track(input=used.get("prompt_tokens") or 0, output=used.get("completion_tokens") or 0,
              cached=(used.get("prompt_tokens_details") or {}).get("cached_tokens") or 0,
              reasoning=(used.get("completion_tokens_details") or {}).get("reasoning_tokens") or 0)
        choices = reply.get("choices") or []
        if not choices:
            raise RuntimeError("Empty answer")
        message = choices[0].get("message") or {}
        calls = message.get("tool_calls") or []
        if not calls or step == MAX_STEPS:
            answer = kept or (message.get("content") or "").strip() or written
            if step < MAX_STEPS and remind(guard, names, reminded):
                kept, reminded = answer, True
                messages.append({"role": "assistant", "content": answer or "(no answer)"})
                messages.append({"role": "user", "content": REMINDER})
                continue
            return answer
        written = (message.get("content") or "").strip() or written
        messages.append({"role": "assistant", "content": message.get("content"), "tool_calls": calls})
        for call in calls:
            function = call.get("function") or {}
            try:
                args = json.loads(function.get("arguments") or "{}")
            except ValueError:
                args = {}
            messages.append({"role": "tool", "tool_call_id": call.get("id"),
                             "content": run_tool(guard, function.get("name"), args)})
    return kept or written


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
    parser.add_argument("--tools", default=",".join(name for name in TOOLS if name not in SHELL_TOOLS))
    parser.add_argument("--shell", default="")
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
    # The tools asked for (the web ones only exist with Anthropic's, and the Responses APIs of OpenAI and xAI for the search).
    names = {name for name in split(options.tools) if name in TOOLS
             or (name in ("web_search", "web_fetch") and options.protocol == "anthropic")
             or (name == "web_search" and openai_responses(options))}
    # (The shell tools need the shell's folder.)
    if not options.shell:
        names -= SHELL_TOOLS
    guard = Guard(split(options.folders), split(options.exclude), names & set(TOOLS), options.shell)
    files = names & set(TOOLS) - SHELL_TOOLS
    docs = names & {"shell_docs_search", "shell_docs_read", "shell_settings"}
    ipc = names & {"shell_ipc_list", "shell_ipc_call", "shell_ipc_propose"}
    web = names - set(TOOLS)
    # The settings panel's pages, by id and name, for the model to name them
    # right and open them (read from the running shell; none without it).
    pages = ""
    if docs or ipc:
        pages = "; ".join(f"{page.get('id')}: {page.get('name')}" for page in shell_map(guard).get("pages") or [])
    # The shell's calls, given up front so the model sees what it can offer
    # without listing them first; without the running shell, no calls.
    calls = ""
    if ipc:
        try:
            catalog = ipc_catalog(guard)
            calls = "\n".join(f"{target}: " + ", ".join(f"{function}({parameters})" for function, (parameters, _)
                                                        in sorted(catalog[target].items())) for target in sorted(catalog))
        except (OSError, subprocess.SubprocessError):
            ipc = set()
            names -= {"shell_ipc_list", "shell_ipc_call", "shell_ipc_propose"}
            guard.tools -= {"shell_ipc_list", "shell_ipc_call", "shell_ipc_propose"}
    shown = [guard.show(root) for root in guard.roots]
    folders = ", ".join(shown[:20]) + (f" and {len(shown) - 20} more" if len(shown) > 20 else "")
    system = (
        "You answer a single question from the user of a Linux desktop; there is no follow-up. "
        + (f"With the tools, you can {', '.join(sorted(files))} (read-only) in their files, within: {folders}; "
           f"the home folder is {HOME}. Look at their files only when the question is about them. "
           "Only the tools decide what is reachable: for a path the user names, try the tool before saying you can't reach it. "
           if files else "You can't see their files. ")
        + ("You are part of olShell, their desktop shell (Quickshell, on Hyprland): its bar, panels, "
           "settings, launcher, notifications... "
           + ("Answer about it as to someone using it, not developing it: what they see and do, where "
              "something is on the screen, which button, key or menu, and a setting by its category and "
              "name as the settings panel shows them (e.g. Panels > Placement > Wallpapers). Never point "
              "them to the code (QML or Python files, properties, setting keys, functions), even where the "
              "documentation names it, unless they ask about the code, a config file or a script; nor, in "
              "your text, to an IPC command, unless they ask how to bind a key or script something (the "
              "action buttons below are fine: they show only their label). Say a setting's value as the "
              "panel words it (\"in the middle of the bar\"), not as stored (\"bar-center\"). "
              + ("A next step you could take for them goes in a button (see below), not in an offer. " if ipc else "")
              if docs or ipc else "")
           + ("For a question about it (how to do something, what a setting does, a key, an IPC call), "
              "search its documentation with shell_docs_search, then read the parts you need with "
              "shell_docs_read; don't read it all, and don't cite it: it is where you learn, not a source to name. When the question is about something of the shell, "
              "also check how it is set now with shell_settings, and say it in your answer (e.g. \"your bar "
              "is at the top\"), so the answer fits their shell rather than the defaults; name a setting as shell_settings "
              "places it in the settings panel (e.g. Bar widgets > Layout), and for a bar widget, say what "
              "its line says (a group shown only on hover is on the bar, just hidden until hovered). "
              + (f"The settings panel's pages (id: name, for settings open): {pages}. " if pages else "")
              if docs else "")
           + ("You can act on it through its IPC calls, listed below: change a setting, open a panel or "
              "the settings on a page, change the volume... When the question asks you to do something, do "
              "it with shell_ipc_call and say in your answer, in plain words, what you changed. When it only "
              "asks about something in the shell (how to do it, what a setting does, where something is), "
              "answer, then offer the next step as buttons with shell_ipc_propose (at most "
              f"{MAX_PROPOSALS}; the user clicks one to run it, since there is no follow-up question): "
              "whenever your answer tells them to open, change or turn on something a call can do, propose "
              "it. Typically: open the panel the question is about; open the settings on the page holding "
              "its setting (settings open <page>, with the page's id as shell_settings or the list of "
              "pages gives it, e.g. layout for Bar widgets > Layout); set the setting to what they seem to "
              "want. Opening another panel closes this chat's panel (the answer still shows when it is "
              "opened again). The calls you can run or propose (target: function(parameters)):\n"
              + calls + "\n" if ipc else "You can't change anything in it. ")
           if docs or ipc else "")
        + (f"You can also use {' and '.join(sorted(web))}, for what their files don't say "
           "or what may have changed since your training; never put anything from their files in a search. "
           if web else "You can't reach the web. ")
        + ("You have a limited number of steps: keep your research short, about six lookups (several at "
           "once are fine), then answer. "
           if names & set(TOOLS) else "")
        + f"Today is {time.strftime('%A %Y-%m-%d, %H:%M')}. "
        "The user can't reply, so end with the answer itself: no closing question or offer of more help "
        "(\"Would you like me to...?\", \"Let me know if...\", \"I can also...\"), and nothing asking them to give, send or clarify anything; "
        "when the question is unclear, answer its most likely meaning and say which you took. "
        "Answer concisely in Markdown, and name the files of theirs and the web pages you used by their path or address. "
        "Write every file or folder of theirs you mention, in a list too, as its full path (from / or ~/, "
        "e.g. `~/Notes/todo.md`, not `todo.md`): the full paths are made clickable. "
        "Your answer is shown with its images: to show one (a picture file of theirs, or one on the web), "
        "write it as ![description](its absolute path or web address), the path as it is, not encoded "
        "(spaces as spaces, not %20). "
        f"Answer in the language of the question (the desktop's is '{options.language}')."
    )
    try:
        if not options.model or not question:
            raise RuntimeError("No model or no question")
        answer = ask_anthropic(options, key, system, question, guard, names) if options.protocol == "anthropic" \
            else ask_openai_responses(options, key, system, question, guard, names) if openai_responses(options) \
            else ask_openai(options, key, system, question, guard, names)
        if not answer:
            raise RuntimeError("The model gave no answer")
        emit("answer", text=answer)
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        emit("error", message=str(error))
        sys.exit(1)


if __name__ == "__main__":
    main()
