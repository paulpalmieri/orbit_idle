local Config = require("game.config.game_config")
local Systems = {
  DeckBuilder = require("game.systems.deck_builder"),
  Modifier = require("game.systems.modifiers"),
  Orbiters = require("game.systems.orbiters"),
  CardRun = require("game.systems.card_run"),
}

local canvas
local uiFont
local uiScreenFont
local uiScreenFontSize = 0
local topDisplayFont
local topDisplayFontSize = 0
local cardFont
local cardFontSize = 0
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

local cx = math.floor(Config.GAME_W / 2)
local cy = math.floor(Config.GAME_H / 2)

local swatch = Config.swatch
local palette = Config.palette
local paletteSwatches = Config.paletteSwatches
local orbitColorCycle = Config.orbitColorCycle

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
  planetVisualRadius = Config.BODY_VISUAL.planetRadius,
  hand = {},
  drawPile = {},
  discardPile = {},
  cardHoverLift = {},
  epoch = 1,
  maxEpochs = Config.MAX_EPOCHS,
  energy = Config.EPOCH_ENERGY,
  heat = 0,
  heatCap = Config.HEAT_CAP,
  points = 0,
  rewardPoints = 0,
  runOutcome = "",
  runComplete = false,
  runWon = false,
  runRewardClaimed = false,
  phase = "planning",
  inputLocked = false,
  currency = 100,
  deckList = nil,
  inventory = {},
}

local ui = {
  mainPlayBtn = {x = 0, y = 0, w = 0, h = 0},
  mainDeckBtn = {x = 0, y = 0, w = 0, h = 0},
  menuBackBtn = {x = 0, y = 0, w = 0, h = 0},
  deckCardButtons = {},
  deckInventoryButtons = {},
  deckShopButtons = {},
  cardButtons = {},
  drawPile = {x = 0, y = 0, w = 0, h = 0},
  discardPile = {x = 0, y = 0, w = 0, h = 0},
  endTurnBtn = {x = 0, y = 0, w = 0, h = 0},
  endGameMenuBtn = {x = 0, y = 0, w = 0, h = 0},
  endGameReplayBtn = {x = 0, y = 0, w = 0, h = 0},
  feedbackAnchors = {
    epoch = {x = 0, y = 0},
    energy = {x = 0, y = 0},
    heat = {x = 0, y = 0},
    points = {x = 0, y = 0},
    systemOpe = {x = 0, y = 0},
  },
}

local runtime = {}
local playMenuBuyClickFx
local micro = {
  lockInput = false,
  sequence = nil,
  floatingTexts = {},
  worldFloatingTexts = {},
  floatingLane = {},
  floatingQueueAt = {},
  displayEnergy = state.energy,
  displayHeat = state.heat,
  displayEpoch = state.epoch,
  summonEntries = {},
  trailBoost = 0,
  orbitLineBoost = 0,
  corePulse = 0,
  coolDown = 0,
  reshuffleCue = 0,
}

local function activeSphereShadeStyle()
  if state.sphereDitherEnabled then
    return Config.SPHERE_SHADE_STYLE_ON
  end
  return Config.SPHERE_SHADE_STYLE_OFF
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
  local cycle = (state.time % Config.LIGHT_ORBIT_PERIOD_SECONDS) / Config.LIGHT_ORBIT_PERIOD_SECONDS
  -- Start from the left and orbit the playfield over two minutes.
  local a = cycle * Config.TWO_PI + math.pi
  local x = cx + math.cos(a) * Config.LIGHT_ORBIT_RADIUS_X
  local y = cy + math.sin(a) * Config.LIGHT_ORBIT_RADIUS_Y
  local z = Config.LIGHT_ORBIT_Z_BASE + math.sin(a + math.pi * 0.5) * Config.LIGHT_ORBIT_Z_VARIATION
  return x, y, z
end

local function lightProjectionZ(z)
  return (z or 0) + (Config.CAMERA_LIGHT_HEIGHT / zoom) / Config.CAMERA_LIGHT_Z_SCALE
end

local function lightDepthForZ(z)
  return lightProjectionZ(z) * Config.CAMERA_LIGHT_Z_SCALE
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
  local vz = (z or 0) * Config.CAMERA_LIGHT_Z_SCALE

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

  local shadowRadius = Config.BODY_VISUAL.planetRadius * (1 + along / math.max(1, dirLen * 0.9))
  local softEdge = shadowRadius * 0.60 + 6
  if radial >= shadowRadius + softEdge then
    return 1
  end

  local edgeT = clamp((radial - shadowRadius) / softEdge, 0, 1)
  local coreShadow = 1 - smoothstep(edgeT)
  local depthStrength = 1 - math.exp(-along / (Config.BODY_VISUAL.planetRadius * 1.6))
  local shadowStrength = coreShadow * depthStrength * 0.90
  return clamp(1 - shadowStrength, 0.02, 1)
end

local function cameraLightAt(x, y, z)
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local depth = (z or 0) * Config.CAMERA_LIGHT_Z_SCALE
  local lightDepth = lightDepthForZ(lightZ)
  local dx = lightX - x
  local dy = lightY - y
  local dz = lightDepth - depth
  local distSq = dx * dx + dy * dy + dz * dz
  local attenuation = 1 / (1 + distSq * Config.CAMERA_LIGHT_FALLOFF)
  local direct = Config.CAMERA_LIGHT_AMBIENT + attenuation * Config.CAMERA_LIGHT_INTENSITY
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
  if targetDepth > depth + Config.DEPTH_SORT_HYSTERESIS then
    orbiter.sortDepth = targetDepth - Config.DEPTH_SORT_HYSTERESIS
  elseif targetDepth < depth - Config.DEPTH_SORT_HYSTERESIS then
    orbiter.sortDepth = targetDepth + Config.DEPTH_SORT_HYSTERESIS
  end
end

local function assignRenderOrder(orbiter)
  state.nextRenderOrder = state.nextRenderOrder + 1
  orbiter.renderOrder = state.nextRenderOrder
end

local function perspectiveScaleForZ(z)
  local denom = 1 - (z or 0) * Config.PERSPECTIVE_Z_STRENGTH
  if denom < 0.35 then
    denom = 0.35
  end
  return clamp(1 / denom, Config.PERSPECTIVE_MIN_SCALE, Config.PERSPECTIVE_MAX_SCALE)
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
  return math.max(4, (Config.LIGHT_SOURCE_MARKER_RADIUS + Config.LIGHT_SOURCE_HIT_PADDING) * projectScale)
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
  return sampleOrbitColorCycle(state.time / Config.PLANET_COLOR_CYCLE_SECONDS)
end

local function computeOrbiterColor(angle)
  return sampleOrbitColorCycle(angle / Config.TWO_PI)
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
  love.graphics.print(tostring(text or ""):lower(), math.floor(x + 0.5), math.floor(y + 0.5))
end

local function drawOrbitIcon(x, y, size, alphaScale)
  local r = math.max(5, size or Config.ORBIT_ICON_SIZE)
  local alpha = clamp(alphaScale or 1, 0, 1)
  local orbitR = r
  local bodyR = math.max(2, math.floor(r * 0.34 + 0.5))
  local orbitRY = orbitR * Config.ORBIT_ICON_FLATTEN
  local angle = (state.time / Config.ORBIT_ICON_CYCLE_SECONDS) * Config.TWO_PI
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
  local rawScale = math.min(w / Config.GAME_W, h / Config.GAME_H)
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
  local drawW = Config.GAME_W * scale
  local drawH = Config.GAME_H * scale
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

local function patchFontWidth(font)
  if not font then return end
  local old = font.getWidth
  font.getWidth = function(self, text)
    return old(self, tostring(text or ""):lower())
  end
  return font
end

local function getUiScreenFont()
  local uiScale = scale >= 1 and scale or 1
  local size = math.max(1, math.floor(Config.UI_FONT_SIZE * uiScale + 0.5))
  if not uiScreenFont or uiScreenFontSize ~= size then
    uiScreenFont = patchFontWidth(love.graphics.newFont("font_gothic.ttf", size, "mono"))
    uiScreenFont:setFilter("nearest", "nearest")
    uiScreenFontSize = size
  end
  return uiScreenFont
end

function getTopDisplayFont()
  local uiScale = scale >= 1 and scale or 1
  local size = math.max(1, math.floor(Config.UI_FONT_SIZE * uiScale * 3.1 + 0.5))
  if not topDisplayFont or topDisplayFontSize ~= size then
    topDisplayFont = patchFontWidth(love.graphics.newFont("font_gothic.ttf", size, "mono"))
    topDisplayFont:setFilter("nearest", "nearest")
    topDisplayFontSize = size
  end
  return topDisplayFont
end

local function getCardFont(cardHeight)
  local uiScale = scale >= 1 and scale or 1
  local uiSize = math.max(1, math.floor(Config.UI_FONT_SIZE * uiScale + 0.5))
  local fitSize = clamp(math.floor(cardHeight * 0.16 + 0.5), 10, 48)
  local size = math.min(uiSize, fitSize)
  if not cardFont or cardFontSize ~= size then
    cardFont = patchFontWidth(love.graphics.newFont("font_gothic.ttf", size, "mono"))
    cardFont:setFilter("nearest", "nearest")
    cardFontSize = size
  end
  return cardFont
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
  if micro.coolDown <= 0 then
    return 1
  end
  local t = clamp(micro.coolDown / 0.16, 0, 1)
  return 1 - 0.09 * t
end

local function collectAllOrbiters()
  if not runtime.cardRun then
    return {}
  end
  return runtime.cardRun:collectAllOrbiters()
end

local function computeSystemOpe()
  if not runtime.cardRun then
    local total = 0
    local orbiters = state.renderOrbiters or {}
    for i = 1, #orbiters do
      local orbiter = orbiters[i]
      if orbiter and orbiter.cardBody then
        total = total + math.max(0, tonumber(orbiter.baseOpe) or 0)
      end
    end
    return total
  end
  return runtime.cardRun:computeSystemOpe()
end

local function triggerGravityPulse()
  if runtime.cardRun then
    runtime.cardRun:triggerGravityPulse()
  end
end

local function copyList(list)
  local out = {}
  for i = 1, #list do
    out[i] = list[i]
  end
  return out
end

local function syncMicroDisplayFromState()
  if micro.sequence then
    return
  end
  micro.lockInput = state.inputLocked == true
  micro.displayEnergy = state.energy
  micro.displayHeat = state.heat
  micro.displayEpoch = state.epoch
end

local function beginFloatingText(anchorId, label, color, opts)
  opts = opts or {}
  local anchor = ui.feedbackAnchors[anchorId] or {x = offsetX + Config.GAME_W * scale * 0.5, y = offsetY + Config.GAME_H * scale * 0.5}
  local now = state.time or 0
  local queueAt = micro.floatingQueueAt[anchorId] or now
  local queueSpacing = opts.queueSpacing or 0.22
  local spawnAt = math.max(now, queueAt)
  micro.floatingQueueAt[anchorId] = spawnAt + queueSpacing

  local lane = micro.floatingLane[anchorId] or 0
  micro.floatingLane[anchorId] = (lane + 1) % 3
  local laneOffset = (lane - 1) * (12 * math.max(scale, 1))
  local delay = (opts.delay or 0) + (spawnAt - now) + lane * 0.04
  micro.floatingTexts[#micro.floatingTexts + 1] = {
    x = anchor.x + laneOffset,
    y = anchor.y + (opts.yOffset or (-14 * math.max(scale, 1))),
    text = tostring(label or ""),
    color = color or swatch.brightest,
    age = -delay,
    life = opts.life or 4.00,
    rise = opts.rise or (42 * math.max(scale, 1)),
  }
