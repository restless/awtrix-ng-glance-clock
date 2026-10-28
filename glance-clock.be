# @name    Glance Clock
# @desc    Time, date, outdoor weather with an icon and an MQTT reading on one screen, small and tidy (52x16 and larger)
# @author  restless
# @version 0.1
# @display 52x16
# @config  lang   select "Language"                       default=English options=English,Polski,Deutsch,Français,Українська help="Weekday names" group="Date"
# @config  wday   bool   "Weekday in the date"            default=true group="Date"
# @config  dfmt   select "Date format"                    default=dd.mm options=dd.mm,dd.mm.yy,mm/dd,mm/dd/yy group="Date"
# @config  wbar   bool   "Week bar"                       default=false help="Seven dashes on the bottom row, today lit" group="Week bar"
# @config  wmon   bool   "Week starts on Monday"          default=true group="Week bar"
# @config  wtd    color  "Today"                          default=#FFFFFF group="Week bar"
# @config  wod    color  "Other days"                     default=#404040 group="Week bar"
# @config  lat    number "Latitude"                       default=52.52 min=-90 max=90 step=0.0001 group="Weather"
# @config  lon    number "Longitude"                      default=13.405 min=-180 max=180 step=0.0001 group="Weather"
# @config  unit   select "Temperature unit"               default=C options=C,F group="Weather"
# @config  wref   number "Weather refresh"                default=10 min=5 max=60 unit=min group="Weather"
# @config  rtopic text   "MQTT topic"                     default="" help="Shown at the bottom left; empty hides it" group="Reading"
# @config  runit  text   "Unit"                           default="°" maxlen=4 help="Added after the value, e.g. ° or %" group="Reading"
# @config  rround bool   "Round numbers"                  default=true help="Text such as Open stays as it is" group="Reading"
# @config  tcol   color  "Time colour"                    default=#FFFFFF group="Colours"
# @config  dcol   color  "Date colour"                    default=#8888AA group="Colours"
# @config  ocol   color  "Outdoor temperature colour"     default=#FFB040 group="Colours"
# @config  rcol   color  "Reading colour"                 default=#40C0FF group="Colours"

