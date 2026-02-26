local GAME_W = 1280
local GAME_H = 720
local LIGHT_X = 24
local LIGHT_Y = GAME_H - 24
local LIGHT_Z = 22
local ORBIT_CONFIGS = {
  moon = {
    bandCapacity = 4,
    baseRadius = 100,
    bandStep = 34,
    tiltMin = 0.35,
    tiltRange = 1.1,
    speedMin = 0.42,
    speedRange = 0.15,
  },
  satellite = {
    bandCapacity = 6,
    baseRadius = 68,
    bandStep = 20,
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
  moonRadius = 6,
  satelliteRadius = 4,
  moonChildSatelliteRadius = 1.8,
}
local PLANET_IMPULSE_MULTIPLIER = 2
local PLANET_IMPULSE_TARGET_BOOST = PLANET_IMPULSE_MULTIPLIER - 1
local PLANET_IMPULSE_DURATION = 10
local PLANET_IMPULSE_RISE_RATE = 4.5
local PLANET_IMPULSE_FALL_RATE = 6.5

local canvas
local scale = 1
local offsetX = 0
local offsetY = 0
local zoom = 1

local cx = math.floor(GAME_W / 2)
local cy = math.floor(GAME_H / 2)

local swatch = {
  coral = {1.0000, 0.5098, 0.4549, 1},    -- #ff8274
  rose = {0.8353, 0.2353, 0.4157, 1},     -- #d53c6a
  mulberry = {0.4863, 0.0941, 0.2353, 1}, -- #7c183c
  plum = {0.2745, 0.0549, 0.1686, 1},     -- #460e2b
  burgundy = {0.1922, 0.0196, 0.1176, 1}, -- #31051e
  maroon = {0.1216, 0.0196, 0.0627, 1},   -- #1f0510
  obsidian = {0.0745, 0.0078, 0.0314, 1}, -- #130208
}

local palette = {
  space = swatch.obsidian,
  nebulaA = swatch.maroon,
  nebulaB = swatch.burgundy,
  starA = swatch.mulberry,
  starB = swatch.coral,
  orbit = swatch.plum,
  panel = swatch.maroon,
  panelEdge = swatch.rose,
  text = swatch.coral,
  muted = swatch.rose,
  accent = swatch.rose,
  planetCore = swatch.mulberry,
  planetDark = swatch.burgundy,
  planetMid = swatch.plum,
  planetLight = swatch.coral,
  moonFront = swatch.coral,
  moonBack = swatch.mulberry,
  satelliteFront = swatch.coral,
  satelliteBack = swatch.plum,
  trail = {swatch.rose[1], swatch.rose[2], swatch.rose[3], 0.35},
  satelliteTrail = {swatch.mulberry[1], swatch.mulberry[2], swatch.mulberry[3], 0.35},
}
local paletteSwatches = {
  swatch.coral,
  swatch.rose,
  swatch.mulberry,
  swatch.plum,
  swatch.burgundy,
  swatch.maroon,
  swatch.obsidian,
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
}

local ui = {
  buySatelliteBtn = {x = GAME_W - 178, y = 8, w = 84, h = 12},
  buyMoonBtn = {x = GAME_W - 90, y = 8, w = 82, h = 12},
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
    pointBlend = 1 / (1 + distSq / 18000)
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

local function moonCost()
  if state.moonsPurchased == 0 then
    return 0
  end
  return 5
end

local function createOrbitalParams(config, index)
  local band = math.floor(index / config.bandCapacity)
  local tilt = config.tiltMin + love.math.random() * config.tiltRange
  return {
    angle = love.math.random() * math.pi * 2,
    radius = config.baseRadius + band * config.bandStep + love.math.random() * 2 - 1,
    flatten = math.cos(tilt),
    depthScale = math.sin(tilt),
    plane = love.math.random() * math.pi * 2,
    speed = config.speedMin + love.math.random() * config.speedRange,
  }
end

local function recomputeViewport()
  local w, h = love.graphics.getDimensions()
  scale = math.min(w / GAME_W, h / GAME_H)
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

local updateOrbiterPosition

local function addMoon()
  local cost = moonCost()
  if state.orbits < cost then
    return
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
end

local function addSatellite()
  if #state.moons < 1 then
    return
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
  table.insert(moon.childSatellites, {
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
  })
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
  love.graphics.setLineWidth(1)

  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)
  local px, py, pz
  for a = 0, math.pi * 2 + 0.14, 0.14 do
    local ox = math.cos(a) * orbiter.radius
    local oy = math.sin(a) * orbiter.radius * orbiter.flatten
    local x = cx + ox * cp - oy * sp
    local y = cy + ox * sp + oy * cp
    local z = math.sin(a) * (orbiter.depthScale or 1)
    if px then
      local segZ = (pz + z) * 0.5
      if (frontPass and segZ > 0) or ((not frontPass) and segZ <= 0) then
        local mx = (px + x) * 0.5
        local my = (py + y) * 0.5
        local segLight = depthLight(segZ, 0.10, 1.10, mx, my)
        local segAlpha = 0.12 + segLight * 0.60
        setColorScaled(palette.text, 1, segAlpha)
        love.graphics.line(math.floor(px + 0.5), math.floor(py + 0.5), math.floor(x + 0.5), math.floor(y + 0.5))
      end
    end
    px, py, pz = x, y, z
  end
end

local function drawPlanet()
  setColorScaled(palette.planetCore, 1, 1)
  love.graphics.circle("fill", cx, cy, BODY_VISUAL.planetRadius, 36)
end

local function drawOrbitalTrail(orbiter, trailLen, color, headAlpha, tailAlpha)
  local radius = math.max(orbiter.radius, 1)
  local arcAngle = trailLen / radius
  local stepCount = math.max(4, math.ceil(arcAngle / 0.06))
  local stepAngle = arcAngle / stepCount
  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)
  local prevX, prevY

  for i = 0, stepCount do
    local a = orbiter.angle - stepAngle * i
    local ox = math.cos(a) * orbiter.radius
    local oy = math.sin(a) * orbiter.radius * orbiter.flatten
    local x = cx + ox * cp - oy * sp
    local y = cy + ox * sp + oy * cp
    if prevX then
      local t = i / stepCount
      local alpha = lerp(headAlpha or 0.35, tailAlpha or 0.02, t)
      setColorScaled(color, 1, alpha)
      love.graphics.line(prevX, prevY, x, y)
    end
    prevX, prevY = x, y
  end
