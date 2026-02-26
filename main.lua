local GAME_W = 1280
local GAME_H = 720
local TWO_PI = math.pi * 2
local LIGHT_X = 24
local LIGHT_Y = GAME_H - 24
local LIGHT_Z = 22
local ORBIT_CONFIGS = {
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
  accent = swatch.brightest,
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
  orbits = 100,
  moons = {},
  satellites = {},
  moonsPurchased = 0,
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
  if state.moonsPurchased == 0 then
    return 0
  end
  return 5
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
  state.moonsPurchased = state.moonsPurchased + 1
  return true
end

local function addSatellite()
  if #state.satellites >= MAX_SATELLITES then
    return false
  end

  if #state.moons < 1 then
    return false
  end

  table.remove(state.moons, #state.moons)

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

  if #state.satellites < 3 then
    return false
  end

  for _ = 1, 3 do
    local removedSatellite = table.remove(state.satellites, #state.satellites)
    if state.selectedOrbiter == removedSatellite then
      state.selectedOrbiter = nil
    end
  end

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
    local pr, pg, pb = computeOrbiterColor(target.angle)
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
          setColorDirect(pr, pg, pb, 0.72)
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
  love.graphics.setLineWidth(1)
  for _, child in ipairs(childSatellites) do
    drawChildOrbitPath(child, false)
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

  for _, child in ipairs(childSatellites) do
    drawChildOrbitPath(child, true)
  end

  for _, child in ipairs(childSatellites) do
    if child.z > moon.z then
      drawChild(child)
    end
  end
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
  local counterFont = getOrbitCounterFont()
  local counterText = tostring(state.orbits)
  local counterTextW = counterFont:getWidth(counterText)
  local counterTextH = counterFont:getHeight()
  local counterIconR = ORBIT_ICON_SIZE * uiScale * 1.65
  local counterGap = math.floor(18 * uiScale)
  local counterW = counterTextW + counterGap + counterIconR * 2
  local counterCenterX = offsetX + (GAME_W * scale) * 0.5
  local counterX = counterCenterX - counterW * 0.5
  local counterY = offsetY + math.floor(8 * uiScale)

  love.graphics.setFont(counterFont)
  love.graphics.setColor(palette.text)
  drawText(counterText, counterX, counterY)
  local counterIconX = counterX + counterTextW + counterGap + counterIconR
  local counterIconY = counterY + counterTextH * 0.5
  drawOrbitIcon(counterIconX, counterIconY, counterIconR, 1)
  love.graphics.setFont(font)

  local panelX = math.floor(offsetX + 6 * uiScale)
  local panelY = math.floor(counterY + counterTextH + 10 * uiScale)
  local panelW = math.floor(350 * uiScale)
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
    setColorScaled(palette.nebulaA or palette.space, 1, 0.85)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
    setColorScaled(palette.panelEdge, 1, alpha)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
    setColorScaled(palette.text, 1, alpha)
    drawText(label, btn.x + math.floor(8 * uiScale), btn.y + rowTextInsetY)
    if status and status ~= "" then
      if orbitCost then
        local sw = font:getWidth(status)
        local iconX = btn.x + btn.w - math.floor(12 * uiScale)
        local iconY = btn.y + math.floor(btn.h * 0.5)
        local iconGap = math.floor(20 * uiScale)
        drawOrbitIcon(iconX - math.floor(7 * uiScale), iconY, ORBIT_ICON_SIZE * uiScale, alpha)
        drawText(status, iconX - iconGap - sw, btn.y + rowTextInsetY)
      else
        local sw = font:getWidth(status)
        drawText(status, btn.x + btn.w - sw - math.floor(8 * uiScale), btn.y + rowTextInsetY)
      end
    end
    y = y + rowH + gap
  end

  local moonBuyCost = moonCost()
  local canBuyMoon = state.orbits >= moonBuyCost and #state.moons < MAX_MOONS
  local moonCostText = moonBuyCost == 0 and "free" or tostring(moonBuyCost)
  local canBuySatellite = #state.moons >= 1 and #state.satellites < MAX_SATELLITES
  local satelliteStatus = #state.moons < 1 and "need moon" or tostring(#state.satellites) .. "/" .. tostring(MAX_SATELLITES)
  local speedWaveReady = state.speedWaveUnlocked or state.orbits >= speedWaveCost()
  local speedClickReady = state.speedClickUnlocked or state.orbits >= speedClickCost()
  local waveStatus = state.speedWaveUnlocked and (state.speedWaveTimer > 0 and "on" or tostring(state.planetClickCount % SPEED_WAVE_CLICK_THRESHOLD) .. "/" .. tostring(SPEED_WAVE_CLICK_THRESHOLD)) or tostring(speedWaveCost())
  local clickStatus = state.speedClickUnlocked and "owned" or tostring(speedClickCost())

  local sectionCount = 2
  local rowCount = 4
  local panelH = math.floor(6 * uiScale) + sectionCount * (lineH + math.floor(2 * uiScale)) + rowCount * (rowH + gap) + math.floor(4 * uiScale)

  setColorScaled(palette.space, 1, 0.85)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
  setColorScaled(palette.panelEdge, 1, 1)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
  love.graphics.setScissor(panelX + 1, panelY + 1, panelW - 2, panelH - 2)

  drawHeader("generators")
  drawRow(ui.buyMoonBtn, "moon", moonCostText, canBuyMoon, moonBuyCost > 0)
  drawRow(ui.buySatelliteBtn, "satellite", satelliteStatus, canBuySatellite)

  drawHeader("upgrades")
  drawRow(ui.speedWaveBtn, "speed wave", waveStatus, speedWaveReady, not state.speedWaveUnlocked)
  drawRow(ui.speedClickBtn, "speed click", clickStatus, speedClickReady, not state.speedClickUnlocked)

  local descAlpha = state.speedClickUnlocked and 1 or 0.58
  setColorScaled(palette.text, 1, descAlpha)
  drawText("planet clicks accelerate a random orbiter", panelX + padX, y)
  love.graphics.setScissor()

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

  local pr, pg, pb = computeOrbiterColor(orbiter.angle)
  local rpm = (orbiter.speed * (1 + orbiter.boost)) * (60 / (math.pi * 2))
  local title = orbiter.kind == "satellite" and "satellite" or "moon"
  local line1 = string.format("%s  rev %d", title, orbiter.revolutions)
  local line2 = string.format("rpm %.2f", rpm)
  local font = getUiScreenFont()
  local uiScale = scale >= 1 and scale or 1
  local textW = math.max(font:getWidth(line1), font:getWidth(line2))
  local lineH = math.floor(font:getHeight())
  local padX = math.floor(6 * uiScale)
  local boxW = textW + padX * 2
  local boxH = lineH * 2 + math.floor(8 * uiScale)
  local boxX = math.floor(offsetX + GAME_W * scale - boxW - 8 * uiScale)
  local boxY = math.floor(offsetY + 8 * uiScale)
  local anchorX = boxX
  local anchorY = boxY + math.floor(boxH * 0.5)
  local anchorWorldX, anchorWorldY = toWorldSpace(anchorX, anchorY)

  return {
    orbiter = orbiter,
    color = {pr, pg, pb},
    line1 = line1,
    line2 = line2,
    lineH = lineH,
    uiScale = uiScale,
    padX = padX,
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
  local pr = layout.color[1]
  local pg = layout.color[2]
  local pb = layout.color[3]

  setColorDirect(pr, pg, pb, 0.82)
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
  local pr = layout.color[1]
  local pg = layout.color[2]
  local pb = layout.color[3]

  setColorDirect(pr, pg, pb, 0.24)
  love.graphics.rectangle("fill", layout.boxX, layout.boxY, layout.boxW, layout.boxH)
  setColorDirect(pr, pg, pb, 1)
  drawText(layout.line1, layout.boxX + layout.padX, layout.boxY + 4)
  drawText(layout.line2, layout.boxX + layout.padX, layout.boxY + 4 + layout.lineH)

  if orbiter.kind == "moon" then
    local btnW = math.max(layout.boxW, 76)
    local btnH = layout.lineH + math.floor(6 * layout.uiScale)
    local btnX = layout.boxX
    local btnY = layout.boxY + layout.boxH + math.floor(3 * layout.uiScale)
    local canAddSatellite = #state.satellites >= 3
    local btnAlpha = canAddSatellite and 1 or 0.45

    ui.moonAddSatelliteBtn.x = btnX
    ui.moonAddSatelliteBtn.y = btnY
    ui.moonAddSatelliteBtn.w = btnW
    ui.moonAddSatelliteBtn.h = btnH
    ui.moonAddSatelliteBtn.visible = true
    ui.moonAddSatelliteBtn.enabled = canAddSatellite

    setColorDirect(pr, pg, pb, 0.24 * btnAlpha)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    setColorDirect(pr, pg, pb, 0.72 * btnAlpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    setColorDirect(pr, pg, pb, btnAlpha)
    drawText("add sat -3 s", btnX + math.floor(6 * layout.uiScale), btnY + math.floor(3 * layout.uiScale))
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
  local ok, source = pcall(love.audio.newSource, "upgrade_fx.wav", "static")
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

  if x >= ui.buyMoonBtn.x and x <= ui.buyMoonBtn.x + ui.buyMoonBtn.w and y >= ui.buyMoonBtn.y and y <= ui.buyMoonBtn.y + ui.buyMoonBtn.h then
    if addMoon() then
      playMenuBuyClickFx()
    end
    return
  end

  if x >= ui.buySatelliteBtn.x and x <= ui.buySatelliteBtn.x + ui.buySatelliteBtn.w and y >= ui.buySatelliteBtn.y and y <= ui.buySatelliteBtn.y + ui.buySatelliteBtn.h then
    local removedMoon = state.moons[#state.moons]
    if addSatellite() then
      playMenuBuyClickFx()
      if state.selectedOrbiter == removedMoon then
        state.selectedOrbiter = nil
      end
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
  for _, m in ipairs(state.moons) do
    if m.z <= 0 then
      table.insert(back, m)
    else
      table.insert(front, m)
    end
  end

  table.sort(back, function(a, b) return a.z < b.z end)
  table.sort(front, function(a, b) return a.z < b.z end)

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
