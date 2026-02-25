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

local canvas
local scale = 1
local offsetX = 0
local offsetY = 0

local cx = math.floor(GAME_W / 2)
local cy = math.floor(GAME_H / 2)

local palette = {
  space = {0.04, 0.06, 0.12, 1},
  nebulaA = {0.11, 0.15, 0.24, 1},
  nebulaB = {0.16, 0.21, 0.34, 1},
  starA = {0.23, 0.32, 0.48, 1},
  starB = {0.45, 0.57, 0.78, 1},
  orbit = {0.20, 0.25, 0.40, 1},
  panel = {0.12, 0.16, 0.24, 1},
  panelEdge = {0.28, 0.35, 0.50, 1},
  text = {0.90, 0.93, 0.99, 1},
  muted = {0.63, 0.68, 0.79, 1},
  accent = {1.0, 0.82, 0.35, 1},
  planetDark = {0.13, 0.31, 0.42, 1},
  planetMid = {0.25, 0.50, 0.66, 1},
  planetLight = {0.47, 0.82, 1.0, 1},
  moonFront = {1.0, 0.88, 0.48, 1},
  moonBack = {0.58, 0.52, 0.33, 1},
  satelliteFront = {0.72, 0.91, 1.0, 1},
  satelliteBack = {0.43, 0.58, 0.68, 1},
  trail = {1.0, 0.80, 0.42, 0.35},
  satelliteTrail = {0.62, 0.88, 1.0, 0.35},
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

local function setColorScaled(color, lightScale, alphaScale)
  local light = lightScale or 1
  local alpha = alphaScale or 1
  love.graphics.setColor(
    clamp(color[1] * light, 0, 1),
    clamp(color[2] * light, 0, 1),
    clamp(color[3] * light, 0, 1),
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
  love.graphics.setColor(
    clamp(r * light, 0, 1),
    clamp(g * light, 0, 1),
    clamp(b * light, 0, 1),
    clamp(a * alpha, 0, 1)
  )
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
        love.graphics.setColor(1, 1, 1, segAlpha)
        love.graphics.line(math.floor(px + 0.5), math.floor(py + 0.5), math.floor(x + 0.5), math.floor(y + 0.5))
      end
    end
    px, py, pz = x, y, z
  end
end

local function drawPlanet()
  drawCircle(cx, cy, BODY_VISUAL.planetRadius, palette.planetMid)
end

local function drawMoon(moon)
  local light = depthLight(moon.z, 0.42, 0.68, moon.x, moon.y)
  local sideBlend = smoothstep((moon.z + 1) * 0.5)
  local trailX = moon.x - math.cos(moon.angle) * (3.0 + moon.boost * 2.4)
  local trailY = moon.y - math.sin(moon.angle) * (3.0 + moon.boost * 2.4)
  setColorScaled(palette.trail, 0.60 + light * 0.42, 0.45 + light * 0.45)
  love.graphics.line(trailX, trailY, moon.x, moon.y)

  setColorBlendScaled(palette.moonBack, palette.moonFront, sideBlend, light)
  love.graphics.circle("fill", moon.x, moon.y, BODY_VISUAL.moonRadius, 18)

  if moon.boost > 0.05 then
    setColorScaled(palette.accent, 0.70 + light * 0.48, 0.60 + light * 0.30)
    love.graphics.arc("fill", "open", moon.x, moon.y, BODY_VISUAL.moonRadius + 2 + moon.boost * 2, moon.angle - 0.35, moon.angle + 0.35, 10)
  end

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
      setColorBlendScaled(palette.satelliteBack, palette.satelliteFront, smoothstep((sz + 1) * 0.5), childLight, 0.88)
      love.graphics.circle("fill", sx, sy, BODY_VISUAL.moonChildSatelliteRadius, 12)
    end
  end
end

local function drawSatellite(satellite)
  local light = depthLight(satellite.z, 0.40, 0.72, satellite.x, satellite.y)
  local sideBlend = smoothstep((satellite.z + 1) * 0.5)
  local trailX = satellite.x - math.cos(satellite.angle) * (2.5 + satellite.boost * 2.0)
  local trailY = satellite.y - math.sin(satellite.angle) * (2.5 + satellite.boost * 2.0)
  setColorScaled(palette.satelliteTrail, 0.62 + light * 0.46, 0.43 + light * 0.50)
  love.graphics.line(trailX, trailY, satellite.x, satellite.y)

  setColorBlendScaled(palette.satelliteBack, palette.satelliteFront, sideBlend, light)
  love.graphics.circle("fill", satellite.x, satellite.y, BODY_VISUAL.satelliteRadius, 18)

  if satellite.boost > 0.05 then
    setColorBlendScaled(palette.satelliteBack, palette.satelliteFront, sideBlend, 0.75 + light * 0.42, 0.62 + light * 0.28)
    love.graphics.arc("line", "open", satellite.x, satellite.y, BODY_VISUAL.satelliteRadius + 1.5 + satellite.boost * 1.5, satellite.angle - 0.35, satellite.angle + 0.35, 10)
  end
end

local function drawHud()
  love.graphics.setColor(palette.text)
  love.graphics.print("ORB " .. tostring(state.orbits), 8, 7)
  love.graphics.setColor(palette.muted)
  love.graphics.print("M " .. tostring(#state.moons) .. "  S " .. tostring(#state.satellites), 72, 7)

  local moonBuyCost = moonCost()
  local canBuyMoon = state.orbits >= moonBuyCost
  local moonAlpha = canBuyMoon and 1 or 0.45
  love.graphics.setColor(1.0, 0.88, 0.48, moonAlpha)
  love.graphics.circle("fill", ui.buyMoonBtn.x + 4, ui.buyMoonBtn.y + 6, 2, 12)
  love.graphics.setColor(1, 1, 1, moonAlpha)
  local moonCostText = moonBuyCost == 0 and "FREE" or tostring(moonBuyCost)
  love.graphics.print("MOON " .. moonCostText, ui.buyMoonBtn.x + 10, ui.buyMoonBtn.y + 1)

  local canBuySatellite = #state.moons >= 1
  local satAlpha = canBuySatellite and 1 or 0.45
  love.graphics.setColor(0.72, 0.91, 1.0, satAlpha)
  love.graphics.circle("fill", ui.buySatelliteBtn.x + 4, ui.buySatelliteBtn.y + 6, 1.8, 12)
  love.graphics.setColor(0.72, 0.91, 1.0, satAlpha * 0.60)
  love.graphics.circle("line", ui.buySatelliteBtn.x + 4, ui.buySatelliteBtn.y + 6, 3.1, 12)
  love.graphics.setColor(1, 1, 1, satAlpha)
  love.graphics.print("SAT 1 MOON", ui.buySatelliteBtn.x + 10, ui.buySatelliteBtn.y + 1)

  love.graphics.setColor(palette.muted)
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

  love.graphics.setColor(1, 1, 1, 0.55 * fade)
  love.graphics.line(anchorX, anchorY, orbiter.x, orbiter.y)
  love.graphics.circle("fill", orbiter.x, orbiter.y, 1.2, 8)

  love.graphics.setColor(0.07, 0.09, 0.16, 0.60 * fade)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
  love.graphics.setColor(1, 1, 1, fade)
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

    love.graphics.setColor(0.07, 0.09, 0.16, 0.60 * btnAlpha)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    love.graphics.setColor(0.72, 0.91, 1.0, 0.60 * btnAlpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1, btnAlpha)
    love.graphics.print("ADD SAT -3 S", btnX + 6, btnY + 2)
  end
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setFont(love.graphics.newFont(10))
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

function love.update(dt)
  dt = math.min(dt, 0.05)
  state.time = state.time + dt

  for _, moon in ipairs(state.moons) do
    local prev = moon.angle
    local effectiveSpeed = moon.speed * (1 + moon.boost)

    moon.angle = moon.angle + effectiveSpeed * dt
    moon.boost = clamp(moon.boost - 0.45 * dt, 0, 1.2)

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
    local effectiveSpeed = satellite.speed * (1 + satellite.boost)

    satellite.angle = satellite.angle + effectiveSpeed * dt
    satellite.boost = clamp(satellite.boost - 0.55 * dt, 0, 1.2)

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

  for i = #state.moons, 1, -1 do
    local moon = state.moons[i]
    local dx = gx - moon.x
    local dy = gy - moon.y
    local moonHitR = BODY_VISUAL.moonRadius + 2
    if dx * dx + dy * dy <= moonHitR * moonHitR then
      state.selectedOrbiter = moon
      return
    end
  end

  for i = #state.satellites, 1, -1 do
    local satellite = state.satellites[i]
    local dx = gx - satellite.x
    local dy = gy - satellite.y
    local satelliteHitR = BODY_VISUAL.satelliteRadius + 1.5
    if dx * dx + dy * dy <= satelliteHitR * satelliteHitR then
      state.selectedOrbiter = satellite
      return
    end
  end
end

function love.draw()
  love.graphics.setCanvas(canvas)
  drawBackground()
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

  drawOrbiterTooltip()
  drawHud()

  love.graphics.setCanvas()
  love.graphics.clear(0.06, 0.08, 0.12, 1)

  love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
end
