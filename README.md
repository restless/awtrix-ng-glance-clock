# Glance Clock for AWTRIX NG

A small, tidy clock for [AWTRIX NG](https://github.com/Blueforcer/awtrix-ng) panels of 52×16 pixels
and larger, such as the Ulanzi TC002. Instead of filling the panel with huge digits, it puts
everything you want to see at a glance on one screen:

![Glance Clock on a 52×16 panel](docs/screenshot.png)

| Top left | Top right |
|---|---|
| weather icon and outdoor temperature | time |
| **Bottom left** | **Bottom right** |
| a reading from MQTT, e.g. the room temperature | weekday and date |

Weather comes from [Open-Meteo](https://open-meteo.com): free, no account, no API key. The icons
are drawn by the script, so there is nothing to install.

## Features

- Small time and date, aligned to the right edge
- Outdoor temperature with a weather icon: clear (sun or moon), partly cloudy, cloudy, fog, rain,
  snow and thunderstorm
- Any value from your MQTT broker on the bottom left, e.g. a room temperature published by
  Home Assistant
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
| Latitude, Longitude | Berlin | the place whose weather is shown |
| Weather refresh | 10 min | how often the weather is fetched |
| Room temperature (MQTT topic) | empty | a topic on the broker set in AWTRIX's MQTT settings; empty hides the value |
| Time, date, outdoor and room colours | | |

### Room temperature from Home Assistant

Publish the sensor to a topic, retained, and put that topic into the setting:

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
