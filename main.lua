local GAME_W = 1280
local GAME_H = 720
local TWO_PI = math.pi * 2
local RAD_PER_SECOND_TO_RPM = 60 / TWO_PI
local CAMERA_LIGHT_HEIGHT = 280
local CAMERA_LIGHT_Z_SCALE = 220
local CAMERA_LIGHT_AMBIENT = 0.10
local CAMERA_LIGHT_INTENSITY = 2.85
local CAMERA_LIGHT_FALLOFF = 1 / (900 * 900)
local LIGHT_ORBIT_PERIOD_SECONDS = 120
local LIGHT_ORBIT_RADIUS_X = GAME_W * 0.62
local LIGHT_ORBIT_RADIUS_Y = GAME_H * 0.42
local LIGHT_ORBIT_Z_BASE = 0.38
local LIGHT_ORBIT_Z_VARIATION = 0.16
local LIGHT_SOURCE_MARKER_RADIUS = 8
local LIGHT_SOURCE_HIT_PADDING = 6
local ZOOM_MIN = 0.55
local ZOOM_MAX = 2
local PERSPECTIVE_Z_STRENGTH = 0.10
local PERSPECTIVE_MIN_SCALE = 0.88
local PERSPECTIVE_MAX_SCALE = 1.18
local DEPTH_SORT_HYSTERESIS = 0.035
local BODY_SHADE_DARK_FLOOR_TONE = 0.22
local BODY_SHADE_ECLIPSE_THRESHOLD = 0.16
local BODY_SHADE_CONTRAST = 1.75
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
    altitudeCapacity = 6,
    altitudeSlotStep = 0.11,
    altitudeBandStep = 0.20,
    tiltMin = 0.30,
    tiltRange = 1.2,
    speedMin = 0.70,
    speedRange = 0.20,
  },
  moonChildSatellite = {
    bandCapacity = 4,
    baseRadius = 10,
    bandStep = 2.0,
    altitudeCapacity = 4,
    altitudeSlotStep = 0.08,
    altitudeBandStep = 0.12,
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
local GRAVITY_WELL_INNER_SCALE = 0.01
local GRAVITY_WELL_RADIUS_SCALE = 1.3
local GRAVITY_WELL_RADIAL_STRENGTH = 0.03
local GRAVITY_WELL_SWIRL_STRENGTH = 0.0010
local SPEED_WAVE_COST = 25
local SPEED_CLICK_COST = 15
local BLACK_HOLE_SHADER_COST = 100
local SPEED_WAVE_CLICK_THRESHOLD = 10
local SPEED_WAVE_MULTIPLIER = 1.5
local SPEED_WAVE_DURATION = 5
local SPEED_WAVE_RIPPLE_LIFETIME = 1.1
local SPEED_WAVE_RIPPLE_WIDTH_START = 0.020
local SPEED_WAVE_RIPPLE_WIDTH_END = 0.092
local SPEED_WAVE_RIPPLE_RADIAL_STRENGTH = 0.062
local SPEED_WAVE_RIPPLE_SWIRL_STRENGTH = 0.0018
local SPEED_WAVE_RIPPLE_END_PADDING = 0.12
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
local SPHERE_SHADE_STYLE_OFF = {
  contrast = 1.08,
  darkFloor = BODY_SHADE_DARK_FLOOR_TONE,
  toneSteps = 0,
  facetSides = 0,
  ditherStrength = 0,
  ditherScale = 1,
}
local SPHERE_SHADE_STYLE_ON = {
  contrast = 0.94,
  darkFloor = BODY_SHADE_DARK_FLOOR_TONE + 0.01,
  toneSteps = 12,
  facetSides = 0,
  ditherStrength = 0.012,
  ditherScale = 1.60,
}

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
local sphereShader
local spherePixel
local gravityWellShader
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
  renderOrbiters = {},
  stars = {},
  time = 0,
  nextRenderOrder = 0,
  selectedOrbiter = nil,
  selectedLightSource = false,
  sphereDitherEnabled = true,
  borderlessFullscreen = false,
  orbitPopTexts = {},
  planetBounceTime = 0,
  speedWaveUnlocked = false,
  speedClickUnlocked = false,
  blackHoleShaderUnlocked = false,
  planetClickCount = 0,
  speedWaveTimer = 0,
  speedWaveRipples = {},
  speedWaveText = nil,
  planetVisualRadius = BODY_VISUAL.planetRadius,
}

local ui = {
  buyMegaPlanetBtn = {x = 0, y = 0, w = 0, h = 0},
  buyPlanetBtn = {x = 0, y = 0, w = 0, h = 0},
  buyMoonBtn = {x = 0, y = 0, w = 0, h = 0},
  buySatelliteBtn = {x = 0, y = 0, w = 0, h = 0},
  speedWaveBtn = {x = 0, y = 0, w = 0, h = 0},
  speedClickBtn = {x = 0, y = 0, w = 0, h = 0},
  blackHoleShaderBtn = {x = 0, y = 0, w = 0, h = 0},
  orbiterActionBtn = {x = 0, y = 0, w = 0, h = 0, visible = false, enabled = false, action = nil},
}

local function activeSphereShadeStyle()
  if state.sphereDitherEnabled then
    return SPHERE_SHADE_STYLE_ON
  end
  return SPHERE_SHADE_STYLE_OFF
end

local function toggleSphereShadeStyle()
  state.sphereDitherEnabled = not state.sphereDitherEnabled
end

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

local function sideLightWorldPosition()
  local cycle = (state.time % LIGHT_ORBIT_PERIOD_SECONDS) / LIGHT_ORBIT_PERIOD_SECONDS
  -- Start from the left and orbit the playfield over two minutes.
  local a = cycle * TWO_PI + math.pi
  local x = cx + math.cos(a) * LIGHT_ORBIT_RADIUS_X
  local y = cy + math.sin(a) * LIGHT_ORBIT_RADIUS_Y
  local z = LIGHT_ORBIT_Z_BASE + math.sin(a + math.pi * 0.5) * LIGHT_ORBIT_Z_VARIATION
  return x, y, z
end

local function lightProjectionZ(z)
  return (z or 0) + (CAMERA_LIGHT_HEIGHT / zoom) / CAMERA_LIGHT_Z_SCALE
end

local function lightDepthForZ(z)
  return lightProjectionZ(z) * CAMERA_LIGHT_Z_SCALE
end

local function planetShadowFactorAt(x, y, z)
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local lightDepth = lightDepthForZ(lightZ)

  local dirX = lightX - cx
  local dirY = lightY - cy
  local dirZ = lightDepth
  local dirLen = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
  if dirLen < 0.0001 then
    return 1
  end

  dirX = dirX / dirLen
  dirY = dirY / dirLen
  dirZ = dirZ / dirLen

  local vx = x - cx
  local vy = y - cy
  local vz = (z or 0) * CAMERA_LIGHT_Z_SCALE

  -- Behind the planet relative to the side light.
  local along = -(vx * dirX + vy * dirY + vz * dirZ)
  if along <= 0 then
    return 1
  end

  local ax = -dirX * along
  local ay = -dirY * along
  local az = -dirZ * along
  local offX = vx - ax
  local offY = vy - ay
  local offZ = vz - az
  local radial = math.sqrt(offX * offX + offY * offY + offZ * offZ)

  local shadowRadius = BODY_VISUAL.planetRadius * (1 + along / math.max(1, dirLen * 0.9))
  local softEdge = shadowRadius * 0.60 + 6
  if radial >= shadowRadius + softEdge then
    return 1
  end

  local edgeT = clamp((radial - shadowRadius) / softEdge, 0, 1)
  local coreShadow = 1 - smoothstep(edgeT)
  local depthStrength = 1 - math.exp(-along / (BODY_VISUAL.planetRadius * 1.6))
  local shadowStrength = coreShadow * depthStrength * 0.90
  return clamp(1 - shadowStrength, 0.02, 1)
