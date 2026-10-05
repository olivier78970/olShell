#!/usr/bin/env bash
# Runs, checks and deploys olShell: the checkout (this repo) for testing, the
# deployed copy (~/.config/olShell) for everyday use. Never both at once.
# Usage (from the repo root):
#   shell.sh status                 which shell is running
#   shell.sh backup                 copy both shells' settings files aside
#   shell.sh dev [--stop-deployed]  back up, then run the checkout (stopping
#                                   the deployed shell only with the flag)
#   shell.sh restart                restart the checkout shell
#   shell.sh log [lines]            the checkout shell's log (default 60)
#   shell.sh deploy                 copy master into the deployed copy
#   shell.sh deployed               stop the checkout, run the deployed copy
#   shell.sh ipc <target> <fn> [args]   an IPC call to the shell that is running
#                                   (the checkout's, else the deployed one's)
set -u

repo=$(git rev-parse --show-toplevel)
deployed="$HOME/.config/olShell"
backups="${XDG_CACHE_HOME:-$HOME/.cache}/olshell-backups"
# The shell exports QS_CONFIG_PATH (services/ConfigPath.qml), which clashes
# with --all and would point bare calls at the deployed copy.
qs() { env -u QS_CONFIG_PATH quickshell "$@"; }

# The pids of the shell of folder $1, from the process list: `qs list` can miss
# a shell for a moment while it reloads after files changed (a branch switch,
# a merge), so it isn't enough to know whether one is running. The pattern is
# anchored so it doesn't match a command line merely mentioning the path.
pids() { pgrep -f "^quickshell -p $1( |\$)"; }

running() { qs list --all 2>/dev/null | grep -F "Config path: $1/shell.qml" >/dev/null || [ -n "$(pids "$1")" ]; }

status() {
  running "$deployed" && echo "deployed shell: running ($deployed)" || echo "deployed shell: not running"
  running "$repo" && echo "checkout shell: running ($repo)" || echo "checkout shell: not running"
}

# Stops the shell of folder $1 (an absolute path: `quickshell kill -p .` does
# nothing) and waits until it is gone, so it has released its D-Bus names
# (notifications, polkit) before another shell starts and wants them.
stop() {
  running "$1" || return 0
  qs kill -p "$1" >/dev/null 2>&1
  for _ in 1 2 3 4 5 6 7 8 9 10; do running "$1" || return 0; sleep 0.5; done
  # Still there (not in `qs list` to be killed that way): end its process.
  pids "$1" | xargs -r kill
  for _ in 1 2 3 4 5 6 7 8 9 10; do running "$1" || return 0; sleep 0.5; done
  echo "failed to stop $1"; return 1
}

backup() {
  local dir="$backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dir/checkout" "$dir/deployed"
  cp "$repo"/config/*.json "$dir/checkout/" 2>/dev/null
  cp "$deployed"/config/*.json "$dir/deployed/" 2>/dev/null
  echo "settings backed up to $dir"
}

# Starts the shell of folder $1 detached, then shows the start of its log.
start() {
  qs -p "$1" -d >/dev/null 2>&1
  for _ in 1 2 3 4 5 6 7 8 9 10; do running "$1" && break; sleep 0.5; done
  running "$1" || { echo "failed to start $1"; return 1; }
  sleep 2
  qs log -p "$1" -t 30 2>/dev/null
}

case ${1:-status} in
  status) status ;;
  backup) backup ;;
  dev)
    if running "$repo"; then echo "checkout shell already running"; status; exit 0; fi
    if running "$deployed"; then
      if [ "${2:-}" != "--stop-deployed" ]; then
        echo "The deployed shell is running. Ask the user before stopping it, then rerun with --stop-deployed."
        exit 2
      fi
      stop "$deployed" || exit 1
    fi
    backup
    start "$repo"
    ;;
  restart)
    stop "$repo" || exit 1
    backup
    start "$repo"
    ;;
  log) qs log -p "$repo" -t "${2:-60}" ;;
  ipc)
    # Whichever shell runs, whatever QS_CONFIG_PATH says (and without a
    # shell-variable word-splitting trap, which `q="quickshell ipc call"` hits in zsh).
    shift
    if running "$repo"; then target="$repo"
    elif running "$deployed"; then target="$deployed"
    else echo "no shell is running"; exit 1; fi
    qs -p "$target" ipc call "$@"
    ;;
  deploy)
    branch=$(git -C "$repo" branch --show-current)
    [ "$branch" = master ] || echo "note: on branch $branch; deploying master, which doesn't have this branch's commits"
    git -C "$repo" diff --quiet master -- || echo "note: uncommitted changes aren't deployed (only master's commits are)"
    backup
    git -C "$repo" archive master | tar -x -C "$deployed"
    echo "deployed master ($(git -C "$repo" log -1 --format='%h %s' master | cut -c1-80))"
    # Files a deploy no longer copies (git archive only adds and replaces):
    # removed from master, or export-ignored in .gitattributes. The
    # git-ignored files the shell writes itself (the config/*.json state,
    # matugen/active.toml) are meant to stay, so they are left out.
    stale=$(cd "$deployed" && find . -type f ! -path './config/*.json' | sed 's|^\./||' | sort \
      | comm -23 - <(git -C "$repo" archive master | tar -t | grep -v '/$' | sort))
    ignored=$(printf '%s\n' "$stale" | git -C "$repo" check-ignore --stdin --no-index)
    [ -n "$ignored" ] && stale=$(printf '%s\n' "$stale" | grep -vxF -f <(printf '%s\n' "$ignored"))
    [ -n "$stale" ] && { echo "in the deployed copy but not in master (not deleted):"; echo "$stale" | sed 's/^/  /'; }
    ;;
  deployed)
    # The files may have just changed (a merge), so a running checkout shell
    # may be reloading: let that settle before looking for it.
    sleep 2
    stop "$repo" || exit 1
    running "$deployed" && { echo "deployed shell already running"; exit 0; }
    start "$deployed" || exit 1
    # Never both: check the checkout didn't come back or survive.
    sleep 1
    running "$repo" && { echo "the checkout shell is still running: stopping it"; stop "$repo" || exit 1; }
    ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
