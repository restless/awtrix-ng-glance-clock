# @name    Glance Clock
# @desc    Time, date, outdoor weather with an icon and an MQTT reading on one screen, small and tidy (52x16 and larger)
# @author  restless
# @version 0.2
# @display 52x16
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
# @config  ntcol  color  "Time colour"                    default=#FF3000 group="Night"
# @config  ndcol  color  "Date colour"                    default=#702000 group="Night"
# @config  nocol  color  "Outdoor temperature colour"     default=#A03000 group="Night"
# @config  nrcol  color  "Reading colour"                 default=#702000 group="Night"
# @config  nwtd   color  "Week bar: today"                default=#A03000 group="Night"
# @config  nwod   color  "Week bar: other days"           default=#200800 group="Night"

class GlanceClock
  var url, ticks, busy
  var ts, ds, out, reading, code, day
  var days
  var night, nfrom, nto, col

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
    self.night = nil
    self.nfrom = self.parse_hm(store.get("nfrom"))
    self.nto = self.parse_hm(store.get("nto"))
    self.use_colours(false)
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
      self.ts = (h < 10 ? "0" : "") + str(h) + ":" + (m < 10 ? "0" : "") + str(m)
      self.ds = self.date_text()
      var n = self.is_night(h * 60 + m)
      if n != self.night self.switch_mode(n) end
    end
    if self.ticks <= 0 && !self.busy
      self.ticks = int(store.get("wref")) * 60
      self.busy = true
      http.get(self.url, / b, st -> self.on_wx(b, st), {'find': "\"current\":{", 'keep': 200})
    end
    self.ticks -= 1
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
  # at night every icon takes the night outdoor colour, so nothing glares
  def ic(c)
    return self.night ? self.col[2] : c
  end

  def cloud(x, y, col)
    circle_fill(x + 2, y + 4, 2, col)
    circle_fill(x + 5, y + 3, 2, col)
    rect_fill(x + 1, y + 4, 6, 3, col)
  end

  def sun(x, y, r)
    circle_fill(x, y, r, self.ic(0xFFD000))
  end

  def wicon()
    var c = self.code
    if c < 0
      return
    elif c == 0 || c == 1
      if self.day == 1
        self.sun(3, 3, 2)
        pixel(3, 0, self.ic(0xFFD000)) pixel(3, 6, self.ic(0xFFD000)) pixel(0, 3, self.ic(0xFFD000)) pixel(6, 3, self.ic(0xFFD000))
        pixel(1, 1, self.ic(0xFFD000)) pixel(5, 1, self.ic(0xFFD000)) pixel(1, 5, self.ic(0xFFD000)) pixel(5, 5, self.ic(0xFFD000))
      else
        circle_fill(3, 3, 3, self.ic(0xD0D0A0))
        circle_fill(5, 2, 3, 0x000000)
      end
    elif c == 2
      if self.day == 1 self.sun(5, 2, 2) else circle_fill(5, 2, 2, self.ic(0xD0D0A0)) end
      self.cloud(0, 1, self.ic(0xC0C0C0))
    elif c == 3
      self.cloud(0, 0, self.ic(0x909090))
    elif c == 45 || c == 48
      line(0, 2, 7, 2, self.ic(0x808080)) line(1, 4, 6, 4, self.ic(0x808080)) line(0, 6, 7, 6, self.ic(0x808080))
    elif c >= 71 && c <= 77 || c == 85 || c == 86
      self.cloud(0, -1, self.ic(0xA0A0A0))
      pixel(1, 7, self.ic(0xFFFFFF)) pixel(4, 6, self.ic(0xFFFFFF)) pixel(6, 7, self.ic(0xFFFFFF))
    elif c >= 95
      self.cloud(0, -1, self.ic(0x707070))
      line(4, 5, 3, 6, self.ic(0xFFD000)) line(3, 6, 5, 6, self.ic(0xFFD000)) pixel(4, 7, self.ic(0xFFD000))
    else                          # drizzle and rain: 51-67, 80-82
      self.cloud(0, -1, self.ic(0x8090A0))
      pixel(1, 6, self.ic(0x3080FF)) pixel(4, 7, self.ic(0x3080FF)) pixel(6, 6, self.ic(0x3080FF)) pixel(2, 7, self.ic(0x3080FF))
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

  def draw()
    clear()
    var w = width()
    # right column: time on top, date below, both right-aligned
    text(w - text_ink_width(self.ts) - 1, 6, self.ts, self.col[0])
    text(w - text_ink_width(self.ds) - 1, 14, self.ds, self.col[1])
    # left column: weather icon + outdoor temperature, the MQTT reading below
    if !self.night || store.get("nicon") self.wicon() end
    if self.out != nil text(10, 6, self.out, self.col[2]) end
    if self.reading != nil text(1, 14, self.reading, self.col[3]) end
    if store.get("wbar") self.week_bar(w) end
  end
end

return GlanceClock()
