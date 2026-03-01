local Systems = {
  Modifier = require("game.systems.modifiers"),
  Orbiters = require("game.systems.orbiters"),
}

local GAME_W = 1280
local GAME_H = 720
local TWO_PI = math.pi * 2
local RAD_PER_SECOND_TO_RPM = 60 / TWO_PI
local RPM_TO_RAD_PER_SECOND = TWO_PI / 60
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
local GRAVITY_WELL_INNER_SCALE = 0.06
local GRAVITY_WELL_RADIUS_SCALE = 1.18
local GRAVITY_WELL_RADIAL_STRENGTH = 0.009
local GRAVITY_WELL_SWIRL_STRENGTH = 0.00028
local SPEED_WAVE_RIPPLE_LIFETIME = 1.1
local SPEED_WAVE_RIPPLE_WIDTH_START = 0.020
local SPEED_WAVE_RIPPLE_WIDTH_END = 0.092
local SPEED_WAVE_RIPPLE_RADIAL_STRENGTH = 0.062
local SPEED_WAVE_RIPPLE_SWIRL_STRENGTH = 0.0018
local SPEED_WAVE_RIPPLE_END_PADDING = 0.12
local PLANET_COLOR_CYCLE_SECONDS = 30
local ORBIT_ICON_CYCLE_SECONDS = 1.8
local ORBIT_ICON_FLATTEN = 0.84
local ORBIT_ICON_SIZE = 6
local UI_FONT_SIZE = 24
local MAX_MOONS = 64
local MAX_SATELLITES = 64
local STARTING_HAND_SIZE = 5
local TURN_ENERGY = 3
local MAX_TURNS = 4
local OBJECTIVE_RPM = 40
local CORE_BASE_RPM = 6
local HEAT_CAP = 10
local END_TURN_HEAT_GAIN = 1
local CARD_W = 176
local CARD_H = 104
local CARD_GAP = 10
local END_TURN_W = 118
local END_TURN_H = 34
local CARD_DEFS = {
  moonseed = {
    id = "moonseed",
    name = "moonseed",
    cost = 2,
    starterCopies = 4,
    isMoonCard = true,
    line = "summon moon 4 rpm",
    tooltip = "Summon a Moon with 4 RPM. Gain 1 Heat.",
  },
  coolant_vent = {
    id = "coolant_vent",
    name = "coolant vent",
    cost = 1,
    starterCopies = 4,
    line = "vent 2",
    tooltip = "Vent 2.",
  },
  spin_up = {
    id = "spin_up",
    name = "spin up",
    cost = 1,
    starterCopies = 2,
    line = "spin +1",
    tooltip = "All Moons gain +1 RPM permanently this run. Gain 1 Heat.",
  },
  overclock = {
    id = "overclock",
    name = "overclock",
    cost = 1,
    starterCopies = 2,
    line = "overclock +2",
    tooltip = "This turn, all Moons gain +2 RPM. Gain 1 Heat.",
  },
  heavy_moon = {
    id = "heavy_moon",
    name = "heavy moon",
    cost = 2,
    shopPrice = 30,
    isMoonCard = true,
    line = "summon heavy 6 rpm",
    tooltip = "Summon Heavy Moon with 6 RPM. Gain 2 Heat.",
  },
  twin_seed = {
    id = "twin_seed",
    name = "twin seed",
    cost = 3,
    shopPrice = 35,
    isMoonCard = true,
    line = "summon 2x moon 3",
    tooltip = "Summon 2 Moons with 3 RPM each. Gain 2 Heat.",
  },
  precision_spin = {
    id = "precision_spin",
    name = "precision spin",
    cost = 1,
    shopPrice = 35,
    line = "spin +2",
    tooltip = "All Moons gain +2 RPM permanently this run. Gain 2 Heat.",
  },
  cold_sink = {
    id = "cold_sink",
    name = "cold sink",
    cost = 1,
    shopPrice = 25,
    line = "vent 4",
    tooltip = "Vent 4.",
  },
  redline = {
    id = "redline",
    name = "redline",
    cost = 1,
    shopPrice = 40,
    line = "overclock +4",
    tooltip = "This turn, all Moons gain +4 RPM. Gain 2 Heat.",
  },
  containment = {
    id = "containment",
    name = "containment",
    cost = 1,
    shopPrice = 30,
    line = "vent 2, next -1 heat",
    tooltip = "Vent 2. Next card this turn gains -1 Heat.",
  },
  compression = {
    id = "compression",
    name = "compression",
    cost = 1,
    shopPrice = 35,
    line = "next moon cheaper +2",
    tooltip = "Next Moon card this turn costs 1 less and gains +2 RPM.",
  },
  reactor_feed = {
    id = "reactor_feed",
    name = "reactor feed",
    cost = 0,
    shopPrice = 30,
    line = "+1 energy this turn",
    tooltip = "Gain +1 Energy this turn. Gain 1 Heat.",
  },
  resonant_burst = {
    id = "resonant_burst",
    name = "resonant burst",
    cost = 2,
    shopPrice = 45,
    line = "+2 rpm this turn/moon",
    tooltip = "Gain +2 RPM this turn per Moon. Gain 2 Heat.",
  },
  anchor = {
    id = "anchor",
    name = "anchor",
    cost = 2,
    shopPrice = 40,
    line = "summon anchor 2 rpm",
    tooltip = "Summon Anchor with 2 RPM. End-turn Heat gain -1.",
  },
}
local STARTER_CARD_ORDER = {"moonseed", "coolant_vent", "spin_up", "overclock"}
local SHOP_CARD_ORDER = {
  "heavy_moon",
  "twin_seed",
  "precision_spin",
  "cold_sink",
  "redline",
  "containment",
  "compression",
  "reactor_feed",
  "resonant_burst",
  "anchor",
}
local STARTING_DECK = {}
do
  for i = 1, #STARTER_CARD_ORDER do
    local id = STARTER_CARD_ORDER[i]
    local copies = CARD_DEFS[id].starterCopies or 0
    for _ = 1, copies do
      STARTING_DECK[#STARTING_DECK + 1] = id
    end
  end
end
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
local rpmDisplayFont
local rpmDisplayFontSize = 0
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
  screen = "main_menu",
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
  planetBounceTime = 0,
  speedWaveRipples = {},
  planetVisualRadius = BODY_VISUAL.planetRadius,
  hand = {},
  drawPile = {},
  discardPile = {},
  cardHoverLift = {},
  turn = 1,
  maxTurns = MAX_TURNS,
  energy = TURN_ENERGY,
  objectiveRpm = OBJECTIVE_RPM,
  coreRpm = CORE_BASE_RPM,
  heat = 0,
  heatCap = HEAT_CAP,
  highestRpm = CORE_BASE_RPM,
  rewardRpm = 0,
  permanentMoonSpin = 0,
  turnOverclockRpm = 0,
  turnBurstRpm = 0,
  nextCardHeatReduction = 0,
  nextMoonCostReduction = 0,
  nextMoonRpmBonus = 0,
  runOutcome = "",
  runComplete = false,
  runWon = false,
  lastTurnPulsePlayed = false,
  rpmRollTimer = 0,
  rpmRollDuration = 0.30,
  rpmRollFrom = 0,
  rpmRollTo = 0,
}