end

local function beginWorldFloatingText(worldX, worldY, worldZ, label, color, opts)
  opts = opts or {}
  micro.worldFloatingTexts[#micro.worldFloatingTexts + 1] = {
    worldX = worldX,
    worldY = worldY,
    worldZ = worldZ or 0,
    yOffset = opts.yOffset or (22 * math.max(scale, 1)),
    text = tostring(label or ""),
    color = color or swatch.brightest,
    age = -(opts.delay or 0),
    life = opts.life or 2.10,
    rise = opts.rise or (56 * math.max(scale, 1)),
  }
end

local function cardEffectClass(cardDef)
  if not cardDef then
    return "generic"
  end
  local effectType = cardDef.effect and cardDef.effect.type or "none"
  if effectType == "vent_and_draw" then
    return "vent"
  end
  if effectType == "next_body_or_satellite_twice" or effectType == "grant_this_epoch_ope" then
    return "burst"
  end
  if effectType == "attach_satellite" then
    return "permanent"
  end
  if effectType == "draw_and_free_satellite" then
    return "support"
  end
  if cardDef.orbitClass == "Heavy" or (cardDef.spawnCount or 1) > 1 then
    return "summon"
  end
  return "generic"
end

local function cardTimingProfile(cardDef)
  local effectClass = cardEffectClass(cardDef)
  local orbitClass = cardDef and cardDef.orbitClass or ""
  local spawnCount = cardDef and (cardDef.spawnCount or 1) or 1
  local profile = {
    commit = 0.22,
    cost = 0.26,
    effect = 0.60,
    result = 0.28,
    settle = 0.20,
    summonGuide = 0.20,
    summonStreak = 0.40,
  }

  if effectClass == "vent" or effectClass == "support" then
    profile.commit = 0.20
    profile.cost = 0.24
    profile.effect = 0.50
    profile.result = 0.24
    profile.settle = 0.16
    profile.summonGuide = 0.18
    profile.summonStreak = 0.32
    return profile
  end

  if effectClass == "burst" then
    profile.effect = 0.76
    profile.result = 0.30
    profile.summonGuide = 0.24
    profile.summonStreak = 0.46
  end

  if orbitClass == "Heavy" or spawnCount > 1 then
    profile.commit = 0.24
    profile.cost = 0.30
    profile.effect = 0.80
    profile.result = 0.32
    profile.settle = 0.24
    profile.summonGuide = 0.22
    profile.summonStreak = 0.48
  end

  return profile
end

local function canResolveCardNow(cardDef)
  if not cardDef then
    return false
  end
  if runtime.cardRun and runtime.cardRun.canResolveCard then
    return runtime.cardRun:canResolveCard(cardDef)
  end
  return true
end

local function estimateCardHeatDelta(cardDef)
  if not cardDef then
    return 0
  end
  if runtime.cardRun and runtime.cardRun.getCardHeatDelta then
    return runtime.cardRun:getCardHeatDelta(cardDef)
  end
  return math.max(0, math.floor(tonumber(cardDef.heat) or 0))
end

local function cardHasHeatGain(cardDef)
  return estimateCardHeatDelta(cardDef) > 0
end