end

local function cameraLightAt(x, y, z)
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local depth = (z or 0) * CAMERA_LIGHT_Z_SCALE
  local lightDepth = lightDepthForZ(lightZ)
  local dx = lightX - x
  local dy = lightY - y
  local dz = lightDepth - depth
  local distSq = dx * dx + dy * dy + dz * dz
  local attenuation = 1 / (1 + distSq * CAMERA_LIGHT_FALLOFF)
  local direct = CAMERA_LIGHT_AMBIENT + attenuation * CAMERA_LIGHT_INTENSITY
  local shadow = planetShadowFactorAt(x, y, z)
  return clamp(direct * shadow, 0.01, 1.25)
end

local function updateOrbiterLight(orbiter)
  orbiter.light = cameraLightAt(orbiter.x, orbiter.y, orbiter.z)
end

local function orbiterRenderDepth(orbiter)
  if not orbiter then
    return 0
  end
  if orbiter.sortDepth == nil then
    return orbiter.z or 0
  end
  return orbiter.sortDepth
end

local function updateOrbiterRenderDepth(orbiter)
  local targetDepth = orbiter.z or 0
  local depth = orbiter.sortDepth
  if depth == nil then
    orbiter.sortDepth = targetDepth
    return
  end
  if targetDepth > depth + DEPTH_SORT_HYSTERESIS then
    orbiter.sortDepth = targetDepth - DEPTH_SORT_HYSTERESIS
  elseif targetDepth < depth - DEPTH_SORT_HYSTERESIS then
    orbiter.sortDepth = targetDepth + DEPTH_SORT_HYSTERESIS
  end
end

local function assignRenderOrder(orbiter)
  state.nextRenderOrder = state.nextRenderOrder + 1
  orbiter.renderOrder = state.nextRenderOrder
end

local function perspectiveScaleForZ(z)
  local denom = 1 - (z or 0) * PERSPECTIVE_Z_STRENGTH
  if denom < 0.35 then
    denom = 0.35
  end
  return clamp(1 / denom, PERSPECTIVE_MIN_SCALE, PERSPECTIVE_MAX_SCALE)
end

local function projectWorldPoint(x, y, z)
  local scale = perspectiveScaleForZ(z or 0)
  return cx + (x - cx) * scale, cy + (y - cy) * scale, scale
end

local function lightSourceProjected()
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local projectedZ = lightProjectionZ(lightZ)
  local px, py, projectScale = projectWorldPoint(lightX, lightY, projectedZ)
  return lightX, lightY, lightZ, projectedZ, px, py, projectScale
end

local function lightSourceHitRadius(projectScale)
  return math.max(4, (LIGHT_SOURCE_MARKER_RADIUS + LIGHT_SOURCE_HIT_PADDING) * projectScale)
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

local function setLitColorDirect(r, g, b, lightScale, alpha)
  local light = lightScale or 1
  local sr = clamp(r * light, 0, 1)
  local sg = clamp(g * light, 0, 1)
  local sb = clamp(b * light, 0, 1)
  local sw = nearestPaletteSwatch(sr, sg, sb)
  love.graphics.setColor(sw[1], sw[2], sw[3], clamp(alpha or 1, 0, 1))
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
    local popLight = cameraLightAt(pop.x, pop.y, 0)
    setLitColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], popLight, fade)
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

local function blackHoleShaderCost()
  return BLACK_HOLE_SHADER_COST
end

local function createOrbitalParams(config, index)
  local band = config.fixedAltitude and 0 or math.floor(index / config.bandCapacity)
  local radiusJitter = config.fixedAltitude and 0 or (love.math.random() * 2 - 1)
  local tilt = config.tiltMin + love.math.random() * config.tiltRange
  local altitudeCapacity = math.max(1, config.altitudeCapacity or 1)
  local altitudeBand = math.floor(index / altitudeCapacity)
  local altitudeSlot = index % altitudeCapacity
  local centeredSlot = altitudeSlot - (altitudeCapacity - 1) * 0.5
  local zBase = centeredSlot * (config.altitudeSlotStep or 0) + altitudeBand * (config.altitudeBandStep or 0)
  local altitudeJitter = config.altitudeJitter or 0
  if altitudeJitter ~= 0 then
    zBase = zBase + (love.math.random() * 2 - 1) * altitudeJitter
  end
  return {
    angle = love.math.random() * math.pi * 2,
    radius = config.baseRadius + band * config.bandStep + radiusJitter,
    flatten = math.cos(tilt),
    depthScale = math.sin(tilt),
    zBase = zBase,
    plane = love.math.random() * math.pi * 2,
    speed = config.speedMin + love.math.random() * config.speedRange,
  }
end

local function recomputeViewport()
  local w, h = love.graphics.getDimensions()
  local rawScale = math.min(w / GAME_W, h / GAME_H)
  if state.borderlessFullscreen then
    -- In borderless fullscreen, use exact scale so the game fills the display.
    scale = rawScale
  elseif rawScale >= 1 then
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
    zBase = orbital.zBase or 0,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    light = 1,
    kind = "mega-planet",
    revolutions = 0,
  }

  updateOrbiterPosition(megaPlanet)
  assignRenderOrder(megaPlanet)
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
    zBase = orbital.zBase or 0,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    light = 1,
    kind = "planet",
    revolutions = 0,
  }

  updateOrbiterPosition(planet)
  assignRenderOrder(planet)
  table.insert(state.planets, planet)
  return true
end

local function addMoon(parentOrbiter)
  if #state.moons >= MAX_MOONS then
    return false
  end
  if parentOrbiter and parentOrbiter.kind ~= "planet" and parentOrbiter.kind ~= "mega-planet" then
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
    zBase = orbital.zBase or 0,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    light = 1,
    kind = "moon",
    parentOrbiter = parentOrbiter,
    revolutions = 0,
    childSatellites = {},
  }

  updateOrbiterPosition(moon)
  assignRenderOrder(moon)
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
    zBase = orbital.zBase or 0,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = cx,
    y = cy,
    z = 0,
    light = 1,
    kind = "satellite",
    revolutions = 0,
  }

  updateOrbiterPosition(satellite)
  assignRenderOrder(satellite)
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
    zBase = orbital.zBase or 0,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = {},
    x = moon.x,
    y = moon.y,
    z = 0,
    light = 1,
    kind = "moon-satellite",
    parentOrbiter = moon,
    parentMoon = moon,
    revolutions = 0,
  }
  updateOrbiterPosition(child)
  assignRenderOrder(child)
  table.insert(moon.childSatellites, child)
  return true
