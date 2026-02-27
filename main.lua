local GAME_W = 1280
local GAME_H = 720
local TWO_PI = math.pi * 2
local LIGHT_X = 24
local LIGHT_Y = GAME_H - 24
local LIGHT_Z = 22
local ORBIT_CONFIGS = {
  megaPlanet = {
    bandCapacity = 1,
    baseRadius = 440,
    bandStep = 90,
    fixedAltitude = true,
    tiltMin = 0.24,
    tiltRange = 0.5,
    speedMin = 0.08,
    speedRange = 0.04,
  },
  planet = {
    bandCapacity = 2,
    baseRadius = 180,
    bandStep = 56,
    fixedAltitude = true,
    tiltMin = 0.28,
    tiltRange = 0.9,
    speedMin = 0.16,
    speedRange = 0.08,
  },
  moon = {
    bandCapacity = 4,
    baseRadius = 100,
    bandStep = 34,
    fixedAltitude = true,
    tiltMin = 0.35,
    tiltRange = 1.1,
    speedMin = 0.42,
    speedRange = 0.15,
  },
  satellite = {
    bandCapacity = 6,
    baseRadius = 40,
    bandStep = 8,
    fixedAltitude = true,
    tiltMin = 0.30,
    tiltRange = 1.2,
    speedMin = 0.70,
    speedRange = 0.20,
  },
  moonChildSatellite = {
    bandCapacity = 4,
    baseRadius = 10,
    bandStep = 2.0,
    tiltMin = 0.30,
    tiltRange = 1.2,
    speedMin = 0.90,
    speedRange = 0.55,
  },
}
local BODY_VISUAL = {
  planetRadius = 30,
  orbitPlanetRadius = 24,
  megaPlanetRadius = 150,
  moonRadius = 10,
  satelliteRadius = 4,
  moonChildSatelliteRadius = 1.8,
}
local PLANET_IMPULSE_MULTIPLIER = 2
local PLANET_IMPULSE_TARGET_BOOST = PLANET_IMPULSE_MULTIPLIER - 1
local PLANET_IMPULSE_DURATION = 10
local PLANET_IMPULSE_RISE_RATE = 4.5
local PLANET_IMPULSE_FALL_RATE = 6.5
local PLANET_BOUNCE_DURATION = 0.12
local SPEED_WAVE_COST = 25
local SPEED_CLICK_COST = 15
local SPEED_WAVE_CLICK_THRESHOLD = 10
local SPEED_WAVE_MULTIPLIER = 1.5
local SPEED_WAVE_DURATION = 5
local SPEED_WAVE_RIPPLE_LIFETIME = 1.1
local SPEED_WAVE_RIPPLE_MAX_RADIUS = 120
local SPEED_WAVE_TEXT_LIFETIME = 0.6
local ORBIT_POP_LIFETIME = 1.44
local PLANET_COLOR_CYCLE_SECONDS = 30
local ORBIT_ICON_CYCLE_SECONDS = 1.8
local ORBIT_ICON_FLATTEN = 0.84
local ORBIT_ICON_SIZE = 6
local UI_FONT_SIZE = 24
local MOON_COST = 50
local PLANET_COST = 1000
local MEGA_PLANET_COST = 5000
local SATELLITE_COST = 5
local MOON_SATELLITE_COST = 10
local MAX_MOONS = 5
local MAX_SATELLITES = 20
local BG_MUSIC_VOLUME = 0.72
local BG_MUSIC_LOOP_FADE_SECONDS = 0.28
local BG_MUSIC_DUCK_SECONDS = 0.22
local BG_MUSIC_DUCK_GAIN = 0.42
local UPGRADE_FX_VOLUME = 0.9
local UPGRADE_FX_FADE_IN_SECONDS = 0.03
local UPGRADE_FX_START_OFFSET_SECONDS = 0.008
local CLICK_FX_VOLUME_OPEN = 0.50
local CLICK_FX_VOLUME_CLOSE = 0.43
local CLICK_FX_PITCH_OPEN = 1.0
local CLICK_FX_PITCH_CLOSE = 0.88
local CLICK_FX_MENU_PITCH_MIN = 0.92
local CLICK_FX_MENU_PITCH_MAX = 1.08
local SELECTED_ORBIT_COLOR = {1.0000, 0.5098, 0.4549, 1}

local canvas
local uiFont
local uiScreenFont
local uiScreenFontSize = 0
local orbitCounterFont
local orbitCounterFontSize = 0
local bgMusic
local bgMusicFirstPass = false
local bgMusicPrevPos = 0
local bgMusicDuckTimer = 0
local upgradeFx
local upgradeFxInstances = {}
local clickFx
local scale = 1
local offsetX = 0
local offsetY = 0
local zoom = 1

local cx = math.floor(GAME_W / 2)
local cy = math.floor(GAME_H / 2)

local swatch = {
  brightest = {1.0000, 0.5098, 0.4549, 1}, -- #ff8274
  bright = {0.8353, 0.2353, 0.4157, 1},    -- #d53c6a
  mid = {0.4863, 0.0941, 0.2353, 1},       -- #7c183c
  dim = {0.2745, 0.0549, 0.1686, 1},       -- #460e2b
  dimmest = {0.1922, 0.0196, 0.1176, 1},   -- #31051e
  nearDark = {0.1216, 0.0196, 0.0627, 1},  -- #1f0510
  darkest = {0.0745, 0.0078, 0.0314, 1},   -- #130208
}

local palette = {
  space = swatch.darkest,
  nebulaA = swatch.nearDark,
  nebulaB = swatch.dimmest,
  starA = swatch.mid,
  starB = swatch.brightest,
  orbit = swatch.dim,
  panel = swatch.brightest,
  panelEdge = swatch.brightest,
  text = swatch.brightest,
  muted = swatch.brightest,
  accent = swatch.mid,
  planetCore = swatch.mid,
  planetDark = swatch.dimmest,
  planetMid = swatch.dim,
  planetLight = swatch.brightest,
  moonFront = swatch.brightest,
  moonBack = swatch.mid,
  satelliteFront = swatch.brightest,
  satelliteBack = swatch.dim,
  trail = {swatch.bright[1], swatch.bright[2], swatch.bright[3], 0.35},
  satelliteTrail = {swatch.mid[1], swatch.mid[2], swatch.mid[3], 0.35},
}
local paletteSwatches = {
  swatch.brightest,
  swatch.bright,
  swatch.mid,
  swatch.dim,
  swatch.dimmest,
  swatch.nearDark,
  swatch.darkest,
}
local orbitColorCycle = {
  swatch.brightest,
  swatch.bright,
  swatch.mid,
  swatch.dim,
  swatch.dimmest,
}

local state = {
  orbits = 10000,
  megaPlanets = {},
  planets = {},
  moons = {},
  satellites = {},
  stars = {},
  time = 0,
  selectedOrbiter = nil,
  borderlessFullscreen = false,
  orbitPopTexts = {},
  planetBounceTime = 0,
  speedWaveUnlocked = false,
  speedClickUnlocked = false,
  planetClickCount = 0,
  speedWaveTimer = 0,
  speedWaveRipples = {},
  speedWaveText = nil,
}