local function addMoonVisualPulse(duration)
  if duration <= 0 then
    return
  end
  local orbiters = collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if runtime.cardRun and runtime.cardRun:isMoonBody(orbiter) then
      orbiter.boostDurations = orbiter.boostDurations or {}
      orbiter.boostDurations[#orbiter.boostDurations + 1] = duration
    end
  end
end

local function triggerMachineFxForCard(cardDef)
  local effectClass = cardEffectClass(cardDef)
  if effectClass == "permanent" or effectClass == "support" then
    micro.orbitLineBoost = math.max(micro.orbitLineBoost, 0.60)
    micro.trailBoost = math.max(micro.trailBoost, 0.50)
    addMoonVisualPulse(0.14)
    return
  end
  if effectClass == "burst" then
    micro.orbitLineBoost = math.max(micro.orbitLineBoost, 0.65)
    micro.trailBoost = math.max(micro.trailBoost, 0.70)
    micro.corePulse = math.max(micro.corePulse, 0.20)
    addMoonVisualPulse(0.20)
    triggerGravityPulse()
    return
  end
  if effectClass == "vent" then
    micro.coolDown = math.max(micro.coolDown, 0.16)
    return
  end
  if effectClass == "reactor" then
    micro.corePulse = math.max(micro.corePulse, 0.12)
    return
  end
end

local function buildOrbiterSet(orbiters)
  local set = {}
  for i = 1, #orbiters do
    set[orbiters[i]] = true
  end
  return set
end

local function summonEntryStartPosition(orbiter)
  local tx = orbiter.x or cx
  local ty = orbiter.y or cy
  local dx = tx - cx
  local dy = ty - cy
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then
    dx, dy, len = 1, 0, 1
  end
  dx = dx / len
  dy = dy / len
  local edge = math.sqrt(Config.GAME_W * Config.GAME_W + Config.GAME_H * Config.GAME_H) * 0.62
  return cx + dx * edge, cy + dy * edge, (orbiter.z or 0) + 0.10
end

local function beginSummonStreakFor(orbiter, timing)
  if not orbiter then
    return
  end
  local sx, sy, sz = summonEntryStartPosition(orbiter)
  local guideDuration = timing and timing.summonGuide or 0.10
  local streakDuration = timing and timing.summonStreak or 0.20
  orbiter.microHidden = true
  micro.summonEntries[#micro.summonEntries + 1] = {
    orbiter = orbiter,
    age = 0,
    guideDuration = guideDuration,
    streakDuration = streakDuration,
    startX = sx,
    startY = sy,
    startZ = sz,
  }
end

local currentCardCost

local function beginCardPlaySequence(handIndex)
  if not runtime.cardRun or micro.lockInput or state.runComplete or state.phase ~= "planning" then
    return false
  end

  local cardId = state.hand[handIndex]
  if not cardId then
    return false
  end
  local cardDef = Config.CARD_DEFS[cardId]
  if not cardDef or not canResolveCardNow(cardDef) then
    return false
  end

  local cost = currentCardCost(cardDef)
  if state.energy < cost then
    return false
  end
  local timing = cardTimingProfile(cardDef)

  micro.lockInput = true
  micro.sequence = {
    type = "card_play",
    phase = "commit",
    timer = timing.commit,
    handIndex = handIndex,
    handSnapshot = copyList(state.hand),
    cardDef = cardDef,
    cost = cost,
    commitDuration = timing.commit,
    costDuration = timing.cost,
    resultDuration = timing.result,
    settleDuration = timing.settle,
    predictedHeatDelta = estimateCardHeatDelta(cardDef),
    beforeHeat = state.heat,
    beforeOpe = math.floor(computeSystemOpe() + 0.5),
    beforeOrbiters = buildOrbiterSet(collectAllOrbiters()),
    afterOpe = math.floor(computeSystemOpe() + 0.5),
    actualHeatDelta = 0,
    actualOpeDelta = 0,
    effectDuration = timing.effect,
    timing = timing,
  }
  return true
end

local function finalizeCardPlaySequence()
  micro.sequence = nil
  micro.lockInput = state.inputLocked == true
  micro.displayEnergy = state.energy
  micro.displayHeat = state.heat
  micro.displayEpoch = state.epoch
end

local function beginEpochSimulation()
  if not runtime.cardRun or micro.lockInput or state.runComplete or state.phase ~= "planning" then
    return false
  end
  local ended = runtime.cardRun:endEpoch()
  if ended then
    micro.lockInput = true
    beginFloatingText("epoch", "Epoch " .. tostring(state.epoch) .. " running", swatch.brightest, {life = 0.9, rise = 20})
  end
  return ended
end

local function endEpochFromUi()
  return beginEpochSimulation()
end

currentCardCost = function(cardDef)
  if runtime.cardRun then
    return runtime.cardRun:currentCardCost(cardDef)
  end
  return 0
end

local function playCard(handIndex)
  return beginCardPlaySequence(handIndex)
end

local function startCardRun()
  if runtime.cardRun then
    runtime.cardRun:startCardRun()
  end
  micro.lockInput = state.inputLocked == true
  micro.sequence = nil
  micro.floatingTexts = {}
  micro.worldFloatingTexts = {}
  micro.floatingLane = {}
  micro.floatingQueueAt = {}
  micro.summonEntries = {}
  micro.trailBoost = 0
  micro.orbitLineBoost = 0
  micro.corePulse = 0
  micro.coolDown = 0
  micro.reshuffleCue = 0
  micro.displayEnergy = state.energy
  micro.displayHeat = state.heat
  micro.displayEpoch = state.epoch
end

local function updateCardPlaySequence(dt)
  local ctx = micro.sequence
  if not ctx or ctx.type ~= "card_play" then
    return
  end

  ctx.timer = ctx.timer - dt
  if ctx.timer > 0 then
    return
  end

  if ctx.phase == "commit" then
    if ctx.cost > 0 then
      beginFloatingText("energy", string.format("-%d Energy", ctx.cost), swatch.brightest)
    end
    if cardHasHeatGain(ctx.cardDef) then
      beginFloatingText("heat", string.format("+%d Heat", math.max(0, ctx.predictedHeatDelta)), swatch.bright)
    end
    ctx.phase = "cost"
    ctx.timer = ctx.costDuration
    return
  end

  if ctx.phase == "cost" then
    local played = runtime.cardRun and runtime.cardRun:playCard(ctx.handIndex)
    if not played then
      finalizeCardPlaySequence()
      return
    end

    micro.displayEnergy = state.energy
    micro.displayHeat = state.heat
    ctx.actualHeatDelta = state.heat - ctx.beforeHeat
    if ctx.actualHeatDelta < 0 then
      beginFloatingText("heat", string.format("-%d Heat", -ctx.actualHeatDelta), swatch.brightest)
    elseif ctx.actualHeatDelta > 0 and ctx.predictedHeatDelta <= 0 then
      beginFloatingText("heat", string.format("+%d Heat", ctx.actualHeatDelta), swatch.bright)
    end

    local afterOrbiters = collectAllOrbiters()
    for i = 1, #afterOrbiters do
      local orbiter = afterOrbiters[i]
      if not ctx.beforeOrbiters[orbiter] then
        beginSummonStreakFor(orbiter, ctx.timing)
      end
    end

    triggerMachineFxForCard(ctx.cardDef)

    ctx.afterOpe = math.floor(computeSystemOpe() + 0.5)
    ctx.actualOpeDelta = ctx.afterOpe - ctx.beforeOpe

    ctx.phase = "effect"
    ctx.timer = ctx.effectDuration
    return
  end

  if ctx.phase == "effect" then
    if ctx.actualOpeDelta ~= 0 then
      local sign = ctx.actualOpeDelta > 0 and "+" or ""
      beginFloatingText("systemOpe", sign .. tostring(ctx.actualOpeDelta) .. " OPE", swatch.brightest)
    else
      beginFloatingText("systemOpe", tostring(ctx.afterOpe) .. " OPE", swatch.brightest)
    end
    ctx.phase = "result"
    ctx.timer = ctx.resultDuration
    return
  end

  if ctx.phase == "result" then
    ctx.phase = "settle"
    ctx.timer = ctx.settleDuration
    return
  end

  finalizeCardPlaySequence()
end

local function updateMicroInteractions(dt)
  for i = #micro.floatingTexts, 1, -1 do
    local text = micro.floatingTexts[i]
    text.age = text.age + dt
    if text.age >= text.life then
      table.remove(micro.floatingTexts, i)
    end
  end

  for i = #micro.worldFloatingTexts, 1, -1 do
    local text = micro.worldFloatingTexts[i]
    text.age = text.age + dt
    if text.age >= text.life then
      table.remove(micro.worldFloatingTexts, i)
    end
  end

  for i = #micro.summonEntries, 1, -1 do
    local entry = micro.summonEntries[i]
    entry.age = entry.age + dt
    local total = entry.guideDuration + entry.streakDuration
    if entry.age >= total then
      if entry.orbiter then
        entry.orbiter.microHidden = nil
      end
      table.remove(micro.summonEntries, i)
    end
  end

  micro.trailBoost = math.max(0, micro.trailBoost - dt)
  micro.orbitLineBoost = math.max(0, micro.orbitLineBoost - dt)
  micro.corePulse = math.max(0, micro.corePulse - dt)
  micro.coolDown = math.max(0, micro.coolDown - dt)
  micro.reshuffleCue = math.max(0, micro.reshuffleCue - dt)

  if micro.sequence then
    if micro.sequence.type == "card_play" then
      updateCardPlaySequence(dt)
    end
  end

  syncMicroDisplayFromState()
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
  if runtime.deckBuilder and runtime.deckBuilder:getDeckSize() < runtime.deckBuilder:getMinDeckSize() then
    openDeckMenu()
    return
  end
  startCardRun()
  switchScreen("run")
  micro.lockInput = state.inputLocked == true
  micro.displayEnergy = state.energy
  micro.displayEpoch = state.epoch
  beginFloatingText("epoch", "Epoch " .. tostring(state.epoch), swatch.brightest, {life = 0.9, rise = 20})
end

local function onPlanetClicked()
  state.planetBounceTime = Config.PLANET_BOUNCE_DURATION
end

local function initGameSystems()
  runtime.deckBuilder = Systems.DeckBuilder.new({
    state = state,
    config = Config,
    startingCurrency = 100,
    minDeckSize = 10,
    maxDeckSize = 20,
  })

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
    orbitConfigs = Config.ORBIT_CONFIGS,
    bodyVisual = Config.BODY_VISUAL,
    twoPi = Config.TWO_PI,
    maxMoons = Config.MAX_MOONS,
    maxSatellites = Config.MAX_SATELLITES,
    impulseDuration = Config.PLANET_IMPULSE_DURATION,
    impulseTargetBoost = Config.PLANET_IMPULSE_TARGET_BOOST,
    impulseRiseRate = Config.PLANET_IMPULSE_RISE_RATE,
    impulseFallRate = Config.PLANET_IMPULSE_FALL_RATE,
    createOrbitalParams = createOrbitalParams,
    updateOrbiterPosition = updateOrbiterPosition,
    assignRenderOrder = assignRenderOrder,
    getStabilitySpeedMultiplier = function()
      return blackHoleStabilitySpeedMultiplier()
    end,
    getTransientBoost = function()
      return 0
    end,
    disableOrbitRewards = true,
  })

  runtime.cardRun = Systems.CardRun.new({
    state = state,
    config = Config,
    orbiters = {
      addMoon = addMoon,
      addPlanet = addPlanet,
      addSatellite = addSatellite,
      updateOrbiterPosition = updateOrbiterPosition,
    },
    getRunDeck = function()
      if runtime.deckBuilder then
        return runtime.deckBuilder:getDeckListCopy()
      end
      return nil
    end,
    onCardPlayed = function()
      playMenuBuyClickFx()
    end,
    onRunFinished = function(_, _)
    end,
    onPayout = function(body, payout, _)
      if not body then
        return
      end
      beginFloatingText("points", "+" .. tostring(payout), swatch.brightest, {
        life = 1.6,
        rise = 42,
        queueSpacing = 0.10,
      })
      beginWorldFloatingText(body.x or cx, body.y or cy, body.z or 0, "+" .. tostring(payout), swatch.brightest, {
        life = 2.3,
        rise = 64,
        yOffset = 28,
      })
    end,
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
          setLitColorDirect(Config.SELECTED_ORBIT_COLOR[1], Config.SELECTED_ORBIT_COLOR[2], Config.SELECTED_ORBIT_COLOR[3], segLight, 0.84)
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
  for a = 0, Config.TWO_PI + step, step do
    local x = cx + math.cos(a) * Config.LIGHT_ORBIT_RADIUS_X
    local y = cy + math.sin(a) * Config.LIGHT_ORBIT_RADIUS_Y
    local z = Config.LIGHT_ORBIT_Z_BASE + math.sin(a + math.pi * 0.5) * Config.LIGHT_ORBIT_Z_VARIATION
    local projectedZ = lightProjectionZ(z)
    if px then
      local segProjZ = (pz + projectedZ) * 0.5
      if (frontPass and segProjZ > 0) or ((not frontPass) and segProjZ <= 0) then
        local segRawZ = (rawZ + z) * 0.5
        local segLight = cameraLightAt((px + x) * 0.5, (py + y) * 0.5, segRawZ)
        setLitColorDirect(Config.SELECTED_ORBIT_COLOR[1], Config.SELECTED_ORBIT_COLOR[2], Config.SELECTED_ORBIT_COLOR[3], segLight, 0.58)
        local sx0, sy0 = projectWorldPoint(px, py, pz)
        local sx1, sy1 = projectWorldPoint(x, y, projectedZ)
        love.graphics.line(math.floor(sx0 + 0.5), math.floor(sy0 + 0.5), math.floor(sx1 + 0.5), math.floor(sy1 + 0.5))
      end
    end
    px, py, pz, rawZ = x, y, projectedZ, z
  end
end

local function orbiterVisualRadius(orbiter)
  if orbiter and orbiter.visualRadius then
    return orbiter.visualRadius, orbiter.visualSegments or 20
  end
  local kind = orbiter and orbiter.kind or ""
  if kind == "moon" then
    return Config.BODY_VISUAL.moonRadius, 20
  end
  if kind == "planet" then
    return Config.BODY_VISUAL.orbitPlanetRadius, 24
  end
  if kind == "mega-planet" then
    return Config.BODY_VISUAL.megaPlanetRadius, 36
  end
  if kind == "satellite" then
    return Config.BODY_VISUAL.satelliteRadius, 18
  end
  if kind == "moon-satellite" then
    return Config.BODY_VISUAL.moonChildSatelliteRadius, 12
  end
  return Config.BODY_VISUAL.moonRadius, 20
end

local function drawOrbiterGuidePath(orbiter, frontPass, alpha)
  if not orbiter then
    return
  end

  local originX, originY, originZ = orbiterOrbitOrigin(orbiter)
  local cp = math.cos(orbiter.plane)
  local sp = math.sin(orbiter.plane)
  local px, py, pz
  local r, g, b = computeOrbiterColor(orbiter.angle)
  local guideAlpha = clamp(alpha or 0.52, 0, 1)

  for a = 0, math.pi * 2 + 0.12, 0.12 do
    local ox = math.cos(a) * orbiter.radius
    local oy = math.sin(a) * orbiter.radius * orbiter.flatten
    local x = originX + ox * cp - oy * sp
    local y = originY + ox * sp + oy * cp
    local z = originZ + (orbiter.zBase or 0) + math.sin(a) * (orbiter.depthScale or 1)
    if px then
      local segZ = (pz + z) * 0.5
      if (frontPass and segZ > 0) or ((not frontPass) and segZ <= 0) then
        local light = cameraLightAt((px + x) * 0.5, (py + y) * 0.5, segZ)
        setLitColorDirect(r, g, b, light, guideAlpha)
        local sx0, sy0 = projectWorldPoint(px, py, pz)
        local sx1, sy1 = projectWorldPoint(x, y, z)
        love.graphics.line(math.floor(sx0 + 0.5), math.floor(sy0 + 0.5), math.floor(sx1 + 0.5), math.floor(sy1 + 0.5))
      end
    end
    px, py, pz = x, y, z
  end
end

local function drawSummonEntries(frontPass)
  for i = 1, #micro.summonEntries do
    local entry = micro.summonEntries[i]
    local orbiter = entry.orbiter
    if orbiter then
      if entry.age < entry.guideDuration then
        local t = clamp(entry.age / math.max(0.001, entry.guideDuration), 0, 1)
        drawOrbiterGuidePath(orbiter, frontPass, 0.62 * (1 - t * 0.55))
      else
        local streakAge = entry.age - entry.guideDuration
        local streakT = clamp(streakAge / math.max(0.001, entry.streakDuration), 0, 1)
        local eased = smoothstep(streakT)
        local tx, ty, tz = orbiter.x or cx, orbiter.y or cy, orbiter.z or 0
        local x = lerp(entry.startX, tx, eased)
        local y = lerp(entry.startY, ty, eased)
        local z = lerp(entry.startZ, tz, eased)
        if (frontPass and z > 0) or ((not frontPass) and z <= 0) then
          local r, g, b = computeOrbiterColor(orbiter.angle)
          local radius, segments = orbiterVisualRadius(orbiter)
          local light = cameraLightAt(x, y, z)
          setLitColorDirect(r, g, b, light, 0.46 * (1 - streakT))
          local sx0, sy0 = projectWorldPoint(entry.startX, entry.startY, entry.startZ)
          local sx1, sy1 = projectWorldPoint(x, y, z)
          love.graphics.line(sx0, sy0, sx1, sy1)
          drawLitSphere(x, y, z, radius, r, g, b, light, segments)
        end
      end
    end
  end
end

local function drawMachineGuides(frontPass)
  if state.phase == "simulating" then
    return
  end

  if micro.orbitLineBoost > 0 and runtime.cardRun then
    local t = clamp(micro.orbitLineBoost / 0.20, 0, 1)
    local orbiters = collectAllOrbiters()
    for i = 1, #orbiters do
      if runtime.cardRun:isMoonBody(orbiters[i]) then
        drawOrbiterGuidePath(orbiters[i], frontPass, 0.34 + t * 0.22)
      end
    end
  end
  drawSummonEntries(frontPass)
end

function drawLitSphere(x, y, z, radius, r, g, b, lightScale, segments)
  local px, py, projectScale = projectWorldPoint(x, y, z or 0)
  local pr = math.max(0.6, radius * projectScale)
  local sideCount = segments or 24
  local shadeStyle = activeSphereShadeStyle()
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local lightPx, lightPy = projectWorldPoint(lightX, lightY, lightProjectionZ(lightZ))
  local objDepth = (z or 0) * Config.CAMERA_LIGHT_Z_SCALE
  local lightDepth = lightDepthForZ(lightZ)
  local lx = lightPx - px
  local ly = -(lightPy - py)
  local lz = (lightDepth - objDepth) / Config.CAMERA_LIGHT_Z_SCALE
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
    local shadowRadius = Config.BODY_VISUAL.planetRadius + pr * 0.9
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
  local inEclipse = shadowFactor <= Config.BODY_SHADE_ECLIPSE_THRESHOLD

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
    sphereShader:send("darkFloor", clamp(shadeStyle.darkFloor or Config.BODY_SHADE_DARK_FLOOR_TONE, 0, 1))
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
  local t = 1 - clamp(state.planetBounceTime / Config.PLANET_BOUNCE_DURATION, 0, 1)
  local kick = math.sin(t * math.pi)
  local bounceScale = 1 + kick * 0.14 * (1 - t)
  if micro.corePulse > 0 then
    local coreT = clamp(micro.corePulse / 0.20, 0, 1)
    bounceScale = bounceScale * (1 + coreT * 0.07)
  end
  if micro.coolDown > 0 then
    local coolT = clamp(micro.coolDown / 0.16, 0, 1)
    bounceScale = bounceScale * (1 - coolT * 0.05)
  end
  local px, py, projScale = projectWorldPoint(cx, cy, 0)
  local pr = math.max(3, Config.BODY_VISUAL.planetRadius * bounceScale * projScale)

  setColorDirect(0, 0, 0, 1)
  love.graphics.circle("fill", px, py, pr, 44)
  state.planetVisualRadius = pr * zoom
end

function drawLightSource(frontPass)
  -- Keep light influence active, but do not render a visible light body.
  return
end

function activeSpeedWaveRippleParams()
  local ripples = state.speedWaveRipples
  local ripple = ripples[#ripples]
  if not ripple then
    return false, 0, 0, 0, 0
  end

  local t = clamp(ripple.age / ripple.life, 0, 1)
  local travel = smoothstep(t)
  local coreR = clamp((state.planetVisualRadius or Config.BODY_VISUAL.planetRadius) / Config.GAME_H, 0.002, 0.45)
  local maxDx = math.max(cx, Config.GAME_W - cx)
  local maxDy = math.max(cy, Config.GAME_H - cy)
  local edgeR = math.sqrt(maxDx * maxDx + maxDy * maxDy) / Config.GAME_H + Config.SPEED_WAVE_RIPPLE_END_PADDING
  local radius = lerp(coreR * 1.15, edgeR, travel)
  local halfWidth = lerp(Config.SPEED_WAVE_RIPPLE_WIDTH_START, Config.SPEED_WAVE_RIPPLE_WIDTH_END, travel)
  local rampIn = smoothstep(clamp(t / 0.08, 0, 1))
  local rampOut = 1 - smoothstep(clamp((t - 0.78) / 0.22, 0, 1))
  local strength = rampIn * rampOut
  return true,
    radius,
    halfWidth,
    Config.SPEED_WAVE_RIPPLE_RADIAL_STRENGTH * strength,
    Config.SPEED_WAVE_RIPPLE_SWIRL_STRENGTH * strength
end

local function orbiterAngularVelocity(orbiter)
  if not orbiter then
    return 0
  end
  local kindMul = 1
  if runtime.orbiters and runtime.orbiters.getSpeedMultiplierForKind then
    kindMul = runtime.orbiters:getSpeedMultiplierForKind(orbiter.kind)
  end
  local totalBoost = (orbiter.boost or 0) + speedWaveBoostFor(orbiter)
  local stabilityMul = blackHoleStabilitySpeedMultiplier()
  return math.max(0, (orbiter.speed or 0) * kindMul * (1 + totalBoost) * stabilityMul)
end

local function trailLengthForLagSeconds(orbiter, lagSeconds)
  if not orbiter then
    return 0
  end
  local radius = math.max(1, orbiter.radius or 1)
  local lag = math.max(0.05, tonumber(lagSeconds) or 0.05)
  local omega = orbiterAngularVelocity(orbiter)
  local arcAngle = math.max(0.12, omega * lag)
  local maxArcTurns = math.max(0.35, tonumber(Config.TRAIL_MAX_ARC_TURNS) or 2.3)
  if state.phase == "simulating" then
    local simMax = tonumber(Config.TRAIL_MAX_ARC_TURNS_SIMULATION) or 0.75
    maxArcTurns = math.min(maxArcTurns, math.max(0.2, simMax))
  end
  local maxArcAngle = Config.TWO_PI * maxArcTurns
  arcAngle = math.min(maxArcAngle, arcAngle)
  return radius * arcAngle
end

function drawOrbitalTrail(orbiter, trailLen, headAlpha, tailAlpha, originX, originY, originZ, lightScale)
  local radius = math.max(orbiter.radius, 1)
  local arcAngle = trailLen / radius
  local stepCount = math.max(8, math.ceil(arcAngle / 0.10))
  stepCount = math.min(stepCount, 200)
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
      local gradientT = clamp(t, 0, 1)
      local r, g, b
      if gradientT < 0.5 then
        local blend = gradientT / 0.5
        r = lerp(swatch.brightest[1], swatch.bright[1], blend)
        g = lerp(swatch.brightest[2], swatch.bright[2], blend)
        b = lerp(swatch.brightest[3], swatch.bright[3], blend)
      else
        local blend = (gradientT - 0.5) / 0.5
        r = lerp(swatch.bright[1], swatch.mid[1], blend)
        g = lerp(swatch.bright[2], swatch.mid[2], blend)
        b = lerp(swatch.bright[3], swatch.mid[3], blend)
      end
      setColorDirect(r, g, b, alpha)
      local sx0, sy0 = projectWorldPoint(prevX, prevY, prevZ)
      local sx1, sy1 = projectWorldPoint(x, y, z)
      love.graphics.line(sx0, sy0, sx1, sy1)
    end
    prevX, prevY, prevZ = x, y, z
  end
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

  local trailBoostT = clamp(micro.trailBoost / 0.22, 0, 1)
  local trailMul = moon.trailMultiplier or 1
  local lagTrailLen = trailLengthForLagSeconds(moon, Config.TRAIL_LAG_SECONDS) * trailMul
  local originX, originY, originZ = orbiterOrbitOrigin(moon)
  drawOrbitalTrail(moon, lagTrailLen, 0.54 + trailBoostT * 0.16, 0.06, originX, originY, originZ, moon.light)

  local childSatellites = moon.childSatellites or {}
  local showChildOrbitPaths = state.selectedOrbiter == moon
  love.graphics.setLineWidth(1)
  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, false)
    end
  end

  local moonR, moonG, moonB = computeOrbiterColor(moon.angle)
  local visualRadius, visualSegments = orbiterVisualRadius(moon)
  drawLitSphere(moon.x, moon.y, moon.z, visualRadius, moonR, moonG, moonB, moon.light, visualSegments)

  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, true)
    end
  end
end

function drawMoonChildSatellite(child)
  local parentMoon = child.parentOrbiter or child.parentMoon
  local trailBoostT = clamp(micro.trailBoost / 0.22, 0, 1)
  local trailMul = child.trailMultiplier or 1
  local lagTrailLen = trailLengthForLagSeconds(child, Config.TRAIL_LAG_SECONDS) * trailMul
  local originX = parentMoon and parentMoon.x or cx
  local originY = parentMoon and parentMoon.y or cy
  local originZ = parentMoon and parentMoon.z or 0
  drawOrbitalTrail(child, lagTrailLen, 0.50 + trailBoostT * 0.12, 0.05, originX, originY, originZ, child.light)
  local childR, childG, childB = computeOrbiterColor(child.angle)
  local visualRadius, visualSegments = orbiterVisualRadius(child)
  drawLitSphere(child.x, child.y, child.z, visualRadius, childR, childG, childB, child.light, visualSegments)
end

function drawOrbitPlanet(planet)
  local trailBoostT = clamp(micro.trailBoost / 0.22, 0, 1)
  local trailMul = planet.trailMultiplier or 1
  local lagTrailLen = trailLengthForLagSeconds(planet, Config.TRAIL_LAG_SECONDS) * trailMul
  drawOrbitalTrail(planet, lagTrailLen, 0.56 + trailBoostT * 0.12, 0.07, nil, nil, 0, planet.light)
  local pr, pg, pb = computeOrbiterColor(planet.angle)
  local visualRadius, visualSegments = orbiterVisualRadius(planet)
  drawLitSphere(planet.x, planet.y, planet.z, visualRadius, pr, pg, pb, planet.light, visualSegments)
end

function drawMegaPlanet(megaPlanet)
  local lagTrailLen = trailLengthForLagSeconds(megaPlanet, Config.TRAIL_LAG_SECONDS)
  drawOrbitalTrail(megaPlanet, lagTrailLen, 0.62, 0.08, nil, nil, 0, megaPlanet.light)
  local pr, pg, pb = computeOrbiterColor(megaPlanet.angle)
  drawLitSphere(megaPlanet.x, megaPlanet.y, megaPlanet.z, Config.BODY_VISUAL.megaPlanetRadius, pr, pg, pb, megaPlanet.light, 36)
end

function drawSatellite(satellite)
  local trailBoostT = clamp(micro.trailBoost / 0.22, 0, 1)
  local trailMul = satellite.trailMultiplier or 1
  local lagTrailLen = trailLengthForLagSeconds(satellite, Config.TRAIL_LAG_SECONDS) * trailMul
  drawOrbitalTrail(satellite, lagTrailLen, 0.50 + trailBoostT * 0.10, 0.05, nil, nil, 0, satellite.light)
  local satR, satG, satB = computeOrbiterColor(satellite.angle)
  local visualRadius, visualSegments = orbiterVisualRadius(satellite)
  drawLitSphere(satellite.x, satellite.y, satellite.z, visualRadius, satR, satG, satB, satellite.light, visualSegments)
end

function orbiterHitRadius(orbiter)
  local baseRadius = orbiter and orbiter.visualRadius or nil
  local margin
  if baseRadius then
    margin = 2
  elseif orbiter.kind == "moon" then
    baseRadius = Config.BODY_VISUAL.moonRadius
    margin = 2
  elseif orbiter.kind == "mega-planet" then
    baseRadius = Config.BODY_VISUAL.megaPlanetRadius
    margin = 2
  elseif orbiter.kind == "planet" then
    baseRadius = Config.BODY_VISUAL.orbitPlanetRadius
    margin = 2
  elseif orbiter.kind == "satellite" then
    baseRadius = Config.BODY_VISUAL.satelliteRadius
    margin = 1.5
  elseif orbiter.kind == "moon-satellite" then
    baseRadius = Config.BODY_VISUAL.moonChildSatelliteRadius
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
  if orbiter and orbiter.microHidden then
    return
  end
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
  local viewportRight = offsetX + Config.GAME_W * scale
  local viewportBottom = offsetY + Config.GAME_H * scale
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

local function getRunBodyCount()
  if runtime.cardRun and runtime.cardRun.getBodyCount then
    return runtime.cardRun:getBodyCount()
  end
  return 0
end

local function previewBodyCardBonus(_, _)
  return 0
end

local function computeCardPreviewYield(cardDef, _, _)
  if not cardDef then
    return 0
  end
  if cardDef.type ~= "body" then
    return 0
  end
  local spawnCount = math.max(1, math.floor(tonumber(cardDef.spawnCount) or 1))
  local ope = math.max(0, math.floor(tonumber(cardDef.ope) or 0))
  local yieldPerOrbit = math.max(0, math.floor(tonumber(cardDef.yieldPerOrbit) or 0))
  return ope * yieldPerOrbit * spawnCount
end

local function getCardDescriptionParts(cardDef, _, _, _)
  if not cardDef then
    return "", "", ""
  end
  local typeText = cardDef.type or "card"
  local line = cardDef.line or ""
  local detail = cardDef.tooltip or ""
  return string.lower(typeText) .. ": ", line, detail
end

local function trimTextToWidth(text, maxWidth, font)
  local value = tostring(text or "")
  if maxWidth <= 0 then
    return ""
  end
  if font:getWidth(value) <= maxWidth then
    return value
  end
  local suffix = "..."
  local suffixW = font:getWidth(suffix)
  if suffixW > maxWidth then
    return ""
  end
  for i = #value, 1, -1 do
    local candidate = value:sub(1, i) .. suffix
    if font:getWidth(candidate) <= maxWidth then
      return candidate
    end
  end
  return ""
end

local function lineTokenWidth(tokens, font)
  local width = 0
  local spaceW = font:getWidth(" ")
  for i = 1, #tokens do
    if i > 1 then
      width = width + spaceW
    end
    width = width + font:getWidth(tokens[i].text)
  end
  return width
end

local function buildWrappedCardDescriptionLines(pre, hi, post, maxWidth, maxLines, font)
  local tokens = {}
  local function appendWords(text, isHighlight)
    for word in tostring(text or ""):gmatch("%S+") do
      tokens[#tokens + 1] = {text = word, hi = isHighlight}
    end
  end

  appendWords(pre, false)
  appendWords(hi, true)
  appendWords(post, false)

  local lines = {}
  local current = {}
  local currentW = 0
  local spaceW = font:getWidth(" ")
  local tokenIndex = 1
  local truncated = false

  while tokenIndex <= #tokens do
    local token = tokens[tokenIndex]
    local tokenW = font:getWidth(token.text)
    local prefixW = (#current > 0) and spaceW or 0
    local projectedW = currentW + prefixW + tokenW

    if #current > 0 and projectedW > maxWidth then
      lines[#lines + 1] = current
      if #lines >= maxLines then
        truncated = true
        break
      end
      current = {}
      currentW = 0
    else
      current[#current + 1] = token
      currentW = projectedW
      tokenIndex = tokenIndex + 1
    end
  end

  if not truncated and #current > 0 and #lines < maxLines then
    lines[#lines + 1] = current
  end

  if #lines == 0 then
    lines[1] = {}
  end

  if truncated then
    local last = lines[#lines]
    local ellipsis = "..."
    local ellipsisW = font:getWidth(ellipsis)
    while #last > 0 and (lineTokenWidth(last, font) + ellipsisW) > maxWidth do
      table.remove(last)
    end
    if #last == 0 then
      if ellipsisW <= maxWidth then
        last[1] = {text = ellipsis, hi = false}
      end
    else
      last[#last].text = last[#last].text .. ellipsis
    end
  end

  return lines
end

local function drawCardDescriptionWrapped(pre, hi, post, x, y, maxWidth, maxLines, lineH, alpha)
  local font = love.graphics.getFont()
  local lines = buildWrappedCardDescriptionLines(pre, hi, post, maxWidth, maxLines, font)
  local spaceW = font:getWidth(" ")

  for lineIndex = 1, #lines do
    local tokens = lines[lineIndex]
    local cursorX = x
    local lineY = y + (lineIndex - 1) * lineH
    for tokenIndex = 1, #tokens do
      local token = tokens[tokenIndex]
      if tokenIndex > 1 then
        cursorX = cursorX + spaceW
      end
      if token.hi then
        setColorScaled(swatch.brightest, 1, 0.98 * alpha)
      else
        setColorScaled(palette.text, 1, 0.84 * alpha)
      end
      drawText(token.text, cursorX, lineY)
      cursorX = cursorX + font:getWidth(token.text)
    end
  end
end

local function drawCardMoonIllustration(x, y, radius, alpha)
  local r = math.max(2, radius)
  if sphereShader and spherePixel then
    local shadeStyle = activeSphereShadeStyle()
    local prevShader = love.graphics.getShader()
    love.graphics.setShader(sphereShader)
    sphereShader:send("baseColor", {palette.moonFront[1], palette.moonFront[2], palette.moonFront[3]})
    sphereShader:send("lightVec", {0.80, 0.30, 0.52})
    sphereShader:send("lightPower", 0.94)
    sphereShader:send("ambient", 0.24)
    sphereShader:send("contrast", shadeStyle.contrast or 1.08)
    sphereShader:send("darkFloor", clamp(shadeStyle.darkFloor or Config.BODY_SHADE_DARK_FLOOR_TONE, 0, 1))
    sphereShader:send("toneSteps", shadeStyle.toneSteps or 0)
    sphereShader:send("facetSides", shadeStyle.facetSides or 0)
    sphereShader:send("ditherStrength", shadeStyle.ditherStrength or 0)
    sphereShader:send("ditherScale", shadeStyle.ditherScale or 1)
    love.graphics.setColor(1, 1, 1, clamp(alpha or 1, 0, 1))
    love.graphics.draw(spherePixel, x - r, y - r, 0, r * 2, r * 2)
    love.graphics.setShader(prevShader)
  else
    setColorScaled(swatch.brightest, 1, 0.94 * alpha)
    love.graphics.circle("fill", x, y, r, 20)
    setColorScaled(swatch.mid, 1, 0.86 * alpha)
    love.graphics.circle("fill", x + r * 0.28, y - r * 0.08, r * 0.86, 20)
    setColorScaled(swatch.dim, 1, 0.42 * alpha)
    love.graphics.circle("fill", x - r * 0.34, y + r * 0.12, r * 0.16, 10)
  end
  setColorScaled(swatch.brightest, 1, 0.56 * alpha)
  love.graphics.circle("line", x, y, r, 20)
end

local function drawCardFace(btn, cardDef, opts)
  local hovered = opts and opts.hovered or false
  local alpha = opts and (opts.alpha or 1) or 1
  local cost = opts and opts.cost
  if cost == nil then
    cost = cardDef and cardDef.cost or 0
  end
  local moonCount = opts and opts.moonCount or 0
  local moonBonus = opts and opts.moonBonus or 0
  local footerText = opts and opts.footerText or ""

  local x = btn.x
  local y = btn.y
  local w = btn.w
  local h = btn.h
  local pad = math.max(4, math.floor(math.min(w, h) * 0.08))
  local innerW = math.max(1, w - pad * 2)

  setColorScaled(swatch.darkest, 1, 0.95 * alpha)
  love.graphics.rectangle("fill", x, y, w, h)
  setColorScaled(swatch.brightest, 1, (hovered and 1 or 0.75) * alpha)
  love.graphics.rectangle("line", x, y, w, h)

  local previousFont = love.graphics.getFont()
  local cardLocalFont = getCardFont(h)
  love.graphics.setFont(cardLocalFont)
  local lineH = cardLocalFont:getHeight()

  local topY = y + pad - math.floor(lineH * 0.12)
  setColorScaled(swatch.bright, 1, 0.98 * alpha)
  drawText(tostring(cost), x + pad, topY)

  local previewYield = computeCardPreviewYield(cardDef, moonCount, moonBonus)
  local yieldText = (previewYield >= 0 and "+" or "") .. tostring(previewYield) .. " yld"
  setColorScaled(swatch.brightest, 1, 0.98 * alpha)
  drawText(yieldText, x + w - pad - cardLocalFont:getWidth(yieldText), topY)

  local moonRadius = math.max(6, math.floor(math.min(w * 0.22, h * 0.16)))
  local moonX = x + math.floor(w * 0.5)
  local moonY = y + math.floor(h * 0.40)
  drawCardMoonIllustration(moonX, moonY, moonRadius, alpha)

  local descriptionY = moonY + moonRadius + math.max(5, math.floor(h * 0.05))
  local footerY = nil
  if footerText ~= "" then
    footerY = y + h - lineH - math.max(2, math.floor(h * 0.03))
  end
  local descriptionBottom = footerY and (footerY - math.max(3, math.floor(h * 0.03))) or (y + h - pad)
  local maxDescriptionLines = math.max(1, math.floor((descriptionBottom - descriptionY) / math.max(1, lineH)))
  local pre, hi, post = getCardDescriptionParts(cardDef, moonCount, moonBonus, previewYield)
  drawCardDescriptionWrapped(pre, hi, post, x + pad, descriptionY, innerW, maxDescriptionLines, lineH, alpha)

  if footerText ~= "" then
    setColorScaled(palette.text, 1, 0.76 * alpha)
    local label = trimTextToWidth(footerText, innerW, cardLocalFont)
    drawText(label, x + w - pad - cardLocalFont:getWidth(label), footerY)
  end

  love.graphics.setFont(previousFont)
end

local function expandCardEntries(entries)
  local cards = {}
  for i = 1, #entries do
    local entry = entries[i]
    local count = math.max(0, math.floor(entry.count or 0))
    for _ = 1, count do
      cards[#cards + 1] = entry.id
    end
  end
  return cards
end

local function chooseCardGridLayout(totalCards, listW, listH, gap, minCardW, maxCols)
  local columnsCap = math.max(1, maxCols or 6)
  local minWidth = math.max(40, minCardW or 72)
  local fallbackCols = 1
  local fallbackW = math.floor(listW)
  local fallbackH = math.floor(fallbackW * 1.42)

  for cols = 1, columnsCap do
    local cardW = math.floor((listW - gap * (cols - 1)) / cols)
    if cardW < minWidth then
      break
    end
    local cardH = math.floor(cardW * 1.42)
    fallbackCols = cols
    fallbackW = cardW
    fallbackH = cardH
    local rows = math.max(1, math.ceil(math.max(1, totalCards) / cols))
    local neededH = rows * cardH + math.max(0, rows - 1) * gap
    if neededH <= listH then
      return cols, cardW, cardH
    end
  end

  return fallbackCols, fallbackW, fallbackH
end

local function handFanYOffset(index, count, uiScale)
  if count <= 1 then
    return 0
  end
  local center = (count + 1) * 0.5
  local dist = math.abs(index - center)
  return math.floor(dist * 1.5 * uiScale)
end

local function drawFloatingTexts()
  local font = love.graphics.getFont()
  for i = 1, #micro.worldFloatingTexts do
    local entry = micro.worldFloatingTexts[i]
    if entry.age >= 0 then
      local t = clamp(entry.age / math.max(0.001, entry.life), 0, 1)
      local eased = smoothstep(t)
      local alpha = 1 - eased
      local gx, gy = projectWorldPoint(entry.worldX, entry.worldY, entry.worldZ)
      gx = (gx - cx) * zoom + cx
      gy = (gy - cy) * zoom + cy
      local sx, sy = toScreenSpace(gx, gy)
      local x = sx - font:getWidth(entry.text) * 0.5
      local y = sy - entry.yOffset - entry.rise * eased
      setColorScaled(entry.color, 1, alpha)
      drawText(entry.text, x, y)
    end
  end

  for i = 1, #micro.floatingTexts do
    local entry = micro.floatingTexts[i]
    if entry.age >= 0 then
      local t = clamp(entry.age / math.max(0.001, entry.life), 0, 1)
      local eased = smoothstep(t)
      local y = entry.y - entry.rise * eased
      local alpha = 1 - eased
      local x = entry.x - font:getWidth(entry.text) * 0.5
      setColorScaled(entry.color, 1, alpha)
      drawText(entry.text, x, y)
    end
  end
end

local function drawHud()
  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local lineH = math.floor(font:getHeight())
  local mouseX, mouseY = love.mouse.getPosition()
  local viewportX = offsetX
  local viewportY = offsetY
  local viewportW = Config.GAME_W * scale
  local viewportH = Config.GAME_H * scale

  local systemOpe = math.floor(computeSystemOpe() + 0.5)
  local points = math.max(0, math.floor(tonumber(state.points) or 0))
  local titleFont = getTopDisplayFont()
  local topY = viewportY + math.floor(4 * uiScale)
  local centerX = viewportX + viewportW * 0.5
  love.graphics.setFont(titleFont)
  local pointsText = tostring(points)
  setColorScaled(swatch.bright, 1, 1)
  drawText(pointsText, centerX - titleFont:getWidth(pointsText) * 0.5, topY)
  love.graphics.setFont(font)
  local pointsLabelY = topY + titleFont:getHeight() - math.floor(8 * uiScale)
  setColorScaled(palette.text, 1, 0.9)
  drawText("points", centerX - font:getWidth("points") * 0.5, pointsLabelY)
  local opeY = pointsLabelY + lineH + math.floor(2 * uiScale)
  local opeText = "system ope " .. tostring(systemOpe)
  setColorScaled(palette.text, 1, 0.85)
  drawText(opeText, centerX - font:getWidth(opeText) * 0.5, opeY)
  ui.feedbackAnchors.points.x = centerX
  ui.feedbackAnchors.points.y = topY + math.floor(titleFont:getHeight() * 0.3)
  ui.feedbackAnchors.systemOpe.x = centerX
  ui.feedbackAnchors.systemOpe.y = opeY + math.floor(lineH * 0.5)

  local cardW = math.floor(Config.CARD_W * uiScale)
  local cardH = math.floor(Config.CARD_H * uiScale)
  local cardGap = math.floor(Config.CARD_GAP * uiScale)
  local cardY = viewportY + viewportH - cardH - math.floor(12 * uiScale)
  local fixedSlots = Config.STARTING_HAND_SIZE
  local fixedHandW = fixedSlots * cardW + (fixedSlots - 1) * cardGap
  local fixedStartX = viewportX + math.floor((viewportW - fixedHandW) * 0.5)

  local statsTitleY = cardY - lineH * 2 - math.floor(14 * uiScale)
  local statsValueY = statsTitleY + lineH + math.floor(2 * uiScale)
  local statColW = fixedHandW / 3
  local epochX = fixedStartX + statColW * 0.5
  local energyX = fixedStartX + statColW * 1.5
  local heatX = fixedStartX + statColW * 2.5

  local epochTitle = "epoch"
  local energyTitle = "energy"
  local heatTitle = "heat"
  local epochValue = string.format("%d/%d", micro.displayEpoch or state.epoch, state.maxEpochs)
  local energyValue = tostring(micro.displayEnergy)
  local heatValue = string.format("%d/%d", micro.displayHeat, state.heatCap)

  setColorScaled(palette.text, 1, 0.82)
  drawText(epochTitle, epochX - font:getWidth(epochTitle) * 0.5, statsTitleY)
  drawText(energyTitle, energyX - font:getWidth(energyTitle) * 0.5, statsTitleY)
  drawText(heatTitle, heatX - font:getWidth(heatTitle) * 0.5, statsTitleY)
  setColorScaled(palette.text, 1, 0.95)
  drawText(epochValue, epochX - font:getWidth(epochValue) * 0.5, statsValueY)
  drawText(energyValue, energyX - font:getWidth(energyValue) * 0.5, statsValueY)
  drawText(heatValue, heatX - font:getWidth(heatValue) * 0.5, statsValueY)

  local anchorY = statsTitleY - lineH - math.floor(10 * uiScale)
  ui.feedbackAnchors.epoch.x = epochX
  ui.feedbackAnchors.epoch.y = anchorY
  ui.feedbackAnchors.energy.x = energyX
  ui.feedbackAnchors.energy.y = anchorY
  ui.feedbackAnchors.heat.x = heatX
  ui.feedbackAnchors.heat.y = anchorY

  local pileW = math.floor(94 * uiScale)
  local pileH = math.floor(56 * uiScale)
  local reshuffleT = clamp(micro.reshuffleCue / 0.16, 0, 1)
  local reshuffleJitter = math.sin((1 - reshuffleT) * 52) * (4 * uiScale) * reshuffleT
  ui.drawPile.x = fixedStartX - pileW - math.floor(12 * uiScale) + reshuffleJitter
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
  if reshuffleT > 0 then
    setColorScaled(swatch.bright, 1, 0.75 * reshuffleT)
    love.graphics.rectangle("line", ui.drawPile.x - 1, ui.drawPile.y - 1, ui.drawPile.w + 2, ui.drawPile.h + 2)
  end
  setColorScaled(swatch.darkest, 1, 0.95)
  drawText("draw", ui.drawPile.x + math.floor(8 * uiScale), ui.drawPile.y + math.floor(5 * uiScale))
  drawText(tostring(#state.drawPile), ui.drawPile.x + math.floor(8 * uiScale), ui.drawPile.y + math.floor(5 * uiScale) + lineH)
  drawText("discard", ui.discardPile.x + math.floor(8 * uiScale), ui.discardPile.y + math.floor(5 * uiScale))
  drawText(tostring(#state.discardPile), ui.discardPile.x + math.floor(8 * uiScale), ui.discardPile.y + math.floor(5 * uiScale) + lineH)

  local endBtn = ui.endTurnBtn
  endBtn.w = math.floor(Config.END_TURN_W * uiScale)
  endBtn.h = math.floor(Config.END_TURN_H * uiScale)
  endBtn.x = viewportX + viewportW - endBtn.w - math.floor(10 * uiScale)
  endBtn.y = viewportY + viewportH - endBtn.h - math.floor(12 * uiScale)
  local canEndEpoch = (not state.runComplete) and (state.phase == "planning") and (not micro.lockInput)
  local endHovered = canEndEpoch and pointInRect(mouseX, mouseY, endBtn)
  local endAlpha = canEndEpoch and 1 or 0.45
  setColorScaled(swatch.brightest, 1, (endHovered and 1 or 0.92) * endAlpha)
  love.graphics.rectangle("fill", endBtn.x, endBtn.y, endBtn.w, endBtn.h)
  setColorScaled(swatch.darkest, 1, (endHovered and 1 or 0.88) * endAlpha)
  love.graphics.rectangle("line", endBtn.x, endBtn.y, endBtn.w, endBtn.h)
  setColorScaled(swatch.darkest, 1, endAlpha)
  local endLabel = "end epoch"
  drawText(endLabel, endBtn.x + math.floor((endBtn.w - font:getWidth(endLabel)) * 0.5), endBtn.y + math.floor((endBtn.h - lineH) * 0.5))

  local sequence = micro.sequence
  local handCards = state.hand
  local handMode = "live"
  if sequence and sequence.type == "card_play" then
    handCards = sequence.handSnapshot
    handMode = "card_play"
  end

  local handCount = #handCards
  local handW = handCount > 0 and (handCount * cardW + (handCount - 1) * cardGap) or 0
  local startX = viewportX + math.floor((viewportW - handW) * 0.5)
  local hoveredTooltipLines
  local hoveredTooltipBtn
  local moonCount = getRunBodyCount()
  local interactive = (handMode == "live") and (not micro.lockInput) and (not state.runComplete)

  for i = #ui.cardButtons, handCount + 1, -1 do
    ui.cardButtons[i] = nil
    state.cardHoverLift[i] = nil
  end

  for i = 1, handCount do
    local cardId = handCards[i]
    local cardDef = Config.CARD_DEFS[cardId]
    local btn = ui.cardButtons[i] or {}
    ui.cardButtons[i] = btn
    local fanY = handFanYOffset(i, handCount, uiScale)
    local finalX = startX + (i - 1) * (cardW + cardGap)
    local finalY = cardY + fanY
    local drawX = finalX
    local drawY = finalY
    local alpha = 1
    local hovered = false
    local skipDraw = false

    if handMode == "card_play" then
      if i == sequence.handIndex then
        skipDraw = true
      else
        alpha = 0.62
      end
    elseif handMode == "discard" then
      local p = smoothstep(1 - clamp(sequence.timer / math.max(0.001, sequence.discardDuration), 0, 1))
      local targetX = ui.discardPile.x + (ui.discardPile.w - cardW) * 0.5
      local targetY = ui.discardPile.y + (ui.discardPile.h - cardH) * 0.5
      drawX = lerp(finalX, targetX, p)
      drawY = lerp(finalY, targetY, p)
      alpha = 1 - p * 0.55
    elseif handMode == "draw" then
      local delay = (i - 1) * sequence.drawStagger
      local t = clamp((sequence.drawElapsed - delay) / math.max(0.001, sequence.drawItemDuration), 0, 1)
      local eased = smoothstep(t)
      local startCardX = ui.drawPile.x + (ui.drawPile.w - cardW) * 0.5
      local startCardY = ui.drawPile.y + (ui.drawPile.h - cardH) * 0.5
      drawX = lerp(startCardX, finalX, eased)
      drawY = lerp(startCardY, finalY, eased)
      alpha = t
      if t <= 0 then
        skipDraw = true
      end
    end

    btn.x = drawX
    btn.y = drawY
    btn.w = cardW
    btn.h = cardH
    btn.cardId = cardId
    btn.index = i

    if interactive then
      local hoverLift = state.cardHoverLift[i] or 0
      hovered = pointInRect(mouseX, mouseY, btn)
      local targetLift = hovered and (6 * uiScale) or 0
      hoverLift = hoverLift + (targetLift - hoverLift) * 0.22
      state.cardHoverLift[i] = hoverLift
      btn.y = drawY - hoverLift
      hovered = pointInRect(mouseX, mouseY, btn)
    else
      state.cardHoverLift[i] = 0
    end

    local cardCost = currentCardCost(cardDef)
    if handMode == "card_play" and i == sequence.handIndex then
      cardCost = sequence.cost
    end
    local moonBonus = previewBodyCardBonus(cardDef, i)
    local playable = cardDef and canResolveCardNow(cardDef) and (state.energy >= cardCost) and (not state.runComplete)
    local cardAlpha = alpha
    if handMode == "live" then
      cardAlpha = cardAlpha * (playable and 1 or 0.45)
      if state.phase ~= "planning" then
        cardAlpha = cardAlpha * 0.55
      end
    end
    if not skipDraw and cardAlpha > 0 and cardDef then
      drawCardFace(btn, cardDef, {
        hovered = hovered,
        alpha = cardAlpha,
        cost = cardCost,
        moonCount = moonCount,
        moonBonus = moonBonus,
      })
    end

    if interactive and hovered and cardDef then
      local heatDelta = estimateCardHeatDelta(cardDef)
      local heatSign = heatDelta > 0 and "+" or ""
      hoveredTooltipBtn = btn
      hoveredTooltipLines = {
        {pre = cardDef.tooltip or "", hi = "", post = ""},
        {pre = "cost ", hi = tostring(cardCost), post = " energy"},
        {pre = "heat ", hi = heatSign .. tostring(heatDelta), post = ""},
        {pre = "type ", hi = tostring(cardDef.type or cardDef.orbitClass or "-"), post = ""},
      }
    end
  end

  if handMode == "card_play" and sequence and sequence.cardDef then
    local i = sequence.handIndex
    local fanY = handFanYOffset(i, handCount, uiScale)
    local baseX = startX + (i - 1) * (cardW + cardGap)
    local baseY = cardY + fanY
    local focusT = 1
    if sequence.phase == "commit" then
      focusT = smoothstep(1 - clamp(sequence.timer / math.max(0.001, sequence.commitDuration), 0, 1))
    end

    local ghostScale = 1 + 0.05 * focusT
    local ghostX = baseX
    local ghostY = baseY - 8 * uiScale * focusT
    if sequence.phase == "settle" then
      local p = smoothstep(1 - clamp(sequence.timer / math.max(0.001, sequence.settleDuration), 0, 1))
      local targetX = ui.discardPile.x + (ui.discardPile.w - cardW) * 0.5
      local targetY = ui.discardPile.y + (ui.discardPile.h - cardH) * 0.5
      ghostX = lerp(baseX, targetX, p)
      ghostY = lerp(baseY - 8 * uiScale, targetY, p)
      ghostScale = lerp(1.05, 0.90, p)
    end

    local ghostW = cardW * ghostScale
    local ghostH = cardH * ghostScale
    local ghostBtn = {
      x = ghostX - (ghostW - cardW) * 0.5,
      y = ghostY - (ghostH - cardH) * 0.5,
      w = ghostW,
      h = ghostH,
    }
    drawCardFace(ghostBtn, sequence.cardDef, {
      hovered = true,
      alpha = 1,
      cost = sequence.cost,
      moonCount = moonCount,
      moonBonus = previewBodyCardBonus(sequence.cardDef, sequence.handIndex),
    })
  end

  drawHoverTooltip(hoveredTooltipLines, hoveredTooltipBtn, uiScale, lineH, true)
  drawFloatingTexts()
end

function drawMainMenu()
  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local lineH = math.floor(font:getHeight())
  local mouseX, mouseY = love.mouse.getPosition()
  local viewportX = offsetX
  local viewportY = offsetY
  local viewportW = Config.GAME_W * scale
  local viewportH = Config.GAME_H * scale

  local title = "orbit protocol"
  local titleFont = getTopDisplayFont()
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
  local viewportW = Config.GAME_W * scale
  local viewportH = Config.GAME_H * scale
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
  local title = "deck menu"

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
  local currency = runtime.deckBuilder and runtime.deckBuilder:getCurrency() or state.currency
  local minDeckSize = runtime.deckBuilder and runtime.deckBuilder:getMinDeckSize() or 10
  local maxDeckSize = runtime.deckBuilder and runtime.deckBuilder:getMaxDeckSize() or 20
  local deckSize = runtime.deckBuilder and runtime.deckBuilder:getDeckSize() or 0
  local currencyText = "currency " .. tostring(currency)
  local deckSizeText = string.format("deck %d/%d-%d", deckSize, minDeckSize, maxDeckSize)
  local titleX = panelX + headerPad
  local headerY = backBtn.y + math.floor((backBtn.h - lineH) * 0.5)
  local statText = currencyText .. "   " .. deckSizeText
  local statGap = math.floor(18 * uiScale)
  local statX = backBtn.x - statGap - font:getWidth(statText)
  local minStatX = titleX + font:getWidth(title) + math.floor(18 * uiScale)
  if statX < minStatX then
    statX = minStatX
  end

  setColorScaled(palette.text, 1, 0.95)
  drawText(title, titleX, headerY)
  setColorScaled(palette.text, 1, 0.90)
  drawText(statText, statX, headerY)

  local contentX = panelX + headerPad
  local contentY = backBtn.y + backBtn.h + math.floor(14 * uiScale)
  local contentW = panelW - headerPad * 2
  local contentH = panelH - (contentY - panelY) - headerPad
  local colGap = math.floor(10 * uiScale)
  local colW = math.floor((contentW - colGap * 2) / 3)
  local headers = {"deck", "inventory", "shop"}

  local deckEntries = runtime.deckBuilder and runtime.deckBuilder:listDeckEntries() or {}
  local inventoryEntries = runtime.deckBuilder and runtime.deckBuilder:listInventoryEntries() or {}
  local deckCounts = runtime.deckBuilder and runtime.deckBuilder:getDeckCounts() or {}
  local inventoryCounts = runtime.deckBuilder and runtime.deckBuilder:getInventoryCounts() or {}
  local deckCards = expandCardEntries(deckEntries)
  local inventoryCards = expandCardEntries(inventoryEntries)
  local shopCards = {}
  for n = 1, #Config.SHOP_CARD_ORDER do
    shopCards[#shopCards + 1] = Config.SHOP_CARD_ORDER[n]
  end
  local hoveredTooltipLines
  local hoveredTooltipBtn
  local moonCount = getRunBodyCount()

  for i = 1, 3 do
    local colX = contentX + (i - 1) * (colW + colGap)
    local colY = contentY
    setColorScaled(swatch.nearDark, 1, 0.95)
    love.graphics.rectangle("fill", colX, colY, colW, contentH)
    setColorScaled(swatch.brightest, 1, 0.7)
    love.graphics.rectangle("line", colX, colY, colW, contentH)
    setColorScaled(palette.text, 1, 0.95)
    drawText(headers[i], colX + math.floor(10 * uiScale), colY + math.floor(8 * uiScale))

    local listPad = math.floor(8 * uiScale)
    local listX = colX + listPad
    local listY = colY + lineH + math.floor(18 * uiScale)
    local listW = colW - listPad * 2
    local listH = contentH - (listY - colY) - listPad
    local cardGap = math.max(4, math.floor(6 * uiScale))
    local cards = nil
    local buttonList = nil
    local minCardW = math.max(56, math.floor(58 * uiScale))
    local maxCols = 6
    local mode = headers[i]

    if mode == "deck" then
      cards = deckCards
      buttonList = ui.deckCardButtons
    elseif mode == "inventory" then
      cards = inventoryCards
      buttonList = ui.deckInventoryButtons
    elseif mode == "shop" then
      cards = shopCards
      buttonList = ui.deckShopButtons
      minCardW = math.max(62, math.floor(64 * uiScale))
      maxCols = 5
    end

    if not cards or not buttonList then
      setColorScaled(palette.text, 1, 0.55)
      drawText("empty", colX + math.floor(10 * uiScale), colY + lineH + math.floor(18 * uiScale))
    else
      for n = #buttonList, #cards + 1, -1 do
        buttonList[n] = nil
      end

      if #cards == 0 then
        setColorScaled(palette.text, 1, 0.55)
        drawText("empty", colX + math.floor(10 * uiScale), colY + lineH + math.floor(18 * uiScale))
      else
        local cols, cardW, cardH = chooseCardGridLayout(#cards, listW, listH, cardGap, minCardW, maxCols)
        for n = 1, #cards do
          local cardId = cards[n]
          local cardDef = Config.CARD_DEFS[cardId]
          local btn = buttonList[n] or {}
          buttonList[n] = btn
          local colIndex = (n - 1) % cols
          local rowIndex = math.floor((n - 1) / cols)
          btn.x = listX + colIndex * (cardW + cardGap)
          btn.y = listY + rowIndex * (cardH + cardGap)
          btn.w = cardW
          btn.h = cardH
          btn.cardId = cardId

          local hovered = pointInRect(mouseX, mouseY, btn)
          local alpha = 1
          local footerText = ""
          if mode == "deck" then
            alpha = (runtime.deckBuilder and runtime.deckBuilder:canRemoveFromDeck(cardId)) and 1 or 0.45
          elseif mode == "inventory" then
            alpha = (runtime.deckBuilder and runtime.deckBuilder:canAddToDeck(cardId)) and 1 or 0.45
          elseif mode == "shop" then
            local price = cardDef and (cardDef.shopPrice or 0) or 0
            alpha = currency >= price and 1 or 0.45
            footerText = "shop " .. tostring(price)
          end

          drawCardFace(btn, cardDef, {
            hovered = hovered,
            alpha = alpha,
            cost = cardDef and cardDef.cost or 0,
            moonCount = moonCount,
            moonBonus = previewBodyCardBonus(cardDef),
            footerText = footerText,
          })

          if hovered and cardDef then
            if mode == "deck" then
              local removable = runtime.deckBuilder and runtime.deckBuilder:canRemoveFromDeck(cardId)
              local actionLine = removable and "remove" or ("min deck " .. tostring(minDeckSize))
              hoveredTooltipBtn = btn
              hoveredTooltipLines = {
                {pre = cardDef.tooltip, hi = "", post = ""},
                {pre = "cost ", hi = tostring(cardDef.cost), post = " energy"},
                {pre = "heat ", hi = tostring(cardDef.heat or 0), post = ""},
                {pre = "type ", hi = tostring(cardDef.type or cardDef.orbitClass or "-"), post = ""},
                {pre = "deck copies ", hi = tostring(deckCounts[cardId] or 0), post = ""},
                {pre = "click ", hi = actionLine, post = removable and " to inventory" or ""},
              }
            elseif mode == "inventory" then
              local addable = runtime.deckBuilder and runtime.deckBuilder:canAddToDeck(cardId)
              local actionLine = addable and "add" or ("max deck " .. tostring(maxDeckSize))
              hoveredTooltipBtn = btn
              hoveredTooltipLines = {
                {pre = cardDef.tooltip, hi = "", post = ""},
                {pre = "cost ", hi = tostring(cardDef.cost), post = " energy"},
                {pre = "heat ", hi = tostring(cardDef.heat or 0), post = ""},
                {pre = "type ", hi = tostring(cardDef.type or cardDef.orbitClass or "-"), post = ""},
                {pre = "inventory copies ", hi = tostring(inventoryCounts[cardId] or 0), post = ""},
                {pre = "click ", hi = actionLine, post = addable and " to deck" or ""},
              }
            elseif mode == "shop" then
              local price = cardDef.shopPrice or 0
              hoveredTooltipBtn = btn
              hoveredTooltipLines = {
                {pre = cardDef.tooltip, hi = "", post = ""},
                {pre = "cost ", hi = tostring(cardDef.cost), post = " energy"},
                {pre = "heat ", hi = tostring(cardDef.heat or 0), post = ""},
                {pre = "type ", hi = tostring(cardDef.type or cardDef.orbitClass or "-"), post = ""},
                {pre = "shop ", hi = tostring(price), post = ""},
                {pre = "owned ", hi = tostring(inventoryCounts[cardId] or 0), post = ""},
                {pre = "click ", hi = "buy", post = ""},
              }
            end
          end
        end
      end
    end
  end

  drawHoverTooltip(hoveredTooltipLines, hoveredTooltipBtn, uiScale, lineH, false)
end

function drawEndGame()
  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local lineH = math.floor(font:getHeight())
  local mouseX, mouseY = love.mouse.getPosition()
  local viewportX = offsetX
  local viewportY = offsetY
  local viewportW = Config.GAME_W * scale
  local viewportH = Config.GAME_H * scale

  local panelW = math.floor(viewportW * 0.48)
  local panelH = math.floor(viewportH * 0.46)
  local panelX = viewportX + math.floor((viewportW - panelW) * 0.5)
  local panelY = viewportY + math.floor((viewportH - panelH) * 0.5)
  local pad = math.floor(16 * uiScale)

  setColorScaled(swatch.darkest, 1, 0.95)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
  setColorScaled(swatch.brightest, 1, 0.92)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

  local title = state.runOutcome == "collapse" and "run collapsed" or "run complete"
  local scoreText = "points " .. tostring(state.points or 0)
  local rewardText = "reward +" .. tostring(state.rewardPoints or 0)
  local currencyText = "currency " .. tostring(state.currency)

  setColorScaled(swatch.brightest, 1, 1)
  drawText(title, panelX + pad, panelY + pad)
  setColorScaled(palette.text, 1, 0.95)
  drawText(scoreText, panelX + pad, panelY + pad + lineH + math.floor(8 * uiScale))
  drawText(rewardText, panelX + pad, panelY + pad + lineH * 2 + math.floor(14 * uiScale))
  drawText(currencyText, panelX + pad, panelY + pad + lineH * 3 + math.floor(20 * uiScale))

  local btnW = math.floor(180 * uiScale)
  local btnH = lineH + math.floor(10 * uiScale)
  local btnGap = math.floor(10 * uiScale)
  local btnY = panelY + panelH - btnH - pad
  local totalW = btnW * 2 + btnGap
  local btnX = panelX + math.floor((panelW - totalW) * 0.5)

  local replayBtn = ui.endGameReplayBtn
  replayBtn.x = btnX
  replayBtn.y = btnY
  replayBtn.w = btnW
  replayBtn.h = btnH
  local replayHovered = pointInRect(mouseX, mouseY, replayBtn)
  setColorScaled(swatch.darkest, 1, replayHovered and 1 or 0.9)
  love.graphics.rectangle("fill", replayBtn.x, replayBtn.y, replayBtn.w, replayBtn.h)
  setColorScaled(swatch.brightest, 1, replayHovered and 1 or 0.8)
  love.graphics.rectangle("line", replayBtn.x, replayBtn.y, replayBtn.w, replayBtn.h)
  setColorScaled(palette.text, 1, 0.95)
  drawText("play again", replayBtn.x + math.floor((replayBtn.w - font:getWidth("play again")) * 0.5), replayBtn.y + math.floor((replayBtn.h - lineH) * 0.5))

  local menuBtn = ui.endGameMenuBtn
  menuBtn.x = btnX + btnW + btnGap
  menuBtn.y = btnY
  menuBtn.w = btnW
  menuBtn.h = btnH
  local menuHovered = pointInRect(mouseX, mouseY, menuBtn)
  setColorScaled(swatch.darkest, 1, menuHovered and 1 or 0.9)
  love.graphics.rectangle("fill", menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h)
  setColorScaled(swatch.brightest, 1, menuHovered and 1 or 0.8)
  love.graphics.rectangle("line", menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h)
  setColorScaled(palette.text, 1, 0.95)
  drawText("main menu", menuBtn.x + math.floor((menuBtn.w - font:getWidth("main menu")) * 0.5), menuBtn.y + math.floor((menuBtn.h - lineH) * 0.5))
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
  local title
  if orbiter.cardBody and orbiter.orbitClass then
    title = "selected " .. string.lower(tostring(orbiter.orbitClass)) .. " body"
  else
    title = "selected moon"
    if orbiter.kind == "satellite" or orbiter.kind == "moon-satellite" then
      title = "selected satellite"
    elseif orbiter.kind == "planet" then
      title = "selected planet"
    elseif orbiter.kind == "mega-planet" then
      title = "selected mega planet"
    end
  end

  local bodyOpe = 0
  local bodyYield = 0
  if runtime.cardRun and runtime.cardRun.effectiveBodyOpe then
    bodyOpe = runtime.cardRun:effectiveBodyOpe(orbiter)
  end
  if runtime.cardRun and runtime.cardRun.effectiveBodyYieldPerOrbit then
    bodyYield = runtime.cardRun:effectiveBodyYieldPerOrbit(orbiter)
  end
  local angularSpeed = math.abs((orbiter.speed or 0) * (1 + totalBoost))
  local visualRadius = orbiter.visualRadius
  if not visualRadius then
    visualRadius = select(1, orbiterVisualRadius(orbiter))
  end
  local detailLines = {
    {pre = "ope ", hi = tostring(bodyOpe), post = ""},
    {pre = "yield/orbit ", hi = tostring(bodyYield), post = ""},
    {pre = "angular speed ", hi = string.format("%.2f", angularSpeed), post = ""},
    {pre = "orbit radius ", hi = string.format("%.0f px", orbiter.radius), post = ""},
    {pre = "body radius ", hi = string.format("%.1f px", visualRadius or 0), post = ""},
    {pre = "active boost ", hi = string.format("%+d%%", boostPercent), post = ""},
  }

  if orbiter.cardBody and orbiter.orbitClass then
    detailLines[#detailLines + 1] = {
      pre = "orbit class ",
      hi = tostring(orbiter.orbitClass),
      post = "",
    }
  end

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
  local boxX = math.floor(offsetX + Config.GAME_W * scale - boxW - 8 * uiScale)
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
  setLitColorDirect(Config.SELECTED_ORBIT_COLOR[1], Config.SELECTED_ORBIT_COLOR[2], Config.SELECTED_ORBIT_COLOR[3], connectorLight, 0.88)
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
  bgMusic:setVolume(Config.BG_MUSIC_VOLUME)
  bgMusic:play()
  bgMusicFirstPass = true
  bgMusicPrevPos = 0
end

local function updateBackgroundMusic(dt)
  if not bgMusic then
    return
  end

  bgMusicDuckTimer = math.max(0, bgMusicDuckTimer - dt)
  local duckT = bgMusicDuckTimer > 0 and (bgMusicDuckTimer / Config.BG_MUSIC_DUCK_SECONDS) or 0
  local duckGain = lerp(1, Config.BG_MUSIC_DUCK_GAIN, duckT)

  if bgMusicFirstPass then
    if not bgMusic:isPlaying() then
      bgMusicFirstPass = false
      bgMusic:setLooping(true)
      bgMusic:play()
      bgMusicPrevPos = 0
    end
    bgMusic:setVolume(Config.BG_MUSIC_VOLUME * duckGain)
    return
  end

  local duration = bgMusic:getDuration("seconds")
  if not duration or duration <= 0 then
    bgMusic:setVolume(Config.BG_MUSIC_VOLUME * duckGain)
    return
  end

  local pos = bgMusic:tell("seconds")
  local remaining = duration - pos
  local fadeWindow = Config.BG_MUSIC_LOOP_FADE_SECONDS
  local fadeOut = remaining < fadeWindow and (remaining / fadeWindow) or 1
  local fadeIn = pos < fadeWindow and (pos / fadeWindow) or 1
  local loopGain = clamp(math.min(fadeOut, fadeIn), 0, 1)
  bgMusic:setVolume(Config.BG_MUSIC_VOLUME * loopGain * duckGain)
  bgMusicPrevPos = pos
end

local function initUpgradeFx()
  local ok, source = pcall(love.audio.newSource, "upgrade_fx.mp3", "static")
  if not ok or not source then
    upgradeFx = nil
    return
  end
  source:setVolume(Config.UPGRADE_FX_VOLUME)
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
    voice:setPitch(Config.CLICK_FX_PITCH_CLOSE)
    voice:setVolume(Config.CLICK_FX_VOLUME_CLOSE)
  else
    voice:setPitch(Config.CLICK_FX_PITCH_OPEN)
    voice:setVolume(Config.CLICK_FX_VOLUME_OPEN)
  end
  love.audio.play(voice)
end

playMenuBuyClickFx = function()
  if not clickFx then
    return
  end
  local voice = clickFx:clone()
  local pitch = lerp(Config.CLICK_FX_MENU_PITCH_MIN, Config.CLICK_FX_MENU_PITCH_MAX, love.math.random())
  voice:setPitch(pitch)
  voice:setVolume(Config.CLICK_FX_VOLUME_OPEN)
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
  updateFadedFxInstances(upgradeFxInstances, Config.UPGRADE_FX_VOLUME, Config.UPGRADE_FX_FADE_IN_SECONDS, dt)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  uiFont = patchFontWidth(love.graphics.newFont("font_gothic.ttf", Config.UI_FONT_SIZE, "mono"))
  uiFont:setFilter("nearest", "nearest")
  love.graphics.setFont(uiFont)
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("none")
  setBorderlessFullscreen(false)

  canvas = love.graphics.newCanvas(Config.GAME_W, Config.GAME_H)
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
      x = love.math.random(0, Config.GAME_W - 1),
      y = love.math.random(0, Config.GAME_H - 1),
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
    if state.screen == "deck_menu" or state.screen == "run" or state.screen == "end_game" then
      openMainMenu()
    end
  elseif key == "b" then
    setBorderlessFullscreen(not state.borderlessFullscreen)
  elseif key == "l" then
    toggleSphereShadeStyle()
  end
end

function love.wheelmoved(_, wy)
  zoom = clamp(zoom + wy * 0.1, Config.ZOOM_MIN, Config.ZOOM_MAX)
end

function love.update(dt)
  dt = math.min(dt, 0.05)
  updateBackgroundMusic(dt)
  updateUpgradeFx(dt)
  state.time = state.time + dt
  state.planetBounceTime = math.max(0, state.planetBounceTime - dt)
  updateMicroInteractions(dt)

  if runtime.cardRun and runtime.cardRun.update then
    runtime.cardRun:update(dt)
  end

  local ripples = state.speedWaveRipples
  for i = #ripples, 1, -1 do
    local ripple = ripples[i]
    ripple.age = ripple.age + dt
    if ripple.age >= ripple.life then
      table.remove(ripples, i)
    end
  end

  if state.screen == "run" and state.runComplete and not micro.lockInput then
    switchScreen("end_game")
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
      return
    end
    for i = 1, #ui.deckCardButtons do
      local btn = ui.deckCardButtons[i]
      if btn and pointInRect(x, y, btn) then
        if runtime.deckBuilder and runtime.deckBuilder:removeFromDeck(btn.cardId) then
          playMenuBuyClickFx()
        else
          playClickFx(true)
        end
        return
      end
    end
    for i = 1, #ui.deckInventoryButtons do
      local btn = ui.deckInventoryButtons[i]
      if btn and pointInRect(x, y, btn) then
        if runtime.deckBuilder and runtime.deckBuilder:addToDeck(btn.cardId) then
          playClickFx(false)
        else
          playClickFx(true)
        end
        return
      end
    end
    for i = 1, #ui.deckShopButtons do
      local btn = ui.deckShopButtons[i]
      if btn and pointInRect(x, y, btn) then
        if runtime.deckBuilder and runtime.deckBuilder:buyShopCard(btn.cardId) then
          playMenuBuyClickFx()
        else
          playClickFx(true)
        end
        return
      end
    end
    return
  elseif state.screen == "end_game" then
    if pointInRect(x, y, ui.endGameReplayBtn) then
      startRunFromMenu()
      playClickFx(false)
      return
    end
    if pointInRect(x, y, ui.endGameMenuBtn) then
      openMainMenu()
      playClickFx(true)
    end
    return
  elseif state.screen ~= "run" then
    return
  end

  if micro.lockInput then
    return
  end

  if pointInRect(x, y, ui.endTurnBtn) and (not state.runComplete) and state.phase == "planning" then
    endEpochFromUi()
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
  if gx < 0 or gy < 0 or gx > Config.GAME_W or gy > Config.GAME_H then
    return
  end

  local wx, wy = toWorldSpace(x, y)
  local planetDx = wx - cx
  local planetDy = wy - cy
  local planetHitR = Config.BODY_VISUAL.planetRadius
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
  drawMachineGuides(false)
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
  drawMachineGuides(true)

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
    local coreR = clamp((state.planetVisualRadius or Config.BODY_VISUAL.planetRadius) / Config.GAME_H, 0.002, 0.45)
    local innerR = clamp(coreR * Config.GRAVITY_WELL_INNER_SCALE, 0.001, coreR - 0.0005)
    local outerR = clamp(coreR * Config.GRAVITY_WELL_RADIUS_SCALE, coreR + 0.01, 0.95)
    local radialStrength = Config.GRAVITY_WELL_RADIAL_STRENGTH
    local swirlStrength = Config.GRAVITY_WELL_SWIRL_STRENGTH
    local prevShader = love.graphics.getShader()
    love.graphics.setShader(gravityWellShader)
    gravityWellShader:send("centerUv", {cx / Config.GAME_W, cy / Config.GAME_H})
    gravityWellShader:send("aspect", Config.GAME_W / Config.GAME_H)
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
  elseif state.screen == "end_game" then
    drawEndGame()
  end
end