end

function orbiterOrbitOrigin(orbiter)
  local parent = orbiter and orbiter.parentOrbiter
  if parent then
    return parent.x, parent.y, parent.z or 0
  end
  return cx, cy, 0
end

updateOrbiterPosition = function(orbiter)
  local ox = math.cos(orbiter.angle) * orbiter.radius
  local oy = math.sin(orbiter.angle) * orbiter.radius * orbiter.flatten

  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)
  local originX, originY, originZ = orbiterOrbitOrigin(orbiter)

  orbiter.x = originX + ox * cp - oy * sp
  orbiter.y = originY + ox * sp + oy * cp
  orbiter.z = originZ + (orbiter.zBase or 0) + math.sin(orbiter.angle) * (orbiter.depthScale or 1)
  updateOrbiterRenderDepth(orbiter)
  updateOrbiterLight(orbiter)
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

local function buyBlackHoleShader()
  if state.blackHoleShaderUnlocked then
    return false
  end
  local cost = blackHoleShaderCost()
  if state.orbits < cost then
    return false
  end
  state.orbits = state.orbits - cost
  state.blackHoleShaderUnlocked = true
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

local function drawBackground()
  love.graphics.clear(palette.space)

  for _, s in ipairs(state.stars) do
    local twinkle = (math.sin(state.time * s.speed + s.phase) + 1) * 0.5
    if twinkle > 0.45 then
      love.graphics.setColor(palette.accent)
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
          local segLight = cameraLightAt((px + x) * 0.5, (py + y) * 0.5, segZ)
          setLitColorDirect(SELECTED_ORBIT_COLOR[1], SELECTED_ORBIT_COLOR[2], SELECTED_ORBIT_COLOR[3], segLight, 0.84)
          local sx0, sy0 = projectWorldPoint(px, py, pz)
          local sx1, sy1 = projectWorldPoint(x, y, z)
          love.graphics.line(math.floor(sx0 + 0.5), math.floor(sy0 + 0.5), math.floor(sx1 + 0.5), math.floor(sy1 + 0.5))
        end
      end
      px, py, pz = x, y, z
    end
  end

  love.graphics.setLineWidth(1)
  local originX, originY, originZ = orbiterOrbitOrigin(orbiter)
  drawOrbitPath(orbiter, originX, originY, originZ + (orbiter.zBase or 0))
end

local function drawSelectedLightOrbit(frontPass)
  if not state.selectedLightSource then
    return
  end

  local step = 0.08
  local px, py, pz, rawZ
  for a = 0, TWO_PI + step, step do
    local x = cx + math.cos(a) * LIGHT_ORBIT_RADIUS_X
    local y = cy + math.sin(a) * LIGHT_ORBIT_RADIUS_Y
    local z = LIGHT_ORBIT_Z_BASE + math.sin(a + math.pi * 0.5) * LIGHT_ORBIT_Z_VARIATION
    local projectedZ = lightProjectionZ(z)
    if px then
      local segProjZ = (pz + projectedZ) * 0.5
      if (frontPass and segProjZ > 0) or ((not frontPass) and segProjZ <= 0) then
        local segRawZ = (rawZ + z) * 0.5
        local segLight = cameraLightAt((px + x) * 0.5, (py + y) * 0.5, segRawZ)
        setLitColorDirect(SELECTED_ORBIT_COLOR[1], SELECTED_ORBIT_COLOR[2], SELECTED_ORBIT_COLOR[3], segLight, 0.58)
        local sx0, sy0 = projectWorldPoint(px, py, pz)
        local sx1, sy1 = projectWorldPoint(x, y, projectedZ)
        love.graphics.line(math.floor(sx0 + 0.5), math.floor(sy0 + 0.5), math.floor(sx1 + 0.5), math.floor(sy1 + 0.5))
      end
    end
    px, py, pz, rawZ = x, y, projectedZ, z
  end
end

local function drawLitSphere(x, y, z, radius, r, g, b, lightScale, segments)
  local px, py, projectScale = projectWorldPoint(x, y, z or 0)
  local pr = math.max(0.6, radius * projectScale)
  local sideCount = segments or 24
  local shadeStyle = activeSphereShadeStyle()
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local lightPx, lightPy = projectWorldPoint(lightX, lightY, lightProjectionZ(lightZ))
  local objDepth = (z or 0) * CAMERA_LIGHT_Z_SCALE
  local lightDepth = lightDepthForZ(lightZ)
  local lx = lightPx - px
  local ly = -(lightPy - py)
  local lz = (lightDepth - objDepth) / CAMERA_LIGHT_Z_SCALE
  local len = math.sqrt(lx * lx + ly * ly + lz * lz)
  if len < 0.0001 then
    lx, ly, lz = 1, 0, 0
  else
    lx = lx / len
    ly = ly / len
    lz = lz / len
  end

  local light = clamp(lightScale or 1, 0.02, 1.3)
  local occlusion = 1
  if (z or 0) < 0 then
    local shadowRadius = BODY_VISUAL.planetRadius + pr * 0.9
    local dx = px - cx
    local dy = py - cy
    local d = math.sqrt(dx * dx + dy * dy)
    if d < shadowRadius then
      local t = 1 - d / shadowRadius
      occlusion = 1 - smoothstep(t) * 0.45
    end
  end
  local bodyLight = light * occlusion
  local shadowFactor = planetShadowFactorAt(x, y, z) * occlusion
  local inEclipse = shadowFactor <= BODY_SHADE_ECLIPSE_THRESHOLD

  if inEclipse then
    setColorDirect(palette.space[1], palette.space[2], palette.space[3], 1)
    love.graphics.circle("fill", px, py, pr, sideCount)
    return
  end

  if sphereShader and spherePixel then
    local shaderLightPower = clamp(0.40 + bodyLight * 0.86, 0.30, 1.08)
    local shaderAmbient = clamp(0.16 + bodyLight * 0.14, 0, 0.40)
    local prevShader = love.graphics.getShader()
    love.graphics.setShader(sphereShader)
    sphereShader:send("baseColor", {clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)})
    sphereShader:send("lightVec", {lx, ly, lz})
    sphereShader:send("lightPower", shaderLightPower)
    sphereShader:send("ambient", shaderAmbient)
    sphereShader:send("contrast", shadeStyle.contrast or 1.08)
    sphereShader:send("darkFloor", clamp(shadeStyle.darkFloor or BODY_SHADE_DARK_FLOOR_TONE, 0, 1))
    sphereShader:send("toneSteps", shadeStyle.toneSteps or 0)
    sphereShader:send("facetSides", shadeStyle.facetSides or 0)
    sphereShader:send("ditherStrength", shadeStyle.ditherStrength or 0)
    sphereShader:send("ditherScale", shadeStyle.ditherScale or 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(spherePixel, px - pr, py - pr, 0, pr * 2, pr * 2)
    love.graphics.setShader(prevShader)
    return
  end

  setLitColorDirect(r, g, b, bodyLight, 1)
  love.graphics.circle("fill", px, py, pr, sideCount)
end

local function drawPlanet()
  local t = 1 - clamp(state.planetBounceTime / PLANET_BOUNCE_DURATION, 0, 1)
  local kick = math.sin(t * math.pi)
  local bounceScale = 1 + kick * 0.14 * (1 - t)
  local px, py, projScale = projectWorldPoint(cx, cy, 0)
  local pr = math.max(3, BODY_VISUAL.planetRadius * bounceScale * projScale)

  setColorDirect(0, 0, 0, 1)
  love.graphics.circle("fill", px, py, pr, 44)
  state.planetVisualRadius = pr * zoom
end

local function drawLightSource(frontPass)
  local lightX, lightY, lightZ, projectedZ, px, py, projectScale = lightSourceProjected()
  if frontPass then
    if projectedZ <= 0 then
      return
    end
  elseif projectedZ > 0 then
    return
  end

  local baseLight = clamp(cameraLightAt(lightX, lightY, lightZ) * 1.08, 0.45, 1.25)
  local coreR = math.max(2, LIGHT_SOURCE_MARKER_RADIUS * projectScale)
  local haloR = coreR * 1.9

  setLitColorDirect(swatch.bright[1], swatch.bright[2], swatch.bright[3], baseLight, 0.42)
  love.graphics.circle("fill", px, py, haloR, 32)
  setLitColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], baseLight, 0.95)
  love.graphics.circle("fill", px, py, coreR, 24)

  if state.selectedLightSource then
    local pulse = 0.5 + 0.5 * math.sin(state.time * 3.2)
    local ringR = lightSourceHitRadius(projectScale) + pulse * (2.8 * projectScale)
    setLitColorDirect(
      SELECTED_ORBIT_COLOR[1],
      SELECTED_ORBIT_COLOR[2],
      SELECTED_ORBIT_COLOR[3],
      clamp(baseLight * 1.04, 0.4, 1.25),
      0.92
    )
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", px, py, ringR, 36)
  end
