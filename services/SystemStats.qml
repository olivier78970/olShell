pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU, RAM, network and storage figures, polled once for the whole shell
// rather than once per bar instance (i.e. per screen). The *History lists
// hold the most recent samples (oldest first) for sparklines.
Singleton {
  id: root

  // How many samples the histories keep.
  readonly property int historyLength: 60

  property real cpuPercent: 0
  property real cpuFrequencyGhz: 0
  property var corePercents: []

  property real ramUsedKb: 0
  property real ramTotalKb: 0
  readonly property real ramPercent: ramTotalKb > 0 ? (ramUsedKb / ramTotalKb) * 100 : 0

  property var prevTimes: ({})

  // Network speed in bytes per second, summed over the physical interfaces
  // (virtual ones such as VPNs and docker would count the same traffic twice).
  property real netDownBps: 0
  property real netUpBps: 0
  property var physicalInterfaces: []
  property var lastNet: null
  property double lastNetTime: 0

  // Mounted disks: [{ mount, device, fstype, size, used }], sizes in bytes.
  property var disks: []
  // The main disk, the one mounted on "/" (null until the first poll), and
  // how full it is, in percent.
  readonly property var rootDisk: root.disks.find(disk => disk.mount === "/") ?? null
  readonly property real rootDiskPercent: root.rootDisk ? (root.rootDisk.used / root.rootDisk.size) * 100 : 0

  property var cpuHistory: []
  property var ramHistory: []
  property var downHistory: []
  property var upHistory: []

  // 1234567 -> "1,2 Mio" / "1.2 MiB" (binary units, in the current language).
  // With `compact`, a
  // value of 10 or more drops the decimals ("15 Mio"), for tight spaces.
  function formatBytes(bytes, compact) {
    const units = I18n.value("format.units")
    let value = bytes
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024
      unit++
    }
    const digits = unit === 0 || (compact && value >= 10) ? 0 : 1
    return I18n.formatNumber(value, digits) + " " + units[unit]
  }

  function formatRate(bytesPerSecond, compact) {
    return root.formatBytes(bytesPerSecond, compact) + "/s"
  }

  // `list` with `value` appended, keeping only the last historyLength items.
  function pushed(list, value) {
    return list.concat([value]).slice(-root.historyLength)
  }

  Process {
    id: cpuProc
    command: ["cat", "/proc/stat"]

    // Each "cpu*" line holds cumulative jiffie counters since boot, so
    // usage is derived from the delta between two samples rather than a
    // single reading.
    stdout: StdioCollector {
      onStreamFinished: {
        const newTimes = {}
        const percents = {}

        for (const line of text.split("\n")) {
          const match = line.match(/^(cpu\d*)\s+(.*)$/)
          if (!match) continue

          const label = match[1]
          const fields = match[2].trim().split(/\s+/).map(Number)
          const idle = fields[3] + (fields[4] ?? 0)
          const total = fields.reduce((sum, n) => sum + n, 0)

          const prev = root.prevTimes[label]
          if (prev) {
            const totalDelta = total - prev.total
            const idleDelta = idle - prev.idle
            percents[label] = totalDelta > 0 ? (1 - idleDelta / totalDelta) * 100 : 0
          }
          newTimes[label] = { total, idle }
        }

        root.prevTimes = newTimes
        if (percents.cpu !== undefined) {
          root.cpuPercent = percents.cpu
          root.cpuHistory = root.pushed(root.cpuHistory, percents.cpu)
        }

        const cores = []
        for (let i = 0; percents["cpu" + i] !== undefined; i++)
          cores.push(percents["cpu" + i])
        root.corePercents = cores
      }
    }
  }

  Process {
    id: freqProc
    command: ["grep", "cpu MHz", "/proc/cpuinfo"]

    stdout: StdioCollector {
      onStreamFinished: {
        const values = []
        for (const line of text.split("\n")) {
          const match = line.match(/cpu MHz\s*:\s*([\d.]+)/)
          if (match) values.push(parseFloat(match[1]))
        }
        if (values.length > 0) {
          const avgMhz = values.reduce((sum, v) => sum + v, 0) / values.length
          root.cpuFrequencyGhz = avgMhz / 1000
        }
      }
    }
  }

  Process {
    id: memProc
    command: ["cat", "/proc/meminfo"]

    stdout: StdioCollector {
      onStreamFinished: {
        const totalMatch = text.match(/MemTotal:\s+(\d+)/)
        const availMatch = text.match(/MemAvailable:\s+(\d+)/)
        if (totalMatch && availMatch) {
          const total = parseInt(totalMatch[1])
          const avail = parseInt(availMatch[1])
          root.ramTotalKb = total
          root.ramUsedKb = total - avail
          root.ramHistory = root.pushed(root.ramHistory, root.ramPercent)
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      cpuProc.running = true
      freqProc.running = true
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: memProc.running = true
  }

  // --- Network -------------------------------------------------------

  // Reads the byte counters of the physical interfaces and turns the change
  // since the previous reading into a speed.
  function parseNet(text) {
    const now = Date.now()
    const current = {}
    for (const line of text.split("\n").slice(2)) {
      const colon = line.indexOf(":")
      if (colon < 0) continue
      const name = line.slice(0, colon).trim()
      if (!root.physicalInterfaces.includes(name)) continue
      const fields = line.slice(colon + 1).trim().split(/\s+/).map(Number)
      current[name] = { rx: fields[0], tx: fields[8] }
    }

    if (root.lastNet) {
      const seconds = (now - root.lastNetTime) / 1000
      let down = 0
      let up = 0
      for (const name in current) {
        const before = root.lastNet[name]
        // A counter that went down was reset (interface restarted): skip it.
        if (!before || current[name].rx < before.rx || current[name].tx < before.tx) continue
        down += current[name].rx - before.rx
        up += current[name].tx - before.tx
      }
      if (seconds > 0) {
        root.netDownBps = down / seconds
        root.netUpBps = up / seconds
        root.downHistory = root.pushed(root.downHistory, root.netDownBps)
        root.upHistory = root.pushed(root.upHistory, root.netUpBps)
      }
    }
    root.lastNet = current
    root.lastNetTime = now
  }

  FileView {
    id: netFile
    path: "/proc/net/dev"
    onLoaded: root.parseNet(netFile.text())
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: netFile.reload()
  }

  // Interfaces backed by real hardware; virtual ones (loopback, VPN, docker,
  // bridges...) live under /sys/devices/virtual.
  Process {
    id: interfaceProc
    command: ["sh", "-c", "for i in /sys/class/net/*; do case \"$(readlink -f \"$i\")\" in */devices/virtual/*) ;; *) basename \"$i\";; esac; done"]

    stdout: StdioCollector {
      onStreamFinished: {
        root.physicalInterfaces = text.split("\n").filter(name => name.length > 0)
        // Interfaces may have come or gone: start the speed from a fresh reading.
        root.lastNet = null
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: interfaceProc.running = true
  }

  // --- Storage -------------------------------------------------------

  Process {
    id: diskProc
    environment: ({ LC_ALL: "C" })
    command: ["df", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "squashfs", "-x", "overlay",
      "--output=source,fstype,size,used,target"]

    stdout: StdioCollector {
      onStreamFinished: {
        // One entry per device (btrfs subvolumes are mounted several times),
        // under its shortest mount point.
        const byDevice = {}
        for (const line of text.split("\n").slice(1)) {
          const parts = line.trim().split(/\s+/)
          if (parts.length < 5) continue
          const disk = { device: parts[0], fstype: parts[1], size: Number(parts[2]), used: Number(parts[3]), mount: parts.slice(4).join(" ") }
          if (!(disk.size > 0)) continue
          const known = byDevice[disk.device]
          if (!known || disk.mount.length < known.mount.length) byDevice[disk.device] = disk
        }
        root.disks = Object.values(byDevice).sort((a, b) => a.mount.length - b.mount.length)
      }
    }
  }

  Timer {
    interval: 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: diskProc.running = true
  }
}
