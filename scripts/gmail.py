#!/usr/bin/env python3
"""Watches a Gmail inbox over IMAP, and keeps its app password in the keyring.

Usage: gmail.py watch ADDRESS
       gmail.py notify ADDRESS UID LINK TITLE BODY OPEN_LABEL READ_LABEL SHELL
       gmail.py read ADDRESS UID
       gmail.py password set|clear|has ADDRESS   (set reads it from stdin)

The app password (Google account → Security → App passwords, which needs
2-step verification) is stored with secret-tool under service=olshell-gmail
and account=ADDRESS, so it never goes in a settings file or on a command line.

`watch` stays connected to imap.gmail.com with IMAP IDLE, so Gmail tells it
at once when the inbox changes, and prints one JSON object a line:
  {"event": "unread", "count": N}      at start and whenever it changes: the
                                        unread conversations, as Gmail counts
                                        them (not the messages)
  {"event": "mail", "uid": U, "from": NAME, "subject": TEXT, "link": URL}
                                        for each unread mail arriving later
                                        (also while the network was down)
  {"event": "mails", "count": N}       in its place for more than 3 at once
  {"event": "error", "reason": R}       R is "password" (none in the keyring),
                                        "appPassword" (the account's own
                                        password was given, not an app
                                        password), "login" (refused) or
                                        "network"
It exits after a "password", "appPassword" or "login" error, and connects again on its own
after a network one. Used by services/Gmail.qml.

`notify` shows a mail's notification with notify-send and waits for its
buttons (so it is started detached): clicking it or OPEN_LABEL asks the shell
running from the folder SHELL to open LINK (`gmail openMail`, which runs the
Gmail widget's click action when it has one), or opens LINK itself when the
shell doesn't answer; READ_LABEL marks the mail as read (an empty UID, for several mails at once,
has no such button). `read` marks a mail as read.
`password` prints {"ok": true} or {"ok": false, "message": TEXT}, `has`
prints {"has": true|false}.
"""

import email
import email.policy
import email.utils
import imaplib
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.parse

HOST = "imap.gmail.com"
ATTRIBUTES = ["service", "olshell-gmail", "account"]
# Gmail drops an IDLE after about 30 minutes; it is renewed before that.
IDLE_SECONDS = 9 * 60
# Seconds between two attempts while the network is down, growing to the last.
RETRY = [15, 30, 60, 120, 300]
# More mails than this arriving at once get one notification for them all.
MANY = 3


def say(**fields):
    print(json.dumps(fields, ensure_ascii=False), flush=True)


def run(command, stdin=None):
    return subprocess.run(command, input=stdin, capture_output=True, text=True, timeout=60)


def password_of(address):
    """The app password kept in the keyring for `address`, or None."""
    if not shutil.which("secret-tool"):
        return None
    result = run(["secret-tool", "lookup"] + ATTRIBUTES + [address])
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


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


def password(action, address):
    """The `password` command: stores, removes or looks for the password."""
    if action == "has":
        say(has=password_of(address) is not None)
        return
    if not shutil.which("secret-tool"):
        say(ok=False, message="secret-tool is not installed (libsecret)")
        return
    # Google shows app passwords in groups of four letters; the spaces don't count.
    secret = re.sub(r"\s+", "", sys.stdin.read()) if action == "set" else ""
    if secret:
        store = ["secret-tool", "store", "--label", f"olShell Gmail: {address}"]
        result = run(store + ATTRIBUTES + [address], secret)
        collection = kept_collection() if result.returncode != 0 else None
        if collection:
            result = run(store + ["--collection", collection] + ATTRIBUTES + [address], secret)
    else:
        result = run(["secret-tool", "clear"] + ATTRIBUTES + [address])
    say(ok=True) if result.returncode == 0 else say(ok=False, message=result.stderr.strip())


def connect(address, secret):
    """A connection logged in to `address` with its inbox selected."""
    imap = imaplib.IMAP4_SSL(HOST, timeout=60)
    imap.login(address, secret)
    imap.select("INBOX")
    return imap


def unread(imap):
    """The UIDs of the inbox's unread mails."""
    _, data = imap.uid("SEARCH", None, "UNSEEN")
    return {int(uid) for uid in data[0].split()}


def conversations(imap, uids, threads):
    """How many conversations the mails `uids` belong to, as Gmail counts its
    unread ones. `threads` maps the UIDs already looked up to their
    conversation (X-GM-THRID); only the others are fetched, and added to it."""
    missing = sorted(uid for uid in uids if uid not in threads)
    for start in range(0, len(missing), 500):
        _, data = imap.uid("FETCH", ",".join(map(str, missing[start:start + 500])), "(UID X-GM-THRID)")
        for part in data:
            meta = part[0] if isinstance(part, tuple) else part
            if not isinstance(meta, bytes):
                continue
            uid = re.search(rb"UID (\d+)", meta)
            thread = re.search(rb"X-GM-THRID (\d+)", meta)
            if uid and thread:
                threads[int(uid.group(1))] = int(thread.group(1))
    return len({threads.get(uid, -uid) for uid in uids})