end

local function activeSpeedWaveRippleParams()
  local ripples = state.speedWaveRipples
  local ripple = ripples[#ripples]
  if not ripple then
    return false, 0, 0, 0, 0
  end

  local t = clamp(ripple.age / ripple.life, 0, 1)
  local travel = smoothstep(t)
  local coreR = clamp((state.planetVisualRadius or BODY_VISUAL.planetRadius) / GAME_H, 0.002, 0.45)
  local maxDx = math.max(cx, GAME_W - cx)
  local maxDy = math.max(cy, GAME_H - cy)
  local edgeR = math.sqrt(maxDx * maxDx + maxDy * maxDy) / GAME_H + SPEED_WAVE_RIPPLE_END_PADDING
  local radius = lerp(coreR * 1.15, edgeR, travel)
  local halfWidth = lerp(SPEED_WAVE_RIPPLE_WIDTH_START, SPEED_WAVE_RIPPLE_WIDTH_END, travel)
  local rampIn = smoothstep(clamp(t / 0.08, 0, 1))
  local rampOut = 1 - smoothstep(clamp((t - 0.78) / 0.22, 0, 1))
  local strength = rampIn * rampOut
  return true,
    radius,
    halfWidth,
    SPEED_WAVE_RIPPLE_RADIAL_STRENGTH * strength,
    SPEED_WAVE_RIPPLE_SWIRL_STRENGTH * strength
end

local function drawOrbitalTrail(orbiter, trailLen, headAlpha, tailAlpha, originX, originY, originZ, lightScale)
  local radius = math.max(orbiter.radius, 1)
  local arcAngle = trailLen / radius
  local stepCount = math.max(4, math.ceil(arcAngle / 0.06))
  local stepAngle = arcAngle / stepCount
  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)
  local prevX, prevY, prevZ
  local centerX = originX or cx
  local centerY = originY or cy
  local centerZ = originZ or 0

  for i = 0, stepCount do
    local a = orbiter.angle - stepAngle * i
    local ox = math.cos(a) * orbiter.radius
    local oy = math.sin(a) * orbiter.radius * orbiter.flatten
    local x = centerX + ox * cp - oy * sp
    local y = centerY + ox * sp + oy * cp
    local z = centerZ + (orbiter.zBase or 0) + math.sin(a) * (orbiter.depthScale or 1)
    if prevX then
      local t = i / stepCount
      local alpha = lerp(headAlpha or 0.35, tailAlpha or 0.02, t)
      local midAngle = a + stepAngle * 0.5
      local r, g, b = computeOrbiterColor(midAngle)
      local trailZ = (prevZ + z) * 0.5
      local trailLight = lightScale or cameraLightAt((prevX + x) * 0.5, (prevY + y) * 0.5, trailZ)
      setLitColorDirect(r, g, b, trailLight, alpha)
      local sx0, sy0 = projectWorldPoint(prevX, prevY, prevZ)
      local sx1, sy1 = projectWorldPoint(x, y, z)
      love.graphics.line(sx0, sy0, sx1, sy1)
    end
    prevX, prevY, prevZ = x, y, z
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
      local z = moon.z + (child.zBase or 0) + math.sin(a) * (child.depthScale or 1)
      if px then
        local segZ = (pz + z) * 0.5
        if (frontPass and segZ > moon.z) or ((not frontPass) and segZ <= moon.z) then
          local segLight = cameraLightAt((px + x) * 0.5, (py + y) * 0.5, segZ)
          setLitColorDirect(pr, pg, pb, segLight, 0.52)
          local sx0, sy0 = projectWorldPoint(px, py, pz)
          local sx1, sy1 = projectWorldPoint(x, y, z)
          love.graphics.line(math.floor(sx0 + 0.5), math.floor(sy0 + 0.5), math.floor(sx1 + 0.5), math.floor(sy1 + 0.5))
        end
      end
      px, py, pz = x, y, z
    end
  end

  if hasActiveBoost(moon) then
    local baseTrailLen = math.min(moon.radius * 2.2, 20 + moon.boost * 28)
    local originX, originY, originZ = orbiterOrbitOrigin(moon)
    drawOrbitalTrail(moon, baseTrailLen, 0.48, 0.03, originX, originY, originZ, moon.light)
  end

  local childSatellites = moon.childSatellites or {}
  local showChildOrbitPaths = state.selectedOrbiter == moon
  love.graphics.setLineWidth(1)
  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, false)
    end
  end

  local moonR, moonG, moonB = computeOrbiterColor(moon.angle)
  drawLitSphere(moon.x, moon.y, moon.z, BODY_VISUAL.moonRadius, moonR, moonG, moonB, moon.light, 20)

  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, true)
    end
  end
end

local function drawMoonChildSatellite(child)
  local parentMoon = child.parentOrbiter or child.parentMoon
  if hasActiveBoost(child) then
    local baseTrailLen = math.min(child.radius * 2.2, 16 + child.boost * 22)
    local originX = parentMoon and parentMoon.x or cx
    local originY = parentMoon and parentMoon.y or cy
    local originZ = parentMoon and parentMoon.z or 0
    drawOrbitalTrail(child, baseTrailLen, 0.44, 0.02, originX, originY, originZ, child.light)
  end
  local childR, childG, childB = computeOrbiterColor(child.angle)
  drawLitSphere(child.x, child.y, child.z, BODY_VISUAL.moonChildSatelliteRadius, childR, childG, childB, child.light, 12)