class GlanceClock
  var url, ticks, busy
  var ts, ds, out, reading, code, day
  var days

  def init()
    self.url = "https://api.open-meteo.com/v1/forecast?latitude=" + str(store.get("lat")) +
               "&longitude=" + str(store.get("lon")) + "&current=temperature_2m,weather_code,is_day" +
               (store.get("unit") == "F" ? "&temperature_unit=fahrenheit" : "")
    self.ticks = 0
    self.busy = false
    self.ts = "--:--"
    self.ds = ""
    self.out = nil
    self.reading = nil
    self.code = -1
    self.day = 1
    var names = {
      "English":    ["SU", "MO", "TU", "WE", "TH", "FR", "SA"],
      "Polski":     ["ND", "PN", "WT", "ŚR", "CZ", "PT", "SB"],
      "Deutsch":    ["SO", "MO", "DI", "MI", "DO", "FR", "SA"],
      "Français":   ["DI", "LU", "MA", "ME", "JE", "VE", "SA"],
      "Українська": ["НД", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"]
    }
    self.days = names.find(store.get("lang"), names["English"])
  end

  def setup()
    var t = store.get("rtopic")
    if size(t) > 0 mqtt.subscribe(t, / tp, p -> self.on_reading(p)) end
  end

  # a number is rounded if asked; anything else (Open, Closed, ...) is shown as it came
  def on_reading(p)
    var v = num(p)
    if v != nil && store.get("rround") p = str(int(v + (v < 0 ? -0.5 : 0.5))) end
    self.reading = str(p) + store.get("runit")
  end

  def loop()
    var h = hour()
    if h >= 0
      var m = minute()
      self.ts = (h < 10 ? "0" : "") + str(h) + ":" + (m < 10 ? "0" : "") + str(m)
      self.ds = self.date_text()
    end
    if self.ticks <= 0 && !self.busy
      self.ticks = int(store.get("wref")) * 60
      self.busy = true
      http.get(self.url, / b, st -> self.on_wx(b, st), {'find': "\"current\":{", 'keep': 200})
    end
    self.ticks -= 1
  end

  def date_text()
    var d = day()
    var dd = (d < 10 ? "0" : "") + str(d)
    var mo = month()
    var mm = (mo < 10 ? "0" : "") + str(mo)
    var y = year() % 100
    var yy = (y < 10 ? "0" : "") + str(y)
    var f = store.get("dfmt")
    var s
    if f == "dd.mm.yy"     s = dd + "." + mm + "." + yy
    elif f == "mm/dd"      s = mm + "/" + dd
    elif f == "mm/dd/yy"   s = mm + "/" + dd + "/" + yy
    else                   s = dd + "." + mm
    end
    return store.get("wday") ? self.days[weekday()] + " " + s : s
  end

  def on_wx(b, st)
    self.busy = false
    if b == nil
      self.ticks = 60            # failed: try again in a minute
      return
    end
    var t = re.search("temperature_2m\":(-?[0-9.]+)", b)
    var c = re.search("weather_code\":([0-9]+)", b)
    var d = re.search("is_day\":([01])", b)
    if t != nil
      var v = real(t[1])
      self.out = str(int(v + (v < 0 ? -0.5 : 0.5))) + "°"
    end
    if c != nil self.code = int(c[1]) end
    if d != nil self.day = int(d[1]) end
  end

  # --- 8x8 weather icons, drawn by hand so nothing has to be installed ---
  def cloud(x, y, col)
    circle_fill(x + 2, y + 4, 2, col)
    circle_fill(x + 5, y + 3, 2, col)
    rect_fill(x + 1, y + 4, 6, 3, col)
  end

  def sun(x, y, r)
    circle_fill(x, y, r, 0xFFD000)
  end

  def wicon()
    var c = self.code
    if c < 0
      return
    elif c == 0 || c == 1
      if self.day == 1
        self.sun(3, 3, 2)
        pixel(3, 0, 0xFFD000) pixel(3, 6, 0xFFD000) pixel(0, 3, 0xFFD000) pixel(6, 3, 0xFFD000)
        pixel(1, 1, 0xFFD000) pixel(5, 1, 0xFFD000) pixel(1, 5, 0xFFD000) pixel(5, 5, 0xFFD000)
      else
        circle_fill(3, 3, 3, 0xD0D0A0)
        circle_fill(5, 2, 3, 0x000000)
      end
    elif c == 2
      if self.day == 1 self.sun(5, 2, 2) else circle_fill(5, 2, 2, 0xD0D0A0) end
      self.cloud(0, 1, 0xC0C0C0)
    elif c == 3
      self.cloud(0, 0, 0x909090)
    elif c == 45 || c == 48
      line(0, 2, 7, 2, 0x808080) line(1, 4, 6, 4, 0x808080) line(0, 6, 7, 6, 0x808080)
    elif c >= 71 && c <= 77 || c == 85 || c == 86
      self.cloud(0, -1, 0xA0A0A0)
      pixel(1, 7, 0xFFFFFF) pixel(4, 6, 0xFFFFFF) pixel(6, 7, 0xFFFFFF)
    elif c >= 95
      self.cloud(0, -1, 0x707070)
      line(4, 5, 3, 6, 0xFFD000) line(3, 6, 5, 6, 0xFFD000) pixel(4, 7, 0xFFD000)
    else                          # drizzle and rain: 51-67, 80-82
      self.cloud(0, -1, 0x8090A0)
      pixel(1, 6, 0x3080FF) pixel(4, 7, 0x3080FF) pixel(6, 6, 0x3080FF) pixel(2, 7, 0x3080FF)
    end
  end

  # seven dashes on the bottom row, centred, as wide as the panel allows
  def week_bar(w)
    var seg = (w + 1) / 7 - 1
    var x = (w - (7 * seg + 6)) / 2
    var today = weekday()
    if store.get("wmon") today = (today + 6) % 7 end
    for i : 0..6
      line(x, height() - 1, x + seg - 1, height() - 1, i == today ? store.get("wtd") : store.get("wod"))
      x += seg + 1
    end
  end

  def draw()
    clear()
    var w = width()
    # right column: time on top, date below, both right-aligned
    text(w - text_ink_width(self.ts) - 1, 6, self.ts, store.get("tcol"))
    text(w - text_ink_width(self.ds) - 1, 14, self.ds, store.get("dcol"))
    # left column: weather icon + outdoor temperature, the MQTT reading below
    self.wicon()
    if self.out != nil text(10, 6, self.out, store.get("ocol")) end
    if self.reading != nil text(1, 14, self.reading, store.get("rcol")) end
    if store.get("wbar") self.week_bar(w) end
  end
end

return GlanceClock()
