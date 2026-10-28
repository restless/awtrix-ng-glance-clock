# @name    Glance Clock
# @desc    Time, date, outdoor weather with an icon and an MQTT reading on one screen, small and tidy (52x16 and larger)
# @author  restless
# @version 0.4
# @display 52x16
# @config  t12    select "Hour format"                    default=24h options=24h,12h group="Time"
# @config  ampm   bool   "AM/PM"                          default=true help="12h only: AM or PM after the minutes" group="Time"
# @config  tlz    bool   "Leading zero"                   default=true help="08:05 rather than 8:05" group="Time"
# @config  tl     select "Top left"                       default="Weather now" options="Weather now,Time,Date,MQTT reading,Humidity outdoors,Feels like,High/low today,Tomorrow,Rain chance today,Wind,Sunrise/sunset,Empty" group="Layout"
# @config  tr     select "Top right"                      default="Time" options="Weather now,Time,Date,MQTT reading,Humidity outdoors,Feels like,High/low today,Tomorrow,Rain chance today,Wind,Sunrise/sunset,Empty" group="Layout"
# @config  bl     select "Bottom left"                    default="MQTT reading" options="Weather now,Time,Date,MQTT reading,Humidity outdoors,Feels like,High/low today,Tomorrow,Rain chance today,Wind,Sunrise/sunset,Empty" group="Layout"
# @config  br     select "Bottom right"                   default="Date" options="Weather now,Time,Date,MQTT reading,Humidity outdoors,Feels like,High/low today,Tomorrow,Rain chance today,Wind,Sunrise/sunset,Empty" group="Layout"
# @config  tsep   select "Colon"                          default=steady options=steady,blink,pulse group="Time"
# @config  lang   select "Language"                       default=English options=English,Polski,Deutsch,Français,Українська help="Weekday names" group="Date"
# @config  wday   bool   "Weekday in the date"            default=true group="Date"
# @config  dfmt   select "Date format"                    default=dd.mm options=dd.mm,dd.mm.yy,dd-mm,dd-mm-yy,mm/dd,mm/dd/yy,yyyy-mm-dd,custom group="Date"
# @config  dcust  text   "Custom date format"             default="d.mm.yy" maxlen=24 help="For Date format custom: dd d mm m yyyy yy ww (weekday), anything else as typed" group="Date"
# @config  wbar   bool   "Week bar"                       default=false help="Seven dashes on the bottom row, today lit" group="Week bar"
# @config  wmon   bool   "Week starts on Monday"          default=true group="Week bar"
# @config  wtd    color  "Today"                          default=#FFFFFF group="Week bar"
# @config  wod    color  "Other days"                     default=#404040 group="Week bar"
# @config  lat    number "Latitude"                       default=52.52 min=-90 max=90 step=0.0001 group="Weather"
# @config  lon    number "Longitude"                      default=13.405 min=-180 max=180 step=0.0001 group="Weather"
# @config  unit   select "Temperature unit"               default=C options=C,F group="Weather"
# @config  wunit  select "Wind unit"                      default=km/h options=km/h,m/s,mph group="Weather"
# @config  wref   number "Weather refresh"                default=10 min=5 max=60 unit=min group="Weather"
# @config  rtopic text   "MQTT topic"                     default="" help="Shown at the bottom left; empty hides it" group="Reading"
# @config  runit  text   "Unit"                           default="°" maxlen=4 help="Added after the value, e.g. ° or %" group="Reading"
# @config  rround bool   "Round numbers"                  default=true help="Text such as Open stays as it is" group="Reading"
# @config  tcol   color  "Time colour"                    default=#FFFFFF group="Colours"
# @config  dcol   color  "Date colour"                    default=#8888AA group="Colours"
# @config  ocol   color  "Outdoor temperature colour"     default=#FFB040 group="Colours"
# @config  rcol   color  "Reading colour"                 default=#40C0FF group="Colours"
# @config  dbri   slider "Day brightness"                 default=0 min=0 max=255 help="0 leaves the device brightness alone" group="Colours"
# @config  nmode  select "Night mode"                     default=off options=off,schedule,on help="schedule: between the two times below" group="Night"
# @config  nfrom  text   "Night from (hh:mm)"             default="22:00" maxlen=5 group="Night"
# @config  nto    text   "Night until (hh:mm)"            default="07:00" maxlen=5 group="Night"
# @config  nbri   slider "Night brightness"               default=8 min=0 max=255 help="0 leaves the device brightness alone" group="Night"
# @config  nicon  bool   "Weather icon at night"          default=true group="Night"
# @config  ntcol  color  "Time colour"                    default=#30E040 group="Night"
# @config  ndcol  color  "Date colour"                    default=#106A1C group="Night"
# @config  nocol  color  "Outdoor temperature colour"     default=#1C9030 group="Night"
# @config  nrcol  color  "Reading colour"                 default=#106A1C group="Night"
# @config  nwtd   color  "Week bar: today"                default=#1C9030 group="Night"
# @config  nwod   color  "Week bar: other days"           default=#04200A group="Night"