end

local function drawOrbitPlanet(planet)
  if hasActiveBoost(planet) then
    local baseTrailLen = math.min(planet.radius * 2.2, 28 + planet.boost * 36)
    drawOrbitalTrail(planet, baseTrailLen, 0.5, 0.04, nil, nil, 0, planet.light)
  end
  local pr, pg, pb = computeOrbiterColor(planet.angle)
  drawLitSphere(planet.x, planet.y, planet.z, BODY_VISUAL.orbitPlanetRadius, pr, pg, pb, planet.light, 24)
end

local function drawMegaPlanet(megaPlanet)
  if hasActiveBoost(megaPlanet) then
    local baseTrailLen = math.min(megaPlanet.radius * 2.2, 36 + megaPlanet.boost * 44)
    drawOrbitalTrail(megaPlanet, baseTrailLen, 0.56, 0.05, nil, nil, 0, megaPlanet.light)
  end
  local pr, pg, pb = computeOrbiterColor(megaPlanet.angle)
  drawLitSphere(megaPlanet.x, megaPlanet.y, megaPlanet.z, BODY_VISUAL.megaPlanetRadius, pr, pg, pb, megaPlanet.light, 36)
end

local function drawSatellite(satellite)
  if hasActiveBoost(satellite) then
    local baseTrailLen = math.min(satellite.radius * 2.2, 16 + satellite.boost * 22)
    drawOrbitalTrail(satellite, baseTrailLen, 0.44, 0.02, nil, nil, 0, satellite.light)
  end
  local satR, satG, satB = computeOrbiterColor(satellite.angle)
  drawLitSphere(satellite.x, satellite.y, satellite.z, BODY_VISUAL.satelliteRadius, satR, satG, satB, satellite.light, 18)
end

local function orbiterHitRadius(orbiter)
  local baseRadius
  local margin
  if orbiter.kind == "moon" then
    baseRadius = BODY_VISUAL.moonRadius
    margin = 2
  elseif orbiter.kind == "mega-planet" then
    baseRadius = BODY_VISUAL.megaPlanetRadius
    margin = 2
  elseif orbiter.kind == "planet" then
    baseRadius = BODY_VISUAL.orbitPlanetRadius
    margin = 2
  elseif orbiter.kind == "satellite" then
    baseRadius = BODY_VISUAL.satelliteRadius
    margin = 1.5
  elseif orbiter.kind == "moon-satellite" then
    baseRadius = BODY_VISUAL.moonChildSatelliteRadius
    margin = 2
  else
    return nil
  end
  local projectScale = perspectiveScaleForZ(orbiter.z)
  return (baseRadius + margin) * projectScale
end

local function depthSortOrbiters(a, b)
  local az = orbiterRenderDepth(a)
  local bz = orbiterRenderDepth(b)
  if az ~= bz then
    return az < bz
  end
  return (a.renderOrder or 0) < (b.renderOrder or 0)
end

local function collectRenderOrbiters()
  local renderOrbiters = state.renderOrbiters
  for i = #renderOrbiters, 1, -1 do
    renderOrbiters[i] = nil
  end

  local n = 0
  local function append(orbiter)
    n = n + 1
    renderOrbiters[n] = orbiter
  end

  for _, megaPlanet in ipairs(state.megaPlanets) do
    append(megaPlanet)
  end
  for _, planet in ipairs(state.planets) do
    append(planet)
  end
  for _, moon in ipairs(state.moons) do
    append(moon)
    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      append(child)
    end
  end
  for _, satellite in ipairs(state.satellites) do
    append(satellite)
  end

  table.sort(renderOrbiters, depthSortOrbiters)
  return renderOrbiters
end

function drawOrbiterByKind(orbiter)
  if orbiter.kind == "moon" then
    drawMoon(orbiter)
  elseif orbiter.kind == "moon-satellite" then
    drawMoonChildSatellite(orbiter)
  elseif orbiter.kind == "mega-planet" then
    drawMegaPlanet(orbiter)
  elseif orbiter.kind == "planet" then
    drawOrbitPlanet(orbiter)
  elseif orbiter.kind == "satellite" then
    drawSatellite(orbiter)
  end
end

function drawHoverTooltip(lines, anchorBtn, uiScale, lineH, preferLeft)
  if not lines or not anchorBtn then
    return
  end

  local font = love.graphics.getFont()
  local tipPadX = math.floor(8 * uiScale)
  local tipPadY = math.floor(6 * uiScale)
  local tipGap = math.floor(2 * uiScale)
  local tipW = 0
  for i = 1, #lines do
    local line = lines[i]
    local lineW = font:getWidth(line.pre or "") + font:getWidth(line.hi or "") + font:getWidth(line.post or "")
    tipW = math.max(tipW, lineW)
  end
  tipW = tipW + tipPadX * 2
  local tipH = tipPadY * 2 + lineH * #lines + tipGap * math.max(0, #lines - 1)
  local tipGapX = math.floor(10 * uiScale)
  local viewportRight = offsetX + GAME_W * scale
  local viewportBottom = offsetY + GAME_H * scale
  local tipX
  if preferLeft then
    tipX = anchorBtn.x - tipW - tipGapX
    if tipX < offsetX + 4 then
      tipX = anchorBtn.x + anchorBtn.w + tipGapX
    end
  else
    tipX = anchorBtn.x + anchorBtn.w + tipGapX
    if tipX + tipW > viewportRight - 4 then
      tipX = anchorBtn.x - tipW - tipGapX
    end
  end
  tipX = clamp(tipX, offsetX + 4, viewportRight - tipW - 4)
  local tipY = clamp(anchorBtn.y, offsetY + 4, viewportBottom - tipH - 4)

  setColorScaled(swatch.darkest, 1, 0.96)
  love.graphics.rectangle("fill", tipX, tipY, tipW, tipH)
  setColorScaled(swatch.brightest, 1, 0.96)
  love.graphics.rectangle("line", tipX, tipY, tipW, tipH)

  for i = 1, #lines do
    local line = lines[i]
    local lineY = tipY + tipPadY + (i - 1) * (lineH + tipGap)
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

  local totalRpm = 0
  for _, megaPlanet in ipairs(state.megaPlanets) do
    totalRpm = totalRpm + megaPlanet.speed * (1 + megaPlanet.boost + speedWaveBoostFor(megaPlanet)) * RAD_PER_SECOND_TO_RPM
  end
  for _, planet in ipairs(state.planets) do
    totalRpm = totalRpm + planet.speed * (1 + planet.boost + speedWaveBoostFor(planet)) * RAD_PER_SECOND_TO_RPM
  end
  for _, moon in ipairs(state.moons) do
    totalRpm = totalRpm + moon.speed * (1 + moon.boost + speedWaveBoostFor(moon)) * RAD_PER_SECOND_TO_RPM
    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      totalRpm = totalRpm + child.speed * (1 + child.boost + speedWaveBoostFor(child)) * RAD_PER_SECOND_TO_RPM
    end
  end
  for _, satellite in ipairs(state.satellites) do
    totalRpm = totalRpm + satellite.speed * (1 + satellite.boost + speedWaveBoostFor(satellite)) * RAD_PER_SECOND_TO_RPM
  end

  local rpmText = string.format("%.2f rpm", totalRpm)
  local rpmTextW = font:getWidth(rpmText)
  local rpmX = counterCenterX - rpmTextW * 0.5
  local rpmY = counterY + counterTextH + math.floor(2 * uiScale)
  love.graphics.setFont(font)
  setColorScaled(palette.accent, 1, 1)
  drawText(rpmText, rpmX, rpmY)

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
  local blackHoleShaderReady = state.blackHoleShaderUnlocked or state.orbits >= blackHoleShaderCost()
  local waveStatus = state.speedWaveUnlocked and (state.speedWaveTimer > 0 and "on" or tostring(state.planetClickCount % SPEED_WAVE_CLICK_THRESHOLD) .. "/" .. tostring(SPEED_WAVE_CLICK_THRESHOLD)) or tostring(speedWaveCost())
  local clickStatus = state.speedClickUnlocked and "owned" or tostring(speedClickCost())
  local blackHoleShaderStatus = state.blackHoleShaderUnlocked and "owned" or tostring(blackHoleShaderCost())

  local sectionCount = 2
  local rowCount = 7
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
  local blackHoleShaderHovered = drawRow(ui.blackHoleShaderBtn, "black hole shader", blackHoleShaderStatus, blackHoleShaderReady, not state.blackHoleShaderUnlocked)
  if blackHoleShaderHovered then
    hoveredTooltipBtn = ui.blackHoleShaderBtn
    hoveredTooltipLines = {
      {
        pre = "Enables the black hole distortion around the core.",
        hi = "",
        post = "",
      },
      {
        pre = "This upgrade is ",
        hi = "visual only",
        post = ".",
      },
    }
  end

  local descAlpha = state.speedClickUnlocked and 1 or 0.58
  setColorScaled(palette.text, 1, descAlpha)
  drawText("planet clicks accelerate a random orbiter", panelX + padX, y)
  love.graphics.setScissor()

  drawHoverTooltip(hoveredTooltipLines, hoveredTooltipBtn, uiScale, lineH, false)

  love.graphics.setColor(palette.muted)
  local viewportBottom = offsetY + GAME_H * scale
  local helpY1 = math.floor(viewportBottom - lineH * 3 - 12 * uiScale)
  local helpY2 = math.floor(viewportBottom - lineH * 2 - 8 * uiScale)
  local helpY3 = math.floor(viewportBottom - lineH - 4 * uiScale)
  local helpX = panelX
  drawText(string.format("zoom %.2fx  scroll to zoom", zoom), helpX, helpY1)
  drawText("l dither " .. (state.sphereDitherEnabled and "on" or "off"), helpX, helpY2)
  drawText("b fullscreen", helpX, helpY3)