local ui = {
  buyMegaPlanetBtn = {x = 0, y = 0, w = 0, h = 0},
  buyPlanetBtn = {x = 0, y = 0, w = 0, h = 0},
  buyMoonBtn = {x = 0, y = 0, w = 0, h = 0},
  buySatelliteBtn = {x = 0, y = 0, w = 0, h = 0},
  speedWaveBtn = {x = 0, y = 0, w = 0, h = 0},
  speedClickBtn = {x = 0, y = 0, w = 0, h = 0},
  moonAddSatelliteBtn = {x = 0, y = 0, w = 0, h = 0, visible = false, enabled = false},
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function smoothstep(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function pointInRect(px, py, rect)
  return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function depthLight(z, ambient, intensity, x, y)
  local t = clamp((z + 1) * 0.5, 0, 1)
  local progressiveBlend = t * 0.55 + smoothstep(t) * 0.45
  local pointBlend = 1
  if x and y then
    local dx = LIGHT_X - x
    local dy = LIGHT_Y - y
    local dz = LIGHT_Z - z
    local distSq = dx * dx + dy * dy + dz * dz
    pointBlend = 1 / (1 + distSq / 220000)
  end
  return clamp(ambient + progressiveBlend * intensity * pointBlend, 0, 1.25)
end

local function nearestPaletteSwatch(r, g, b)
  local best = paletteSwatches[1]
  local bestDist = math.huge
  for i = 1, #paletteSwatches do
    local p = paletteSwatches[i]
    local dr = r - p[1]
    local dg = g - p[2]
    local db = b - p[3]
    local dist = dr * dr + dg * dg + db * db
    if dist < bestDist then
      bestDist = dist
      best = p
    end
  end
  return best
end

local function setColorScaled(color, lightScale, alphaScale)
  local light = lightScale or 1
  local alpha = alphaScale or 1
  local sr = clamp(color[1] * light, 0, 1)
  local sg = clamp(color[2] * light, 0, 1)
  local sb = clamp(color[3] * light, 0, 1)
  local sw = nearestPaletteSwatch(sr, sg, sb)
  love.graphics.setColor(
    sw[1],
    sw[2],
    sw[3],
    clamp((color[4] or 1) * alpha, 0, 1)
  )
end

local function setColorBlendScaled(colorA, colorB, blend, lightScale, alphaScale)
  local t = clamp(blend or 0, 0, 1)
  local light = lightScale or 1
  local alpha = alphaScale or 1
  local r = lerp(colorA[1], colorB[1], t)
  local g = lerp(colorA[2], colorB[2], t)
  local b = lerp(colorA[3], colorB[3], t)
  local a = lerp(colorA[4] or 1, colorB[4] or 1, t)
  local sr = clamp(r * light, 0, 1)
  local sg = clamp(g * light, 0, 1)
  local sb = clamp(b * light, 0, 1)
  local sw = nearestPaletteSwatch(sr, sg, sb)
  love.graphics.setColor(
    sw[1],
    sw[2],
    sw[3],
    clamp(a * alpha, 0, 1)
  )
end

local function setOrbiterShadedColor(backColor, sideBlend, light, alphaScale)
  local faceBlend = clamp(sideBlend or 0, 0, 1)
  local lightBlend = smoothstep(clamp(light or 0, 0, 1))
  local blend = clamp(faceBlend * 0.68 + lightBlend * 0.32, 0, 1)
  -- Orbiters always peak at the brightest swatch color.
  setColorBlendScaled(backColor, palette.planetLight, blend, 1, alphaScale or 1)
end

local function sampleOrbitColorCycle(phase)
  local size = #orbitColorCycle
  local p = phase - math.floor(phase)
  local pingPong = 1 - math.abs(2 * p - 1)
  local scaled = pingPong * (size - 1)
  local i = math.floor(scaled) + 1
  local localT = scaled - math.floor(scaled)
  local a = orbitColorCycle[i]
  local b = orbitColorCycle[math.min(i + 1, size)]
  return lerp(a[1], b[1], localT), lerp(a[2], b[2], localT), lerp(a[3], b[3], localT)
end

local function currentPlanetColor()
  return sampleOrbitColorCycle(state.time / PLANET_COLOR_CYCLE_SECONDS)
end

local function computeOrbiterColor(angle)
  return sampleOrbitColorCycle(angle / TWO_PI)
end

local function setColorDirect(r, g, b, alpha)
  love.graphics.setColor(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1), clamp(alpha or 1, 0, 1))
end

local function drawText(text, x, y)
  love.graphics.print(text, math.floor(x + 0.5), math.floor(y + 0.5))
end

local function drawOrbitIcon(x, y, size, alphaScale)
  local r = math.max(5, size or ORBIT_ICON_SIZE)
  local alpha = clamp(alphaScale or 1, 0, 1)
  local orbitR = r
  local bodyR = math.max(2, math.floor(r * 0.34 + 0.5))
  local orbitRY = orbitR * ORBIT_ICON_FLATTEN
  local angle = (state.time / ORBIT_ICON_CYCLE_SECONDS) * TWO_PI
  local bx = x + math.cos(angle) * orbitR
  local by = y + math.sin(angle) * orbitRY

  -- Same trail mechanism as gameplay orbiters: segmented arc with fading alpha.
  local radius = math.max(orbitR, 1)
  local trailLen = radius * 6.2
  local arcAngle = trailLen / radius
  local stepCount = math.max(6, math.ceil(arcAngle / 0.06))
  local stepAngle = arcAngle / stepCount
  local prevX, prevY
  for i = 0, stepCount do
    local a = angle - stepAngle * i
    local tx = x + math.cos(a) * orbitR
    local ty = y + math.sin(a) * orbitRY
    if prevX then
      local t = i / stepCount
      local segAlpha = lerp(0.55, 0.03, t) * alpha
      setColorScaled(swatch.bright, 1, segAlpha)
      love.graphics.line(prevX, prevY, tx, ty)
    end
    prevX, prevY = tx, ty
  end

  setColorScaled(swatch.brightest, 1, alpha)
  love.graphics.circle("fill", bx, by, bodyR, 12)
end

local function spawnOrbitGainFx(x, y, count, bodyRadius)
  count = math.max(1, count or 1)
  local verticalOffset = (bodyRadius or 0) + 8
  for i = 1, count do
    local n = #state.orbitPopTexts + 1
    local spread = (i - (count + 1) * 0.5)
    state.orbitPopTexts[n] = {
      x = x + spread * 3.5,
      y = y - verticalOffset,
      vx = spread * 10,
      vy = -17 - love.math.random() * 6,
      age = 0,
      life = ORBIT_POP_LIFETIME,
      text = "+1",
    }
  end
end

local function updateOrbitGainFx(dt)
  local texts = state.orbitPopTexts
  for i = #texts, 1, -1 do
    local pop = texts[i]
    pop.age = pop.age + dt
    local t = pop.age / pop.life
    if t >= 1 then
      table.remove(texts, i)
    else
      pop.x = pop.x + pop.vx * dt
      pop.y = pop.y + pop.vy * dt
      pop.vy = pop.vy - 7 * dt
      pop.vx = pop.vx * (1 - math.min(1, dt * 2.4))
    end
  end
end

local function drawOrbitGainFx()
  for _, pop in ipairs(state.orbitPopTexts) do
    local t = clamp(pop.age / pop.life, 0, 1)
    local fade = 1 - smoothstep(t)
    local drawX = (pop.x - cx) * zoom + cx
    local drawY = (pop.y - cy) * zoom + cy
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], fade)
    drawText(pop.text, drawX, drawY)
  end
end

local function moonCost()
  return MOON_COST
end

local function planetCost()
  return PLANET_COST
end

local function megaPlanetCost()
  return MEGA_PLANET_COST
end

local function satelliteCost()
  return SATELLITE_COST
end

local function moonSatelliteCost()
  return MOON_SATELLITE_COST
end

local function speedWaveCost()
  return SPEED_WAVE_COST
end

local function speedClickCost()
  return SPEED_CLICK_COST
end

local function createOrbitalParams(config, index)
  local band = config.fixedAltitude and 0 or math.floor(index / config.bandCapacity)
  local radiusJitter = config.fixedAltitude and 0 or (love.math.random() * 2 - 1)
  local tilt = config.tiltMin + love.math.random() * config.tiltRange
  return {
    angle = love.math.random() * math.pi * 2,
    radius = config.baseRadius + band * config.bandStep + radiusJitter,
    flatten = math.cos(tilt),
    depthScale = math.sin(tilt),
    plane = love.math.random() * math.pi * 2,
    speed = config.speedMin + love.math.random() * config.speedRange,
  }
end

local function recomputeViewport()
  local w, h = love.graphics.getDimensions()
  local rawScale = math.min(w / GAME_W, h / GAME_H)
  if rawScale >= 1 then
    scale = math.max(1, math.floor(rawScale + 1e-6))
  else
    -- Use reciprocal integer downscale steps (1/2, 1/3, ...) to avoid soft sampling.
    local denom = math.max(1, math.ceil((1 / rawScale) - 1e-6))
    scale = 1 / denom
  end
  local drawW = GAME_W * scale
  local drawH = GAME_H * scale
  offsetX = math.floor((w - drawW) / 2)
  offsetY = math.floor((h - drawH) / 2)
end

local function setBorderlessFullscreen(enabled)
  state.borderlessFullscreen = enabled
  if enabled then
    love.window.setMode(0, 0, {
      fullscreen = true,
      fullscreentype = "desktop",
      borderless = true,
      resizable = true,
      vsync = 1,
      minwidth = 960,
      minheight = 540,
    })
  else
    love.window.setMode(1280, 720, {
      fullscreen = false,
      borderless = false,
      resizable = true,
      vsync = 1,
      minwidth = 960,
      minheight = 540,
    })
  end
  recomputeViewport()
end

local function toGameSpace(mx, my)
  return (mx - offsetX) / scale, (my - offsetY) / scale
end

local function toWorldSpace(mx, my)
  local gx, gy = toGameSpace(mx, my)
  return (gx - cx) / zoom + cx, (gy - cy) / zoom + cy
end

local function toScreenSpace(gx, gy)
  return offsetX + gx * scale, offsetY + gy * scale
end

