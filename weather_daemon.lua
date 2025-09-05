-- weather_daemon.lua
-- Collects world time, day, moon, optional real weather/temp/biome via Environment Detector.
-- Writes to /weather/data.json every few seconds.

local json = textutils
local DATA_PATH = "/weather"
local FILE = DATA_PATH .. "/data.json"
local INTERVAL = 5 -- seconds

-- Try find peripherals
local env = peripheral.find("environmentDetector") -- Advanced Peripherals (optional)

-- Helpers
local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function mcTime()
  -- os.time(): 0..24; os.day(): day #
  return os.time(), os.day()
end

local function moonPhase(day)
  return (day % 8)
end

local function sunriseSunset(daytime)
  -- Approx vanilla day: 06:00 - 18:00
  return 6.0, 18.0
end

local function tempFromBiome(biome)
  if not biome then return 20 end
  biome = string.lower(biome)
  if biome:find("desert") or biome:find("badlands") or biome:find("savanna") then return 35
  elseif biome:find("snow") or biome:find("ice") then return -2
  elseif biome:find("taiga") then return 6
  elseif biome:find("jungle") then return 28
  elseif biome:find("swamp") then return 24
  elseif biome:find("plains") or biome:find("forest") then return 18
  else return 16 end
end

local function forecastSeed(day, biome)
  local b = biome or "unknown"
  return (day * 131) + (#b * 97)
end

local function seededRand(seed)
  local state = seed
  return function(min, max)
    state = (state * 1103515245 + 12345) % 2^31
    local r = state / 2^31
    if min and max then return math.floor(min + r * (max - min + 1)) end
    return r
  end
end

local function mkForecast(day, biome, baseTemp, hasReal)
  local seed = forecastSeed(day, biome)
  local rnd = seededRand(seed)
  local out = {}
  local weatherKinds = { "clear","clear","clouds","rain","clear","rain","clear","thunder" }
  for i=1,3 do
    local k = weatherKinds[rnd(1, #weatherKinds)]
    local tShift = ({clear=2, clouds=0, rain=-3, thunder=-4})[k] or 0
    local t = baseTemp + tShift + rnd(-1,2)
    if hasReal then t = math.floor((baseTemp*2 + t)/3) end
    table.insert(out, { dayOffset = i, kind = k, tempC = t })
  end
  return out
end

local function readSensors()
  local data = {}
  local time24, day = mcTime()
  data.time = time24
  data.day = day
  data.moon = moonPhase(day)
  local sr, ss = sunriseSunset(time24)
  data.sunrise = sr
  data.sunset = ss

  data.biome = nil
  data.tempC = nil
  data.weather = "clear"
  data.hasReal = false

  if env then
    local okB, biome = pcall(env.getBiome)
    if okB and biome and biome ~= "" then data.biome = biome end

    local okT, temp = pcall(env.getTemperature)
    if okT and type(temp) == "number" then
      if temp > 80 then temp = temp - 273.15 end -- Kelvin → °C fallback
      data.tempC = math.floor(temp+0.5)
      data.hasReal = true
    end

    local okR, rain = pcall(env.isRaining)
    local okTh, th = pcall(env.isThundering)
    if okR and rain then data.weather = "rain" end
    if okTh and th then data.weather = "thunder" end
  end

  if not data.tempC then
    data.tempC = tempFromBiome(data.biome)
  end

  data.forecast = mkForecast(day, data.biome, data.tempC, data.hasReal)
  return data
end

ensureDir(DATA_PATH)
while true do
  local payload = readSensors()
  local f = fs.open(FILE, "w")
  f.write(json.serialize(payload))
  f.close()
  sleep(INTERVAL)
end
