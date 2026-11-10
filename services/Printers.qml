pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The CUPS printers and the print jobs waiting or printing, for the printer
// widget. A helper script (scripts/printers-watch.py) asks CUPS every couple
// of seconds and prints the queue whenever it changes; it only runs while the
// printer widget is enabled. IPC (target `printers`): `jobs` lists the queue,
// `hold <id>` suspends a job, `release <id>` lets it print again,
// `cancel <id>` cancels a job, `cancelAll` cancels every job, `settings` opens
// the printer settings (system-config-printer).
Singleton {
  id: root

  // The jobs not yet completed, oldest first: { id, name, printer (the
  // queue's name), size (kilobytes), state (3 pending, 4 held, 5 printing,
  // 6 stopped), user }.
  readonly property var jobs: root.watching ? root.queue.jobs : []
  // The printers: { name, info (the name shown), state (3 idle, 4 printing,
  // 5 stopped), message (what CUPS says about it, often empty) }.
  readonly property var printers: root.watching ? root.queue.printers : []
  // What keeps the queue from being known: "" (nothing), "pycups" (the
  // Python module is missing) or "cups" (CUPS can't be reached).
  readonly property string error: root.watching ? root.queue.error : ""
  // Whether the queue is watched: while the printer widget is enabled.
  readonly property bool watching: Settings.widgetEnabled("printer")
  // The queue as the helper script last printed it. It's only ever replaced
  // by a new line, never emptied as the script stops: that happens as the
  // shell exits, and a new list reaching the menu's Repeater while it's
  // being destroyed crashes Quickshell. The lists above are empty while not
  // watching instead.
  property var queue: ({ jobs: [], printers: [], error: "" })

  // The printer named `name` (a job's `printer`), or null.
  function printer(name) {
    return root.printers.find(printer => printer.name === name) ?? null
  }

  // Whether a printer with jobs waiting is stopped (out of paper, jammed,
  // paused), so the widget warns.
  readonly property bool stalled: root.jobs.some(job => job.state === 6 || root.printer(job.printer)?.state === 5)

  // Cancels job `id` (CUPS only lets you cancel your own jobs).
  function cancel(id) {
    Quickshell.execDetached(["cancel", String(id)])
  }

  // Suspends job `id` (holds it in the queue until it's released).
  function hold(id) {
    Quickshell.execDetached(["lp", "-i", String(id), "-H", "hold"])
  }

  // Lets suspended job `id` print again.
  function release(id) {
    Quickshell.execDetached(["lp", "-i", String(id), "-H", "resume"])
  }

  // Cancels every job of the queue.
  function cancelAll() {
    Quickshell.execDetached(["cancel", "-a"])
  }

  // Opens the printer settings.
  function openSettings() {
    Quickshell.execDetached(["system-config-printer"])
  }

  Process {
    running: root.watching
    command: ["python3", Paths.printersWatchScript]

    stdout: SplitParser {
      onRead: line => {
        try {
          const state = JSON.parse(line)
          root.queue = { jobs: state.jobs ?? [], printers: state.printers ?? [], error: state.error ?? "" }
        } catch (e) {
          console.warn("Printers: unreadable line from printers-watch.py:", line)
        }
      }
    }
  }

  IpcHandler {
    target: "printers"
    enabled: root.watching

    // The jobs waiting or printing, one per line: id, printer, size in
    // kilobytes, state and name.
    function jobs(): string {
      return root.jobs.map(job => [job.id, job.printer, job.size, job.state, job.name].join("\t")).join("\n")
    }

    // Cancels job `id`.
    function cancel(id: int): void {
      root.cancel(id)
    }

    // Suspends job `id`.
    function hold(id: int): void {
      root.hold(id)
    }

    // Lets suspended job `id` print again.
    function release(id: int): void {
      root.release(id)
    }

    // Cancels every job.
    function cancelAll(): void {
      root.cancelAll()
    }

    // Opens the printer settings (system-config-printer).
    function settings(): void {
      root.openSettings()
    }
  }
}