local ui = {
  mainPlayBtn = {x = 0, y = 0, w = 0, h = 0},
  mainDeckBtn = {x = 0, y = 0, w = 0, h = 0},
  menuBackBtn = {x = 0, y = 0, w = 0, h = 0},
  deckCardButtons = {},
  deckShopButtons = {},
  cardButtons = {},
  drawPile = {x = 0, y = 0, w = 0, h = 0},
  discardPile = {x = 0, y = 0, w = 0, h = 0},
  endTurnBtn = {x = 0, y = 0, w = 0, h = 0},
}

local runtime = {}
local playMenuBuyClickFx

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

local function shuffleInPlace(list)
  for i = #list, 2, -1 do
    local j = love.math.random(1, i)
    list[i], list[j] = list[j], list[i]
  end
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
      highdpi = true,
      resizable = true,
      vsync = 1,
      minwidth = 960,
      minheight = 540,
    })
  else
    love.window.setMode(1280, 720, {
      fullscreen = false,
      borderless = false,
      highdpi = true,
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

function getRpmDisplayFont()
  local uiScale = scale >= 1 and scale or 1
  local size = math.max(1, math.floor(UI_FONT_SIZE * uiScale * 3.1 + 0.5))
  if not rpmDisplayFont or rpmDisplayFontSize ~= size then
    rpmDisplayFont = love.graphics.newFont("font_gothic.ttf", size, "mono")
    rpmDisplayFont:setFilter("nearest", "nearest")
    rpmDisplayFontSize = size
  end
  return rpmDisplayFont
end

local updateOrbiterPosition

local function addMegaPlanet()
  if not runtime.orbiters then
    return false
  end
  return runtime.orbiters:addMegaPlanet()
end

local function addPlanet()
  if not runtime.orbiters then
    return false
  end
  return runtime.orbiters:addPlanet()
end

local function addMoon(parentOrbiter)
  if not runtime.orbiters then
    return false
  end
  return runtime.orbiters:addMoon(parentOrbiter)
end

local function addSatellite()
  if not runtime.orbiters then
    return false
  end
  return runtime.orbiters:addSatellite()
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

local function speedWaveBoostFor(_)
  return 0
end

function blackHoleStabilitySpeedMultiplier()
  return 1
end

local function collectAllOrbiters()
  local pool = {}
  for _, megaPlanet in ipairs(state.megaPlanets) do
    pool[#pool + 1] = megaPlanet
  end
  for _, planet in ipairs(state.planets) do
    pool[#pool + 1] = planet
  end
  for _, moon in ipairs(state.moons) do
    pool[#pool + 1] = moon
    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      pool[#pool + 1] = child
    end
  end
  for _, satellite in ipairs(state.satellites) do
    pool[#pool + 1] = satellite
  end
  return pool
end

local function isMoonBody(orbiter)
  return orbiter and (orbiter.bodyKind == "moon" or orbiter.bodyKind == "heavy_moon")
end

local function countMoonBodies()
  local count = 0
  local orbiters = collectAllOrbiters()
  for i = 1, #orbiters do
    if isMoonBody(orbiters[i]) then
      count = count + 1
    end
  end
  return count
end

local function countAnchors()
  local count = 0
  local orbiters = collectAllOrbiters()
  for i = 1, #orbiters do
    if orbiters[i].bodyKind == "anchor" then
      count = count + 1
    end
  end
  return count
end

local function effectiveBodyRpm(orbiter)
  if not orbiter then
    return 0
  end
  local rpm = orbiter.baseRpm or 0
  if isMoonBody(orbiter) then
    rpm = rpm + state.permanentMoonSpin + state.turnOverclockRpm
  end
  return math.max(0, rpm)
end

local function syncOrbiterSpeedsFromBodies()
  local orbiters = collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    orbiter.speed = effectiveBodyRpm(orbiter) * RPM_TO_RAD_PER_SECOND
  end
end

local function computeTotalRpm()
  local total = state.coreRpm + state.turnBurstRpm
  local orbiters = collectAllOrbiters()
  for i = 1, #orbiters do
    total = total + effectiveBodyRpm(orbiters[i])
  end
  return total
end

local function updateHighestRpm()
  local current = math.floor(computeTotalRpm() + 0.5)
  if current > state.highestRpm then
    state.highestRpm = current
  end
  return current
end

local function triggerGravityPulse()
  state.speedWaveRipples[#state.speedWaveRipples + 1] = {
    age = 0,
    life = SPEED_WAVE_RIPPLE_LIFETIME,
  }
end

local function refillDrawPileIfEmpty()
  if #state.drawPile > 0 or #state.discardPile == 0 then
    return
  end
  for i = 1, #state.discardPile do
    state.drawPile[#state.drawPile + 1] = state.discardPile[i]
  end
  for i = #state.discardPile, 1, -1 do
    state.discardPile[i] = nil
  end
  shuffleInPlace(state.drawPile)
end

local function drawCards(count)
  for _ = 1, count do
    refillDrawPileIfEmpty()
    if #state.drawPile == 0 then
      return
    end
    state.hand[#state.hand + 1] = table.remove(state.drawPile)
  end
end

local function discardCurrentHand()
  for i = #state.hand, 1, -1 do
    state.discardPile[#state.discardPile + 1] = state.hand[i]
    state.hand[i] = nil
  end
end

local function resetTurnModifiers()
  state.turnOverclockRpm = 0
  state.turnBurstRpm = 0
  state.nextCardHeatReduction = 0
  state.nextMoonCostReduction = 0
  state.nextMoonRpmBonus = 0
end

local function finishRun(outcome)
  state.runComplete = true
  state.runOutcome = outcome
  state.runWon = outcome ~= "collapse" and state.highestRpm >= state.objectiveRpm
  state.rewardRpm = state.highestRpm
end

local function ventHeat(amount)
  if amount <= 0 then
    return
  end
  state.heat = math.max(0, state.heat - amount)
end

local function addHeat(amount)
  if amount <= 0 then
    return
  end
  state.heat = state.heat + amount
  if state.heat >= state.heatCap then
    state.heat = state.heatCap
    updateHighestRpm()
    finishRun("collapse")
  end
end

local function tagBody(orbiter, bodyKind, baseRpm)
  if not orbiter then
    return
  end
  orbiter.bodyKind = bodyKind
  orbiter.baseRpm = baseRpm
end

local function summonMoon(baseRpm)
  local before = #state.moons
  if not addMoon(nil) then
    return false
  end
  tagBody(state.moons[before + 1], "moon", baseRpm)
  return true
end

local function summonHeavyMoon(baseRpm)
  local before = #state.planets
  if not addPlanet() then
    return false
  end
  tagBody(state.planets[before + 1], "heavy_moon", baseRpm)
  return true
end

local function summonAnchor(baseRpm)
  local before = #state.satellites
  if not addSatellite() then
    return false
  end
  tagBody(state.satellites[before + 1], "anchor", baseRpm)
  return true
end

local function applyCard(cardDef, moonBonusRpm)
  local heatGain = 0
  local id = cardDef.id
  if id == "moonseed" then
    if not summonMoon(4 + moonBonusRpm) then
      return false
    end
    heatGain = 1
  elseif id == "coolant_vent" then
    ventHeat(2)
  elseif id == "spin_up" then
    state.permanentMoonSpin = state.permanentMoonSpin + 1
    heatGain = 1
  elseif id == "overclock" then
    state.turnOverclockRpm = state.turnOverclockRpm + 2
    heatGain = 1
  elseif id == "heavy_moon" then
    if not summonHeavyMoon(6 + moonBonusRpm) then
      return false
    end
    heatGain = 2
  elseif id == "twin_seed" then
    if not summonMoon(3 + moonBonusRpm) then
      return false
    end
    if not summonMoon(3 + moonBonusRpm) then
      return false
    end
    heatGain = 2
  elseif id == "precision_spin" then
    state.permanentMoonSpin = state.permanentMoonSpin + 2
    heatGain = 2
  elseif id == "cold_sink" then
    ventHeat(4)
  elseif id == "redline" then
    state.turnOverclockRpm = state.turnOverclockRpm + 4
    heatGain = 2
  elseif id == "containment" then
    ventHeat(2)
    state.nextCardHeatReduction = state.nextCardHeatReduction + 1
  elseif id == "compression" then
    state.nextMoonCostReduction = state.nextMoonCostReduction + 1
    state.nextMoonRpmBonus = state.nextMoonRpmBonus + 2
  elseif id == "reactor_feed" then
    state.energy = state.energy + 1
    heatGain = 1
  elseif id == "resonant_burst" then
    state.turnBurstRpm = state.turnBurstRpm + countMoonBodies() * 2
    heatGain = 2
  elseif id == "anchor" then
    if not summonAnchor(2) then
      return false
    end
  else
    return false
  end

  local heatReduction = state.nextCardHeatReduction
  if heatReduction > 0 then
    heatGain = math.max(0, heatGain - heatReduction)
    state.nextCardHeatReduction = 0
  end
  addHeat(heatGain)
  syncOrbiterSpeedsFromBodies()
  updateHighestRpm()
  return true
end

local function beginTurn(turnNumber)
  state.turn = turnNumber
  state.energy = TURN_ENERGY
  resetTurnModifiers()
  drawCards(STARTING_HAND_SIZE)
  if state.turn == state.maxTurns and not state.lastTurnPulsePlayed then
    triggerGravityPulse()
    state.lastTurnPulsePlayed = true
  end
end

local function endPlayerTurn()
  if state.runComplete then
    return
  end
  local endTurnHeat = math.max(0, END_TURN_HEAT_GAIN - countAnchors())
  addHeat(endTurnHeat)
  syncOrbiterSpeedsFromBodies()
  updateHighestRpm()
  if state.runComplete then
    return
  end
  discardCurrentHand()
  if state.turn >= state.maxTurns then
    finishRun("completed")
    return
  end
  beginTurn(state.turn + 1)
end

local function currentCardCost(cardDef)
  if not cardDef then
    return 0
  end
  local cost = cardDef.cost or 0
  if cardDef.isMoonCard and state.nextMoonCostReduction > 0 then
    cost = math.max(0, cost - state.nextMoonCostReduction)
  end
  return cost
end

local function playCard(handIndex)
  if state.runComplete then
    return false
  end
  local cardId = state.hand[handIndex]
  if not cardId then
    return false
  end
  local cardDef = CARD_DEFS[cardId]
  if not cardDef then
    return false
  end
  local beforeRpm = math.floor(computeTotalRpm() + 0.5)
  local moonCostReduction = state.nextMoonCostReduction
  local moonRpmBonus = 0
  if cardDef.isMoonCard and moonCostReduction > 0 then
    moonRpmBonus = state.nextMoonRpmBonus
  end
  local effectiveCost = currentCardCost(cardDef)
  if state.energy < effectiveCost then
    return false
  end
  state.energy = state.energy - effectiveCost
  if cardDef.isMoonCard and moonCostReduction > 0 then
    state.nextMoonCostReduction = 0
    state.nextMoonRpmBonus = 0
  end
  if not applyCard(cardDef, moonRpmBonus) then
    state.energy = state.energy + effectiveCost
    return false
  end
  table.remove(state.hand, handIndex)
  state.discardPile[#state.discardPile + 1] = cardId
  local afterRpm = math.floor(computeTotalRpm() + 0.5)
  state.rpmRollFrom = beforeRpm
  state.rpmRollTo = afterRpm
  state.rpmRollTimer = state.rpmRollDuration
  playMenuBuyClickFx()
  return true
end

local function startCardRun()
  state.megaPlanets = {}
  state.planets = {}
  state.moons = {}
  state.satellites = {}
  state.renderOrbiters = {}
  state.nextRenderOrder = 0
  state.selectedOrbiter = nil
  state.selectedLightSource = false
  state.hand = {}
  state.drawPile = {}
  state.discardPile = {}
  state.cardHoverLift = {}
  state.speedWaveRipples = {}
  for i = 1, #STARTING_DECK do
    state.drawPile[#state.drawPile + 1] = STARTING_DECK[i]
  end
  shuffleInPlace(state.drawPile)
  state.coreRpm = CORE_BASE_RPM
  state.heat = 0
  state.heatCap = HEAT_CAP
  state.permanentMoonSpin = 0
  state.turnOverclockRpm = 0
  state.turnBurstRpm = 0
  state.nextCardHeatReduction = 0
  state.nextMoonCostReduction = 0
  state.nextMoonRpmBonus = 0
  state.highestRpm = CORE_BASE_RPM
  state.rewardRpm = 0
  state.runOutcome = ""
  state.turn = 1
  state.energy = TURN_ENERGY
  state.runComplete = false
  state.runWon = false
  state.lastTurnPulsePlayed = false
  state.rpmRollFrom = 0
  state.rpmRollTo = 0
  state.rpmRollTimer = 0
  syncOrbiterSpeedsFromBodies()
  updateHighestRpm()
  beginTurn(1)
end

function switchScreen(screenId)
  state.screen = screenId
  state.selectedOrbiter = nil
  state.selectedLightSource = false
end

function openMainMenu()
  switchScreen("main_menu")
end

function openDeckMenu()
  switchScreen("deck_menu")
end

function startRunFromMenu()
  startCardRun()
  switchScreen("run")
end

local function onPlanetClicked()
  state.planetBounceTime = PLANET_BOUNCE_DURATION
end

local function initGameSystems()
  runtime.modifiers = Systems.Modifier.new()
  local freeEconomy = {
    trySpendCost = function()
      return true
    end,
    getCost = function()
      return 0
    end,
  }
  runtime.orbiters = Systems.Orbiters.new({
    state = state,
    economy = freeEconomy,
    modifiers = runtime.modifiers,
    orbitConfigs = ORBIT_CONFIGS,
    bodyVisual = BODY_VISUAL,
    twoPi = TWO_PI,
    maxMoons = MAX_MOONS,
    maxSatellites = MAX_SATELLITES,
    impulseDuration = PLANET_IMPULSE_DURATION,
    impulseTargetBoost = PLANET_IMPULSE_TARGET_BOOST,
    impulseRiseRate = PLANET_IMPULSE_RISE_RATE,
    impulseFallRate = PLANET_IMPULSE_FALL_RATE,
    createOrbitalParams = createOrbitalParams,
    updateOrbiterPosition = updateOrbiterPosition,
    assignRenderOrder = assignRenderOrder,
    getStabilitySpeedMultiplier = function()
      return 1
    end,
    getTransientBoost = function()
      return 0
    end,
    disableOrbitRewards = true,
  })
end

function drawBackground()
  love.graphics.clear(palette.space)

  for _, s in ipairs(state.stars) do
    local twinkle = (math.sin(state.time * s.speed + s.phase) + 1) * 0.5
    if twinkle > 0.45 then
      love.graphics.setColor(palette.accent)
      love.graphics.rectangle("fill", s.x, s.y, 1, 1)
    end
  end
end

function drawSelectedOrbit(frontPass)
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

function drawSelectedLightOrbit(frontPass)
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

function drawLitSphere(x, y, z, radius, r, g, b, lightScale, segments)
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

function drawPlanet()
  local t = 1 - clamp(state.planetBounceTime / PLANET_BOUNCE_DURATION, 0, 1)
  local kick = math.sin(t * math.pi)
  local bounceScale = 1 + kick * 0.14 * (1 - t)
  local px, py, projScale = projectWorldPoint(cx, cy, 0)
  local pr = math.max(3, BODY_VISUAL.planetRadius * bounceScale * projScale)

  setColorDirect(0, 0, 0, 1)
  love.graphics.circle("fill", px, py, pr, 44)
  state.planetVisualRadius = pr * zoom
end

function drawLightSource(frontPass)
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

function activeSpeedWaveRippleParams()
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

function drawOrbitalTrail(orbiter, trailLen, headAlpha, tailAlpha, originX, originY, originZ, lightScale)
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

function hasActiveBoost(orbiter)
  if not orbiter then
    return false
  end
  if orbiter.boostDurations and #orbiter.boostDurations > 0 then
    return true
  end
  return speedWaveBoostFor(orbiter) > 0
end

function drawMoon(moon)
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

function drawMoonChildSatellite(child)
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

function drawOrbitPlanet(planet)
  if hasActiveBoost(planet) then
    local baseTrailLen = math.min(planet.radius * 2.2, 28 + planet.boost * 36)
    drawOrbitalTrail(planet, baseTrailLen, 0.5, 0.04, nil, nil, 0, planet.light)
  end
  local pr, pg, pb = computeOrbiterColor(planet.angle)
  drawLitSphere(planet.x, planet.y, planet.z, BODY_VISUAL.orbitPlanetRadius, pr, pg, pb, planet.light, 24)
end

function drawMegaPlanet(megaPlanet)
  if hasActiveBoost(megaPlanet) then
    local baseTrailLen = math.min(megaPlanet.radius * 2.2, 36 + megaPlanet.boost * 44)
    drawOrbitalTrail(megaPlanet, baseTrailLen, 0.56, 0.05, nil, nil, 0, megaPlanet.light)
  end
  local pr, pg, pb = computeOrbiterColor(megaPlanet.angle)
  drawLitSphere(megaPlanet.x, megaPlanet.y, megaPlanet.z, BODY_VISUAL.megaPlanetRadius, pr, pg, pb, megaPlanet.light, 36)
end

function drawSatellite(satellite)
  if hasActiveBoost(satellite) then
    local baseTrailLen = math.min(satellite.radius * 2.2, 16 + satellite.boost * 22)
    drawOrbitalTrail(satellite, baseTrailLen, 0.44, 0.02, nil, nil, 0, satellite.light)
  end
  local satR, satG, satB = computeOrbiterColor(satellite.angle)
  drawLitSphere(satellite.x, satellite.y, satellite.z, BODY_VISUAL.satelliteRadius, satR, satG, satB, satellite.light, 18)
end

function orbiterHitRadius(orbiter)
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

function depthSortOrbiters(a, b)
  local az = orbiterRenderDepth(a)
  local bz = orbiterRenderDepth(b)
  if az ~= bz then
    return az < bz
  end
  return (a.renderOrder or 0) < (b.renderOrder or 0)
end

function collectRenderOrbiters()
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
  local uiScale = scale >= 1 and scale or 1
  local lineH = math.floor(font:getHeight())
  local mouseX, mouseY = love.mouse.getPosition()
  local viewportX = offsetX
  local viewportY = offsetY
  local viewportW = GAME_W * scale
  local viewportH = GAME_H * scale
  local totalRpm = computeTotalRpm()
  local rpmInt = math.floor(totalRpm + 0.5)
  local rpmFont = getRpmDisplayFont()
  local rpmY = viewportY + math.floor(4 * uiScale)
  local shownRpm = rpmInt
  if state.rpmRollTimer > 0 and state.rpmRollFrom ~= state.rpmRollTo then
    local t = 1 - clamp(state.rpmRollTimer / state.rpmRollDuration, 0, 1)
    local eased = smoothstep(t)
    shownRpm = math.floor(lerp(state.rpmRollFrom, state.rpmRollTo, eased) + 0.5)
  end
  love.graphics.setFont(rpmFont)
  local rpmText = tostring(shownRpm)
  setColorScaled(swatch.bright, 1, 1)
  drawText(rpmText, viewportX + viewportW * 0.5 - rpmFont:getWidth(rpmText) * 0.5, rpmY)
  love.graphics.setFont(font)
  local rpmLabelY = rpmY + rpmFont:getHeight() - math.floor(8 * uiScale)
  local rpmLabel = "rpm"
  setColorScaled(palette.text, 1, 0.9)
  drawText(rpmLabel, viewportX + viewportW * 0.5 - font:getWidth(rpmLabel) * 0.5, rpmLabelY)

  local objectiveText = string.format("objective: get to %d rpm", state.objectiveRpm)
  local objectiveX = viewportX + viewportW - font:getWidth(objectiveText) - math.floor(10 * uiScale)
  local objectiveY = viewportY + math.floor(10 * uiScale)
  setColorScaled(palette.text, 1, 0.92)
  drawText(objectiveText, objectiveX, objectiveY)
  local highText = string.format("highest rpm %d", state.highestRpm)
  setColorScaled(palette.text, 1, 0.85)
  drawText(highText, viewportX + viewportW - font:getWidth(highText) - math.floor(10 * uiScale), objectiveY + lineH + math.floor(2 * uiScale))
  if state.runComplete then
    local outcomeText = state.runOutcome == "collapse" and "collapse" or (state.runWon and "goal reached" or "goal missed")
    local rewardText = string.format("reward %d", state.rewardRpm)
    setColorScaled(state.runOutcome == "collapse" and swatch.bright or swatch.brightest, 1, 0.95)
    drawText(outcomeText, viewportX + viewportW - font:getWidth(outcomeText) - math.floor(10 * uiScale), objectiveY + lineH * 2 + math.floor(4 * uiScale))
    setColorScaled(swatch.brightest, 1, 0.95)
    drawText(rewardText, viewportX + viewportW - font:getWidth(rewardText) - math.floor(10 * uiScale), objectiveY + lineH * 3 + math.floor(6 * uiScale))
  end

  local endBtn = ui.endTurnBtn
  endBtn.w = math.floor(END_TURN_W * uiScale)
  endBtn.h = math.floor(END_TURN_H * uiScale)
  endBtn.x = viewportX + viewportW - endBtn.w - math.floor(10 * uiScale)
  endBtn.y = viewportY + viewportH - endBtn.h - math.floor(12 * uiScale)
  local canEndTurn = not state.runComplete
  local endHovered = pointInRect(mouseX, mouseY, endBtn)
  local endAlpha = canEndTurn and 1 or 0.45
  setColorScaled(swatch.brightest, 1, (endHovered and 1 or 0.92) * endAlpha)
  love.graphics.rectangle("fill", endBtn.x, endBtn.y, endBtn.w, endBtn.h)
  setColorScaled(swatch.darkest, 1, (endHovered and 1 or 0.88) * endAlpha)
  love.graphics.rectangle("line", endBtn.x, endBtn.y, endBtn.w, endBtn.h)
  setColorScaled(swatch.darkest, 1, endAlpha)
  local endLabel = "end turn"
  drawText(endLabel, endBtn.x + math.floor((endBtn.w - font:getWidth(endLabel)) * 0.5), endBtn.y + math.floor((endBtn.h - lineH) * 0.5))

  local cardW = math.floor(CARD_W * uiScale)
  local cardH = math.floor(CARD_H * uiScale)
  local cardGap = math.floor(CARD_GAP * uiScale)
  local handCount = #state.hand
  local handW = handCount > 0 and (handCount * cardW + (handCount - 1) * cardGap) or 0
  local cardY = viewportY + viewportH - cardH - math.floor(12 * uiScale)
  local startX = viewportX + math.floor((viewportW - handW) * 0.5)
  local fixedSlots = STARTING_HAND_SIZE
  local fixedHandW = fixedSlots * cardW + (fixedSlots - 1) * cardGap
  local fixedStartX = viewportX + math.floor((viewportW - fixedHandW) * 0.5)

  local turnText = string.format("turn %d/%d", state.turn, state.maxTurns)
  local energyText = string.format("energy %d", state.energy)
  local heatText = string.format("heat %d/%d", state.heat, state.heatCap)
  local infoY = cardY - lineH * 3 - math.floor(12 * uiScale)
  setColorScaled(palette.text, 1, 0.92)
  drawText(turnText, viewportX + viewportW * 0.5 - font:getWidth(turnText) * 0.5, infoY)
  drawText(energyText, viewportX + viewportW * 0.5 - font:getWidth(energyText) * 0.5, infoY + lineH + math.floor(2 * uiScale))
  drawText(heatText, viewportX + viewportW * 0.5 - font:getWidth(heatText) * 0.5, infoY + lineH * 2 + math.floor(4 * uiScale))

  local pileW = math.floor(94 * uiScale)
  local pileH = math.floor(56 * uiScale)
  ui.drawPile.x = fixedStartX - pileW - math.floor(12 * uiScale)
  ui.drawPile.y = cardY + math.floor((cardH - pileH) * 0.5)
  ui.drawPile.w = pileW
  ui.drawPile.h = pileH
  ui.discardPile.x = fixedStartX + fixedHandW + math.floor(12 * uiScale)
  ui.discardPile.y = ui.drawPile.y
  ui.discardPile.w = pileW
  ui.discardPile.h = pileH

  setColorScaled(swatch.brightest, 1, 0.95)
  love.graphics.rectangle("fill", ui.drawPile.x, ui.drawPile.y, ui.drawPile.w, ui.drawPile.h)
  love.graphics.rectangle("fill", ui.discardPile.x, ui.discardPile.y, ui.discardPile.w, ui.discardPile.h)
  setColorScaled(swatch.darkest, 1, 0.95)
  love.graphics.rectangle("line", ui.drawPile.x, ui.drawPile.y, ui.drawPile.w, ui.drawPile.h)
  love.graphics.rectangle("line", ui.discardPile.x, ui.discardPile.y, ui.discardPile.w, ui.discardPile.h)
  setColorScaled(swatch.darkest, 1, 0.95)
  drawText("draw", ui.drawPile.x + math.floor(8 * uiScale), ui.drawPile.y + math.floor(5 * uiScale))
  drawText(tostring(#state.drawPile), ui.drawPile.x + math.floor(8 * uiScale), ui.drawPile.y + math.floor(5 * uiScale) + lineH)
  drawText("discard", ui.discardPile.x + math.floor(8 * uiScale), ui.discardPile.y + math.floor(5 * uiScale))
  drawText(tostring(#state.discardPile), ui.discardPile.x + math.floor(8 * uiScale), ui.discardPile.y + math.floor(5 * uiScale) + lineH)

  local hoveredTooltipLines
  local hoveredTooltipBtn
  for i = #ui.cardButtons, handCount + 1, -1 do
    ui.cardButtons[i] = nil
    state.cardHoverLift[i] = nil
  end
  for i = 1, handCount do
    local cardId = state.hand[i]
    local cardDef = CARD_DEFS[cardId]
    local btn = ui.cardButtons[i] or {}
    ui.cardButtons[i] = btn
    local hoverLift = state.cardHoverLift[i] or 0
    btn.x = startX + (i - 1) * (cardW + cardGap)
    btn.y = cardY - hoverLift
    btn.w = cardW
    btn.h = cardH
    btn.cardId = cardId
    btn.index = i
    local hovered = pointInRect(mouseX, mouseY, btn)
    local targetLift = hovered and (6 * uiScale) or 0
    hoverLift = hoverLift + (targetLift - hoverLift) * 0.22
    state.cardHoverLift[i] = hoverLift
    btn.y = cardY - hoverLift
    hovered = pointInRect(mouseX, mouseY, btn)
    local cardCost = currentCardCost(cardDef)
    local playable = (not state.runComplete) and cardDef and (state.energy >= cardCost)
    local alpha = playable and 1 or 0.45
    setColorScaled(swatch.darkest, 1, 0.92 * alpha)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
    setColorScaled(swatch.brightest, 1, (hovered and 1 or 0.75) * alpha)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
    setColorScaled(palette.text, 1, alpha)
    local costText = cardDef and ("cost " .. tostring(cardCost)) or "cost ?"
    drawText(costText, btn.x + math.floor(8 * uiScale), btn.y + math.floor(6 * uiScale))
    drawText(cardDef and cardDef.name or cardId, btn.x + math.floor(8 * uiScale), btn.y + lineH + math.floor(12 * uiScale))
    drawText(cardDef and cardDef.line or "", btn.x + math.floor(8 * uiScale), btn.y + lineH * 2 + math.floor(18 * uiScale))
    if hovered and cardDef then
      hoveredTooltipBtn = btn
      hoveredTooltipLines = {
        {pre = cardDef.tooltip or "", hi = "", post = ""},
        {pre = "cost ", hi = tostring(cardCost), post = " energy"},
      }
    end
  end
  drawHoverTooltip(hoveredTooltipLines, hoveredTooltipBtn, uiScale, lineH, true)
end

function drawMainMenu()
  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local lineH = math.floor(font:getHeight())
  local mouseX, mouseY = love.mouse.getPosition()
  local viewportX = offsetX
  local viewportY = offsetY
  local viewportW = GAME_W * scale
  local viewportH = GAME_H * scale

  local title = "orbit protocol"
  local titleFont = getRpmDisplayFont()
  love.graphics.setFont(titleFont)
  setColorScaled(swatch.bright, 1, 1)
  drawText(title, viewportX + viewportW * 0.5 - titleFont:getWidth(title) * 0.5, viewportY + math.floor(viewportH * 0.22))
  love.graphics.setFont(font)

  local btnW = math.floor(220 * uiScale)
  local btnH = lineH + math.floor(12 * uiScale)
  local startY = viewportY + math.floor(viewportH * 0.58)
  local gap = math.floor(12 * uiScale)
  local btnX = viewportX + math.floor((viewportW - btnW) * 0.5)

  local function drawMenuButton(btn, label, y)
    btn.x = btnX
    btn.y = y
    btn.w = btnW
    btn.h = btnH
    local hovered = pointInRect(mouseX, mouseY, btn)
    setColorScaled(swatch.darkest, 1, hovered and 1 or 0.9)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
    setColorScaled(swatch.brightest, 1, hovered and 1 or 0.8)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
    setColorScaled(palette.text, 1, 0.95)
    drawText(label, btn.x + math.floor((btn.w - font:getWidth(label)) * 0.5), btn.y + math.floor((btn.h - lineH) * 0.5))
  end

  drawMenuButton(ui.mainPlayBtn, "play", startY)
  drawMenuButton(ui.mainDeckBtn, "deck", startY + btnH + gap)
end

function drawDeckMenu()
  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local lineH = math.floor(font:getHeight())
  local mouseX, mouseY = love.mouse.getPosition()
  local viewportX = offsetX
  local viewportY = offsetY
  local viewportW = GAME_W * scale
  local viewportH = GAME_H * scale
  local panelPad = math.floor(22 * uiScale)
  local panelX = viewportX + panelPad
  local panelY = viewportY + panelPad
  local panelW = viewportW - panelPad * 2
  local panelH = viewportH - panelPad * 2

  setColorScaled(swatch.darkest, 1, 0.92)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
  setColorScaled(swatch.brightest, 1, 0.9)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

  local headerPad = math.floor(12 * uiScale)
  setColorScaled(palette.text, 1, 0.95)
  drawText("deck menu", panelX + headerPad, panelY + headerPad)

  local backBtn = ui.menuBackBtn
  backBtn.w = math.floor(88 * uiScale)
  backBtn.h = lineH + math.floor(8 * uiScale)
  backBtn.x = panelX + panelW - backBtn.w - headerPad
  backBtn.y = panelY + math.floor(8 * uiScale)
  local backHovered = pointInRect(mouseX, mouseY, backBtn)
  setColorScaled(swatch.brightest, 1, backHovered and 1 or 0.86)
  love.graphics.rectangle("fill", backBtn.x, backBtn.y, backBtn.w, backBtn.h)
  setColorScaled(swatch.darkest, 1, 1)
  love.graphics.rectangle("line", backBtn.x, backBtn.y, backBtn.w, backBtn.h)
  drawText("back", backBtn.x + math.floor((backBtn.w - font:getWidth("back")) * 0.5), backBtn.y + math.floor((backBtn.h - lineH) * 0.5))

  local contentX = panelX + headerPad
  local contentY = panelY + lineH + math.floor(24 * uiScale)
  local contentW = panelW - headerPad * 2
  local contentH = panelH - (contentY - panelY) - headerPad
  local colGap = math.floor(10 * uiScale)
  local colW = math.floor((contentW - colGap * 2) / 3)
  local headers = {"deck", "inventory", "shop"}
  local hoveredTooltipLines
  local hoveredTooltipBtn

  for i = 1, 3 do
    local colX = contentX + (i - 1) * (colW + colGap)
    local colY = contentY
    setColorScaled(swatch.nearDark, 1, 0.95)
    love.graphics.rectangle("fill", colX, colY, colW, contentH)
    setColorScaled(swatch.brightest, 1, 0.7)
    love.graphics.rectangle("line", colX, colY, colW, contentH)
    setColorScaled(palette.text, 1, 0.95)
    drawText(headers[i], colX + math.floor(10 * uiScale), colY + math.floor(8 * uiScale))

    if headers[i] == "deck" then
      local listX = colX + math.floor(10 * uiScale)
      local listY = colY + lineH + math.floor(18 * uiScale)
      local cardW = colW - math.floor(20 * uiScale)
      local cardH = lineH * 3 + math.floor(16 * uiScale)
      local cardGap = math.floor(8 * uiScale)
      for n = #ui.deckCardButtons, #STARTER_CARD_ORDER + 1, -1 do
        ui.deckCardButtons[n] = nil
      end
      for n = 1, #STARTER_CARD_ORDER do
        local cardId = STARTER_CARD_ORDER[n]
        local cardDef = CARD_DEFS[cardId]
        local copies = cardDef.starterCopies or 0
        local btn = ui.deckCardButtons[n] or {}
        ui.deckCardButtons[n] = btn
        btn.x = listX
        btn.y = listY + (n - 1) * (cardH + cardGap)
        btn.w = cardW
        btn.h = cardH
        local hovered = pointInRect(mouseX, mouseY, btn)
        setColorScaled(swatch.darkest, 1, hovered and 0.98 or 0.9)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        setColorScaled(swatch.brightest, 1, hovered and 1 or 0.7)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        setColorScaled(palette.text, 1, 0.95)
        drawText("x" .. tostring(copies) .. "  cost " .. tostring(cardDef.cost), btn.x + math.floor(8 * uiScale), btn.y + math.floor(4 * uiScale))
        drawText(cardDef.name, btn.x + math.floor(8 * uiScale), btn.y + lineH + math.floor(8 * uiScale))
        drawText(cardDef.line, btn.x + math.floor(8 * uiScale), btn.y + lineH * 2 + math.floor(12 * uiScale))
        if hovered then
          hoveredTooltipBtn = btn
          hoveredTooltipLines = {
            {pre = cardDef.tooltip, hi = "", post = ""},
            {pre = "cost ", hi = tostring(cardDef.cost), post = " energy"},
            {pre = "starter copies ", hi = tostring(copies), post = ""},
          }
        end
      end
    elseif headers[i] == "shop" then
      local rowX = colX + math.floor(10 * uiScale)
      local rowY = colY + lineH + math.floor(12 * uiScale)
      local rowW = colW - math.floor(20 * uiScale)
      local rowH = lineH + math.floor(8 * uiScale)
      local rowGap = math.floor(4 * uiScale)
      for n = #ui.deckShopButtons, #SHOP_CARD_ORDER + 1, -1 do
        ui.deckShopButtons[n] = nil
      end
      for n = 1, #SHOP_CARD_ORDER do
        local cardId = SHOP_CARD_ORDER[n]
        local cardDef = CARD_DEFS[cardId]
        local btn = ui.deckShopButtons[n] or {}
        ui.deckShopButtons[n] = btn
        btn.x = rowX
        btn.y = rowY + (n - 1) * (rowH + rowGap)
        btn.w = rowW
        btn.h = rowH
        local hovered = pointInRect(mouseX, mouseY, btn)
        setColorScaled(swatch.darkest, 1, hovered and 0.98 or 0.9)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        setColorScaled(swatch.brightest, 1, hovered and 1 or 0.7)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        setColorScaled(palette.text, 1, 0.95)
        drawText(cardDef.name, btn.x + math.floor(8 * uiScale), btn.y + math.floor(4 * uiScale))
        local priceText = tostring(cardDef.shopPrice or 0)
        drawText(priceText, btn.x + btn.w - font:getWidth(priceText) - math.floor(8 * uiScale), btn.y + math.floor(4 * uiScale))
        if hovered then
          hoveredTooltipBtn = btn
          hoveredTooltipLines = {
            {pre = cardDef.tooltip, hi = "", post = ""},
            {pre = "cost ", hi = tostring(cardDef.cost), post = " energy"},
            {pre = "shop ", hi = tostring(cardDef.shopPrice or 0), post = ""},
          }
        end
      end
    else
      setColorScaled(palette.text, 1, 0.55)
      drawText("empty", colX + math.floor(10 * uiScale), colY + lineH + math.floor(18 * uiScale))
    end
  end

  drawHoverTooltip(hoveredTooltipLines, hoveredTooltipBtn, uiScale, lineH, false)
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

  local currentRpm = orbiter.speed * (1 + totalBoost) * RAD_PER_SECOND_TO_RPM
  local detailLines = {
    {pre = "orbit radius ", hi = string.format("%.0f px", orbiter.radius), post = ""},
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
  }
end

function drawOrbiterTooltipConnector(frontPass)
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

playMenuBuyClickFx = function()
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
  initGameSystems()
  openMainMenu()

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
  if key == "escape" then
    if state.screen == "deck_menu" or state.screen == "run" then
      openMainMenu()
    end
  elseif key == "b" then
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
  state.rpmRollTimer = math.max(0, state.rpmRollTimer - dt)

  if runtime.orbiters then
    runtime.orbiters:update(dt)
  end

  local ripples = state.speedWaveRipples
  for i = #ripples, 1, -1 do
    local ripple = ripples[i]
    ripple.age = ripple.age + dt
    if ripple.age >= ripple.life then
      table.remove(ripples, i)
    end
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  if state.screen == "main_menu" then
    if pointInRect(x, y, ui.mainPlayBtn) then
      startRunFromMenu()
      playClickFx(false)
      return
    end
    if pointInRect(x, y, ui.mainDeckBtn) then
      openDeckMenu()
      playClickFx(false)
      return
    end
    return
  elseif state.screen == "deck_menu" then
    if pointInRect(x, y, ui.menuBackBtn) then
      openMainMenu()
      playClickFx(true)
    end
    return
  elseif state.screen ~= "run" then
    return
  end

  if pointInRect(x, y, ui.endTurnBtn) and not state.runComplete then
    endPlayerTurn()
    return
  end

  for i = 1, #ui.cardButtons do
    local btn = ui.cardButtons[i]
    if btn and pointInRect(x, y, btn) then
      playCard(btn.index)
      return
    end
  end
  if pointInRect(x, y, ui.drawPile) or pointInRect(x, y, ui.discardPile) then
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

  love.graphics.setCanvas()
  love.graphics.clear(palette.space)
  love.graphics.setColor(1, 1, 1, 1)
  local rippleActive, waveCenterR, waveHalfWidth, waveRadialStrength, waveSwirlStrength = activeSpeedWaveRippleParams()
  if gravityWellShader then
    local coreR = clamp((state.planetVisualRadius or BODY_VISUAL.planetRadius) / GAME_H, 0.002, 0.45)
    local innerR = clamp(coreR * GRAVITY_WELL_INNER_SCALE, 0.001, coreR - 0.0005)
    local outerR = clamp(coreR * GRAVITY_WELL_RADIUS_SCALE, coreR + 0.01, 0.95)
    local radialStrength = GRAVITY_WELL_RADIAL_STRENGTH
    local swirlStrength = GRAVITY_WELL_SWIRL_STRENGTH
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
  if state.screen == "run" then
    drawOrbiterTooltip()
    drawHud()
  elseif state.screen == "main_menu" then
    drawMainMenu()
  elseif state.screen == "deck_menu" then
    drawDeckMenu()
  end
end
