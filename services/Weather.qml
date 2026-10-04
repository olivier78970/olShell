pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The weather for the clock panel's weather tab, from Open-Meteo (free, no
// key needed): the conditions now, the next hours and the next days, in the
// unit picked (Settings.weatherUnit). The place is the one typed in the
// settings (Settings.weatherLocation, found with Open-Meteo's place search),
// or else the one of the internet address (ipinfo.io). Fetched when the tab
// is turned on, every half hour after that, and again when the unit or the
// place changes; nothing is fetched while the tab is off.
Singleton {
  id: root

  // Whether it's wanted: the clock panel shows its tab.
  readonly property bool active: Settings.clockShowWeather
  readonly property bool fahrenheit: Settings.weatherUnit === "fahrenheit"

  // The place: its name, and where it is.
  property string place: ""
  property real latitude: 0
  property real longitude: 0
  // The setting the place was found for, so a place typed in is only
  // searched for once.
  property string placeFor: "\u0000"

  // The conditions now: { temperature, apparent, humidity, wind, code, isDay }.
  property var current: null
  // The next hours, from this one: [{ time (a Date), temperature, code, isDay }].
  property var hours: []
  // The next days, from today: [{ date (a Date), code, max, min, rain (%) }].
  property var days: []
  // When it was last fetched (a Date), or null.
  property var updated: null
  property bool loading: false
  // What went wrong with the last fetch: "" (nothing), "place" (the place
  // typed in wasn't found) or "network".
  property string error: ""

  // Counts the fetches, so a reply to one overtaken by another (the unit or
  // the place changed meanwhile) is dropped.
  property int generation: 0

  // How many hours and days are kept.
  readonly property int hourCount: 12
  readonly property int dayCount: 7

  // An icon and a description key for a WMO weather code (Open-Meteo's).
  function kindOf(code) {
    if (code === 0) return "clear"
    if (code === 1 || code === 2) return "partly"
    if (code === 3) return "cloudy"
    if (code === 45 || code === 48) return "fog"
    if (code >= 51 && code <= 57) return "drizzle"
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return code === 65 || code === 82 ? "heavyRain" : "rain"
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow"
    if (code === 95) return "storm"
    if (code === 96 || code === 99) return "hail"
    return "cloudy"
  }

  function iconOf(code, isDay) {
    switch (root.kindOf(code)) {
    case "clear": return isDay ? "󰖙" : "󰖔"
    case "partly": return isDay ? "󰖕" : "󰼱"
    case "fog": return "󰖑"
    case "drizzle": return "󰖗"
    case "rain": return "󰖗"
    case "heavyRain": return "󰖖"
    case "snow": return "󰖘"
    case "storm": return "󰖓"
    case "hail": return "󰖒"
    default: return "󰖐"
    }
  }

  // Fetches the weather (finding the place first when needed).
  function refresh() {
    if (!root.active) return
    root.generation += 1
    root.loading = true
    const wanted = Settings.weatherLocation
    if (root.placeFor === wanted) {
      root.fetchForecast()
      return
    }
    if (wanted === "") {
      root.get("https://ipinfo.io/json", data => {
        const loc = String(data?.loc ?? "").split(",")
        if (loc.length !== 2) return root.fail("network")
        root.setPlace(wanted, data.city ?? "", Number(loc[0]), Number(loc[1]))
      })
    } else {
      root.get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=" + I18n.language + "&name=" + encodeURIComponent(wanted), data => {
        if (data === null) return root.fail("network")
        const found = data.results?.[0]
        if (!found) return root.fail("place")
        root.setPlace(wanted, found.name + (found.country ? ", " + found.country : ""), found.latitude, found.longitude)
      })
    }
  }

  function setPlace(wanted, name, latitude, longitude) {
    root.placeFor = wanted
    root.place = name
    root.latitude = latitude
    root.longitude = longitude
    root.fetchForecast()
  }

  function fetchForecast() {
    const url = "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude
      + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
      + "&hourly=temperature_2m,weather_code,is_day"
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
      + "&timezone=auto&forecast_days=" + root.dayCount
      + "&temperature_unit=" + (root.fahrenheit ? "fahrenheit" : "celsius")
      + "&wind_speed_unit=" + (root.fahrenheit ? "mph" : "kmh")
    root.get(url, data => {
      if (!data?.current || !data.hourly || !data.daily) return root.fail("network")
      const now = data.current
      root.current = {
        temperature: now.temperature_2m,
        apparent: now.apparent_temperature,
        humidity: now.relative_humidity_2m,
        wind: now.wind_speed_10m,
        code: now.weather_code,
        isDay: now.is_day === 1
      }
      // The place's local times, from the hour now on.
      const hour = now.time.slice(0, 13)
      const from = Math.max(0, data.hourly.time.findIndex(time => time.slice(0, 13) >= hour))
      root.hours = data.hourly.time.slice(from, from + root.hourCount).map((time, i) => ({
        time: new Date(time),
        temperature: data.hourly.temperature_2m[from + i],
        code: data.hourly.weather_code[from + i],
        isDay: data.hourly.is_day[from + i] === 1
      }))
      root.days = data.daily.time.map((date, i) => ({
        date: new Date(date + "T12:00"),
        code: data.daily.weather_code[i],
        max: data.daily.temperature_2m_max[i],
        min: data.daily.temperature_2m_min[i],
        rain: data.daily.precipitation_probability_max[i]
      }))
      root.updated = new Date()
      root.error = ""
      root.loading = false
    })
  }

  function fail(error) {
    root.error = error
    root.loading = false
  }

  // GETs `url` and passes its JSON to `done`, or null when it fails; not at
  // all when another fetch has started since.
  function get(url, done) {
    const generation = root.generation
    const request = new XMLHttpRequest()
    request.onreadystatechange = () => {
      if (request.readyState !== XMLHttpRequest.DONE || generation !== root.generation) return
      let data = null
      try {
        if (request.status === 200) data = JSON.parse(request.responseText)
      } catch (e) {
        data = null
      }
      done(data)
    }
    request.open("GET", url)
    request.send()
  }

  IpcHandler {
    target: "weather"
    enabled: Settings.widgetEnabled("clock")

    // Fetches the weather again now (while the weather tab is on).
    function refresh(): void {
      root.refresh()
    }

    // The weather as last fetched, as JSON: the place, the conditions now,
    // the next days, when it was fetched and what went wrong, if anything.
    function now(): string {
      return JSON.stringify({ place: root.place, unit: Settings.weatherUnit, current: root.current, days: root.days, updated: root.updated, error: root.error })
    }
  }

  // Every half hour while wanted, starting when it's turned on (unless a
  // fetch is still under way).
  Timer {
    interval: 30 * 60 * 1000
    repeat: true
    running: root.active
    triggeredOnStart: true
    onTriggered: if (!root.loading) root.refresh()
  }

  // Again at once for another unit or place (after the typing has settled).
  Connections {
    target: Settings

    function onWeatherUnitChanged() {
      refetch.restart()
    }

    function onWeatherLocationChanged() {
      refetch.restart()
    }
  }

  Timer {
    id: refetch
    interval: 300
    onTriggered: root.refresh()
  }
}