def link(address, gmail_id):
    """The address of a mail in Gmail's web page, from its X-GM-MSGID. The
    account goes in authuser, which signs in to it when needed (the
    /mail/u/<address>/ form is a 404 while that account isn't signed in)."""
    return f"https://mail.google.com/mail/?authuser={urllib.parse.quote(address)}#all/{gmail_id:x}"


def mails(imap, address, uids):
    """Announces the mails `uids`, oldest first."""
    if not uids:
        return
    _, data = imap.uid("FETCH", ",".join(map(str, sorted(uids))),
                       "(X-GM-MSGID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT)])")
    for part in data:
        if not isinstance(part, tuple):
            continue
        meta = part[0].decode(errors="replace")
        uid = re.search(r"UID (\d+)", meta)
        gmail_id = re.search(r"X-GM-MSGID (\d+)", meta)
        if not uid or not gmail_id:
            continue
        headers = email.message_from_bytes(part[1], policy=email.policy.default)
        name, sender = email.utils.parseaddr(str(headers.get("From", "")))
        say(event="mail", uid=int(uid.group(1)), **{"from": name or sender},
            subject=str(headers.get("Subject", "")).strip(), link=link(address, int(gmail_id.group(1))))


def watch(address):
    """The `watch` command: runs until the password is missing or refused."""
    secret = password_of(address)
    if not secret:
        say(event="error", reason="password")
        sys.exit(2)
    failures = 0
    # The first UID a mail arriving later gets (None before the first
    # connection), kept across connections so mails arriving meanwhile are
    # announced too, the unread count last printed, and the conversation of
    # each mail looked up (see conversations()).
    next_uid = None
    count = None
    threads = {}
    while True:
        try:
            imap = connect(address, secret)
        except imaplib.IMAP4.error as error:
            # Gmail asks for an app password when given the account's own.
            say(event="error", reason="appPassword" if "Application-specific password" in str(error) else "login")
            sys.exit(2)
        except OSError:
            say(event="error", reason="network")
            time.sleep(RETRY[min(failures, len(RETRY) - 1)])
            failures += 1
            continue
        failures = 0
        try:
            if next_uid is None:
                uid_next = imap.response("UIDNEXT")[1]
                next_uid = int(uid_next[0]) if uid_next and uid_next[0] else max(unread(imap), default=0) + 1
            while True:
                now = unread(imap)
                fresh = {uid for uid in now if uid >= next_uid}
                if len(fresh) > MANY:
                    say(event="mails", count=len(fresh))
                else:
                    mails(imap, address, fresh)
                if fresh:
                    next_uid = max(fresh) + 1
                unread_count = conversations(imap, now, threads)
                if unread_count != count:
                    count = unread_count
                    say(event="unread", count=count)
                with imap.idle(duration=IDLE_SECONDS) as idler:
                    list(idler.burst())
        except (imaplib.IMAP4.error, OSError):
            say(event="error", reason="network")
            count = None
            try:
                imap.logout()
            except (imaplib.IMAP4.error, OSError):
                pass
            time.sleep(RETRY[0])


def read(address, uid):
    """The `read` command: marks mail `uid` of the inbox as read."""
    secret = password_of(address)
    if not secret:
        sys.exit(2)
    imap = connect(address, secret)
    imap.uid("STORE", uid, "+FLAGS", "(\\Seen)")
    imap.logout()


def notify(address, uid, url, title, body, open_label, read_label, shell):
    """The `notify` command: shows a mail and does what its buttons ask."""
    # No time limit: notify-send waits until the notification is closed.
    if not shutil.which("notify-send"):
        return
    buttons = ["--action=default=" + open_label, "--action=open=" + open_label]
    if uid:
        buttons.append("--action=read=" + read_label)
    answer = subprocess.run(["notify-send", "--app-name", "Gmail", "--icon", "mail-unread"] + buttons + [title, body],
                            capture_output=True, text=True)
    choice = answer.stdout.strip()
    if choice in ("default", "open"):
        # The shell may have restarted meanwhile, or be gone.
        # (-p goes after "ipc": before it, QS_CONFIG_PATH would win.)
        asked = subprocess.run(["quickshell", "ipc", "-p", shell, "call", "gmail", "openMail", url],
                               capture_output=True, check=False) if shutil.which("quickshell") else None
        if asked is None or asked.returncode != 0:
            subprocess.run(["xdg-open", url], check=False)
    elif choice == "read":
        read(address, uid)


def main():
    args = sys.argv[1:]
    if args[:1] == ["watch"] and len(args) == 2:
        watch(args[1])
    elif args[:1] == ["notify"] and len(args) == 9:
        notify(*args[1:])
    elif args[:1] == ["read"] and len(args) == 3:
        read(args[1], args[2])
    elif args[:1] == ["password"] and len(args) == 3 and args[1] in ("set", "clear", "has"):
        password(args[1], args[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