end

function getOrbiterAction(orbiter)
  if orbiter.kind == "planet" or orbiter.kind == "mega-planet" then
    local cost = moonCost()
    return {
      action = "buy-moon",
      label = "moon",
      price = tostring(cost),
      enabled = state.orbits >= cost and #state.moons < MAX_MOONS,
      tooltipLines = {
        {pre = "Adds a moon orbiting this planet.", hi = "", post = ""},
        {pre = "Moons can host ", hi = "satellites", post = "."},
      },
    }
  end
  if orbiter.kind == "moon" then
    local cost = moonSatelliteCost()
    return {
      action = "buy-satellite",
      label = "sattelite",
      price = tostring(cost),
      enabled = state.orbits >= cost,
      tooltipLines = {
        {pre = "Adds a satellite orbiting this moon.", hi = "", post = ""},
        {pre = "Satellites generate ", hi = "orbits", post = " when clicked."},
      },
    }
  end
  return nil
end

function getOrbiterTooltipLayout()
  local orbiter = state.selectedOrbiter
  if not orbiter then
    return nil
  end

  local font = getUiScreenFont()
  local uiScale = scale >= 1 and scale or 1
  local totalBoost = orbiter.boost + speedWaveBoostFor(orbiter)
  local boostPercent = math.floor(totalBoost * 100 + 0.5)
  local title = "selected moon"
  if orbiter.kind == "satellite" or orbiter.kind == "moon-satellite" then
    title = "selected satellite"
  elseif orbiter.kind == "planet" then
    title = "selected planet"
  elseif orbiter.kind == "mega-planet" then
    title = "selected mega planet"
  end

  local baseRpm = orbiter.speed * RAD_PER_SECOND_TO_RPM
  local currentRpm = orbiter.speed * (1 + totalBoost) * RAD_PER_SECOND_TO_RPM
  local detailLines = {
    {pre = "revolutions ", hi = tostring(orbiter.revolutions), post = ""},
    {pre = "orbit radius ", hi = string.format("%.0f px", orbiter.radius), post = ""},
    {pre = "base speed ", hi = string.format("%.2f rpm", baseRpm), post = ""},
    {pre = "current speed ", hi = string.format("%.2f rpm", currentRpm), post = ""},
    {pre = "active boost ", hi = string.format("%+d%%", boostPercent), post = ""},
  }

  if orbiter.kind == "planet" or orbiter.kind == "mega-planet" then
    local moonCount = 0
    for _, moon in ipairs(state.moons) do
      if moon.parentOrbiter == orbiter then
        moonCount = moonCount + 1
      end
    end
    detailLines[#detailLines + 1] = {
      pre = "moons ",
      hi = tostring(moonCount),
      post = "",
    }
  elseif orbiter.kind == "moon" then
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
    action = getOrbiterAction(orbiter),
  }
end

function drawOrbiterTooltipConnector(frontPass)
  ui.orbiterActionBtn.visible = false
  ui.orbiterActionBtn.enabled = false
  ui.orbiterActionBtn.action = nil

  local layout = getOrbiterTooltipLayout()
  if not layout then
    return
  end
  local orbiter = layout.orbiter

  local renderDepth = orbiterRenderDepth(orbiter)
  if (frontPass and renderDepth <= 0) or ((not frontPass) and renderDepth > 0) then
    return
  end

  local connectorLight = orbiter.light or cameraLightAt(orbiter.x, orbiter.y, orbiter.z)
  setLitColorDirect(SELECTED_ORBIT_COLOR[1], SELECTED_ORBIT_COLOR[2], SELECTED_ORBIT_COLOR[3], connectorLight, 0.88)
  local px, py = projectWorldPoint(orbiter.x, orbiter.y, orbiter.z)
  love.graphics.line(layout.anchorWorldX, layout.anchorWorldY, px, py)
end

