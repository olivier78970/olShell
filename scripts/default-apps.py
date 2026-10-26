#!/usr/bin/env python3
"""Lists and sets the default applications, by kind, for the settings' Default apps.

Usage:
  default-apps.py list TERMINAL_ID...
  default-apps.py apply [--shell-dir DIR] [--mail-compose TEMPLATE] KIND ID [KIND ID]...
  default-apps.py open-mail SHELL_DIR NAME TEMPLATE LINK

The kinds are browser, mail, fileManager, textEditor, terminal, imageViewer,
videoPlayer, musicPlayer, pdfViewer, archiveManager and torrentClient, each a
set of MIME types (KINDS below); the terminal has none, it is the first line
of ~/.config/xdg-terminals.list.

`list` prints {KIND: [{"id", "name"}]} as JSON, sorted by name: the installed
applications (desktop entries not hidden) that open the kind's main types or
are in its category (CATEGORIES),
and for the terminal those among TERMINAL_ID (the terminals the shell knows
how to drive) that are installed.

`apply` makes each ID (a desktop entry id) the default of its KIND's types in
~/.config/mimeapps.list's [Default Applications], keeping its other lines,
and writes the file only when something changes. An ID that isn't installed
is left out. The mail client may be a web app, "webapp:NAME": with
--mail-compose (its site's address composing a mail, %s for the encoded
mailto: link) and --shell-dir (the shell's folder), a desktop entry
olshell-webapp-mail.desktop is written for it, running `open-mail`, and made
the mailto default; without them the mail default is left as it is. Any other
mail client removes that entry.

`open-mail` asks the shell in SHELL_DIR to open mailto: link LINK in web app
NAME (`qs ipc call defaultApps openMail`), and when no shell answers opens the
mail's compose address (TEMPLATE) in the browser.
"""

import json
import os
import shutil
import subprocess
import sys
from urllib.parse import quote

# The MIME types of each kind: an application is offered for a kind when it
# opens one of the first `main` ones, and is made the default of all of them.
KINDS = {
    "browser": (2, ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml",
                    "application/x-extension-htm", "application/x-extension-html", "application/x-extension-shtml",
                    "application/x-extension-xhtml", "application/x-extension-xht", "x-scheme-handler/about",
                    "x-scheme-handler/unknown"]),
    "mail": (1, ["x-scheme-handler/mailto"]),
    "fileManager": (1, ["inode/directory"]),
    "textEditor": (1, ["text/plain", "text/markdown", "application/json", "application/x-shellscript",
                       "text/x-python", "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/css",
                       "application/javascript", "application/xml", "application/toml", "application/x-yaml"]),
    "imageViewer": (4, ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp",
                        "image/tiff", "image/avif", "image/heif", "image/x-icon"]),
    "videoPlayer": (4, ["video/mp4", "video/x-matroska", "video/webm", "video/x-msvideo", "video/quicktime",
                        "video/mpeg", "video/ogg", "video/x-flv", "video/3gpp"]),
    "musicPlayer": (3, ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/wav", "audio/aac",
                        "audio/mp4", "audio/x-m4a", "audio/opus", "audio/x-vorbis+ogg", "audio/x-flac"]),
    "pdfViewer": (1, ["application/pdf"]),
    "archiveManager": (1, ["application/zip", "application/x-tar", "application/x-compressed-tar",
                           "application/x-xz-compressed-tar", "application/x-zstd-compressed-tar",
                           "application/x-bzip2-compressed-tar", "application/x-7z-compressed",
                           "application/vnd.rar", "application/x-rar", "application/gzip", "application/x-xz"]),
    "torrentClient": (1, ["x-scheme-handler/magnet", "application/x-bittorrent"]),
}
# The desktop entry category that also offers an application for a kind, for
# those that don't list the kind's types (Visual Studio Code, as a text editor).
CATEGORIES = {"browser": "WebBrowser", "mail": "Email", "fileManager": "FileManager", "textEditor": "TextEditor"}
HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share")
MIMEAPPS = os.path.join(CONFIG, "mimeapps.list")
TERMINALS = os.path.join(CONFIG, "xdg-terminals.list")
# The desktop entry standing for a web app as the mail client.
MAIL_ENTRY = "olshell-webapp-mail.desktop"
MAIL_ENTRY_PATH = os.path.join(DATA_HOME, "applications", MAIL_ENTRY)


def application_dirs():
    """The folders holding desktop entries, the first one taking precedence."""
    data_dirs = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    return [os.path.join(folder, "applications") for folder in [DATA_HOME] + data_dirs if folder]


def desktop_entries():
    """{id: {key: value}} of the installed desktop entries' [Desktop Entry]."""
    entries = {}
    for folder in application_dirs():
        for root, _, files in os.walk(folder):
            for name in files:
                if not name.endswith(".desktop"):
                    continue
                path = os.path.join(root, name)
                entry_id = os.path.relpath(path, folder).replace("/", "-")
                if entry_id not in entries:
                    entries[entry_id] = read_entry(path)
    return {entry_id: entry for entry_id, entry in entries.items() if entry is not None}


def read_entry(path):
    """The keys of desktop entry `path`'s [Desktop Entry] group, None if unreadable."""
    try:
        with open(path, encoding="utf-8", errors="replace") as file:
            lines = file.read().splitlines()
    except OSError:
        return None
    entry, group = {}, None
    for line in lines:
        line = line.strip()
        if line.startswith("["):
            group = line
        elif group == "[Desktop Entry]" and "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            entry.setdefault(key.strip(), value.strip())
    return entry


def shown(entry):
    """Whether desktop entry `entry` is an application meant to be offered."""
    return entry.get("Type", "Application") == "Application" and entry.get("NoDisplay") != "true" \
        and entry.get("Hidden") != "true"