end

local function drawMoon(moon)
  local baseTrailLen = math.min(moon.radius * 2.2, 20 + moon.boost * 28)
  drawOrbitalTrail(moon, baseTrailLen, palette.moonFront, 0.48, 0.03)
  setColorScaled(palette.moonFront, 1, 1)
  love.graphics.circle("fill", moon.x, moon.y, BODY_VISUAL.moonRadius, 18)

  local childSatellites = moon.childSatellites or {}
  if #childSatellites > 0 then
    for _, child in ipairs(childSatellites) do
      local cp = math.cos(child.plane)
      local sp = math.sin(child.plane)
      local ox = math.cos(child.angle) * child.radius
      local oy = math.sin(child.angle) * child.radius * child.flatten
      local sx = moon.x + ox * cp - oy * sp
      local sy = moon.y + ox * sp + oy * cp
      local sz = math.sin(child.angle) * (child.depthScale or 1)
      local childLight = depthLight(sz, 0.35, 0.88, sx, sy)
      setOrbiterShadedColor(palette.satelliteBack, smoothstep((sz + 1) * 0.5), childLight, 0.88)
      love.graphics.circle("fill", sx, sy, BODY_VISUAL.moonChildSatelliteRadius, 12)
    end
  end
end

local function drawSatellite(satellite)
  local baseTrailLen = math.min(satellite.radius * 2.2, 16 + satellite.boost * 22)
  drawOrbitalTrail(satellite, baseTrailLen, palette.satelliteFront, 0.44, 0.02)
  setColorScaled(palette.satelliteFront, 1, 1)
  love.graphics.circle("fill", satellite.x, satellite.y, BODY_VISUAL.satelliteRadius, 18)
end