function drawOrbiterTooltip()
  ui.orbiterActionBtn.visible = false
  ui.orbiterActionBtn.enabled = false
  ui.orbiterActionBtn.action = nil

  local layout = getOrbiterTooltipLayout()
  if not layout then
    return
  end

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

  local action = layout.action
  if not action then
    return
  end

  local btnW = layout.boxW
  local btnH = layout.lineH + math.floor(6 * layout.uiScale)
  local btnX = layout.boxX
  local btnY = layout.boxY + layout.boxH + math.floor(3 * layout.uiScale)
  local btn = ui.orbiterActionBtn
  btn.x = btnX
  btn.y = btnY
  btn.w = btnW
  btn.h = btnH
  btn.visible = true
  btn.enabled = action.enabled
  btn.action = action.action

  local btnAlpha = action.enabled and 1 or 0.45
  local mouseX, mouseY = love.mouse.getPosition()
  local hovered = pointInRect(mouseX, mouseY, btn)
  if hovered then
    setColorScaled(swatch.brightest, 1, 0.95 * btnAlpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
  end
  local textY = btnY + math.floor(3 * layout.uiScale)
  setColorScaled(palette.text, 1, btnAlpha)
  drawText(action.label, btnX + math.floor(8 * layout.uiScale), textY)
  local priceW = font:getWidth(action.price)
  drawText(action.price, btnX + btnW - priceW - math.floor(8 * layout.uiScale), textY)

  if hovered then
    drawHoverTooltip(action.tooltipLines, btn, layout.uiScale, layout.lineH, true)
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

local function initSphereShader()
  local pixelData = love.image.newImageData(1, 1)
  pixelData:setPixel(0, 0, 1, 1, 1, 1)
  spherePixel = love.graphics.newImage(pixelData)
  spherePixel:setFilter("nearest", "nearest")

  local ok, shaderOrErr = pcall(love.graphics.newShader, [[
    extern vec3 baseColor;
    extern vec3 lightVec;
    extern float lightPower;
    extern float ambient;
    extern float contrast;
    extern float darkFloor;
    extern float toneSteps;
    extern float facetSides;
    extern float ditherStrength;
    extern float ditherScale;
    extern vec3 pal0;
    extern vec3 pal1;
    extern vec3 pal2;
    extern vec3 pal3;
    extern vec3 pal4;
    extern vec3 pal5;
    extern vec3 pal6;

    vec3 paletteRamp(float t) {
      t = clamp(t, 0.0, 1.0);
      float s = t * 6.0;
      if (s < 1.0) {
        return mix(pal0, pal1, s);
      } else if (s < 2.0) {
        return mix(pal1, pal2, s - 1.0);
      } else if (s < 3.0) {
        return mix(pal2, pal3, s - 2.0);
      } else if (s < 4.0) {
        return mix(pal3, pal4, s - 3.0);
      } else if (s < 5.0) {
        return mix(pal4, pal5, s - 4.0);
      }
      return mix(pal5, pal6, s - 5.0);
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      vec2 p = texture_coords * 2.0 - 1.0;
      float r2 = dot(p, p);
      if (r2 > 1.0) {
        return vec4(0.0);
      }

      vec2 nxy = p;
      if (facetSides > 2.5) {
        float angle = atan(nxy.y, nxy.x);
        float step = 6.28318530718 / facetSides;
        angle = floor((angle + step * 0.5) / step) * step;
        float radius = length(nxy);
        nxy = vec2(cos(angle), sin(angle)) * radius;
      }

      float nz = sqrt(max(0.0, 1.0 - dot(nxy, nxy)));
      vec3 n = normalize(vec3(nxy.x, -nxy.y, nz));
      vec3 l = normalize(lightVec);
      float ndotl = dot(n, l);
      float wrap = 0.72;
      float diffuse = clamp((ndotl + wrap) / (1.0 + wrap), 0.0, 1.0);
      diffuse = smoothstep(0.02, 0.98, diffuse);
      float curvature = smoothstep(0.0, 1.0, nz);
      float sphereMix = 0.35 + curvature * 0.65;
      float lit = diffuse * sphereMix;
      float shade = clamp(ambient + lightPower * (lit * 0.82 + curvature * 0.18), 0.0, 1.0);

      float baseL = dot(baseColor, vec3(0.299, 0.587, 0.114));
      float tone = clamp((shade - 0.5) * contrast + 0.5, 0.0, 1.0);
      tone = max(tone, darkFloor);
      tone = clamp(tone + (baseL - 0.5) * 0.16, 0.0, 1.0);
      if (ditherStrength > 0.0) {
        float scale = max(ditherScale, 0.001);
        float pattern = fract(sin(dot(floor(screen_coords * scale), vec2(12.9898, 78.233))) * 43758.5453);
        tone = clamp(tone + (pattern - 0.5) * ditherStrength, 0.0, 1.0);
      }
      if (toneSteps > 1.0) {
        float levels = max(2.0, toneSteps);
        tone = floor(tone * (levels - 1.0) + 0.5) / (levels - 1.0);
      }

      vec3 palColor = paletteRamp(tone);
      return vec4(palColor, 1.0) * color;
    }
  ]])

  if not ok then
    sphereShader = nil
    return
  end

  sphereShader = shaderOrErr
  sphereShader:send("pal0", {swatch.darkest[1], swatch.darkest[2], swatch.darkest[3]})
  sphereShader:send("pal1", {swatch.nearDark[1], swatch.nearDark[2], swatch.nearDark[3]})
  sphereShader:send("pal2", {swatch.dimmest[1], swatch.dimmest[2], swatch.dimmest[3]})
  sphereShader:send("pal3", {swatch.dim[1], swatch.dim[2], swatch.dim[3]})
  sphereShader:send("pal4", {swatch.mid[1], swatch.mid[2], swatch.mid[3]})
  sphereShader:send("pal5", {swatch.bright[1], swatch.bright[2], swatch.bright[3]})
  sphereShader:send("pal6", {swatch.brightest[1], swatch.brightest[2], swatch.brightest[3]})
end

local function initGravityWellShader()
  local ok, shaderOrErr = pcall(love.graphics.newShader, [[
    extern vec2 centerUv;
    extern float aspect;
    extern float innerR;
    extern float coreR;
    extern float outerR;
    extern float radialStrength;
    extern float swirlStrength;
    extern float waveCenterR;
    extern float waveHalfWidth;
    extern float waveRadialStrength;
    extern float waveSwirlStrength;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      vec2 uv = texture_coords;
      vec2 p = uv - centerUv;
      p.x *= aspect;
      float r = length(p);
      float safeR = max(r, 0.000001);
      vec2 dir = p / safeR;
      vec2 tangent = vec2(-dir.y, dir.x);
      vec2 warped = p;

      if (outerR > innerR && r > innerR && r < outerR) {
        float span = max(0.0001, outerR - innerR);
        float t = clamp((r - innerR) / span, 0.0, 1.0);
        float borderPos = clamp((coreR - innerR) / span, 0.001, 0.999);
        float edgeWidth = 0.12;
        float edgeIn = smoothstep(0.0, edgeWidth, t);
        float edgeOut = 1.0 - smoothstep(1.0 - edgeWidth, 1.0, t);
        float baseBand = edgeIn * edgeOut;
        float insideSpan = max(borderPos, 0.001);
        float outsideSpan = max(1.0 - borderPos, 0.001);
        float distIn = (borderPos - t) / insideSpan;
        float distOut = (t - borderPos) / outsideSpan;
        float distToBorder = mix(distIn, distOut, step(borderPos, t));
        float borderPeak = 1.0 - smoothstep(0.0, 1.0, distToBorder);
        float well = baseBand * (0.58 + borderPeak * 0.42);
        float radial = radialStrength * well * (0.92 + borderPeak * 0.24);
        float swirl = swirlStrength * well * (0.82 + borderPeak * 0.18);
        warped += dir * radial + tangent * swirl;
      }

      if (waveHalfWidth > 0.0) {
        float span = max(0.0001, waveHalfWidth);
        float delta = (r - waveCenterR) / span;
        float absDelta = abs(delta);
        if (absDelta < 1.0) {
          float ring = 1.0 - absDelta;
          ring = ring * ring * (3.0 - 2.0 * ring);
          float waveRadial = -delta * ring * waveRadialStrength;
          float waveSwirl = ring * waveSwirlStrength;
          warped += dir * waveRadial + tangent * waveSwirl;
        }
      }

      vec2 sampleUv = centerUv + vec2(warped.x / aspect, warped.y);
      sampleUv = clamp(sampleUv, vec2(0.0), vec2(1.0));
      return Texel(texture, sampleUv) * color;
    }
  ]])

  if not ok then
    gravityWellShader = nil
    return
  end

  gravityWellShader = shaderOrErr
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
  initSphereShader()
  initGravityWellShader()
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
  elseif key == "l" then
    toggleSphereShadeStyle()
  end
