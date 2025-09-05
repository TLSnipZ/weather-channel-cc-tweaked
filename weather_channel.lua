-- weather_channel.lua (auto-refresh edition)
-- Pretty GUI for the Weather Channel with autoscale + buttons + hotkeys + auto refresh.

-- Import UI helper (kein require-Problem)
local ui = dofile("ui.lua")

local DATA_FILE = "/weather/data.json"

-- Config
local MONITOR_SIDE = nil -- z.B. "right"; nil = auto-find
local THEME = settings.get("wx.theme") or "dark"
local USE_FAHRENHEIT = settings.get("wx.useF") or false
local AUTO_REFRESH_SECS = settings.get("wx.autoRefresh") or 10 -- 🔄 alle 10s

local palette = {
  dark = { bg=colors.black, fg=colors.white, accent=colors.cyan, panel=colors.gray },
  light= { bg=colors.white, fg=colors.black, accent=colors.blue, panel=colors.lightGray },
}

local function c2f(c) return math.floor((c * 9/5) + 32 + 0.5) end
local function fmtTime(hh)
  local h = math.floor(hh)
  local m = math.floor((hh - h) * 60 + 0.5)
  return string.format("%02d:%02d", (h % 24), m)
end

local function draw(ctx, data)
  local p = palette[THEME]
  ui.cls(ctx, p.bg, p.fg)

  -- Header
  term.setTextColor(p.accent)
  ui.center(ctx, 1, "Minecraft Weather Channel")
  term.setTextColor(p.fg)

  local w, h = ctx.w, ctx.h
  local pad = 2
  local colW = math.floor((w - pad*3) / 2)
  local leftX = pad
  local rightX = leftX + colW + pad

  -- Left panel (Now)
  ui.box(leftX, 3, colW, 9, palette[THEME].panel, p.fg)
  term.setCursorPos(leftX+2, 3); term.write("Now")
  local weatherIcon = ui.iconWeather(data.weather)
  local moonIcon = ui.iconMoon(data.moon)
  term.setCursorPos(leftX+2, 4); term.write("Time: "..fmtTime(data.time))
  term.setCursorPos(leftX+2, 5); term.write("Day:  "..data.day.."  Moon: "..moonIcon)
  term.setCursorPos(leftX+2, 6); term.write("Sunrise: "..fmtTime(data.sunrise))
  term.setCursorPos(leftX+2, 7); term.write("Sunset:  "..fmtTime(data.sunset))
  term.setCursorPos(leftX+2, 8); term.write("Weather: "..weatherIcon.."  "..data.weather)
  local tempDisp = USE_FAHRENHEIT and (c2f(data.tempC).."°F") or (data.tempC.."°C")
  term.setCursorPos(leftX+2, 9); term.write("Temp:   "..tempDisp)
  local biome = data.biome or "Unknown"
  term.setCursorPos(leftX+2, 10); term.write("Biome:  "..biome)

  -- Right panel (Forecast)
  ui.box(rightX, 3, colW, 9, palette[THEME].panel, p.fg)
  term.setCursorPos(rightX+2, 3); term.write("3-Day Forecast")
  for i,day in ipairs(data.forecast or {}) do
    local y = 4 + (i-1)*2
    local icon = ui.iconWeather(day.kind)
    local t = USE_FAHRENHEIT and (c2f(day.tempC).."°F") or (day.tempC.."°C")
    term.setCursorPos(rightX+2, y); term.write(string.format("D+%d  %s  %s", day.dayOffset, icon, day.kind))
    term.setCursorPos(rightX+2, y+1); term.write("   Temp ~ "..t)
  end

  -- Footer buttons
  local by = h - 2
  ui.button(pad, by, 12, "[R] Refresh", false)
  ui.button(pad+14, by, 10, "[T] °C/°F", USE_FAHRENHEIT)
  ui.button(pad+26, by, 10, "[L] Theme", THEME=="light")
  ui.button(w-8, by, 7, "[Q]uit", false)

  local autoTxt = (AUTO_REFRESH_SECS and AUTO_REFRESH_SECS > 0) and (AUTO_REFRESH_SECS.."s auto") or "auto off"
  term.setCursorPos(pad, h); term.write("Env: "..(data.hasReal and "Sensor" or "Simulated").." | "..autoTxt)
end

local function readData()
  if not fs.exists(DATA_FILE) then
    return {
      time = os.time(), day=os.day(), moon=0, sunrise=6, sunset=18,
      weather="clear", tempC=18, biome=nil, hasReal=false,
      forecast={}
    }
  end
  local f = fs.open(DATA_FILE, "r"); local s = f.readAll(); f.close()
  local ok, obj = pcall(textutils.unserialize, s)
  if ok and type(obj)=="table" then return obj end
  return { time=os.time(), day=os.day(), moon=0, sunrise=6, sunset=18, weather="clear", tempC=18, hasReal=false, forecast={} }
end

local function attachMonitor()
  local m = ui.getMonitor(MONITOR_SIDE)
  if not m then return nil end
  m.setTextScale(0.5)
  m.setBackgroundColor(colors.black)
  m.clear()
  return m
end

-- MAIN
local mon = attachMonitor()
local restore = false
if mon then term.redirect(mon); restore = true end
local ctx = ui.init(term)

local function refresh()
  local data = readData()
  draw(ctx, data)
end

-- 🔄 Auto-refresh timer handling
local activeTimer = nil
local function armTimer()
  if AUTO_REFRESH_SECS and AUTO_REFRESH_SECS > 0 then
    activeTimer = os.startTimer(AUTO_REFRESH_SECS)
  else
    activeTimer = nil
  end
end

-- initial draw + timer
refresh()
armTimer()

while true do
  local e = { os.pullEvent() }
  local ev = e[1]

  if ev == "timer" then
    local id = e[2]
    if activeTimer and id == activeTimer then
      refresh()
      armTimer()
    end

  elseif ev == "monitor_touch" then
    refresh()

  elseif ev == "key" then
    local key = e[2]
    if key == keys.q then
      break
    elseif key == keys.r then
      refresh(); armTimer()
    elseif key == keys.t then
      USE_FAHRENHEIT = not USE_FAHRENHEIT
      settings.set("wx.useF", USE_FAHRENHEIT); settings.save()
      refresh(); armTimer()
    elseif key == keys.l then
      THEME = (THEME=="dark") and "light" or "dark"
      settings.set("wx.theme", THEME); settings.save()
      refresh(); armTimer()
    end

  elseif ev == "term_resize" then
    ctx = ui.init(term)
    refresh(); armTimer()

  elseif ev == "mouse_click" or ev == "monitor_touch" then
    local x, y = e[3], e[4]
    local w, h = ctx.w, ctx.h
    local pad = 2
    local by = h - 2
    local function inRect(rx, ry, rw, rh)
      return x >= rx and x <= rx+rw-1 and y >= ry and y <= ry+rh-1
    end
    if inRect(pad, by, 12, 1) then
      refresh(); armTimer()
    elseif inRect(pad+14, by, 10, 1) then
      USE_FAHRENHEIT = not USE_FAHRENHEIT
      settings.set("wx.useF", USE_FAHRENHEIT); settings.save()
      refresh(); armTimer()
    elseif inRect(pad+26, by, 10, 1) then
      THEME = (THEME=="dark") and "light" or "dark"
      settings.set("wx.theme", THEME); settings.save()
      refresh(); armTimer()
    elseif inRect(w-8, by, 7, 1) then
      break
    end
  end
end

if restore then term.redirect(term.native()) end