def list_apps(terminal_ids):
    entries = desktop_entries()
    result = {}
    for kind, (main, types) in KINDS.items():
        wanted = set(types[:main])
        result[kind] = sorted(({"id": entry_id, "name": entry.get("Name", entry_id)}
                               for entry_id, entry in entries.items()
                               if entry_id != MAIL_ENTRY and shown(entry)
                               and (wanted & set(entry.get("MimeType", "").split(";"))
                                    or CATEGORIES.get(kind) in entry.get("Categories", "").split(";"))),
                              key=lambda app: app["name"].lower())
    result["terminal"] = sorted(({"id": entry_id, "name": entries[entry_id].get("Name", entry_id)}
                                 for entry_id in terminal_ids if entry_id in entries),
                                key=lambda app: app["name"].lower())
    print(json.dumps(result))


def set_defaults(defaults):
    """Sets {MIME type: id} in mimeapps.list's [Default Applications]."""
    try:
        with open(MIMEAPPS, encoding="utf-8") as file:
            lines = file.read().splitlines()
    except FileNotFoundError:
        lines = []
    if "[Default Applications]" not in (line.strip() for line in lines):
        lines = ["[Default Applications]"] + ([""] if lines else []) + lines
    start = next(i for i, line in enumerate(lines) if line.strip() == "[Default Applications]") + 1
    end = next((i for i in range(start, len(lines)) if lines[i].strip().startswith("[")), len(lines))
    left = dict(defaults)
    new = lines[:start]
    for line in lines[start:end]:
        key = line.split("=", 1)[0].strip() if "=" in line and not line.lstrip().startswith("#") else None
        if key in left:
            new.append(key + "=" + left.pop(key))
        else:
            new.append(line)
    # The types not there yet go after the group's last line that isn't blank.
    insert = len(new)
    while insert > start and new[insert - 1].strip() == "":
        insert -= 1
    new[insert:insert] = [mime + "=" + entry_id for mime, entry_id in left.items()]
    new += lines[end:]
    if new != lines:
        write(MIMEAPPS, "\n".join(new) + "\n")


def set_terminal(entry_id):
    """Puts `entry_id` first in xdg-terminals.list."""
    try:
        with open(TERMINALS, encoding="utf-8") as file:
            lines = file.read().splitlines()
    except FileNotFoundError:
        lines = []
    new = [entry_id] + [line for line in lines if line.strip() != entry_id]
    if new != lines:
        write(TERMINALS, "\n".join(new) + "\n")


def write(path, text):
    """Writes `text` to `path` through a temporary file, so it is never half written."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temporary = path + ".olshell-tmp"
    with open(temporary, "w", encoding="utf-8") as file:
        file.write(text)
    os.replace(temporary, path)


def write_mail_entry(shell_dir, name, template):
    """Writes the desktop entry opening mailto: links in web app `name`."""
    # Desktop entry Exec arguments are quoted with double quotes, `"`, `` ` ``,
    # `$` and `\` escaped by a backslash, and `%` doubled.
    def arg(text):
        text = "".join("\\" + c if c in "\"`$\\" else c for c in text).replace("%", "%%")
        return '"' + text + '"'
    script = os.path.join(shell_dir, "scripts", "default-apps.py")
    text = "\n".join([
        "[Desktop Entry]",
        "Type=Application",
        "Name=" + name,
        "Exec=python3 " + " ".join(arg(word) for word in [script, "open-mail", shell_dir, name, template]) + " %u",
        "MimeType=x-scheme-handler/mailto;",
        "NoDisplay=true",
        "Terminal=false",
        "",
    ])
    try:
        with open(MAIL_ENTRY_PATH, encoding="utf-8") as file:
            if file.read() == text:
                return
    except FileNotFoundError:
        pass
    write(MAIL_ENTRY_PATH, text)


def apply(args):
    shell_dir = compose = None
    while args and args[0].startswith("--"):
        if args[0] == "--shell-dir":
            shell_dir = args[1]
        elif args[0] == "--mail-compose":
            compose = args[1]
        args = args[2:]
    installed = set(desktop_entries())
    defaults = {}
    for kind, entry_id in zip(args[::2], args[1::2]):
        if kind == "mail" and entry_id.startswith("webapp:"):
            if not (shell_dir and compose):
                continue
            write_mail_entry(shell_dir, entry_id[len("webapp:"):], compose)
            entry_id = MAIL_ENTRY
            installed.add(MAIL_ENTRY)
        if entry_id not in installed:
            continue
        if kind == "mail" and entry_id != MAIL_ENTRY and os.path.exists(MAIL_ENTRY_PATH):
            os.remove(MAIL_ENTRY_PATH)
        if kind == "terminal":
            set_terminal(entry_id)
        elif kind in KINDS:
            defaults.update((mime, entry_id) for mime in KINDS[kind][1])
    if defaults:
        set_defaults(defaults)


def open_mail(shell_dir, name, template, link):
    qs = shutil.which("qs") or shutil.which("quickshell")
    if qs:
        try:
            done = subprocess.run([qs, "-p", shell_dir, "ipc", "call", "defaultApps", "openMail", name, link],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
            if done.returncode == 0:
                return
        except (OSError, subprocess.TimeoutExpired):
            pass
    subprocess.Popen(["xdg-open", template.replace("%s", quote(link, safe=""))])


def main():
    args = sys.argv[1:]
    if args[:1] == ["list"]:
        list_apps(args[1:])
    elif args[:1] == ["apply"]:
        apply(args[1:])
    elif args[:1] == ["open-mail"] and len(args) == 5:
        open_mail(*args[1:])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