end

function love.wheelmoved(_, wy)
  zoom = clamp(zoom + wy * 0.1, ZOOM_MIN, ZOOM_MAX)
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
      child.parentOrbiter = moon
      child.parentMoon = moon
      updateOrbiterPosition(child)

      local prevTurns = math.floor(prev / TWO_PI)
      local newTurns = math.floor(child.angle / TWO_PI)
      if newTurns > prevTurns then
        local turnsGained = newTurns - prevTurns
        state.orbits = state.orbits + turnsGained
        child.revolutions = child.revolutions + turnsGained
        spawnOrbitGainFx(child.x, child.y, turnsGained, BODY_VISUAL.moonChildSatelliteRadius)
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

  if x >= ui.blackHoleShaderBtn.x and x <= ui.blackHoleShaderBtn.x + ui.blackHoleShaderBtn.w and y >= ui.blackHoleShaderBtn.y and y <= ui.blackHoleShaderBtn.y + ui.blackHoleShaderBtn.h then
    buyBlackHoleShader()
    return
  end

  if ui.orbiterActionBtn.visible and x >= ui.orbiterActionBtn.x and x <= ui.orbiterActionBtn.x + ui.orbiterActionBtn.w and y >= ui.orbiterActionBtn.y and y <= ui.orbiterActionBtn.y + ui.orbiterActionBtn.h then
    if ui.orbiterActionBtn.enabled then
      local bought = false
      if ui.orbiterActionBtn.action == "buy-moon" then
        bought = addMoon(state.selectedOrbiter)
      elseif ui.orbiterActionBtn.action == "buy-satellite" then
        bought = addSatelliteToMoon(state.selectedOrbiter)
      end
      if bought then
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

  local _, _, _, _, lightPx, lightPy, lightProjScale = lightSourceProjected()
  local lightHitRadius = lightSourceHitRadius(lightProjScale)
  local lightDx = wx - lightPx
  local lightDy = wy - lightPy
  if lightDx * lightDx + lightDy * lightDy <= lightHitRadius * lightHitRadius then
    if (not state.selectedLightSource) or state.selectedOrbiter then
      playClickFx(false)
    end
    state.selectedOrbiter = nil
    state.selectedLightSource = true
    return
  end

  local renderOrbiters = collectRenderOrbiters()
  for i = #renderOrbiters, 1, -1 do
    local orbiter = renderOrbiters[i]
    local hitRadius = orbiterHitRadius(orbiter)
    if hitRadius then
      local px, py = projectWorldPoint(orbiter.x, orbiter.y, orbiter.z)
      local dx = wx - px
      local dy = wy - py
      if dx * dx + dy * dy <= hitRadius * hitRadius then
        if state.selectedOrbiter ~= orbiter then
          playClickFx(false)
        end
        state.selectedOrbiter = orbiter
        state.selectedLightSource = false
        return
      end
    end
  end

  if state.selectedOrbiter or state.selectedLightSource then
    playClickFx(true)
  end
  state.selectedOrbiter = nil
  state.selectedLightSource = false
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
  drawSelectedLightOrbit(false)
  drawOrbiterTooltipConnector(false)
  drawLightSource(false)

  local renderOrbiters = collectRenderOrbiters()
  local firstFront = #renderOrbiters + 1
  for i = 1, #renderOrbiters do
    if orbiterRenderDepth(renderOrbiters[i]) > 0 then
      firstFront = i
      break
    end
  end

  for i = 1, firstFront - 1 do
    drawOrbiterByKind(renderOrbiters[i])
  end
  drawPlanet()
  drawOrbiterTooltipConnector(true)
  drawSelectedOrbit(true)
  drawSelectedLightOrbit(true)

  for i = firstFront, #renderOrbiters do
    drawOrbiterByKind(renderOrbiters[i])
  end
  drawLightSource(true)
  love.graphics.pop()

  drawOrbitGainFx()

  love.graphics.setCanvas()
  love.graphics.clear(palette.space)
  love.graphics.setColor(1, 1, 1, 1)
  local rippleActive, waveCenterR, waveHalfWidth, waveRadialStrength, waveSwirlStrength = activeSpeedWaveRippleParams()
  if gravityWellShader and (state.blackHoleShaderUnlocked or rippleActive) then
    local coreR = clamp((state.planetVisualRadius or BODY_VISUAL.planetRadius) / GAME_H, 0.002, 0.45)
    local innerR = coreR
    local outerR = coreR
    local radialStrength = 0
    local swirlStrength = 0
    if state.blackHoleShaderUnlocked then
      innerR = clamp(coreR * GRAVITY_WELL_INNER_SCALE, 0.001, coreR - 0.0005)
      outerR = clamp(coreR * GRAVITY_WELL_RADIUS_SCALE, coreR + 0.01, 0.95)
      radialStrength = GRAVITY_WELL_RADIAL_STRENGTH
      swirlStrength = GRAVITY_WELL_SWIRL_STRENGTH
    end
    local prevShader = love.graphics.getShader()
    love.graphics.setShader(gravityWellShader)
    gravityWellShader:send("centerUv", {cx / GAME_W, cy / GAME_H})
    gravityWellShader:send("aspect", GAME_W / GAME_H)
    gravityWellShader:send("innerR", innerR)
    gravityWellShader:send("coreR", coreR)
    gravityWellShader:send("outerR", outerR)
    gravityWellShader:send("radialStrength", radialStrength)
    gravityWellShader:send("swirlStrength", swirlStrength)
    gravityWellShader:send("waveCenterR", rippleActive and waveCenterR or 0)
    gravityWellShader:send("waveHalfWidth", rippleActive and waveHalfWidth or 0)
    gravityWellShader:send("waveRadialStrength", rippleActive and waveRadialStrength or 0)
    gravityWellShader:send("waveSwirlStrength", rippleActive and waveSwirlStrength or 0)
    love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
    love.graphics.setShader(prevShader)
  else
    love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
  end

  love.graphics.setFont(getUiScreenFont())
  drawSpeedWaveText()
  drawOrbiterTooltip()
  drawHud()
end