local function getUiScreenFont()
  local uiScale = scale >= 1 and scale or 1
  local size = math.max(1, math.floor(UI_FONT_SIZE * uiScale + 0.5))
  if not uiScreenFont or uiScreenFontSize ~= size then
    uiScreenFont = love.graphics.newFont("font_gothic.ttf", size, "mono")
    uiScreenFont:setFilter("nearest", "nearest")
    uiScreenFontSize = size
  end
  return uiScreenFont
end

local function getOrbitCounterFont()
  local uiScale = scale >= 1 and scale or 1
  local size = math.max(1, math.floor(UI_FONT_SIZE * uiScale * 1.65 + 0.5))
  if not orbitCounterFont or orbitCounterFontSize ~= size then
    orbitCounterFont = love.graphics.newFont("font_gothic.ttf", size, "mono")
    orbitCounterFont:setFilter("nearest", "nearest")
    orbitCounterFontSize = size
  end
  return orbitCounterFont
end

local updateOrbiterPosition

local function addMegaPlanet()
  local cost = megaPlanetCost()
  if state.orbits < cost then
    return false
  end

  state.orbits = state.orbits - cost

  local megaPlanetIndex = #state.megaPlanets
  local orbital = createOrbitalParams(ORBIT_CONFIGS.megaPlanet, megaPlanetIndex)
  local megaPlanet = {
    angle = orbital.angle,
    radius = orbital.radius,
    flatten = orbital.flatten,
    depthScale = orbital.depthScale,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    kind = "mega-planet",
    revolutions = 0,
  }

  updateOrbiterPosition(megaPlanet)
  table.insert(state.megaPlanets, megaPlanet)
  return true
end

local function addPlanet()
  local cost = planetCost()
  if state.orbits < cost then
    return false
  end

  state.orbits = state.orbits - cost

  local planetIndex = #state.planets
  local orbital = createOrbitalParams(ORBIT_CONFIGS.planet, planetIndex)
  local planet = {
    angle = orbital.angle,
    radius = orbital.radius,
    flatten = orbital.flatten,
    depthScale = orbital.depthScale,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    kind = "planet",
    revolutions = 0,
  }

  updateOrbiterPosition(planet)
  table.insert(state.planets, planet)
  return true
end

local function addMoon()
  if #state.moons >= MAX_MOONS then
    return false
  end

  local cost = moonCost()
  if state.orbits < cost then
    return false
  end

  state.orbits = state.orbits - cost

  local moonIndex = #state.moons
  local orbital = createOrbitalParams(ORBIT_CONFIGS.moon, moonIndex)
  local moon = {
    angle = orbital.angle,
    radius = orbital.radius,
    flatten = orbital.flatten,
    depthScale = orbital.depthScale,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    kind = "moon",
    revolutions = 0,
    childSatellites = {},
  }

  updateOrbiterPosition(moon)
  table.insert(state.moons, moon)
  return true
end

local function addSatellite()
  if #state.satellites >= MAX_SATELLITES then
    return false
  end

  local cost = satelliteCost()
  if state.orbits < cost then
    return false
  end

  state.orbits = state.orbits - cost

  local satIndex = #state.satellites
  local orbital = createOrbitalParams(ORBIT_CONFIGS.satellite, satIndex)
  local satellite = {
    angle = orbital.angle,
    radius = orbital.radius,
    flatten = orbital.flatten,
    depthScale = orbital.depthScale,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    kind = "satellite",
    revolutions = 0,
  }

  updateOrbiterPosition(satellite)
  table.insert(state.satellites, satellite)
  return true
end

local function addSatelliteToMoon(moon)
  if not moon or moon.kind ~= "moon" then
    return false
  end

  local cost = moonSatelliteCost()
  if state.orbits < cost then
    return false
  end

  state.orbits = state.orbits - cost

  moon.childSatellites = moon.childSatellites or {}
  local childIndex = #moon.childSatellites
  local orbital = createOrbitalParams(ORBIT_CONFIGS.moonChildSatellite, childIndex)
  local child = {
    angle = orbital.angle,
    radius = orbital.radius,
    flatten = orbital.flatten,
    depthScale = orbital.depthScale,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = moon.x,
    y = moon.y,
    z = 0,
    kind = "moon-satellite",
    revolutions = 0,
  }
  local cp = math.cos(child.plane)
  local sp = math.sin(child.plane)
  local ox = math.cos(child.angle) * child.radius
  local oy = math.sin(child.angle) * child.radius * child.flatten
  child.x = moon.x + ox * cp - oy * sp
  child.y = moon.y + ox * sp + oy * cp
  child.z = moon.z + math.sin(child.angle) * (child.depthScale or 1)
  table.insert(moon.childSatellites, child)
  return true
end

updateOrbiterPosition = function(orbiter)
  local ox = math.cos(orbiter.angle) * orbiter.radius
  local oy = math.sin(orbiter.angle) * orbiter.radius * orbiter.flatten

  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)

  orbiter.x = cx + ox * cp - oy * sp
  orbiter.y = cy + ox * sp + oy * cp
  orbiter.z = math.sin(orbiter.angle) * (orbiter.depthScale or 1)
end

local function updateOrbiterBoost(orbiter, dt)
  local durations = orbiter.boostDurations or {}
  for i = #durations, 1, -1 do
    durations[i] = durations[i] - dt
    if durations[i] <= 0 then
      table.remove(durations, i)
    end
  end
  orbiter.boostDurations = durations

  local activeStacks = #durations
  local targetBoost = activeStacks * PLANET_IMPULSE_TARGET_BOOST
  local blendRate = activeStacks > 0 and PLANET_IMPULSE_RISE_RATE or PLANET_IMPULSE_FALL_RATE
  local blend = math.min(1, dt * blendRate)
  orbiter.boost = orbiter.boost + (targetBoost - orbiter.boost) * blend

  if activeStacks == 0 and orbiter.boost < 0.001 then
    orbiter.boost = 0
  end
end

