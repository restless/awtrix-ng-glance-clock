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

That is the default layout: each corner can show any element, so you can swap them around or
leave one empty. An optional week bar on the bottom row lights today.

Weather comes from [Open-Meteo](https://open-meteo.com): free, no account, no API key. The icons
are drawn by the script, so there is nothing to install.

## Features

- Four corners, each showing whatever you pick: weather, time, date, an MQTT reading, the
  outdoor humidity, the feels-like temperature, today's high/low, tomorrow's weather, or nothing

  ![Corners swapped](docs/layout-swapped.png) ![Without Home Assistant: humidity, feels-like, high/low, tomorrow](docs/no-ha.png)
- Small time with a steady, blinking or pulsing colon, 24h or 12h with AM/PM; and the date; weekday names in English, Polish, German,
  French or Ukrainian; date presets with dots, dashes or slashes, or a pattern of your own
- Optional week bar: seven dashes on the bottom row with today lit
- Outdoor temperature in °C or °F with a weather icon: clear (sun or moon), partly cloudy, cloudy, fog, rain,
  snow and thunderstorm
- Any value from your MQTT broker on the bottom left with a unit of your choice: a room
  temperature, the humidity, or text such as `Open` from a door sensor

  ![A text reading](docs/reading-text.png)
- Night mode, on a schedule or always on: its own colours for every element (the weather icon
  included) and its own brightness

  ![Night mode](docs/night.png)
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
| Top left, Top right, Bottom left, Bottom right | weather, time, reading, date | what each corner shows; see below |
| Hour format | 24h | 24h or 12h |
| AM/PM | on | 12h only |
| Leading zero | on | 08:05 rather than 8:05 |
| Colon | steady | steady, blink or pulse |
| Language | English | the weekday names: English, Polski, Deutsch, Français, Українська |
| Weekday in the date | on | |
| Date format | dd.mm | dd.mm, dd.mm.yy, dd-mm, dd-mm-yy, mm/dd, mm/dd/yy, yyyy-mm-dd or custom |
| Custom date format | d.mm.yy | used when Date format is custom: `dd` `d` `mm` `m` `yyyy` `yy` `ww` (weekday); anything else is shown as typed, e.g. `ww d·m` |
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
| Day brightness | 0 | 0 leaves the device brightness alone; otherwise set when night mode ends |
| Night mode | off | off, schedule or on |
| Night from, Night until | 22:00, 07:00 | the schedule; it may wrap past midnight |
| Night brightness | 8 | 0 leaves the device brightness alone |
| Weather icon at night | on | |
| Night colours | greens | time, date, outdoor temperature, reading and week bar |

Brightness is a device-wide setting. With a day brightness of 0, the brightness the device had
before night began is restored in the morning. Long custom date formats can run into the reading
on the left; keep them short.

### What a corner can show

| Option | Shows | Needs |
|---|---|---|
| `weather` | icon and outdoor temperature | internet |
| `time` | the time | |
| `date` | the date, as set under Date | |
| `reading` | the MQTT reading | an MQTT broker |
| `humidity` | outdoor relative humidity, e.g. `42%` | internet |
| `feels` | feels-like temperature, e.g. `~10°` | internet |
| `hilo` | today's high and low, e.g. `14/5°` | internet |
| `tomorrow` | tomorrow's icon and high | internet |
| `none` | nothing | |

Left corners start at the left edge, right corners end at the right edge. Keep the wider elements
(time, date) apart from each other on one row, or they overlap.

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