local function drawHud()
  love.graphics.setColor(palette.text)
  love.graphics.print("ORB " .. tostring(state.orbits), 8, 7)
  love.graphics.setColor(palette.muted)
  love.graphics.print("M " .. tostring(#state.moons) .. "  S " .. tostring(#state.satellites), 72, 7)

  local moonBuyCost = moonCost()
  local canBuyMoon = state.orbits >= moonBuyCost
  local moonAlpha = canBuyMoon and 1 or 0.45
  setColorScaled(palette.moonFront, 1, moonAlpha)
  love.graphics.circle("fill", ui.buyMoonBtn.x + 4, ui.buyMoonBtn.y + 6, 2, 12)
  setColorScaled(palette.text, 1, moonAlpha)
  local moonCostText = moonBuyCost == 0 and "FREE" or tostring(moonBuyCost)
  love.graphics.print("MOON " .. moonCostText, ui.buyMoonBtn.x + 10, ui.buyMoonBtn.y + 1)

  local canBuySatellite = #state.moons >= 1
  local satAlpha = canBuySatellite and 1 or 0.45
  setColorScaled(palette.satelliteFront, 1, satAlpha)
  love.graphics.circle("fill", ui.buySatelliteBtn.x + 4, ui.buySatelliteBtn.y + 6, 1.8, 12)
  setColorScaled(palette.satelliteFront, 1, satAlpha * 0.60)
  love.graphics.circle("line", ui.buySatelliteBtn.x + 4, ui.buySatelliteBtn.y + 6, 3.1, 12)
  setColorScaled(palette.text, 1, satAlpha)
  love.graphics.print("SAT 1 MOON", ui.buySatelliteBtn.x + 10, ui.buySatelliteBtn.y + 1)

  love.graphics.setColor(palette.muted)
  if zoom > 1.005 then
    love.graphics.print(string.format("ZOOM %.1fx  SCROLL TO ZOOM", zoom), 8, GAME_H - 22)
  else
    love.graphics.print("SCROLL TO ZOOM", 8, GAME_H - 22)
  end
  love.graphics.print("B FULLSCREEN", 8, GAME_H - 12)
end

local function drawOrbiterTooltip()
  local orbiter = state.selectedOrbiter
  ui.moonAddSatelliteBtn.visible = false
  ui.moonAddSatelliteBtn.enabled = false
  if not orbiter then
    return
  end

  local fade = 0.20 + depthLight(orbiter.z, 0.0, 1.0, orbiter.x, orbiter.y) * 0.75
  local rpm = (orbiter.speed * (1 + orbiter.boost)) * (60 / (math.pi * 2))
  local title = orbiter.kind == "satellite" and "SATELLITE" or "MOON"
  local line1 = string.format("%s  REV %d", title, orbiter.revolutions)
  local line2 = string.format("RPM %.2f", rpm)
  local textW = math.max(love.graphics.getFont():getWidth(line1), love.graphics.getFont():getWidth(line2))
  local padX = 6
  local boxW = textW + padX * 2
  local boxH = 20
  local boxX = GAME_W - boxW - 8
  local boxY = GAME_H - boxH - 8
  local anchorX = boxX
  local anchorY = boxY + math.floor(boxH * 0.5)

  local zoomedX = (orbiter.x - cx) * zoom + cx
  local zoomedY = (orbiter.y - cy) * zoom + cy

  setColorScaled(palette.text, 1, 0.55 * fade)
  love.graphics.line(anchorX, anchorY, zoomedX, zoomedY)
  love.graphics.circle("fill", zoomedX, zoomedY, 1.2, 8)

  setColorScaled(palette.panel, 1, 0.60 * fade)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
  setColorScaled(palette.text, 1, fade)
  love.graphics.print(line1, boxX + padX, boxY + 3)
  love.graphics.print(line2, boxX + padX, boxY + 11)

  if orbiter.kind == "moon" then
    local btnW = math.max(boxW, 76)
    local btnH = 11
    local btnX = boxX
    local btnY = boxY + boxH + 3
    local canAddSatellite = #state.satellites >= 3
    local btnAlpha = canAddSatellite and fade or fade * 0.45

    ui.moonAddSatelliteBtn.x = btnX
    ui.moonAddSatelliteBtn.y = btnY
    ui.moonAddSatelliteBtn.w = btnW
    ui.moonAddSatelliteBtn.h = btnH
    ui.moonAddSatelliteBtn.visible = true
    ui.moonAddSatelliteBtn.enabled = canAddSatellite

    setColorScaled(palette.panel, 1, 0.60 * btnAlpha)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    setColorScaled(palette.panelEdge, 1, 0.60 * btnAlpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    setColorScaled(palette.text, 1, btnAlpha)
    love.graphics.print("ADD SAT -3 S", btnX + 6, btnY + 2)
  end
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setFont(love.graphics.newFont("m5x7.ttf", 16))
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("none")
  setBorderlessFullscreen(false)

  canvas = love.graphics.newCanvas(GAME_W, GAME_H)
  canvas:setFilter("nearest", "nearest")

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
  state.time = state.time + dt

  for _, moon in ipairs(state.moons) do
    local prev = moon.angle
    updateOrbiterBoost(moon, dt)
    local effectiveSpeed = moon.speed * (1 + moon.boost)

    moon.angle = moon.angle + effectiveSpeed * dt

    local prevTurns = math.floor(prev / (math.pi * 2))
    local newTurns = math.floor(moon.angle / (math.pi * 2))
    if newTurns > prevTurns then
      local turnsGained = newTurns - prevTurns
      state.orbits = state.orbits + turnsGained
      moon.revolutions = moon.revolutions + turnsGained
    end

    updateOrbiterPosition(moon)

    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      local prev = child.angle
      local effectiveSpeed = child.speed * (1 + child.boost)
      child.angle = child.angle + effectiveSpeed * dt
      child.boost = clamp(child.boost - 0.60 * dt, 0, 1.2)

      local prevTurns = math.floor(prev / (math.pi * 2))
      local newTurns = math.floor(child.angle / (math.pi * 2))
      if newTurns > prevTurns then
        local turnsGained = newTurns - prevTurns
        state.orbits = state.orbits + turnsGained
        child.revolutions = child.revolutions + turnsGained
      end
    end
  end

  for _, satellite in ipairs(state.satellites) do
    local prev = satellite.angle
    updateOrbiterBoost(satellite, dt)
    local effectiveSpeed = satellite.speed * (1 + satellite.boost)

    satellite.angle = satellite.angle + effectiveSpeed * dt

    local prevTurns = math.floor(prev / (math.pi * 2))
    local newTurns = math.floor(satellite.angle / (math.pi * 2))
    if newTurns > prevTurns then
      local turnsGained = newTurns - prevTurns
      state.orbits = state.orbits + turnsGained
      satellite.revolutions = satellite.revolutions + turnsGained
    end

    updateOrbiterPosition(satellite)
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  local gx, gy = toGameSpace(x, y)
  if gx < 0 or gy < 0 or gx > GAME_W or gy > GAME_H then
    return
  end

  if gx >= ui.buyMoonBtn.x and gx <= ui.buyMoonBtn.x + ui.buyMoonBtn.w and gy >= ui.buyMoonBtn.y and gy <= ui.buyMoonBtn.y + ui.buyMoonBtn.h then
    addMoon()
    return
  end

  if gx >= ui.buySatelliteBtn.x and gx <= ui.buySatelliteBtn.x + ui.buySatelliteBtn.w and gy >= ui.buySatelliteBtn.y and gy <= ui.buySatelliteBtn.y + ui.buySatelliteBtn.h then
    local removedMoon = state.moons[#state.moons]
    addSatellite()
    if state.selectedOrbiter == removedMoon then
      state.selectedOrbiter = nil
    end
    return
  end

  if ui.moonAddSatelliteBtn.visible and gx >= ui.moonAddSatelliteBtn.x and gx <= ui.moonAddSatelliteBtn.x + ui.moonAddSatelliteBtn.w and gy >= ui.moonAddSatelliteBtn.y and gy <= ui.moonAddSatelliteBtn.y + ui.moonAddSatelliteBtn.h then
    if ui.moonAddSatelliteBtn.enabled then
      addSatelliteToMoon(state.selectedOrbiter)
    end
    return
  end

  local wx, wy = toWorldSpace(x, y)
  local planetDx = wx - cx
  local planetDy = wy - cy
  local planetHitR = BODY_VISUAL.planetRadius
  if planetDx * planetDx + planetDy * planetDy <= planetHitR * planetHitR then
    triggerPlanetImpulse()
    return
  end

  for i = #state.moons, 1, -1 do
    local moon = state.moons[i]
    local dx = wx - moon.x
    local dy = wy - moon.y
    local moonHitR = BODY_VISUAL.moonRadius + 2
    if dx * dx + dy * dy <= moonHitR * moonHitR then
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
      state.selectedOrbiter = satellite
      return
    end
  end

  state.selectedOrbiter = nil
end

function love.draw()
  love.graphics.setCanvas(canvas)
  drawBackground()

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(zoom, zoom)
  love.graphics.translate(-cx, -cy)

  drawSelectedOrbit(false)

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
  drawSelectedOrbit(true)
  for _, s in ipairs(satFront) do
    drawSatellite(s)
  end
  for _, m in ipairs(front) do
    drawMoon(m)
  end

  love.graphics.pop()

  drawOrbiterTooltip()
  drawHud()

  love.graphics.setCanvas()
  love.graphics.clear(palette.space)

  love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
end
