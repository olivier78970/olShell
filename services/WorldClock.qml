pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The places of the clock panel's clocks tab (Settings.worldClocks) and
// their time now. The shell's JavaScript can't convert between time zones,
// so each zone's UTC offset (daylight saving time included) comes from
// scripts/timezones.py, asked again when the places change and every ten
// minutes, so a change of daylight saving time is caught. A place is added
// by name: Open-Meteo's place search (as for the weather) gives its time
// zone.
Singleton {
  id: root

  // Each zone's offset now, by zone: { offset (seconds east of UTC), abbrev }.
  property var zones: ({})
  // The zones wanted: the places'.
  readonly property var wanted: [...new Set(Settings.worldClocks.map(clock => clock.zone))]
  // What the last search for a place to add gave: "" (nothing yet, or it was
  // added), "searching", or "notFound" / "network" with `searched` the name.
  property string status: ""
  property string searched: ""

  // The offset of the zone this computer is in, in seconds east of UTC.
  function localOffset() {
    return -new Date().getTimezoneOffset() * 60
  }

  // The time now in `zone`, as a Date whose own (local) fields read the
  // zone's wall clock time, or null while its offset isn't known.
  function timeIn(zone, now) {
    const known = root.zones[zone]
    if (!known) return null
    return new Date(now.getTime() + (known.offset - root.localOffset()) * 1000)
  }

  // Looks `name` up and adds the place found, with its time zone.
  function add(name) {
    const text = name.trim()
    if (text === "") return
    root.searched = text
    root.status = "searching"
    const request = new XMLHttpRequest()
    request.onreadystatechange = () => {
      if (request.readyState !== XMLHttpRequest.DONE) return
      let found = null
      try {
        if (request.status !== 200) return root.status = "network"
        found = JSON.parse(request.responseText).results?.[0] ?? null
      } catch (e) {
        return root.status = "network"
      }
      if (!found?.timezone) return root.status = "notFound"
      Settings.addWorldClock(found.name + (found.country ? ", " + found.country : ""), found.timezone)
      root.status = ""
    }
    request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&language=" + I18n.language + "&name=" + encodeURIComponent(text))
    request.send()
  }

  function refresh() {
    if (root.wanted.length === 0) return
    reader.command = ["python3", Paths.timezonesScript].concat(root.wanted)
    reader.running = true
  }

  onWantedChanged: root.refresh()

  Process {
    id: reader

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.zones = JSON.parse(this.text)
        } catch (e) {
          root.zones = {}
        }
      }
    }
  }

  // Every ten minutes, for daylight saving time.
  Timer {
    interval: 10 * 60 * 1000
    repeat: true
    running: root.wanted.length > 0
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
