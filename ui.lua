-- ui.lua - tiny UI kit with autoscale
local ui = {}

function ui.round(x) return math.floor(x + 0.5) end

function ui.getMonitor(side)
  if side then
    local m = peripheral.wrap(side)
    if m and m.isColor and m.isColor() then return m end
  end
  local mons = { peripheral.find("monitor", function(n, p) return p.isColor and p.isColor() end) }
  return mons[1]
end

function ui.init(termLike)
  local t = termLike or term
  local w, h = t.getSize()
  local base = math.min(w / 48, h / 18) -- comfy scaling for typical wall monitors
  local scale = math.max(0.8, math.min(2.5, base))
  return { t = t, w = w, h = h, scale = scale }
end

function ui.cls(ctx, bg, fg)
  local t = ctx.t
  t.setBackgroundColor(bg or colors.black)
  t.setTextColor(fg or colors.white)
  t.clear()
  t.setCursorPos(1,1)
end

function ui.center(ctx, y, text)
  local w = ctx.w
  local x = math.floor((w - #text) / 2) + 1
  term.setCursorPos(math.max(1,x), y)
  term.write(text)
end

function ui.box(x,y,w,h,bg,fg)
  local t = term
  local oldBg, oldFg = t.getBackgroundColor(), t.getTextColor()
  t.setBackgroundColor(bg or colors.gray)
  t.setTextColor(fg or colors.white)
  for i=0,h-1 do
    t.setCursorPos(x, y+i)
    t.write(string.rep(" ", w))
  end
  t.setBackgroundColor(oldBg) t.setTextColor(oldFg)
end

function ui.button(x,y,w,label,active)
  local t = term
  local oldBg, oldFg = t.getBackgroundColor(), t.getTextColor()
  t.setBackgroundColor(active and colors.lime or colors.gray)
  t.setTextColor(colors.black)
  t.setCursorPos(x,y)
  local pad = math.max(0, w - #label)
  local left = math.floor(pad/2)
  t.write(string.rep(" ", left) .. label .. string.rep(" ", pad-left))
  t.setBackgroundColor(oldBg) t.setTextColor(oldFg)
end

function ui.progress(x,y,w,ratio)
  local t = term
  local filled = math.floor(w * math.max(0, math.min(1, ratio)))
  t.setCursorPos(x,y)
  t.write(string.rep("█", filled) .. string.rep(" ", w - filled))
end

function ui.iconWeather(kind)
  if kind == "thunder" then return "⛈"
  elseif kind == "rain" then return "🌧"
  elseif kind == "clear" then return "☀"
  elseif kind == "clouds" then return "☁"
  else return "🌤" end
end

function ui.iconMoon(phase) -- 0..7
  local arr = { "🌑","🌒","🌓","🌔","🌕","🌖","🌗","🌘" }
  return arr[(phase % 8) + 1]
end

return ui
