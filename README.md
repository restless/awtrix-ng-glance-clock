# Glance Clock for AWTRIX NG

A small, tidy clock for [AWTRIX NG](https://github.com/Blueforcer/awtrix-ng) panels of 52×16 pixels
and larger, such as the Ulanzi TC002. Instead of filling the panel with huge digits, it puts
everything you want to see at a glance on one screen:

![Glance Clock on a 52×16 panel](docs/screenshot.png)

| Top left | Top right |
|---|---|
| weather icon and outdoor temperature | time |
| **Bottom left** | **Bottom right** |
| any reading from MQTT, e.g. the room temperature | weekday and date |

An optional week bar on the bottom row lights today.

Weather comes from [Open-Meteo](https://open-meteo.com): free, no account, no API key. The icons
are drawn by the script, so there is nothing to install.

## Features

- Small time and date, aligned to the right edge; weekday names in English, Polish, German,
  French or Ukrainian, and four date formats
- Optional week bar: seven dashes on the bottom row with today lit
- Outdoor temperature in °C or °F with a weather icon: clear (sun or moon), partly cloudy, cloudy, fog, rain,
  snow and thunderstorm
- Any value from your MQTT broker on the bottom left with a unit of your choice: a room
  temperature, the humidity, or text such as `Open` from a door sensor

  ![A text reading](docs/reading-text.png)
- Colours for every element
- The layout is anchored to the panel's edges, so it spreads out on larger panels

## Installation

In the AWTRIX NG web UI, open **Scripts**, create a new script, paste
[`glance-clock.be`](glance-clock.be) and save. Or upload it over HTTP:

```sh
curl -X PUT --data-binary @glance-clock.be http://<clock-ip>/api/v1/apps/script/Glance-Clock
```

Then open the app's settings (**Apps** → gear icon) and set your **latitude** and **longitude**.
The default is Berlin.

## Settings

| Setting | Default | |
|---|---|---|
| Language | English | the weekday names: English, Polski, Deutsch, Français, Українська |
| Weekday in the date | on | |
| Date format | dd.mm | dd.mm, dd.mm.yy, mm/dd or mm/dd/yy |
| Week bar | off | seven dashes on the bottom row, today lit |
| Week starts on Monday | on | |
| Today, Other days | white, grey | the week bar's colours |
| Latitude, Longitude | Berlin | the place whose weather is shown |
| Temperature unit | C | C or F |
| Weather refresh | 10 min | how often the weather is fetched |
| MQTT topic | empty | a topic on the broker set in AWTRIX's MQTT settings; empty hides the reading |
| Unit | ° | added after the value, e.g. `°` or `%`; empty for text |
| Round numbers | on | numbers are rounded; text is shown as it is |
| Time, date, outdoor temperature and reading colours | | |

### A reading from Home Assistant

Publish the sensor to a topic, retained, and put that topic into the **MQTT topic** setting.
Publishing on a schedule keeps the panel calm when the sensor reports often, and fills the value
in within a minute after the script restarts:

```yaml
alias: "Room temperature to AWTRIX"
triggers:
  - trigger: time_pattern
    minutes: "/1"
actions:
  - action: mqtt.publish
    data:
      topic: awtrix/room/temp
      payload: "{{ states('sensor.room_temperature') }}"
      retain: true
```

## Requirements

- AWTRIX NG with scripting, on a panel of at least 52×16 pixels
- Internet access for the weather; an MQTT broker only for the bottom-left reading

## License

[MIT](LICENSE)