class GlanceClock
  var url, ticks, busy
  var ts, hh, mm, ap, ds, out, reading, code, day
  var hum, feels, hilo, tmax, tcode, rain, wind
  var sunev, suntxt, sunicon
  var days
  var night, nfrom, nto, col
  var slots

  def init()
    self.url = "https://api.open-meteo.com/v1/forecast?latitude=" + str(store.get("lat")) +
               "&longitude=" + str(store.get("lon")) + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m,apparent_temperature,wind_speed_10m" +
               "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset" +
               "&forecast_days=2&timezone=auto&wind_speed_unit=" + {"km/h": "kmh", "m/s": "ms", "mph": "mph"}.find(store.get("wunit"), "kmh") +
               (store.get("unit") == "F" ? "&temperature_unit=fahrenheit" : "")
    self.ticks = 0
    self.busy = false
    self.ts = "--:--"
    self.hh = "--"
    self.mm = "--"
    self.ap = ""
    self.ds = ""
    self.out = nil
    self.reading = nil
    self.code = -1
    self.tcode = -1
    self.sunev = nil
    self.sunicon = -1
    self.day = 1
    var names = {
      "English":    ["SU", "MO", "TU", "WE", "TH", "FR", "SA"],
      "Polski":     ["ND", "PN", "WT", "ŚR", "CZ", "PT", "SB"],
      "Deutsch":    ["SO", "MO", "DI", "MI", "DO", "FR", "SA"],
      "Français":   ["DI", "LU", "MA", "ME", "JE", "VE", "SA"],
      "Українська": ["НД", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"]
    }
    self.days = names.find(store.get("lang"), names["English"])
    self.night = nil
    self.nfrom = self.parse_hm(store.get("nfrom"))
    self.nto = self.parse_hm(store.get("nto"))
    self.use_colours(false)
    # the labels picked in the web UI, and the short names stored by 0.4
    var ids = {
      "Weather now": "weather", "Time": "time", "Date": "date", "MQTT reading": "reading",
      "Humidity outdoors": "humidity", "Feels like": "feels", "High/low today": "hilo",
      "Tomorrow": "tomorrow", "Rain chance today": "rain", "Wind": "wind",
      "Sunrise/sunset": "sun", "Empty": "none"
    }
    self.slots = []
    for k : ["tl", "tr", "bl", "br"]
      var v = store.get(k)
      self.slots.push(ids.find(v, v))
    end
  end

  # "22:00" -> minutes after midnight, nil if it does not read as a time
  def parse_hm(t)
    var m = re.search("^ *([0-9]?[0-9]):([0-5][0-9]) *$", str(t))
    if m == nil || int(m[1]) > 23 return nil end
    return int(m[1]) * 60 + int(m[2])
  end

  # time, date, outdoor, reading, week bar today, week bar other days
  def use_colours(n)
    var k = n ? ["ntcol", "ndcol", "nocol", "nrcol", "nwtd", "nwod"] : ["tcol", "dcol", "ocol", "rcol", "wtd", "wod"]
    self.col = []
    for key : k self.col.push(store.get(key)) end
  end

  def is_night(now)
    var mode = store.get("nmode")
    if mode == "on" return true end
    if mode != "schedule" || self.nfrom == nil || self.nto == nil || self.nfrom == self.nto return false end
    if self.nfrom < self.nto return now >= self.nfrom && now < self.nto end
    return now >= self.nfrom || now < self.nto        # the window wraps past midnight
  end

  # brightness is a device setting: the day value is remembered before night changes it
  def switch_mode(n)
    self.night = n
    self.use_colours(n)
    var nb = int(store.get("nbri"))
    var db = int(store.get("dbri"))
    if n
      if nb > 0
        if !store.get("saved_bri", false) store.set("saved_bri", settings.get("brightness")) end
        settings.set("brightness", nb)
      end
    else
      var saved = store.get("saved_bri", false)
      if db > 0 settings.set("brightness", db)
      elif saved settings.set("brightness", saved)
      end
      store.set("saved_bri", false)
    end
  end

  def setup()
    var t = store.get("rtopic")
    if size(t) == 0 return end
    # a restart (e.g. saving the settings) would leave the corner empty until the next message
    if store.get("last_topic", "") == t self.show_reading(store.get("last_value")) end
    mqtt.subscribe(t, / tp, p -> self.on_reading(p))
  end

  def on_reading(p)
    p = str(p)
    if p != store.get("last_value", nil)
      store.set("last_topic", store.get("rtopic"))
      store.set("last_value", p)
    end
    self.show_reading(p)
  end

  # a number is rounded if asked; anything else (Open, Closed, ...) is shown as it came
  def show_reading(p)
    var v = num(p)
    if v != nil && store.get("rround") p = str(int(v + (v < 0 ? -0.5 : 0.5))) end
    self.reading = str(p) + store.get("runit")
  end

  def loop()
    var h = hour()
    if h >= 0
      var m = minute()
      var hd = h
      self.ap = ""
      if store.get("t12") == "12h"
        hd = h % 12
        if hd == 0 hd = 12 end
        if store.get("ampm") self.ap = h < 12 ? "AM" : "PM" end
      end
      self.hh = (hd < 10 && store.get("tlz") ? "0" : "") + str(hd)
      self.mm = (m < 10 ? "0" : "") + str(m)
      self.ts = self.hh + ":" + self.mm + self.ap
      self.ds = self.date_text()
      if self.sunev != nil
        var now = h * 60 + m
        var e = now < self.sunev[0] ? 0 : (now < self.sunev[1] ? 1 : 2)
        self.sunicon = e == 1 ? 1001 : 1000
        self.suntxt = self.fmt_hm(self.sunev[e])
      end
      var n = self.is_night(h * 60 + m)
      if n != self.night self.switch_mode(n) end
    end
    if self.ticks <= 0 && !self.busy
      self.ticks = int(store.get("wref")) * 60
      self.busy = true
      http.get(self.url, / b, st -> self.on_wx(b, st), {'cap': 4096})
    end
    self.ticks -= 1
  end

  # minutes after midnight as h:mm in the clock's hour format, without the colon effects
  def fmt_hm(t)
    var h = t / 60
    var m = t % 60
    var ap = ""
    if store.get("t12") == "12h"
      if store.get("ampm") ap = h < 12 ? "AM" : "PM" end
      h = h % 12
      if h == 0 h = 12 end
    end
    return (h < 10 && store.get("tlz") ? "0" : "") + str(h) + ":" + (m < 10 ? "0" : "") + str(m) + ap
  end

  def date_text()
    var f = store.get("dfmt")
    var s = self.fmt_date(f == "custom" ? store.get("dcust") : f)
    return store.get("wday") ? self.days[weekday()] + " " + s : s
  end

  # turns a pattern such as dd.mm.yy into a date; longest token first, the rest as typed
  def fmt_date(p)
    var d = day()
    var mo = month()
    var y = year()
    var out = ""
    var i = 0
    while i < size(p)
      var t = p[i..i + 3]
      if t == "yyyy"                out += str(y)  i += 4
      elif t[0..1] == "yy"          out += (y % 100 < 10 ? "0" : "") + str(y % 100)  i += 2
      elif t[0..1] == "dd"          out += (d < 10 ? "0" : "") + str(d)  i += 2
      elif t[0..1] == "mm"          out += (mo < 10 ? "0" : "") + str(mo)  i += 2
      elif t[0..1] == "ww"          out += self.days[weekday()]  i += 2
      elif t[0] == "d"              out += str(d)  i += 1
      elif t[0] == "m"              out += str(mo)  i += 1
      else                          out += p[i]  i += 1
      end
    end
    return out
  end

  def deg(v)
    return str(int(v + (v < 0 ? -0.5 : 0.5))) + "°"
  end

  # current values first, then today's and tomorrow's from the daily arrays
  def on_wx(b, st)
    self.busy = false
    if b == nil
      self.ticks = 60            # failed: try again in a minute
      return
    end
    var t = re.search("temperature_2m\":(-?[0-9.]+)", b)
    var c = re.search("weather_code\":([0-9]+)", b)
    var d = re.search("is_day\":([01])", b)
    var h = re.search("relative_humidity_2m\":([0-9.]+)", b)
    var f = re.search("apparent_temperature\":(-?[0-9.]+)", b)
    var hi = re.search("temperature_2m_max\":\\[(-?[0-9.]+),(-?[0-9.]+)", b)
    var lo = re.search("temperature_2m_min\":\\[(-?[0-9.]+),(-?[0-9.]+)", b)
    var dc = re.search("weather_code\":\\[([0-9]+),([0-9]+)", b)
    if t != nil self.out = self.deg(real(t[1])) end
    if c != nil self.code = int(c[1]) end
    if d != nil self.day = int(d[1]) end
    if h != nil self.hum = str(int(real(h[1]))) + "%" end
    if f != nil self.feels = "~" + self.deg(real(f[1])) end
    if hi != nil && lo != nil
      var l = self.deg(real(lo[1]))
      self.hilo = self.deg(real(hi[1]))[0..-3] + "/" + l          # 18/9°: one degree sign
      self.tmax = self.deg(real(hi[2]))
    end
    if dc != nil self.tcode = int(dc[2]) end
    var pr = re.search("precipitation_probability_max\":\\[([0-9]+)", b)
    var ws = re.search("wind_speed_10m\":([0-9.]+)", b)
    var hm = "T([0-9][0-9]):([0-9][0-9])\""
    var sr = re.search("sunrise\":\\[\"[^T]*" + hm + ",\"[^T]*" + hm, b)
    var ss = re.search("sunset\":\\[\"[^T]*" + hm, b)
    if pr != nil self.rain = pr[1] + "%" end
    if ws != nil self.wind = str(int(real(ws[1]) + 0.5)) + store.get("wunit") end
    if sr != nil && ss != nil      # today's sunrise and sunset, tomorrow's sunrise, in minutes
      self.sunev = [int(sr[1]) * 60 + int(sr[2]), int(ss[1]) * 60 + int(ss[2]), int(sr[3]) * 60 + int(sr[4])]
    end
  end

  # --- 8x8 weather icons, drawn by hand so nothing has to be installed ---
  # at night every icon takes the night outdoor colour, so nothing glares
  def ic(c)
    return self.night ? self.col[2] : c
  end

  def cloud(x, y, col)
    circle_fill(x + 2, y + 4, 2, col)
    circle_fill(x + 5, y + 3, 2, col)
    rect_fill(x + 1, y + 4, 6, 3, col)
  end

  # the icon for WMO weather code c, its top left corner at (x, y)
  def wicon(x, y, c, isday)
    var sun = self.ic(0xFFD000)
    var moon = self.ic(0xD0D0A0)
    if c < 0
      return
    elif c >= 1000
      var o = self.ic(0xFF9000)
      if c == 1000 pixel(x + 3, y, sun) pixel(x + 2, y + 1, sun) pixel(x + 4, y + 1, sun)
      else pixel(x + 2, y, sun) pixel(x + 4, y, sun) pixel(x + 3, y + 1, sun)
      end
      line(x + 2, y + 3, x + 4, y + 3, sun) rect_fill(x + 1, y + 4, 5, 2, sun)
      line(x, y + 6, x + 6, y + 6, o)
    elif c == 0 || c == 1
      if isday
        circle_fill(x + 3, y + 3, 2, sun)
        pixel(x + 3, y, sun) pixel(x + 3, y + 6, sun) pixel(x, y + 3, sun) pixel(x + 6, y + 3, sun)
        pixel(x + 1, y + 1, sun) pixel(x + 5, y + 1, sun) pixel(x + 1, y + 5, sun) pixel(x + 5, y + 5, sun)
      else
        circle_fill(x + 3, y + 3, 3, moon)
        circle_fill(x + 5, y + 2, 3, 0x000000)
      end
    elif c == 2
      circle_fill(x + 5, y + 2, 2, isday ? sun : moon)
      self.cloud(x, y + 1, self.ic(0xC0C0C0))
    elif c == 3
      self.cloud(x, y, self.ic(0x909090))
    elif c == 45 || c == 48
      var f = self.ic(0x808080)
      line(x, y + 2, x + 7, y + 2, f) line(x + 1, y + 4, x + 6, y + 4, f) line(x, y + 6, x + 7, y + 6, f)
    elif c >= 71 && c <= 77 || c == 85 || c == 86
      var w = self.ic(0xFFFFFF)
      self.cloud(x, y - 1, self.ic(0xA0A0A0))
      pixel(x + 1, y + 7, w) pixel(x + 4, y + 6, w) pixel(x + 6, y + 7, w)
    elif c >= 95
      self.cloud(x, y - 1, self.ic(0x707070))
      line(x + 4, y + 5, x + 3, y + 6, sun) line(x + 3, y + 6, x + 5, y + 6, sun) pixel(x + 4, y + 7, sun)
    else                          # drizzle and rain: 51-67, 80-82
      var d = self.ic(0x3080FF)
      self.cloud(x, y - 1, self.ic(0x8090A0))
      pixel(x + 1, y + 6, d) pixel(x + 4, y + 7, d) pixel(x + 6, y + 6, d) pixel(x + 2, y + 7, d)
    end
  end

  # seven dashes on the bottom row, centred, as wide as the panel allows
  def week_bar(w)
    var seg = (w + 1) / 7 - 1
    var x = (w - (7 * seg + 6)) / 2
    var today = weekday()
    if store.get("wmon") today = (today + 6) % 7 end
    for i : 0..6
      line(x, height() - 1, x + seg - 1, height() - 1, i == today ? self.col[4] : self.col[5])
      x += seg + 1
    end
  end

  # hh, colon and mm drawn apart so the colon can blink or pulse
  def draw_time(x, y, c)
    x += text(x, y, self.hh, c)
    var sep = store.get("tsep")
    var phase = now_ms() % 2000
    var cc = c
    if sep == "blink"
      if phase >= 1000 cc = 0 end
    elif sep == "pulse"
      var f = phase < 1000 ? phase : 2000 - phase      # 0..1000..0 over two seconds
      f = 250 + f * 3 / 4                               # never fully dark
      cc = rgb(((c >> 16) & 255) * f / 1000, ((c >> 8) & 255) * f / 1000, (c & 255) * f / 1000)
    end
    x += text(x, y, ":", cc)
    x += text(x, y, self.mm, c)
    if size(self.ap) > 0 text(x, y, self.ap, c) end
  end

  # one corner: slot 0 top left, 1 top right, 2 bottom left, 3 bottom right.
  # Left corners start at the left edge, right corners end at the right edge.
  def draw_slot(i, w)
    var what = self.slots[i]
    var right = i == 1 || i == 3
    var y = i < 2 ? 6 : 14
    if what == "time"
      self.draw_time(right ? w - text_ink_width(self.ts) - 1 : 1, y, self.col[0])
      return
    end
    var t = nil            # the text, its colour, and the icon in front of it (-1: none)
    var k = 2
    var icon = -1
    var isday = true
    if what == "date"           t = self.ds  k = 1
    elif what == "reading"      t = self.reading  k = 3
    elif what == "humidity"     t = self.hum
    elif what == "feels"        t = self.feels
    elif what == "hilo"         t = self.hilo
    elif what == "weather"      t = self.out  icon = self.code  isday = self.day == 1
    elif what == "tomorrow"     t = self.tmax  icon = self.tcode
    elif what == "rain"         t = self.rain  icon = self.rain != nil ? 61 : -1
    elif what == "wind"         t = self.wind
    elif what == "sun"          t = self.suntxt  icon = self.sunicon
    end
    if self.night && !store.get("nicon") icon = -1 end
    var tw = t != nil ? text_ink_width(t) : 0
    var iw = icon >= 0 ? 10 : 0
    var x = right ? w - tw - iw - 1 : (iw > 0 ? 0 : 1)
    if icon >= 0      # a bottom icon moves up a row to keep clear of the week bar
      self.wicon(x, y - (i >= 2 && store.get("wbar") ? 7 : 6), icon, isday)
    end
    if t != nil text(x + iw, y, t, self.col[k]) end
  end

  def draw()
    clear()
    var w = width()
    for i : 0..3 self.draw_slot(i, w) end
    if store.get("wbar") self.week_bar(w) end
  end
end

return GlanceClock()