local function pickPlanetImpulseTarget()
  local pool = {}
  for _, megaPlanet in ipairs(state.megaPlanets) do
    table.insert(pool, megaPlanet)
  end
  for _, planet in ipairs(state.planets) do
    table.insert(pool, planet)
  end
  for _, moon in ipairs(state.moons) do
    table.insert(pool, moon)
    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      table.insert(pool, child)
    end
  end
  for _, satellite in ipairs(state.satellites) do
    table.insert(pool, satellite)
  end

  if #pool == 0 then
    return nil
  end

  return pool[love.math.random(1, #pool)]
end

local function triggerPlanetImpulse()
  local target = pickPlanetImpulseTarget()
  if not target then
    return false
  end

  target.boostDurations = target.boostDurations or {}
  table.insert(target.boostDurations, PLANET_IMPULSE_DURATION)
  return true
end

local function spawnModifierRipple()
  state.speedWaveRipples[#state.speedWaveRipples + 1] = {
    age = 0,
    life = SPEED_WAVE_RIPPLE_LIFETIME,
  }
end

local function speedWaveBoostFor(orbiter)
  if state.speedWaveTimer <= 0 then
    return 0
  end
  if not orbiter then
    return 0
  end
  if orbiter.kind == "satellite" or orbiter.kind == "moon-satellite" then
    return SPEED_WAVE_MULTIPLIER - 1
  end
  return 0
end

local function triggerSpeedWave()
  state.speedWaveTimer = SPEED_WAVE_DURATION
  spawnModifierRipple()
  local mx, my = love.mouse.getPosition()
  state.speedWaveText = {
    x = mx,
    y = my,
    age = 0,
    life = SPEED_WAVE_TEXT_LIFETIME,
  }
end

local function buySpeedWave()
  if state.speedWaveUnlocked then
    return false
  end
  local cost = speedWaveCost()
  if state.orbits < cost then
    return false
  end
  state.orbits = state.orbits - cost
  state.speedWaveUnlocked = true
  state.planetClickCount = 0
  if upgradeFx then
    local voice = upgradeFx:clone()
    voice:setVolume(0)
    local duration = voice:getDuration("seconds") or 0
    if duration > UPGRADE_FX_START_OFFSET_SECONDS then
      voice:seek(UPGRADE_FX_START_OFFSET_SECONDS, "seconds")
    end
    voice:play()
    upgradeFxInstances[#upgradeFxInstances + 1] = {source = voice, age = 0}
    bgMusicDuckTimer = BG_MUSIC_DUCK_SECONDS
  end
  return true
end

local function buySpeedClick()
  if state.speedClickUnlocked then
    return false
  end
  local cost = speedClickCost()
  if state.orbits < cost then
    return false
  end
  state.orbits = state.orbits - cost
  state.speedClickUnlocked = true
  if upgradeFx then
    local voice = upgradeFx:clone()
    voice:setVolume(0)
    local duration = voice:getDuration("seconds") or 0
    if duration > UPGRADE_FX_START_OFFSET_SECONDS then
      voice:seek(UPGRADE_FX_START_OFFSET_SECONDS, "seconds")
    end
    voice:play()
    upgradeFxInstances[#upgradeFxInstances + 1] = {source = voice, age = 0}
    bgMusicDuckTimer = BG_MUSIC_DUCK_SECONDS
  end
  return true
end

local function onPlanetClicked()
  state.planetBounceTime = PLANET_BOUNCE_DURATION
  if state.speedClickUnlocked then
    triggerPlanetImpulse()
  end
  if not state.speedWaveUnlocked then
    return
  end
  state.planetClickCount = state.planetClickCount + 1
  if state.planetClickCount % SPEED_WAVE_CLICK_THRESHOLD == 0 then
    triggerSpeedWave()
  end
end

local function drawCircle(x, y, r, color, lightScale, alphaScale)
  setColorScaled(color, lightScale, alphaScale)
  love.graphics.circle("fill", x, y, r, 18)
end

local function drawBackground()
  love.graphics.clear(palette.space)

  for _, s in ipairs(state.stars) do
    local twinkle = (math.sin(state.time * s.speed + s.phase) + 1) * 0.5
    if twinkle > 0.45 then
      if s.kind == 0 then
        love.graphics.setColor(palette.starA)
      else
        love.graphics.setColor(palette.starB)
      end
      love.graphics.rectangle("fill", s.x, s.y, 1, 1)
    end
  end
end

local function drawSelectedOrbit(frontPass)
  local orbiter = state.selectedOrbiter
  if not orbiter then
    return
  end
  local function drawOrbitPath(target, originX, originY, zOffset)
    local cp = math.cos(target.plane)
    local sp = math.sin(target.plane)
    local px, py, pz
    for a = 0, math.pi * 2 + 0.14, 0.14 do
      local ox = math.cos(a) * target.radius
      local oy = math.sin(a) * target.radius * target.flatten
      local x = originX + ox * cp - oy * sp
      local y = originY + ox * sp + oy * cp
      local z = zOffset + math.sin(a) * (target.depthScale or 1)
      if px then
        local segZ = (pz + z) * 0.5
        if (frontPass and segZ > 0) or ((not frontPass) and segZ <= 0) then
          setColorDirect(SELECTED_ORBIT_COLOR[1], SELECTED_ORBIT_COLOR[2], SELECTED_ORBIT_COLOR[3], 0.84)
          love.graphics.line(math.floor(px + 0.5), math.floor(py + 0.5), math.floor(x + 0.5), math.floor(y + 0.5))
        end
      end
      px, py, pz = x, y, z
    end
  end

  love.graphics.setLineWidth(1)
  drawOrbitPath(orbiter, cx, cy, 0)
end

local function drawPlanet()
  local r, g, b = currentPlanetColor()
  local t = 1 - clamp(state.planetBounceTime / PLANET_BOUNCE_DURATION, 0, 1)
  local kick = math.sin(t * math.pi)
  local bounceScale = 1 + kick * 0.14 * (1 - t)
  setColorDirect(r, g, b, 1)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(bounceScale, bounceScale)
  love.graphics.translate(-cx, -cy)
  love.graphics.circle("fill", cx, cy, BODY_VISUAL.planetRadius, 36)
  love.graphics.pop()
end

local function drawSpeedWaveRipples()
  local ripples = state.speedWaveRipples
  for i = 1, #ripples do
    local ripple = ripples[i]
    local t = clamp(ripple.age / ripple.life, 0, 1)
    local radius = BODY_VISUAL.planetRadius + t * SPEED_WAVE_RIPPLE_MAX_RADIUS
    local alpha = (1 - smoothstep(t)) * 0.9
    local brightness = 1 - t
    setColorBlendScaled(swatch.brightest, swatch.dim, 1 - brightness, 1, alpha)
    love.graphics.setLineWidth(2 - t * 0.8)
    love.graphics.circle("line", cx, cy, radius, 64)
  end
  love.graphics.setLineWidth(1)
end

local function drawOrbitalTrail(orbiter, trailLen, headAlpha, tailAlpha, originX, originY)
  local radius = math.max(orbiter.radius, 1)
  local arcAngle = trailLen / radius
  local stepCount = math.max(4, math.ceil(arcAngle / 0.06))
  local stepAngle = arcAngle / stepCount
  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)
  local prevX, prevY
  local centerX = originX or cx
  local centerY = originY or cy

  for i = 0, stepCount do
    local a = orbiter.angle - stepAngle * i
    local ox = math.cos(a) * orbiter.radius
    local oy = math.sin(a) * orbiter.radius * orbiter.flatten
    local x = centerX + ox * cp - oy * sp
    local y = centerY + ox * sp + oy * cp
    if prevX then
      local t = i / stepCount
      local alpha = lerp(headAlpha or 0.35, tailAlpha or 0.02, t)
      local midAngle = a + stepAngle * 0.5
      local r, g, b = computeOrbiterColor(midAngle)
      setColorDirect(r, g, b, alpha)
      love.graphics.line(prevX, prevY, x, y)
    end
    prevX, prevY = x, y
  end
end

local function hasActiveBoost(orbiter)
  if not orbiter then
    return false
  end
  if orbiter.boostDurations and #orbiter.boostDurations > 0 then
    return true
  end
  return speedWaveBoostFor(orbiter) > 0
end

local function drawMoon(moon)
  local function drawChildOrbitPath(child, frontPass)
    local pr, pg, pb = computeOrbiterColor(child.angle)
    local cp = math.cos(child.plane)
    local sp = math.sin(child.plane)
    local px, py, pz
    for a = 0, math.pi * 2 + 0.14, 0.14 do
      local ox = math.cos(a) * child.radius
      local oy = math.sin(a) * child.radius * child.flatten
      local x = moon.x + ox * cp - oy * sp
      local y = moon.y + ox * sp + oy * cp
      local z = moon.z + math.sin(a) * (child.depthScale or 1)
      if px then
        local segZ = (pz + z) * 0.5
        if (frontPass and segZ > moon.z) or ((not frontPass) and segZ <= moon.z) then
          setColorDirect(pr, pg, pb, 0.52)
          love.graphics.line(math.floor(px + 0.5), math.floor(py + 0.5), math.floor(x + 0.5), math.floor(y + 0.5))
        end
      end
      px, py, pz = x, y, z
    end
  end

  if hasActiveBoost(moon) then
    local baseTrailLen = math.min(moon.radius * 2.2, 20 + moon.boost * 28)
    drawOrbitalTrail(moon, baseTrailLen, 0.48, 0.03)
  end

  local childSatellites = moon.childSatellites or {}
  local showChildOrbitPaths = state.selectedOrbiter == moon
  love.graphics.setLineWidth(1)
  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, false)
    end
  end

  local function drawChild(child)
    if hasActiveBoost(child) then
      local baseTrailLen = math.min(child.radius * 2.2, 16 + child.boost * 22)
      drawOrbitalTrail(child, baseTrailLen, 0.44, 0.02, moon.x, moon.y)
    end
    local childR, childG, childB = computeOrbiterColor(child.angle)
    setColorDirect(childR, childG, childB, 1)
    love.graphics.circle("fill", child.x, child.y, BODY_VISUAL.moonChildSatelliteRadius, 12)
  end

  for _, child in ipairs(childSatellites) do
    if child.z <= moon.z then
      drawChild(child)
    end
  end

  local moonR, moonG, moonB = computeOrbiterColor(moon.angle)
  setColorDirect(moonR, moonG, moonB, 1)
  love.graphics.circle("fill", moon.x, moon.y, BODY_VISUAL.moonRadius, 18)

  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, true)
    end
  end

  for _, child in ipairs(childSatellites) do
    if child.z > moon.z then
      drawChild(child)
    end
  end
end

local function drawOrbitPlanet(planet)
  if hasActiveBoost(planet) then
    local baseTrailLen = math.min(planet.radius * 2.2, 28 + planet.boost * 36)
    drawOrbitalTrail(planet, baseTrailLen, 0.5, 0.04)
  end
  local pr, pg, pb = computeOrbiterColor(planet.angle)
  setColorDirect(pr, pg, pb, 1)
  love.graphics.circle("fill", planet.x, planet.y, BODY_VISUAL.orbitPlanetRadius, 22)
end

local function drawMegaPlanet(megaPlanet)
  if hasActiveBoost(megaPlanet) then
    local baseTrailLen = math.min(megaPlanet.radius * 2.2, 36 + megaPlanet.boost * 44)
    drawOrbitalTrail(megaPlanet, baseTrailLen, 0.56, 0.05)
  end
  local pr, pg, pb = computeOrbiterColor(megaPlanet.angle)
  setColorDirect(pr, pg, pb, 1)
  love.graphics.circle("fill", megaPlanet.x, megaPlanet.y, BODY_VISUAL.megaPlanetRadius, 30)
end

local function drawSatellite(satellite)
  if hasActiveBoost(satellite) then
    local baseTrailLen = math.min(satellite.radius * 2.2, 16 + satellite.boost * 22)
    drawOrbitalTrail(satellite, baseTrailLen, 0.44, 0.02)
  end
  local satR, satG, satB = computeOrbiterColor(satellite.angle)
  setColorDirect(satR, satG, satB, 1)
  love.graphics.circle("fill", satellite.x, satellite.y, BODY_VISUAL.satelliteRadius, 18)
end

local function drawHud()
  local font = love.graphics.getFont()
  local lineH = math.floor(font:getHeight())
  local uiScale = scale >= 1 and scale or 1
  local mouseX, mouseY = love.mouse.getPosition()
  local counterFont = getOrbitCounterFont()
  local counterText = tostring(state.orbits)
  local counterTextW = counterFont:getWidth(counterText)
  local counterTextH = counterFont:getHeight()
  local counterW = counterTextW
  local counterCenterX = offsetX + (GAME_W * scale) * 0.5
  local counterX = counterCenterX - counterW * 0.5
  local counterY = offsetY + math.floor(8 * uiScale)

  love.graphics.setFont(counterFont)
  love.graphics.setColor(palette.text)
  drawText(counterText, counterX, counterY)
  love.graphics.setFont(font)

  local panelX = math.floor(offsetX + 12 * uiScale)
  local panelY = math.floor(offsetY + 12 * uiScale)
  local panelW = math.floor(292 * uiScale)
  local padX = math.floor(8 * uiScale)
  local rowH = lineH + math.floor(5 * uiScale)
  local gap = math.floor(2 * uiScale)
  local rowTextInsetY = math.floor(2 * uiScale)
  local y = panelY + math.floor(6 * uiScale)

  local function drawHeader(text)
    love.graphics.setColor(palette.text)
    drawText(text, panelX + padX, y)
    y = y + lineH + math.floor(2 * uiScale)
  end

  local function drawRow(btn, label, status, enabled, orbitCost)
    btn.x = panelX + padX
    btn.y = y
    btn.w = panelW - padX * 2
    btn.h = rowH
    local alpha = enabled and 1 or 0.40
    local hovered = pointInRect(mouseX, mouseY, btn)
    if hovered then
      setColorScaled(swatch.brightest, 1, 0.95 * alpha)
      love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
    end
    setColorScaled(palette.text, 1, alpha)
    drawText(label, btn.x + math.floor(8 * uiScale), btn.y + rowTextInsetY)
    if status and status ~= "" then
      if orbitCost then
        local sw = font:getWidth(status)
        drawText(status, btn.x + btn.w - sw - math.floor(8 * uiScale), btn.y + rowTextInsetY)
      else
        local sw = font:getWidth(status)
        drawText(status, btn.x + btn.w - sw - math.floor(8 * uiScale), btn.y + rowTextInsetY)
      end
    end
    y = y + rowH + gap
    return hovered
  end

  local megaPlanetBuyCost = megaPlanetCost()
  local planetBuyCost = planetCost()
  local moonBuyCost = moonCost()
  local canBuyMegaPlanet = state.orbits >= megaPlanetBuyCost
  local canBuyPlanet = state.orbits >= planetBuyCost
  local canBuyMoon = state.orbits >= moonBuyCost and #state.moons < MAX_MOONS
  local canBuySatellite = #state.satellites < MAX_SATELLITES and state.orbits >= satelliteCost()
  local satelliteStatus = tostring(satelliteCost())
  local speedWaveReady = state.speedWaveUnlocked or state.orbits >= speedWaveCost()
  local speedClickReady = state.speedClickUnlocked or state.orbits >= speedClickCost()
  local waveStatus = state.speedWaveUnlocked and (state.speedWaveTimer > 0 and "on" or tostring(state.planetClickCount % SPEED_WAVE_CLICK_THRESHOLD) .. "/" .. tostring(SPEED_WAVE_CLICK_THRESHOLD)) or tostring(speedWaveCost())
  local clickStatus = state.speedClickUnlocked and "owned" or tostring(speedClickCost())

  local sectionCount = 2
  local rowCount = 6
  local panelH = math.floor(6 * uiScale) + sectionCount * (lineH + math.floor(2 * uiScale)) + rowCount * (rowH + gap) + math.floor(4 * uiScale)

  local hoveredTooltipLines
  local hoveredTooltipBtn

  love.graphics.setScissor(panelX + 1, panelY + 1, panelW - 2, panelH - 2)

  drawHeader("generators")
  local megaPlanetHovered = drawRow(ui.buyMegaPlanetBtn, "mega planet", tostring(megaPlanetBuyCost), canBuyMegaPlanet, true)
  if megaPlanetHovered then
    hoveredTooltipBtn = ui.buyMegaPlanetBtn
    hoveredTooltipLines = {
      {
        pre = "Adds a massive planet orbiting the core.",
        hi = "",
        post = "",
      },
      {
        pre = "Size is ",
        hi = "5x",
        post = " the main planet.",
      },
    }
  end
  local planetHovered = drawRow(ui.buyPlanetBtn, "planet", tostring(planetBuyCost), canBuyPlanet, true)
  if planetHovered then
    hoveredTooltipBtn = ui.buyPlanetBtn
    hoveredTooltipLines = {
      {
        pre = "Adds a large planet orbiting the core.",
        hi = "",
        post = "",
      },
      {
        pre = "Size is ",
        hi = "80%",
        post = " of the main planet.",
      },
    }
  end
  local moonHovered = drawRow(ui.buyMoonBtn, "moon", tostring(moonBuyCost), canBuyMoon, true)
  if moonHovered then
    hoveredTooltipBtn = ui.buyMoonBtn
    hoveredTooltipLines = {
      {
        pre = "Adds a moon orbiting the planet.",
        hi = "",
        post = "",
      },
      {
        pre = "Moons can host ",
        hi = "moon satellites",
        post = ".",
      },
    }
  end
  local satelliteHovered = drawRow(ui.buySatelliteBtn, "satellite", satelliteStatus, canBuySatellite)
  if satelliteHovered then
    hoveredTooltipBtn = ui.buySatelliteBtn
    hoveredTooltipLines = {
      {
        pre = "Adds a satellite orbiting the planet.",
        hi = "",
        post = "",
      },
      {
        pre = "Satellites generate ",
        hi = "orbits",
        post = " when clicked.",
      },
    }
  end

  drawHeader("upgrades")
  local waveHovered = drawRow(ui.speedWaveBtn, "speed wave", waveStatus, speedWaveReady, not state.speedWaveUnlocked)
  if waveHovered then
    hoveredTooltipBtn = ui.speedWaveBtn
    hoveredTooltipLines = {
      {
        pre = "Satellites and moon satellites get ",
        hi = string.format("+%d%% speed for %ds", math.floor((SPEED_WAVE_MULTIPLIER - 1) * 100 + 0.5), SPEED_WAVE_DURATION),
        post = ".",
      },
      {
        pre = "Re-triggering refreshes duration; ",
        hi = "it does not stack",
        post = ".",
      },
    }
  end
  local clickHovered = drawRow(ui.speedClickBtn, "speed click", clickStatus, speedClickReady, not state.speedClickUnlocked)
  if clickHovered then
    hoveredTooltipBtn = ui.speedClickBtn
    hoveredTooltipLines = {
      {
        pre = "Planet clicks apply ",
        hi = string.format("+%d%% speed for %ds", math.floor(PLANET_IMPULSE_TARGET_BOOST * 100 + 0.5), PLANET_IMPULSE_DURATION),
        post = " to a random orbiter.",
      },
      {
        pre = "Repeated hits on the same target ",
        hi = "stack",
        post = ".",
      },
    }
  end

  local descAlpha = state.speedClickUnlocked and 1 or 0.58
  setColorScaled(palette.text, 1, descAlpha)
  drawText("planet clicks accelerate a random orbiter", panelX + padX, y)
  love.graphics.setScissor()

  if hoveredTooltipLines and hoveredTooltipBtn then
    local tipPadX = math.floor(8 * uiScale)
    local tipPadY = math.floor(6 * uiScale)
    local tipGap = math.floor(2 * uiScale)
    local tipLineH = lineH
    local tipW = 0
    for i = 1, #hoveredTooltipLines do
      local line = hoveredTooltipLines[i]
      local lineW = font:getWidth(line.pre or "") + font:getWidth(line.hi or "") + font:getWidth(line.post or "")
      tipW = math.max(tipW, lineW)
    end
    tipW = tipW + tipPadX * 2
    local tipH = tipPadY * 2 + tipLineH * #hoveredTooltipLines + tipGap * math.max(0, #hoveredTooltipLines - 1)
    local tipX = hoveredTooltipBtn.x + hoveredTooltipBtn.w + math.floor(10 * uiScale)
    local tipY = hoveredTooltipBtn.y
    local viewportRight = offsetX + GAME_W * scale
    local viewportBottom = offsetY + GAME_H * scale
    if tipX + tipW > viewportRight - 4 then
      tipX = hoveredTooltipBtn.x - tipW - math.floor(10 * uiScale)
    end
    tipX = clamp(tipX, offsetX + 4, viewportRight - tipW - 4)

    setColorScaled(swatch.darkest, 1, 0.96)
    love.graphics.rectangle("fill", tipX, tipY, tipW, tipH)
    setColorScaled(swatch.brightest, 1, 0.96)
    love.graphics.rectangle("line", tipX, tipY, tipW, tipH)
    for i = 1, #hoveredTooltipLines do
      local line = hoveredTooltipLines[i]
      local lineY = tipY + tipPadY + (i - 1) * (tipLineH + tipGap)
      local lineX = tipX + tipPadX
      setColorScaled(palette.text, 1, 0.85)
      drawText(line.pre or "", lineX, lineY)
      lineX = lineX + font:getWidth(line.pre or "")
      setColorScaled(palette.accent, 1, 1)
      drawText(line.hi or "", lineX, lineY)
      lineX = lineX + font:getWidth(line.hi or "")
      setColorScaled(palette.text, 1, 0.85)
      drawText(line.post or "", lineX, lineY)
    end
  end

  love.graphics.setColor(palette.muted)
  local viewportBottom = offsetY + GAME_H * scale
  local helpY1 = math.floor(viewportBottom - lineH * 2 - 8 * uiScale)
  local helpY2 = math.floor(viewportBottom - lineH - 4 * uiScale)
  local helpX = panelX
  if zoom > 1.005 then
    drawText(string.format("zoom %.1fx  scroll to zoom", zoom), helpX, helpY1)
  else
    drawText("scroll to zoom", helpX, helpY1)
  end
  drawText("b fullscreen", helpX, helpY2)
end

local function getOrbiterTooltipLayout()
  local orbiter = state.selectedOrbiter
  if not orbiter then
    return nil
  end

  local font = getUiScreenFont()
  local uiScale = scale >= 1 and scale or 1
  local baseRpm = orbiter.speed * (60 / (math.pi * 2))
  local totalBoost = orbiter.boost + speedWaveBoostFor(orbiter)
  local currentRpm = orbiter.speed * (1 + totalBoost) * (60 / (math.pi * 2))
  local boostPercent = math.floor(totalBoost * 100 + 0.5)
  local title = "selected moon"
  if orbiter.kind == "satellite" then
    title = "selected satellite"
  elseif orbiter.kind == "planet" then
    title = "selected planet"
  elseif orbiter.kind == "mega-planet" then
    title = "selected mega planet"
  end
  local detailLines = {
    {pre = "revolutions ", hi = tostring(orbiter.revolutions), post = ""},
    {pre = "orbit radius ", hi = string.format("%.0f px", orbiter.radius), post = ""},
    {pre = "base speed ", hi = string.format("%.2f rpm", baseRpm), post = ""},
    {pre = "current speed ", hi = string.format("%.2f rpm", currentRpm), post = ""},
    {pre = "active boost ", hi = string.format("%+d%%", boostPercent), post = ""},
  }
  if orbiter.kind == "moon" then
    detailLines[#detailLines + 1] = {
      pre = "moon satellites ",
      hi = tostring(#(orbiter.childSatellites or {})),
      post = "",
    }
  end

  local textW = font:getWidth(title)
  for i = 1, #detailLines do
    local line = detailLines[i]
    local lineW = font:getWidth(line.pre or "") + font:getWidth(line.hi or "") + font:getWidth(line.post or "")
    textW = math.max(textW, lineW)
  end
  local lineH = math.floor(font:getHeight())
  local padX = math.floor(8 * uiScale)
  local padY = math.floor(6 * uiScale)
  local lineGap = math.floor(2 * uiScale)
  local titleGap = math.floor(2 * uiScale)
  local boxW = textW + padX * 2
  local boxH = padY * 2 + lineH + titleGap + #detailLines * lineH + lineGap * math.max(0, #detailLines - 1)
  local boxX = math.floor(offsetX + GAME_W * scale - boxW - 8 * uiScale)
  local boxY = math.floor(offsetY + 8 * uiScale)
  local anchorX = boxX
  local anchorY = boxY + math.floor(boxH * 0.5)
  local anchorWorldX, anchorWorldY = toWorldSpace(anchorX, anchorY)

  return {
    orbiter = orbiter,
    title = title,
    detailLines = detailLines,
    lineH = lineH,
    lineGap = lineGap,
    titleGap = titleGap,
    uiScale = uiScale,
    padX = padX,
    padY = padY,
    boxX = boxX,
    boxY = boxY,
    boxW = boxW,
    boxH = boxH,
    anchorWorldX = anchorWorldX,
    anchorWorldY = anchorWorldY,
  }
end

local function drawOrbiterTooltipConnector(frontPass)
  ui.moonAddSatelliteBtn.visible = false
  ui.moonAddSatelliteBtn.enabled = false
  local layout = getOrbiterTooltipLayout()
  if not layout then
    return
  end
  local orbiter = layout.orbiter

  if (frontPass and orbiter.z <= 0) or ((not frontPass) and orbiter.z > 0) then
    return
  end

  setColorDirect(SELECTED_ORBIT_COLOR[1], SELECTED_ORBIT_COLOR[2], SELECTED_ORBIT_COLOR[3], 0.88)
  love.graphics.line(layout.anchorWorldX, layout.anchorWorldY, orbiter.x, orbiter.y)
end

local function drawOrbiterTooltip()
  ui.moonAddSatelliteBtn.visible = false
  ui.moonAddSatelliteBtn.enabled = false
  local layout = getOrbiterTooltipLayout()
  if not layout then
    return
  end
  local orbiter = layout.orbiter

  setColorScaled(swatch.darkest, 1, 0.96)
  love.graphics.rectangle("fill", layout.boxX, layout.boxY, layout.boxW, layout.boxH)
  setColorScaled(swatch.brightest, 1, 0.96)
  love.graphics.rectangle("line", layout.boxX, layout.boxY, layout.boxW, layout.boxH)

  local textX = layout.boxX + layout.padX
  local y = layout.boxY + layout.padY
  local font = love.graphics.getFont()
  setColorScaled(palette.text, 1, 0.96)
  drawText(layout.title, textX, y)
  y = y + layout.lineH + layout.titleGap
  for i = 1, #layout.detailLines do
    local line = layout.detailLines[i]
    local lineX = textX
    setColorScaled(palette.text, 1, 0.85)
    drawText(line.pre or "", lineX, y)
    lineX = lineX + font:getWidth(line.pre or "")
    setColorScaled(palette.accent, 1, 1)
    drawText(line.hi or "", lineX, y)
    lineX = lineX + font:getWidth(line.hi or "")
    setColorScaled(palette.text, 1, 0.85)
    drawText(line.post or "", lineX, y)
    y = y + layout.lineH + layout.lineGap
  end

  if orbiter.kind == "moon" then
    local btnW = math.max(layout.boxW, 76)
    local btnH = layout.lineH + math.floor(6 * layout.uiScale)
    local btnX = layout.boxX
    local btnY = layout.boxY + layout.boxH + math.floor(3 * layout.uiScale)
    local canAddSatellite = state.orbits >= moonSatelliteCost()
    local btnAlpha = canAddSatellite and 1 or 0.45

    ui.moonAddSatelliteBtn.x = btnX
    ui.moonAddSatelliteBtn.y = btnY
    ui.moonAddSatelliteBtn.w = btnW
    ui.moonAddSatelliteBtn.h = btnH
    ui.moonAddSatelliteBtn.visible = true
    ui.moonAddSatelliteBtn.enabled = canAddSatellite

    setColorScaled(swatch.brightest, 1, 0.96 * btnAlpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    setColorScaled(palette.text, 1, btnAlpha)
    drawText("add satellite  -" .. tostring(moonSatelliteCost()) .. " orbits", btnX + math.floor(6 * layout.uiScale), btnY + math.floor(3 * layout.uiScale))
  end
end

local function drawSpeedWaveText()
  local popup = state.speedWaveText
  if not popup then
    return
  end
  local t = clamp(popup.age / popup.life, 0, 1)
  local alpha = 1 - smoothstep(t)
  local uiScale = scale >= 1 and scale or 1
  local yLift = t * 12 * uiScale
  setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], alpha)
  drawText("speed wave", popup.x + 8 * uiScale, popup.y - 10 * uiScale - yLift)
end

local function initBackgroundMusic()
  local ok, source = pcall(love.audio.newSource, "music.wav", "stream")
  if not ok or not source then
    bgMusic = nil
    bgMusicFirstPass = false
    return
  end

  bgMusic = source
  bgMusic:setLooping(false)
  bgMusic:setVolume(BG_MUSIC_VOLUME)
  bgMusic:play()
  bgMusicFirstPass = true
  bgMusicPrevPos = 0
end

local function updateBackgroundMusic(dt)
  if not bgMusic then
    return
  end

  bgMusicDuckTimer = math.max(0, bgMusicDuckTimer - dt)
  local duckT = bgMusicDuckTimer > 0 and (bgMusicDuckTimer / BG_MUSIC_DUCK_SECONDS) or 0
  local duckGain = lerp(1, BG_MUSIC_DUCK_GAIN, duckT)

  if bgMusicFirstPass then
    if not bgMusic:isPlaying() then
      bgMusicFirstPass = false
      bgMusic:setLooping(true)
      bgMusic:play()
      bgMusicPrevPos = 0
    end
    bgMusic:setVolume(BG_MUSIC_VOLUME * duckGain)
    return
  end

  local duration = bgMusic:getDuration("seconds")
  if not duration or duration <= 0 then
    bgMusic:setVolume(BG_MUSIC_VOLUME * duckGain)
    return
  end

  local pos = bgMusic:tell("seconds")
  local remaining = duration - pos
  local fadeWindow = BG_MUSIC_LOOP_FADE_SECONDS
  local fadeOut = remaining < fadeWindow and (remaining / fadeWindow) or 1
  local fadeIn = pos < fadeWindow and (pos / fadeWindow) or 1
  local loopGain = clamp(math.min(fadeOut, fadeIn), 0, 1)
  bgMusic:setVolume(BG_MUSIC_VOLUME * loopGain * duckGain)
  bgMusicPrevPos = pos
end

local function initUpgradeFx()
  local ok, source = pcall(love.audio.newSource, "upgrade_fx.mp3", "static")
  if not ok or not source then
    upgradeFx = nil
    return
  end
  source:setVolume(UPGRADE_FX_VOLUME)
  upgradeFx = source
end

local function initClickFx()
  local ok, source = pcall(love.audio.newSource, "click_fx.wav", "static")
  if not ok or not source then
    clickFx = nil
    return
  end
  clickFx = source
end

local function playClickFx(isClosing)
  if not clickFx then
    return
  end
  local voice = clickFx:clone()
  if isClosing then
    voice:setPitch(CLICK_FX_PITCH_CLOSE)
    voice:setVolume(CLICK_FX_VOLUME_CLOSE)
  else
    voice:setPitch(CLICK_FX_PITCH_OPEN)
    voice:setVolume(CLICK_FX_VOLUME_OPEN)
  end
  love.audio.play(voice)
end

local function playMenuBuyClickFx()
  if not clickFx then
    return
  end
  local voice = clickFx:clone()
  local pitch = lerp(CLICK_FX_MENU_PITCH_MIN, CLICK_FX_MENU_PITCH_MAX, love.math.random())
  voice:setPitch(pitch)
  voice:setVolume(CLICK_FX_VOLUME_OPEN)
  love.audio.play(voice)
end

local function updateFadedFxInstances(instances, targetVolume, fadeSeconds, dt)
  for i = #instances, 1, -1 do
    local entry = instances[i]
    local source = entry.source
    if not source:isPlaying() then
      table.remove(instances, i)
    else
      entry.age = entry.age + dt
      local gain = clamp(entry.age / fadeSeconds, 0, 1)
      source:setVolume(targetVolume * gain)
    end
  end
end

local function updateUpgradeFx(dt)
  updateFadedFxInstances(upgradeFxInstances, UPGRADE_FX_VOLUME, UPGRADE_FX_FADE_IN_SECONDS, dt)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  uiFont = love.graphics.newFont("font_gothic.ttf", UI_FONT_SIZE, "mono")
  uiFont:setFilter("nearest", "nearest")
  love.graphics.setFont(uiFont)
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("none")
  setBorderlessFullscreen(false)

  canvas = love.graphics.newCanvas(GAME_W, GAME_H)
  canvas:setFilter("nearest", "nearest")
  initBackgroundMusic()
  initUpgradeFx()
  initClickFx()

  recomputeViewport()

  for _ = 1, 72 do
    table.insert(state.stars, {
      x = love.math.random(0, GAME_W - 1),
      y = love.math.random(0, GAME_H - 1),
      phase = love.math.random() * math.pi * 2,
      speed = 0.35 + love.math.random() * 0.6,
      kind = love.math.random(0, 1),
    })
  end
end

function love.resize()
  recomputeViewport()
end

function love.keypressed(key)
  if key == "b" then
    setBorderlessFullscreen(not state.borderlessFullscreen)
  end
end

function love.wheelmoved(_, wy)
  zoom = clamp(zoom + wy * 0.1, 1, 2)
end

function love.update(dt)
  dt = math.min(dt, 0.05)
  updateBackgroundMusic(dt)
  updateUpgradeFx(dt)
  state.time = state.time + dt
  state.planetBounceTime = math.max(0, state.planetBounceTime - dt)
  state.speedWaveTimer = math.max(0, state.speedWaveTimer - dt)
  updateOrbitGainFx(dt)

  local ripples = state.speedWaveRipples
  for i = #ripples, 1, -1 do
    local ripple = ripples[i]
    ripple.age = ripple.age + dt
    if ripple.age >= ripple.life then
      table.remove(ripples, i)
    end
  end

  if state.speedWaveText then
    state.speedWaveText.age = state.speedWaveText.age + dt
    if state.speedWaveText.age >= state.speedWaveText.life then
      state.speedWaveText = nil
    end
  end

  for _, moon in ipairs(state.moons) do
    local prev = moon.angle
    updateOrbiterBoost(moon, dt)
    local effectiveSpeed = moon.speed * (1 + moon.boost)

    moon.angle = moon.angle + effectiveSpeed * dt

    local prevTurns = math.floor(prev / TWO_PI)
    local newTurns = math.floor(moon.angle / TWO_PI)
    if newTurns > prevTurns then
      local turnsGained = newTurns - prevTurns
      state.orbits = state.orbits + turnsGained
      moon.revolutions = moon.revolutions + turnsGained
      spawnOrbitGainFx(moon.x, moon.y, turnsGained, BODY_VISUAL.moonRadius)
    end

    updateOrbiterPosition(moon)

    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      local prev = child.angle
      updateOrbiterBoost(child, dt)
      local totalBoost = child.boost + speedWaveBoostFor(child)
      local effectiveSpeed = child.speed * (1 + totalBoost)
      child.angle = child.angle + effectiveSpeed * dt
      local cp = math.cos(child.plane)
      local sp = math.sin(child.plane)
      local ox = math.cos(child.angle) * child.radius
      local oy = math.sin(child.angle) * child.radius * child.flatten
      local sx = moon.x + ox * cp - oy * sp
      local sy = moon.y + ox * sp + oy * cp
      child.x = sx
      child.y = sy
      child.z = moon.z + math.sin(child.angle) * (child.depthScale or 1)

      local prevTurns = math.floor(prev / TWO_PI)
      local newTurns = math.floor(child.angle / TWO_PI)
      if newTurns > prevTurns then
        local turnsGained = newTurns - prevTurns
        state.orbits = state.orbits + turnsGained
        child.revolutions = child.revolutions + turnsGained
        spawnOrbitGainFx(sx, sy, turnsGained, BODY_VISUAL.moonChildSatelliteRadius)
      end
    end
  end

  for _, megaPlanet in ipairs(state.megaPlanets) do
    local prev = megaPlanet.angle
    updateOrbiterBoost(megaPlanet, dt)
    local effectiveSpeed = megaPlanet.speed * (1 + megaPlanet.boost)
    megaPlanet.angle = megaPlanet.angle + effectiveSpeed * dt

    local prevTurns = math.floor(prev / TWO_PI)
    local newTurns = math.floor(megaPlanet.angle / TWO_PI)
    if newTurns > prevTurns then
      local turnsGained = newTurns - prevTurns
      state.orbits = state.orbits + turnsGained
      megaPlanet.revolutions = megaPlanet.revolutions + turnsGained
      spawnOrbitGainFx(megaPlanet.x, megaPlanet.y, turnsGained, BODY_VISUAL.megaPlanetRadius)
    end

    updateOrbiterPosition(megaPlanet)
  end

  for _, planet in ipairs(state.planets) do
    local prev = planet.angle
    updateOrbiterBoost(planet, dt)
    local effectiveSpeed = planet.speed * (1 + planet.boost)
    planet.angle = planet.angle + effectiveSpeed * dt

    local prevTurns = math.floor(prev / TWO_PI)
    local newTurns = math.floor(planet.angle / TWO_PI)
    if newTurns > prevTurns then
      local turnsGained = newTurns - prevTurns
      state.orbits = state.orbits + turnsGained
      planet.revolutions = planet.revolutions + turnsGained
      spawnOrbitGainFx(planet.x, planet.y, turnsGained, BODY_VISUAL.orbitPlanetRadius)
    end

    updateOrbiterPosition(planet)
  end

  for _, satellite in ipairs(state.satellites) do
    local prev = satellite.angle
    updateOrbiterBoost(satellite, dt)
    local totalBoost = satellite.boost + speedWaveBoostFor(satellite)
    local effectiveSpeed = satellite.speed * (1 + totalBoost)

    satellite.angle = satellite.angle + effectiveSpeed * dt

    local prevTurns = math.floor(prev / TWO_PI)
    local newTurns = math.floor(satellite.angle / TWO_PI)
    if newTurns > prevTurns then
      local turnsGained = newTurns - prevTurns
      state.orbits = state.orbits + turnsGained
      satellite.revolutions = satellite.revolutions + turnsGained
      spawnOrbitGainFx(satellite.x, satellite.y, turnsGained, BODY_VISUAL.satelliteRadius)
    end

    updateOrbiterPosition(satellite)
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  if x >= ui.buyMegaPlanetBtn.x and x <= ui.buyMegaPlanetBtn.x + ui.buyMegaPlanetBtn.w and y >= ui.buyMegaPlanetBtn.y and y <= ui.buyMegaPlanetBtn.y + ui.buyMegaPlanetBtn.h then
    if addMegaPlanet() then
      playMenuBuyClickFx()
    end
    return
  end

  if x >= ui.buyPlanetBtn.x and x <= ui.buyPlanetBtn.x + ui.buyPlanetBtn.w and y >= ui.buyPlanetBtn.y and y <= ui.buyPlanetBtn.y + ui.buyPlanetBtn.h then
    if addPlanet() then
      playMenuBuyClickFx()
    end
    return
  end

  if x >= ui.buyMoonBtn.x and x <= ui.buyMoonBtn.x + ui.buyMoonBtn.w and y >= ui.buyMoonBtn.y and y <= ui.buyMoonBtn.y + ui.buyMoonBtn.h then
    if addMoon() then
      playMenuBuyClickFx()
    end
    return
  end

  if x >= ui.buySatelliteBtn.x and x <= ui.buySatelliteBtn.x + ui.buySatelliteBtn.w and y >= ui.buySatelliteBtn.y and y <= ui.buySatelliteBtn.y + ui.buySatelliteBtn.h then
    if addSatellite() then
      playMenuBuyClickFx()
    end
    return
  end

  if x >= ui.speedWaveBtn.x and x <= ui.speedWaveBtn.x + ui.speedWaveBtn.w and y >= ui.speedWaveBtn.y and y <= ui.speedWaveBtn.y + ui.speedWaveBtn.h then
    buySpeedWave()
    return
  end

  if x >= ui.speedClickBtn.x and x <= ui.speedClickBtn.x + ui.speedClickBtn.w and y >= ui.speedClickBtn.y and y <= ui.speedClickBtn.y + ui.speedClickBtn.h then
    buySpeedClick()
    return
  end

  if ui.moonAddSatelliteBtn.visible and x >= ui.moonAddSatelliteBtn.x and x <= ui.moonAddSatelliteBtn.x + ui.moonAddSatelliteBtn.w and y >= ui.moonAddSatelliteBtn.y and y <= ui.moonAddSatelliteBtn.y + ui.moonAddSatelliteBtn.h then
    if ui.moonAddSatelliteBtn.enabled then
      if addSatelliteToMoon(state.selectedOrbiter) then
        playMenuBuyClickFx()
      end
    end
    return
  end

  local gx, gy = toGameSpace(x, y)
  if gx < 0 or gy < 0 or gx > GAME_W or gy > GAME_H then
    return
  end

  local wx, wy = toWorldSpace(x, y)
  local planetDx = wx - cx
  local planetDy = wy - cy
  local planetHitR = BODY_VISUAL.planetRadius
  if planetDx * planetDx + planetDy * planetDy <= planetHitR * planetHitR then
    onPlanetClicked()
    return
  end

  for i = #state.moons, 1, -1 do
    local moon = state.moons[i]
    local dx = wx - moon.x
    local dy = wy - moon.y
    local moonHitR = BODY_VISUAL.moonRadius + 2
    if dx * dx + dy * dy <= moonHitR * moonHitR then
      if state.selectedOrbiter ~= moon then
        playClickFx(false)
      end
      state.selectedOrbiter = moon
      return
    end
  end

  for i = #state.megaPlanets, 1, -1 do
    local megaPlanet = state.megaPlanets[i]
    local dx = wx - megaPlanet.x
    local dy = wy - megaPlanet.y
    local megaPlanetHitR = BODY_VISUAL.megaPlanetRadius + 2
    if dx * dx + dy * dy <= megaPlanetHitR * megaPlanetHitR then
      if state.selectedOrbiter ~= megaPlanet then
        playClickFx(false)
      end
      state.selectedOrbiter = megaPlanet
      return
    end
  end

  for i = #state.planets, 1, -1 do
    local planet = state.planets[i]
    local dx = wx - planet.x
    local dy = wy - planet.y
    local orbitPlanetHitR = BODY_VISUAL.orbitPlanetRadius + 2
    if dx * dx + dy * dy <= orbitPlanetHitR * orbitPlanetHitR then
      if state.selectedOrbiter ~= planet then
        playClickFx(false)
      end
      state.selectedOrbiter = planet
      return
    end
  end

  for i = #state.satellites, 1, -1 do
    local satellite = state.satellites[i]
    local dx = wx - satellite.x
    local dy = wy - satellite.y
    local satelliteHitR = BODY_VISUAL.satelliteRadius + 1.5
    if dx * dx + dy * dy <= satelliteHitR * satelliteHitR then
      if state.selectedOrbiter ~= satellite then
        playClickFx(false)
      end
      state.selectedOrbiter = satellite
      return
    end
  end

  if state.selectedOrbiter then
    playClickFx(true)
  end
  state.selectedOrbiter = nil
end

function love.draw()
  love.graphics.setFont(uiFont)
  love.graphics.setCanvas(canvas)
  drawBackground()

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(zoom, zoom)
  love.graphics.translate(-cx, -cy)

  drawSelectedOrbit(false)
  drawOrbiterTooltipConnector(false)

  local back = {}
  local front = {}
  local megaPlanetBack = {}
  local megaPlanetFront = {}
  local planetBack = {}
  local planetFront = {}
  for _, m in ipairs(state.moons) do
    if m.z <= 0 then
      table.insert(back, m)
    else
      table.insert(front, m)
    end
  end

  table.sort(back, function(a, b) return a.z < b.z end)
  table.sort(front, function(a, b) return a.z < b.z end)
  for _, mp in ipairs(state.megaPlanets) do
    if mp.z <= 0 then
      table.insert(megaPlanetBack, mp)
    else
      table.insert(megaPlanetFront, mp)
    end
  end
  table.sort(megaPlanetBack, function(a, b) return a.z < b.z end)
  table.sort(megaPlanetFront, function(a, b) return a.z < b.z end)
  for _, p in ipairs(state.planets) do
    if p.z <= 0 then
      table.insert(planetBack, p)
    else
      table.insert(planetFront, p)
    end
  end
  table.sort(planetBack, function(a, b) return a.z < b.z end)
  table.sort(planetFront, function(a, b) return a.z < b.z end)

  for _, mp in ipairs(megaPlanetBack) do
    drawMegaPlanet(mp)
  end
  for _, p in ipairs(planetBack) do
    drawOrbitPlanet(p)
  end
  for _, m in ipairs(back) do
    drawMoon(m)
  end

  local satBack = {}
  local satFront = {}
  for _, s in ipairs(state.satellites) do
    if s.z <= 0 then
      table.insert(satBack, s)
    else
      table.insert(satFront, s)
    end
  end
  table.sort(satBack, function(a, b) return a.z < b.z end)
  table.sort(satFront, function(a, b) return a.z < b.z end)

  for _, s in ipairs(satBack) do
    drawSatellite(s)
  end
  drawPlanet()
  drawOrbiterTooltipConnector(true)
  drawSpeedWaveRipples()
  drawSelectedOrbit(true)
  for _, s in ipairs(satFront) do
    drawSatellite(s)
  end
  for _, mp in ipairs(megaPlanetFront) do
    drawMegaPlanet(mp)
  end
  for _, p in ipairs(planetFront) do
    drawOrbitPlanet(p)
  end
  for _, m in ipairs(front) do
    drawMoon(m)
  end
  love.graphics.pop()

  drawOrbitGainFx()

  love.graphics.setCanvas()
  love.graphics.clear(palette.space)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)

  love.graphics.setFont(getUiScreenFont())
  drawSpeedWaveText()
  drawOrbiterTooltip()
  drawHud()
end
