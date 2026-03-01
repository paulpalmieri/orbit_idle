local Systems = {
  Modifier = require("game.systems.modifiers"),
  Orbiters = require("game.systems.orbiters"),
  MoonTiming = require("game.systems.moon_timing"),
}

local GameConfig = require("game.config.gameplay")
local ProgressionContent = require("game.content.progression_content")
local Assets = require("game.config.assets")

WORLD = GameConfig.world
GAMEPLAY = GameConfig.gameplay
SLICE = GameConfig.slice
PROGRESSION = GameConfig.progression
UPGRADE_EFFECTS = GameConfig.upgradeEffects
MOON_VARIANTS = GameConfig.moonVariants
RUN_PRESSURE = GameConfig.runPressure
ECONOMY = GameConfig.economy
AUDIO = GameConfig.audio
ORBIT_CONFIGS = GameConfig.orbitConfigs
BODY_VISUAL = GameConfig.bodyVisual

Systems.MoonTiming.config.perfectWindow = SLICE.perfectWindow
Systems.MoonTiming.config.goodWindow = SLICE.goodWindow

local SELECTED_ORBIT_COLOR = {1.0000, 0.5098, 0.4549, 1}
local SPHERE_SHADE_STYLE_OFF = {
  contrast = 1.08,
  darkFloor = WORLD.bodyShadeDarkFloorTone,
  toneSteps = 0,
  facetSides = 0,
  ditherStrength = 0,
  ditherScale = 1,
}
local SPHERE_SHADE_STYLE_ON = {
  contrast = 0.94,
  darkFloor = WORLD.bodyShadeDarkFloorTone + 0.01,
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
local clickFx
local perfectHitFx
local perfectHitFxInstances = {}
local missFx
local unlockSkillFx
local sphereShader
local spherePixel
local gravityWellShader
local scale = 1
local offsetX = 0
local offsetY = 0
local zoom = 1

local cx = math.floor(WORLD.gameW / 2)
local cy = math.floor(WORLD.gameH / 2)

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
  trail = {swatch.bright[1], swatch.bright[2], swatch.bright[3], 0.35},
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

local function cloneTable(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, entry in pairs(value) do
    out[key] = cloneTable(entry)
  end
  return out
end

local function cloneSet(source)
  local out = {}
  for key, value in pairs(source or {}) do
    if value then
      out[key] = true
    end
  end
  return out
end

function createState(opts)
  opts = opts or {}
  local ditherEnabled = opts.sphereDitherEnabled
  if ditherEnabled == nil then
    ditherEnabled = true
  end
  local totalShards = math.max(0, math.floor(tonumber(opts.totalShards) or 0))
  local campaign = opts.campaign or {}
  local activeVariant = campaign.activeMoonVariant
  if type(activeVariant) ~= "string" or not MOON_VARIANTS[activeVariant] then
    activeVariant = "standard"
  end
  local activeObjectives = cloneSet(campaign.activeObjectives)
  if next(activeObjectives) == nil then
    activeObjectives.reach_60_rpm = true
  end
  return {
    moons = {},
    renderOrbiters = {},
    stars = opts.stars or {},
    time = 0,
    nextRenderOrder = 0,
    selectedOrbiter = nil,
    sphereDitherEnabled = ditherEnabled,
    borderlessFullscreen = opts.borderlessFullscreen or false,
    orbitPopTexts = {},
    planetBounceTime = 0,
    planetClickCount = 0,
    gravityRipples = {},
    stability = 1,
    stabilityIdleTimer = 0,
    stabilityBoostTimer = 0,
    stabilityWaveTimer = 0,
    stabilityMaxFxTimer = 0,
    planetVisualRadius = BODY_VISUAL.planetRadius,
    baseRpm = SLICE.baseMoonRpm,
    permanentRpmBonus = 0,
    tempBurstRpm = 0,
    temporaryRpm = 0,
    currentRpm = 0,
    instability = RUN_PRESSURE.instability.start,
    instabilityDisplay = RUN_PRESSURE.instability.start,
    instabilityMax = RUN_PRESSURE.instability.max,
    maxInstabilityReached = RUN_PRESSURE.instability.start,
    instabilitySoftTickTimer = 0,
    instabilitySpikeTimer = 0,
    instabilityShaveFx = {},
    rpmLimitTempFill = 0,
    rpmLimitFill = 0,
    maxRpmReached = SLICE.baseMoonRpm,
    objectiveReached = false,
    objectivePopupTimer = 0,
    orbitsEarnedThisRun = 0,
    perfectHits = 0,
    goodHits = 0,
    perfectStreak = 0,
    maxPerfectStreak = 0,
    shardsGainedThisRun = 0,
    totalShards = totalShards,
    timingPopups = {},
    timingRings = {},
    hitTrailTimer = 0,
    perfectFlashTimer = 0,
    goodFlashTimer = 0,
    missFlashTimer = 0,
    redlineFlashTimer = 0,
    collapseFreezeTimer = 0,
    singleMoonMode = SLICE.singleMoonMode,
    collapseSequenceActive = false,
    collapseTimer = 0,
    collapseRpm = 0,
    instabilityWaveTimer = 0,
    screenShakeX = 0,
    screenShakeY = 0,
    objectivesCompletedThisRun = 0,
    runCriticalInstabilitySeen = false,
    maxRpmAfterCritical = 0,
    runRecoveredFromCritical = false,
    lastObjectiveCompletionText = nil,
    objectiveNoticeTimer = 0,
    skillUnlocks = cloneSet(campaign.skillUnlocks),
    skillChoiceLocks = cloneSet(campaign.skillChoiceLocks),
    pendingSkillChoices = cloneTable(campaign.pendingSkillChoices or {}),
    skillUnlockFx = {},
    activeObjectives = activeObjectives,
    completedObjectives = cloneSet(campaign.completedObjectives),
    progressionFlags = cloneSet(campaign.progressionFlags),
    activeMoonVariant = activeVariant,
    gameOver = false,
    brokenMoon = nil,
  }
end

local state = createState()

local ui = {
  restartBtn = {x = 0, y = 0, w = 0, h = 0, visible = false},
  skillsBtn = {x = 0, y = 0, w = 0, h = 0, visible = false},
  skillTreeBackBtn = {x = 0, y = 0, w = 0, h = 0, visible = false},
  skillTreeRestartBtn = {x = 0, y = 0, w = 0, h = 0, visible = false},
}

local runtime = {}
local initGameSystems
local SCENE_GAME = "game"
local SCENE_SKILL_TREE = "skill-tree"
local scene = SCENE_GAME
local skillTree = {
  panX = 0,
  panY = 0,
  dragging = false,
}
local SKILL_TREE_NODE_DIAMETER = 74
local progressionContent = ProgressionContent.build(UPGRADE_EFFECTS)
SKILL_CHOICE_TIERS = progressionContent.skillChoiceTiers
OBJECTIVE_DEFS = progressionContent.objectiveDefs
OBJECTIVE_ORDER = progressionContent.objectiveOrder
SKILL_TREE_NODES = progressionContent.skillTreeNodes
SKILL_TREE_LINKS = progressionContent.skillTreeLinks

local persistence = {
  totalShards = 0,
}

local function loadTotalShards()
  if not love.filesystem.getInfo(SLICE.shardSaveFile) then
    return 0
  end
  local ok, content = pcall(love.filesystem.read, SLICE.shardSaveFile)
  if not ok or type(content) ~= "string" then
    return 0
  end
  local parsed = tonumber(content)
  if not parsed then
    return 0
  end
  return math.max(0, math.floor(parsed))
end

local function saveTotalShards(totalShards)
  local value = math.max(0, math.floor(tonumber(totalShards) or 0))
  pcall(love.filesystem.write, SLICE.shardSaveFile, tostring(value))
end

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

local function dangerTierForRpm(rpm)
  local value = rpm or 0
  if value >= SLICE.dangerousRpm then
    return 3
  end
  if value >= SLICE.chargedRpm then
    return 2
  end
  if value >= SLICE.calmRpm then
    return 1
  end
  return 0
end

local function dangerBlendForRpm(rpm)
  return clamp(((rpm or 0) - SLICE.calmRpm) / math.max(1, SLICE.collapseRpm - SLICE.calmRpm), 0, 1)
end

local function instabilityRatio()
  local maxValue = state.instabilityMax or RUN_PRESSURE.instability.max
  return clamp((state.instability or 0) / math.max(1, maxValue), 0, 1)
end

local function instabilityStressBlend()
  local startRatio = RUN_PRESSURE.instability.stressStartRatio
  return clamp((instabilityRatio() - startRatio) / math.max(0.001, 1 - startRatio), 0, 1)
end

local function instabilityTier()
  local ratio = instabilityRatio()
  if ratio >= 0.85 then
    return 3
  end
  if ratio >= 0.60 then
    return 2
  end
  if ratio >= 0.30 then
    return 1
  end
  return 0
end

local function pointInRect(px, py, rect)
  return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

TIMING_OUTCOME_STYLE = nil
spawnTimingPopup = nil
playUnlockSkillFx = nil

SKILL_TREE_NODE_BY_ID = {}
for i = 1, #SKILL_TREE_NODES do
  local node = SKILL_TREE_NODES[i]
  SKILL_TREE_NODE_BY_ID[node.id] = node
end

local function isSkillUnlocked(skillId)
  return state.skillUnlocks and state.skillUnlocks[skillId] == true
end

local function isSkillLockedByChoice(skillId)
  return state.skillChoiceLocks and state.skillChoiceLocks[skillId] == true
end

local function activeMoonVariantConfig()
  local variantId = state.activeMoonVariant
  local config = MOON_VARIANTS[variantId or "standard"]
  if config then
    return config
  end
  return MOON_VARIANTS.standard
end

local function objectiveIsOptional(objectiveId)
  local def = OBJECTIVE_DEFS[objectiveId]
  if not def then
    return false
  end
  if def.optional then
    return true
  end
  if def.category == "path" and state.progressionFlags and state.progressionFlags.first_path_completed then
    return not state.completedObjectives[objectiveId]
  end
  return false
end

local function objectivePassesVariant(objectiveId)
  local def = OBJECTIVE_DEFS[objectiveId]
  if not def or not def.requiredVariant then
    return true
  end
  return state.activeMoonVariant == def.requiredVariant
end

local function activateObjective(objectiveId)
  if not OBJECTIVE_DEFS[objectiveId] then
    return
  end
  if state.completedObjectives[objectiveId] then
    state.activeObjectives[objectiveId] = nil
    return
  end
  state.activeObjectives[objectiveId] = true
end

local function deactivateObjective(objectiveId)
  state.activeObjectives[objectiveId] = nil
end

local function isChoiceQueued(tierId)
  for i = 1, #state.pendingSkillChoices do
    if state.pendingSkillChoices[i] == tierId then
      return true
    end
  end
  return false
end

local function queueSkillChoice(tierId)
  if not SKILL_CHOICE_TIERS[tierId] then
    return
  end
  if isChoiceQueued(tierId) then
    return
  end
  state.pendingSkillChoices[#state.pendingSkillChoices + 1] = tierId
end

local function activeChoiceTierId()
  return state.pendingSkillChoices[1]
end

local function canUnlockSkillNode(skillId)
  local node = SKILL_TREE_NODE_BY_ID[skillId]
  if not node then
    return false, "unknown"
  end
  if isSkillUnlocked(skillId) then
    return false, "owned"
  end
  if isSkillLockedByChoice(skillId) then
    return false, "locked"
  end
  if not state.gameOver then
    return false, "between-runs"
  end
  local tierId = activeChoiceTierId()
  if tierId ~= node.tier then
    return false, "tier-locked"
  end
  return true, "ok"
end

local function objectiveCompletedCountThisRunExcluding(objectiveId)
  local count = state.objectivesCompletedThisRun or 0
  if state.completedObjectives[objectiveId] then
    count = math.max(0, count - 1)
  end
  return count
end

local function objectiveIsMetNow(objectiveId, collapseCheck)
  local def = OBJECTIVE_DEFS[objectiveId]
  if not def then
    return false
  end
  if not objectivePassesVariant(objectiveId) then
    return false
  end
  if def.type == "rpm" then
    return (state.maxRpmReached or 0) >= (def.target or 0)
  end
  if def.type == "perfect_hits" then
    return (state.perfectHits or 0) >= (def.target or 0)
  end
  if def.type == "critical_recover_rpm" then
    return state.runRecoveredFromCritical == true and (state.maxRpmReached or 0) >= (def.target or 0)
  end
  if def.type == "objectives_in_run" then
    local count = objectiveCompletedCountThisRunExcluding(objectiveId)
    return count >= (def.target or 0)
  end
  if def.type == "collapse_after_rpm" and collapseCheck then
    local peakOk = (state.maxRpmReached or 0) >= (def.peakRequired or 0)
    local collapseOk = (state.collapseRpm or 0) >= (def.collapseMin or 0)
    return peakOk and collapseOk
  end
  return false
end

local function pushObjectiveNotice(text)
  state.lastObjectiveCompletionText = text
  state.objectiveNoticeTimer = 2.2
end

local function ensureVariantObjectiveForSelection()
  if state.activeMoonVariant == "heavy_moon" then
    activateObjective("variant_heavy_110")
    deactivateObjective("variant_glass_130")
  elseif state.activeMoonVariant == "glass_moon" then
    activateObjective("variant_glass_130")
    deactivateObjective("variant_heavy_110")
  else
    deactivateObjective("variant_heavy_110")
    deactivateObjective("variant_glass_130")
  end
end

local function advanceProgressionMilestones(completedObjectiveId)
  if completedObjectiveId == "reach_60_rpm" then
    activateObjective("reach_80_rpm")
    if not state.progressionFlags.unlocked_starter_choice then
      queueSkillChoice("starter")
      state.progressionFlags.unlocked_starter_choice = true
      pushObjectiveNotice("first upgrade choice unlocked")
    end
  end

  if completedObjectiveId == "reach_80_rpm" then
    activateObjective("reach_100_rpm")
  end

  if completedObjectiveId == "reach_100_rpm" and not state.progressionFlags.unlocked_paths then
    activateObjective("reach_120_rpm")
    activateObjective("perfect_6_run")
    state.progressionFlags.unlocked_paths = true
  end

  if completedObjectiveId == "reach_120_rpm" or completedObjectiveId == "perfect_6_run" then
    if not state.progressionFlags.first_path_completed then
      state.progressionFlags.first_path_completed = true
      if not state.progressionFlags.unlocked_focus_choice then
        queueSkillChoice("focus")
        state.progressionFlags.unlocked_focus_choice = true
      end
      if not state.progressionFlags.unlocked_trials then
        activateObjective("trial_collapse_above_90")
        activateObjective("trial_perfect_8_run")
        state.progressionFlags.unlocked_trials = true
      end
    end
  end

  if completedObjectiveId == "trial_collapse_above_90" or completedObjectiveId == "trial_perfect_8_run" then
    if not state.progressionFlags.unlocked_variant_choice then
      queueSkillChoice("variant")
      state.progressionFlags.unlocked_variant_choice = true
      pushObjectiveNotice("moon variant unlocked")
    end
  end

  if completedObjectiveId == "variant_heavy_110" or completedObjectiveId == "variant_glass_130" then
    if not state.progressionFlags.unlocked_late_loop then
      activateObjective("reach_150_rpm")
      activateObjective("perfect_10_run")
      activateObjective("collapse_after_120")
      activateObjective("recover_critical_100")
      activateObjective("two_objectives_single_run")
      state.progressionFlags.unlocked_late_loop = true
    end
  end
end

local function completeObjective(objectiveId)
  local def = OBJECTIVE_DEFS[objectiveId]
  if not def then
    return false
  end
  if state.completedObjectives[objectiveId] then
    return false
  end

  state.completedObjectives[objectiveId] = true
  state.activeObjectives[objectiveId] = nil
  state.objectiveReached = true
  state.objectivesCompletedThisRun = (state.objectivesCompletedThisRun or 0) + 1

  local reward = math.max(0, math.floor(def.reward or 0))
  if reward > 0 then
    state.shardsGainedThisRun = (state.shardsGainedThisRun or 0) + reward
    state.totalShards = math.max(0, math.floor((state.totalShards or 0) + reward))
    persistence.totalShards = state.totalShards
    saveTotalShards(state.totalShards)
  end

  local popupText = reward > 0 and string.format("objective +%d shard", reward) or "objective complete"
  spawnTimingPopup(cx, cy - 32, 0, popupText, TIMING_OUTCOME_STYLE.perfect.color, 1.0, 22)
  pushObjectiveNotice(def.label)
  advanceProgressionMilestones(objectiveId)
  return true
end

local function evaluateActiveObjectives(collapseCheck)
  local completedAny = false
  for _, objectiveId in ipairs(OBJECTIVE_ORDER) do
    if state.activeObjectives[objectiveId] and (not state.completedObjectives[objectiveId]) then
      if objectiveIsMetNow(objectiveId, collapseCheck) then
        if completeObjective(objectiveId) then
          completedAny = true
        end
      end
    end
  end
  return completedAny
end

local function removePendingChoiceTier(tierId)
  for i = #state.pendingSkillChoices, 1, -1 do
    if state.pendingSkillChoices[i] == tierId then
      table.remove(state.pendingSkillChoices, i)
      return
    end
  end
end

local function unlockSkillNode(skillId)
  local ok = canUnlockSkillNode(skillId)
  if not ok then
    return false
  end
  local node = SKILL_TREE_NODE_BY_ID[skillId]
  local tier = SKILL_CHOICE_TIERS[node.tier]

  state.skillUnlocks[skillId] = true
  state.skillUnlockFx[#state.skillUnlockFx + 1] = {
    skillId = skillId,
    age = 0,
    life = PROGRESSION.unlockNodeFxSeconds,
  }
  if playUnlockSkillFx then
    playUnlockSkillFx()
  end

  if tier and tier.exclusive then
    for i = 1, #tier.options do
      local otherId = tier.options[i]
      if otherId ~= skillId and not state.skillUnlocks[otherId] then
        state.skillChoiceLocks[otherId] = true
      end
    end
  end
  removePendingChoiceTier(node.tier)

  if skillId == "heavy_moon" or skillId == "glass_moon" then
    state.activeMoonVariant = skillId
    ensureVariantObjectiveForSelection()
  end

  pushObjectiveNotice(node.label .. " unlocked")
  return true
end

local function orderedActiveObjectives()
  local list = {}
  for i = 1, #OBJECTIVE_ORDER do
    local id = OBJECTIVE_ORDER[i]
    if state.activeObjectives[id] and (not state.completedObjectives[id]) then
      list[#list + 1] = id
    end
  end
  return list
end

local function pendingChoiceSummary()
  local tierId = activeChoiceTierId()
  local tier = tierId and SKILL_CHOICE_TIERS[tierId] or nil
  if not tier then
    return nil
  end
  return tier.title
end

local function sideLightWorldPosition()
  local x = cx + WORLD.lightSourceOffsetX
  local y = cy + WORLD.lightSourceOffsetY
  local z = WORLD.lightSourceZ
  return x, y, z
end

local function lightProjectionZ(z)
  return (z or 0) + (WORLD.cameraLightHeight / zoom) / WORLD.cameraLightZScale
end

local function lightDepthForZ(z)
  return lightProjectionZ(z) * WORLD.cameraLightZScale
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
  local vz = (z or 0) * WORLD.cameraLightZScale

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
  local depth = (z or 0) * WORLD.cameraLightZScale
  local lightDepth = lightDepthForZ(lightZ)
  local dx = lightX - x
  local dy = lightY - y
  local dz = lightDepth - depth
  local distSq = dx * dx + dy * dy + dz * dz
  local attenuation = 1 / (1 + distSq * WORLD.cameraLightFalloff)
  local direct = WORLD.cameraLightAmbient + attenuation * WORLD.cameraLightIntensity
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
  if targetDepth > depth + WORLD.depthSortHysteresis then
    orbiter.sortDepth = targetDepth - WORLD.depthSortHysteresis
  elseif targetDepth < depth - WORLD.depthSortHysteresis then
    orbiter.sortDepth = targetDepth + WORLD.depthSortHysteresis
  end
end

local function assignRenderOrder(orbiter)
  state.nextRenderOrder = state.nextRenderOrder + 1
  orbiter.renderOrder = state.nextRenderOrder
end

local function perspectiveScaleForZ(z)
  local denom = 1 - (z or 0) * WORLD.perspectiveZStrength
  if denom < 0.35 then
    denom = 0.35
  end
  return clamp(1 / denom, WORLD.perspectiveMinScale, WORLD.perspectiveMaxScale)
end

local function projectWorldPoint(x, y, z)
  local scale = perspectiveScaleForZ(z or 0)
  return cx + (x - cx) * scale, cy + (y - cy) * scale, scale
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
  return sampleOrbitColorCycle(state.time / WORLD.planetColorCycleSeconds)
end

local function computeOrbiterColor(angle)
  return sampleOrbitColorCycle(angle / WORLD.twoPi)
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

function timingFreePulseColor()
  local pulse = 0.5 + 0.5 * math.sin(state.time * 22)
  return lerp(swatch.brightest[1], swatch.bright[1], pulse),
    lerp(swatch.brightest[2], swatch.bright[2], pulse),
    lerp(swatch.brightest[3], swatch.bright[3], pulse)
end

local function drawText(text, x, y)
  love.graphics.print(text, math.floor(x + 0.5), math.floor(y + 0.5))
end

local function drawOrbitIcon(x, y, size, alphaScale)
  local r = math.max(5, size or WORLD.orbitIconSize)
  local alpha = clamp(alphaScale or 1, 0, 1)
  local orbitR = r
  local bodyR = math.max(2, math.floor(r * 0.34 + 0.5))
  local orbitRY = orbitR * WORLD.orbitIconFlatten
  local angle = (state.time / WORLD.orbitIconCycleSeconds) * WORLD.twoPi
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
      life = WORLD.orbitPopLifetime,
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

local function createOrbitalParams(config, index)
  local band = config.fixedAltitude and 0 or math.floor(index / config.bandCapacity)
  local radiusJitter = config.fixedAltitude and 0 or (love.math.random() * 2 - 1)
  local tilt = config.tiltMin + love.math.random() * config.tiltRange
  local flatten = math.cos(tilt)
  local flattenMin = config.flattenMin
  local flattenMax = config.flattenMax
  if flattenMin ~= nil or flattenMax ~= nil then
    flatten = clamp(flatten, flattenMin or -1, flattenMax or 1)
  end
  local depthScale = math.sqrt(math.max(0, 1 - flatten * flatten))
  local planeMin = config.planeMin
  local planeRange = config.planeRange
  local plane
  if planeMin ~= nil and planeRange ~= nil then
    plane = planeMin + love.math.random() * planeRange
  else
    plane = love.math.random() * math.pi * 2
  end
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
    flatten = flatten,
    depthScale = depthScale,
    zBase = zBase,
    plane = plane,
    speed = config.speedMin + love.math.random() * config.speedRange,
  }
end

local function recomputeViewport()
  local w, h = love.graphics.getDimensions()
  local rawScale = math.min(w / WORLD.gameW, h / WORLD.gameH)
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
  local drawW = WORLD.gameW * scale
  local drawH = WORLD.gameH * scale
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
  local shakeX = state.screenShakeX or 0
  local shakeY = state.screenShakeY or 0
  return (mx - (offsetX + shakeX)) / scale, (my - (offsetY + shakeY)) / scale
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
  local size = math.max(1, math.floor(WORLD.uiFontSize * uiScale + 0.5))
  if not uiScreenFont or uiScreenFontSize ~= size then
    uiScreenFont = love.graphics.newFont(Assets.fonts.ui, size, "mono")
    uiScreenFont:setFilter("nearest", "nearest")
    uiScreenFontSize = size
  end
  return uiScreenFont
end

local function getOrbitCounterFont()
  local uiScale = scale >= 1 and scale or 1
  local size = math.max(1, math.floor(WORLD.uiFontSize * uiScale * 3.30 + 0.5))
  if not orbitCounterFont or orbitCounterFontSize ~= size then
    orbitCounterFont = love.graphics.newFont(Assets.fonts.ui, size, "mono")
    orbitCounterFont:setFilter("nearest", "nearest")
    orbitCounterFontSize = size
  end
  return orbitCounterFont
end

local updateOrbiterPosition

local function addMoon(parentOrbiter)
  if not runtime.orbiters then
    return false
  end
  return runtime.orbiters:addMoon(parentOrbiter)
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

local spawnGravityWaveRipple

TIMING_OUTCOME_STYLE = {
  perfect = {
    label = "Perfect",
    color = {swatch.brightest[1], swatch.brightest[2], swatch.brightest[3]},
    ringAlpha = 0.92,
    trailSeconds = 0.36,
    ringLife = 0.34,
    ringScale = 3.2,
  },
  good = {
    label = "Good",
    color = {swatch.bright[1], swatch.bright[2], swatch.bright[3]},
    ringAlpha = 0.72,
    trailSeconds = 0.26,
    ringLife = 0.28,
    ringScale = 2.5,
  },
  miss = {
    label = "Miss",
    color = {swatch.mid[1], swatch.mid[2], swatch.mid[3]},
    ringAlpha = 0.52,
    trailSeconds = 0,
    ringLife = 0.20,
    ringScale = 1.7,
  },
}

spawnTimingPopup = function(x, y, z, text, color, life, vy)
  state.timingPopups[#state.timingPopups + 1] = {
    x = x,
    y = y,
    z = z or 0,
    text = text,
    color = color,
    age = 0,
    life = life or 0.7,
    vy = vy or 16,
  }
end


local function spawnInstabilityShaveFx(fromRatio, toRatio)
  if toRatio >= fromRatio then
    return
  end
  state.instabilityShaveFx[#state.instabilityShaveFx + 1] = {
    fromRatio = clamp(fromRatio, 0, 1),
    toRatio = clamp(toRatio, 0, 1),
    age = 0,
    life = 0.34,
  }
end

local function spawnTimingRing(x, y, z, style)
  local moonRadius = BODY_VISUAL.moonRadius
  state.timingRings[#state.timingRings + 1] = {
    x = x,
    y = y,
    z = z or 0,
    age = 0,
    life = style.ringLife,
    radiusStart = moonRadius * 0.9,
    radiusEnd = moonRadius * style.ringScale,
    color = style.color,
    alpha = style.ringAlpha,
  }
end

local function playTimingHook(result, perfectStreak)
  if result == "perfect" and perfectHitFx then
    local voice = perfectHitFx:clone()
    local streak = math.max(1, math.floor(perfectStreak or 1))
    local sat = math.max(2, AUDIO.perfectHitComboSaturation or 12)
    local streakNorm = clamp((streak - 1) / (sat - 1), 0, 1)
    local shaped = smoothstep(streakNorm)
    local basePitch = lerp(AUDIO.perfectHitPitchMin, AUDIO.perfectHitPitchMax, shaped)
    local tier = math.floor((streak - 1) / 3)
    local tierBoost = math.min(0.045, tier * 0.009)
    local jitter = (love.math.random() * 2 - 1) * 0.012
    voice:setPitch(clamp(basePitch + tierBoost + jitter, 0.7, 1.45))
    local volume = lerp(
      AUDIO.perfectHitFxVolume,
      AUDIO.perfectHitFxVolume + (AUDIO.perfectHitComboVolumeBoost or 0.24),
      shaped
    )
    volume = volume + math.min(0.06, tier * 0.012)
    voice:setVolume(volume)
    love.audio.play(voice)
    local duration = voice:getDuration("seconds")
    if duration and duration > 0 then
      perfectHitFxInstances[#perfectHitFxInstances + 1] = {
        source = voice,
        duration = duration,
        age = 0,
        baseVolume = volume,
      }
    end
    return
  end

  if not clickFx then
    if result == "miss" and missFx then
      local voice = missFx:clone()
      local pitch = lerp(AUDIO.missFxPitchMin, AUDIO.missFxPitchMax, love.math.random())
      voice:setPitch(pitch)
      voice:setVolume(AUDIO.missFxVolume)
      love.audio.play(voice)
    end
    return
  end
  if result == "good" then
    local voice = clickFx:clone()
    voice:setPitch(1.02)
    voice:setVolume(0.50)
    love.audio.play(voice)
    return
  end
  if result == "miss" and missFx then
    local voice = missFx:clone()
    local pitch = lerp(AUDIO.missFxPitchMin, AUDIO.missFxPitchMax, love.math.random())
    voice:setPitch(pitch)
    voice:setVolume(AUDIO.missFxVolume)
    love.audio.play(voice)
    return
  else
    local voice = clickFx:clone()
    voice:setPitch(0.72)
    voice:setVolume(0.42)
    love.audio.play(voice)
  end
end

local function updateTimingFeedback(dt)
  for i = #state.timingPopups, 1, -1 do
    local popup = state.timingPopups[i]
    popup.age = popup.age + dt
    if popup.age >= popup.life then
      table.remove(state.timingPopups, i)
    else
      popup.y = popup.y - popup.vy * dt
      popup.vy = popup.vy + 34 * dt
    end
  end

  for i = #state.timingRings, 1, -1 do
    local ring = state.timingRings[i]
    ring.age = ring.age + dt
    if ring.age >= ring.life then
      table.remove(state.timingRings, i)
    end
  end

  state.hitTrailTimer = math.max(0, (state.hitTrailTimer or 0) - dt)
  state.perfectFlashTimer = math.max(0, (state.perfectFlashTimer or 0) - dt)
  state.goodFlashTimer = math.max(0, (state.goodFlashTimer or 0) - dt)
  state.missFlashTimer = math.max(0, (state.missFlashTimer or 0) - dt)
  state.redlineFlashTimer = math.max(0, (state.redlineFlashTimer or 0) - dt)
  state.instabilitySoftTickTimer = math.max(0, (state.instabilitySoftTickTimer or 0) - dt)
  state.instabilitySpikeTimer = math.max(0, (state.instabilitySpikeTimer or 0) - dt)
  state.objectiveNoticeTimer = math.max(0, (state.objectiveNoticeTimer or 0) - dt)

  for i = #state.instabilityShaveFx, 1, -1 do
    local fx = state.instabilityShaveFx[i]
    fx.age = fx.age + dt
    if fx.age >= fx.life then
      table.remove(state.instabilityShaveFx, i)
    end
  end

  for i = #state.skillUnlockFx, 1, -1 do
    local fx = state.skillUnlockFx[i]
    fx.age = fx.age + dt
    if fx.age >= (fx.life or PROGRESSION.unlockNodeFxSeconds) then
      table.remove(state.skillUnlockFx, i)
    end
  end
end


local function clampInstability(value)
  local maxValue = state.instabilityMax or RUN_PRESSURE.instability.max
  return clamp(value, 0, maxValue)
end

local function applyInstabilityDelta(delta, feedback)
  if not delta or delta == 0 then
    return 0, clampInstability(state.instability or 0), clampInstability(state.instability or 0)
  end
  local before = clampInstability(state.instability or 0)
  local after = clampInstability(before + delta)
  if after == before then
    return 0, before, after
  end

  state.instability = after
  state.maxInstabilityReached = math.max(state.maxInstabilityReached or 0, after)

  if feedback == "soft" then
    state.instabilitySoftTickTimer = math.max(
      state.instabilitySoftTickTimer or 0,
      RUN_PRESSURE.instability.softTickSeconds
    )
  elseif feedback == "spike" then
    state.instabilitySpikeTimer = math.max(
      state.instabilitySpikeTimer or 0,
      RUN_PRESSURE.instability.spikeFlashSeconds
    )
  end

  if after >= (state.instabilityMax or RUN_PRESSURE.instability.max) then
    triggerInstabilityCollapse()
  end
  return after - before, before, after
end

local function passiveInstabilityGainPerSecond()
  local rpm = state.currentRpm or 0
  local base = RUN_PRESSURE.instability.passiveBasePerSecond + rpm * RUN_PRESSURE.instability.passiveRpmFactor
  local upgradeMul = 1
  if isSkillUnlocked("reinforced_orbit") then
    upgradeMul = upgradeMul * (UPGRADE_EFFECTS.reinforced_orbit.passiveInstabilityMultiplier or 1)
  end
  local variant = activeMoonVariantConfig()
  local variantMul = variant.passiveInstabilityMul or 1
  return base * upgradeMul * variantMul
end

local function updatePassiveInstability(dt)
  applyInstabilityDelta(passiveInstabilityGainPerSecond() * dt, nil)
end


local function ensureSingleMoonExists()
  local moon = Systems.MoonTiming.getSingleMoon(state, WORLD.twoPi)
  if moon then
    return moon
  end
  if runtime.orbiters and #state.moons == 0 then
    runtime.orbiters:addMoon(nil)
  end
  moon = Systems.MoonTiming.getSingleMoon(state, WORLD.twoPi)
  if moon then
    moon.speed = (state.baseRpm or SLICE.baseMoonRpm) / WORLD.radPerSecondToRpm
    moon.boost = 0
    moon.boostDurations = {}
  end
  return moon
end

local function applyTimingOutcome(moon, outcome)
  if not moon or not outcome then
    return false
  end

  local result = outcome.result or "miss"
  local style = TIMING_OUTCOME_STYLE[result] or TIMING_OUTCOME_STYLE.miss
  local popupX = moon.x
  local popupY = moon.y - BODY_VISUAL.moonRadius * 1.3
  local popupZ = moon.z or 0
  spawnTimingRing(moon.x, moon.y, moon.z or 0, style)

  if result == "perfect" or result == "good" then
    if result == "perfect" then
      state.perfectStreak = (state.perfectStreak or 0) + 1
      state.maxPerfectStreak = math.max(state.maxPerfectStreak or 0, state.perfectStreak)
      state.perfectHits = (state.perfectHits or 0) + 1
      local perfectStabilizeDelta = RUN_PRESSURE.instability.onPerfect * perfectHitStabilizeMultiplier()
      local applied, beforeInstability, afterInstability = applyInstabilityDelta(perfectStabilizeDelta, "soft")
      if applied < 0 then
        local maxValue = math.max(1, state.instabilityMax or RUN_PRESSURE.instability.max)
        spawnInstabilityShaveFx(beforeInstability / maxValue, afterInstability / maxValue)
      end
      state.perfectFlashTimer = math.max(state.perfectFlashTimer or 0, 0.24)
      playTimingHook(result, state.perfectStreak)
    else
      state.perfectStreak = 0
      state.goodHits = (state.goodHits or 0) + 1
      applyInstabilityDelta(RUN_PRESSURE.instability.onGood, "soft")
      state.goodFlashTimer = math.max(state.goodFlashTimer or 0, 0.18)
      playTimingHook(result, 0)
    end

    local basePerm = result == "perfect" and SLICE.perfectPermGain or SLICE.goodPermGain
    local baseBurst = result == "perfect" and SLICE.perfectBurstGain or SLICE.goodBurstGain
    local variant = activeMoonVariantConfig()
    local permMul = variant.permanentGainMul or 1
    local burstMul = variant.burstGainMul or 1

    if result == "perfect" and isSkillUnlocked("tighter_burn") then
      permMul = permMul * (UPGRADE_EFFECTS.tighter_burn.perfectPermMultiplier or 1)
      burstMul = burstMul * (UPGRADE_EFFECTS.tighter_burn.perfectBurstMultiplier or 1)
    end

    if result == "perfect" and isSkillUnlocked("resonant_core") then
      local cap = UPGRADE_EFFECTS.resonant_core.streakCap or 6
      local streak = math.min(cap, math.max(0, state.perfectStreak or 0))
      local streakDepth = math.max(0, streak - 1)
      basePerm = basePerm + streakDepth * (UPGRADE_EFFECTS.resonant_core.streakPermBonus or 0)
      baseBurst = baseBurst + streakDepth * (UPGRADE_EFFECTS.resonant_core.streakBurstBonus or 0)
    end

    local gainPerm = basePerm * permMul
    local gainBurst = baseBurst * burstMul
    state.permanentRpmBonus = (state.permanentRpmBonus or 0) + gainPerm
    state.tempBurstRpm = (state.tempBurstRpm or 0) + gainBurst
    state.hitTrailTimer = math.max(state.hitTrailTimer or 0, style.trailSeconds)

    if result == "perfect" then
      spawnGravityWaveRipple({
        life = 0.34,
        widthStart = 0.024,
        widthEnd = 0.070,
        radialStrength = 0.067,
        swirlStrength = 0.0021,
        endPadding = GAMEPLAY.gravityRippleEndPadding,
        startRadiusScale = 1.02,
      })
    elseif dangerTierForRpm(state.currentRpm or 0) >= 2 then
      spawnGravityWaveRipple({
        life = 0.24,
        widthStart = 0.020,
        widthEnd = 0.056,
        radialStrength = 0.036,
        swirlStrength = 0.0014,
        endPadding = GAMEPLAY.gravityRippleEndPadding,
        startRadiusScale = 1.02,
      })
    end

    spawnTimingPopup(
      popupX,
      popupY,
      popupZ,
      string.format("%s +%.1f", style.label, gainPerm),
      style.color,
      result == "perfect" and 0.86 or 0.76,
      result == "perfect" and 21 or 18
    )
    return true
  end

  state.perfectStreak = 0
  applyInstabilityDelta(RUN_PRESSURE.instability.onMiss, "spike")
  state.missFlashTimer = 0.18
  spawnGravityWaveRipple({
    life = 0.40,
    widthStart = 0.022,
    widthEnd = 0.088,
    radialStrength = 0.074,
    swirlStrength = 0.0025,
    endPadding = GAMEPLAY.gravityRippleEndPadding,
    startRadiusScale = 1.01,
  })
  playTimingHook(result, 0)
  spawnTimingPopup(popupX, popupY, popupZ, style.label, style.color, 0.55, 14)
  return false
end

local function syncSingleMoonSpeed()
  local moon = ensureSingleMoonExists()
  if not moon then
    return nil
  end
  local totalRpm = (state.baseRpm or SLICE.baseMoonRpm) + (state.permanentRpmBonus or 0) + (state.tempBurstRpm or 0)
  moon.speed = math.max(0, totalRpm) / WORLD.radPerSecondToRpm
  moon.boost = 0
  moon.boostDurations = {}
  return moon
end

function tryTimedSingleMoonBoost()
  local moon = ensureSingleMoonExists()
  if not moon then
    return false, "miss"
  end
  local outcome = Systems.MoonTiming.evaluateTap(moon, WORLD.twoPi)
  local success = applyTimingOutcome(moon, outcome)
  state.temporaryRpm, state.currentRpm = computeRpmBreakdown()
  state.maxRpmReached = math.max(state.maxRpmReached or 0, state.currentRpm or 0)
  return success, outcome.result or "miss"
end

function updateSingleMoonTiming(dt)
  local moon = ensureSingleMoonExists()
  if moon then
    Systems.MoonTiming.update(moon, dt, WORLD.twoPi)
  end
  state.tempBurstRpm = math.max(0, (state.tempBurstRpm or 0) - SLICE.tempBurstDecayPerSecond * dt)
  updateTimingFeedback(dt)
end

function orbiterCurrentRpm(orbiter)
  if not orbiter then
    return 0
  end
  local totalBoost = orbiter.boost
  return orbiter.speed * (1 + totalBoost) * WORLD.radPerSecondToRpm
end

function computeRpmBreakdown()
  local baseRpm = state.baseRpm or SLICE.baseMoonRpm
  local permanent = state.permanentRpmBonus or 0
  local burst = state.tempBurstRpm or 0
  return burst, math.max(0, baseRpm + permanent + burst)
end

local function smoothRpmBarFill(current, target, dt)
  local rate = target > current and GAMEPLAY.rpmBarFillRiseRate or GAMEPLAY.rpmBarFillFallRate
  local blend = 1 - math.exp(-rate * dt)
  return current + (target - current) * blend
end

function updateRpmLimitFill(dt)
  local threshold = GAMEPLAY.rpmCollapseThreshold
  local totalTarget = clamp((state.currentRpm or 0) / threshold, 0, 1)
  local temporaryTarget = clamp((state.temporaryRpm or 0) / threshold, 0, 1)

  state.rpmLimitFill = clamp(smoothRpmBarFill(clamp(state.rpmLimitFill or 0, 0, 1), totalTarget, dt), 0, 1)
  state.rpmLimitTempFill = clamp(smoothRpmBarFill(clamp(state.rpmLimitTempFill or 0, 0, 1), temporaryTarget, dt), 0, 1)
end

spawnGravityWaveRipple = function(config)
  config = config or {}
  state.gravityRipples[#state.gravityRipples + 1] = {
    age = 0,
    life = config.life or GAMEPLAY.gravityRippleLifetime,
    widthStart = config.widthStart,
    widthEnd = config.widthEnd,
    radialStrength = config.radialStrength,
    swirlStrength = config.swirlStrength,
    endPadding = config.endPadding,
    startRadiusScale = config.startRadiusScale,
  }
end

local function smoothInstabilityDisplay(current, target, dt)
  local rise = RUN_PRESSURE.instability.meterRiseRate
  local fall = RUN_PRESSURE.instability.meterFallRate
  local rate = target > current and rise or fall
  local blend = 1 - math.exp(-rate * dt)
  return current + (target - current) * blend
end

local function instabilityEffectPressure()
  if state.gameOver then
    return 0
  end
  if state.collapseSequenceActive then
    return 1
  end
  return instabilityStressBlend()
end

local function updateInstabilityEffects(dt)
  local target = clampInstability(state.instability or 0)
  local current = state.instabilityDisplay or target
  state.instabilityDisplay = clampInstability(smoothInstabilityDisplay(current, target, dt))

  local pressure = instabilityEffectPressure()
  if pressure <= 0 then
    state.instabilityWaveTimer = 0
    state.screenShakeX = 0
    state.screenShakeY = 0
    return
  end

  local tier = instabilityTier()
  local tierMul = tier == 3 and 1.35 or (tier == 2 and 1.10 or 0.80)
  local amp = RUN_PRESSURE.instability.shakeMax * pressure * pressure * tierMul
  state.screenShakeX = math.sin(state.time * 31) * amp
  state.screenShakeY = math.cos(state.time * 27) * amp * 0.62

  state.instabilityWaveTimer = state.instabilityWaveTimer - dt
  if state.instabilityWaveTimer > 0 then
    return
  end

  spawnGravityWaveRipple({
    life = RUN_PRESSURE.instability.waveLife,
    widthStart = RUN_PRESSURE.instability.waveWidthStart,
    widthEnd = RUN_PRESSURE.instability.waveWidthEnd,
    radialStrength = RUN_PRESSURE.instability.waveRadialStrength * pressure,
    swirlStrength = RUN_PRESSURE.instability.waveSwirlStrength * pressure,
    endPadding = GAMEPLAY.gravityRippleEndPadding,
    startRadiusScale = 1.05,
  })

  state.instabilityWaveTimer = lerp(
    RUN_PRESSURE.instability.waveIntervalStart,
    RUN_PRESSURE.instability.waveIntervalEnd,
    pressure
  ) * (tier == 3 and 0.72 or (tier == 2 and 0.86 or 1.0))
end

function triggerInstabilityCollapse()
  if state.gameOver or state.collapseSequenceActive then
    return
  end
  state.collapseSequenceActive = true
  state.collapseRpm = state.currentRpm or 0
  state.collapseTimer = GAMEPLAY.rpmCollapseEndDelay
  state.collapseFreezeTimer = SLICE.collapseFreezeSeconds
  state.redlineFlashTimer = 0.24
  state.instability = state.instabilityMax or RUN_PRESSURE.instability.max
  state.maxInstabilityReached = math.max(state.maxInstabilityReached or 0, state.instability)
  state.instabilitySpikeTimer = math.max(state.instabilitySpikeTimer or 0, RUN_PRESSURE.instability.spikeFlashSeconds)
  state.selectedOrbiter = nil
  state.instabilityWaveTimer = 0

  local moon = Systems.MoonTiming.getSingleMoon(state, WORLD.twoPi) or state.moons[1]
  state.brokenMoon = moon
  if not moon then
    return
  end

  local dx = moon.x - cx
  local dy = moon.y - cy
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.0001 then
    dx, dy, len = 1, 0, 1
  end
  local rx, ry = dx / len, dy / len
  local tx, ty = -ry, rx
  moon.breakVx = rx * 82 + tx * 50
  moon.breakVy = ry * 82 + ty * 50
  moon.breakVz = moon.z >= 0 and 0.12 or -0.12
  moon.breakAccel = 54
  moon.boostDurations = {}
  moon.boost = 0
  spawnTimingPopup(
    moon.x,
    moon.y - BODY_VISUAL.moonRadius * 2.5,
    moon.z or 0,
    state.objectiveReached and "objective reached" or "collapse",
    state.objectiveReached and TIMING_OUTCOME_STYLE.perfect.color or TIMING_OUTCOME_STYLE.miss.color,
    0.62,
    8
  )
end

function triggerRpmCollapse()
  triggerInstabilityCollapse()
end

local function calculateCollapseShardReward()
  return 0
end

local function completeRpmCollapse()
  evaluateActiveObjectives(true)
  local reward = calculateCollapseShardReward()
  if reward > 0 then
    state.shardsGainedThisRun = (state.shardsGainedThisRun or 0) + reward
    state.totalShards = math.max(0, math.floor((state.totalShards or 0) + reward))
    persistence.totalShards = state.totalShards
    saveTotalShards(state.totalShards)
  end
  state.gameOver = true
  state.collapseSequenceActive = false
  state.collapseTimer = 0
  state.collapseFreezeTimer = 0
  state.screenShakeX = 0
  state.screenShakeY = 0
end

function updateBrokenMoon(dt)
  local moon = state.brokenMoon
  if not moon then
    return
  end

  local dx = moon.x - cx
  local dy = moon.y - cy
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.0001 then
    dx, dy, len = 1, 0, 1
  end
  local rx, ry = dx / len, dy / len
  local accel = moon.breakAccel or 0
  moon.breakVx = (moon.breakVx or 0) + rx * accel * dt
  moon.breakVy = (moon.breakVy or 0) + ry * accel * dt
  moon.x = moon.x + (moon.breakVx or 0) * dt
  moon.y = moon.y + (moon.breakVy or 0) * dt
  moon.z = moon.z + (moon.breakVz or 0) * dt
  updateOrbiterRenderDepth(moon)
  updateOrbiterLight(moon)
end

function restartRun()
  local stars = state.stars or {}
  local dither = state.sphereDitherEnabled
  local borderless = state.borderlessFullscreen
  local totalShards = state.totalShards or persistence.totalShards or 0
  local campaign = {
    skillUnlocks = state.skillUnlocks,
    skillChoiceLocks = state.skillChoiceLocks,
    pendingSkillChoices = state.pendingSkillChoices,
    activeObjectives = state.activeObjectives,
    completedObjectives = state.completedObjectives,
    progressionFlags = state.progressionFlags,
    activeMoonVariant = state.activeMoonVariant,
  }
  state = createState({
    stars = stars,
    sphereDitherEnabled = dither,
    borderlessFullscreen = borderless,
    totalShards = totalShards,
    campaign = campaign,
  })
  scene = SCENE_GAME
  skillTree.dragging = false
  ensureVariantObjectiveForSelection()
  initGameSystems()
end

function perfectHitStabilizeMultiplier()
  local mul = 1
  if isSkillUnlocked("stabilizer_lattice") then
    mul = mul * (UPGRADE_EFFECTS.stabilizer_lattice.perfectStabilityMultiplier or 1)
  end
  return mul
end

initGameSystems = function()
  runtime.modifiers = Systems.Modifier.new()

  runtime.orbiters = Systems.Orbiters.new({
    state = state,
    modifiers = runtime.modifiers,
    orbitConfigs = ORBIT_CONFIGS,
    bodyVisual = BODY_VISUAL,
    twoPi = WORLD.twoPi,
    maxMoons = ECONOMY.maxMoons,
    createOrbitalParams = createOrbitalParams,
    updateOrbiterPosition = updateOrbiterPosition,
    assignRenderOrder = assignRenderOrder,
    getStabilitySpeedMultiplier = function()
      return 1
    end,
    onOrbitGainFx = state.singleMoonMode and nil or spawnOrbitGainFx,
    onOrbitsEarned = function(count)
      state.orbitsEarnedThisRun = (state.orbitsEarnedThisRun or 0) + count
    end,
  })
  ensureVariantObjectiveForSelection()

  if state.singleMoonMode then
    ensureSingleMoonExists()
    state.currentRpm = state.baseRpm or SLICE.baseMoonRpm
    state.temporaryRpm = state.tempBurstRpm or 0
    syncSingleMoonSpeed()
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

function orbitSegmentVisible(frontPass, segZ)
  if frontPass then
    return segZ > 0
  end
  return segZ <= 0
end

function orbitalPathPoint(target, angle, radiusOffset, originX, originY, zOffset, cp, sp)
  local radius = math.max(1, target.radius + (radiusOffset or 0))
  local ox = math.cos(angle) * radius
  local oy = math.sin(angle) * radius * target.flatten
  local x = originX + ox * cp - oy * sp
  local y = originY + ox * sp + oy * cp
  local z = zOffset + math.sin(angle) * (target.depthScale or 1)
  return x, y, z
end

function drawOrbitalPathSegment(target, originX, originY, zOffset, startAngle, spanAngle, frontPass, r, g, b, alpha, radiusOffset, segmentStep, snapToPixel, useLighting)
  local cp = math.cos(target.plane)
  local sp = math.sin(target.plane)
  local stepSize = segmentStep or 0.14
  local stepCount = math.max(4, math.ceil(math.abs(spanAngle) / stepSize))
  local stepAngle = spanAngle / stepCount
  local shouldSnap = snapToPixel ~= false
  local shouldLight = useLighting ~= false
  local px, py, pz
  for i = 0, stepCount do
    local a = startAngle + stepAngle * i
    local x, y, z = orbitalPathPoint(target, a, radiusOffset, originX, originY, zOffset, cp, sp)
    if px then
      local segZ = (pz + z) * 0.5
      if orbitSegmentVisible(frontPass, segZ) then
        if shouldLight then
          local segLight = cameraLightAt((px + x) * 0.5, (py + y) * 0.5, segZ)
          setLitColorDirect(r, g, b, segLight, alpha)
        else
          setColorDirect(r, g, b, alpha)
        end
        local sx0, sy0 = projectWorldPoint(px, py, pz)
        local sx1, sy1 = projectWorldPoint(x, y, z)
        if shouldSnap then
          sx0, sy0 = math.floor(sx0 + 0.5), math.floor(sy0 + 0.5)
          sx1, sy1 = math.floor(sx1 + 0.5), math.floor(sy1 + 0.5)
        end
        love.graphics.line(sx0, sy0, sx1, sy1)
      end
    end
    px, py, pz = x, y, z
  end
end

function drawOrbitalCapsuleBorder(target, originX, originY, zOffset, startAngle, spanAngle, frontPass, r, g, b, alpha, halfWidth, segmentStep, snapToPixel, useLighting)
  local width = math.max(0.4, halfWidth or 1)
  drawOrbitalPathSegment(target, originX, originY, zOffset, startAngle, spanAngle, frontPass, r, g, b, alpha, -width, segmentStep, snapToPixel, useLighting)
  drawOrbitalPathSegment(target, originX, originY, zOffset, startAngle, spanAngle, frontPass, r, g, b, alpha, width, segmentStep, snapToPixel, useLighting)

  local cp = math.cos(target.plane)
  local sp = math.sin(target.plane)
  local shouldSnap = snapToPixel ~= false
  local shouldLight = useLighting ~= false
  local function drawEndCap(angle)
    local innerX, innerY, innerZ = orbitalPathPoint(target, angle, -width, originX, originY, zOffset, cp, sp)
    local outerX, outerY, outerZ = orbitalPathPoint(target, angle, width, originX, originY, zOffset, cp, sp)
    local segZ = (innerZ + outerZ) * 0.5
    if not orbitSegmentVisible(frontPass, segZ) then
      return
    end
    if shouldLight then
      local segLight = cameraLightAt((innerX + outerX) * 0.5, (innerY + outerY) * 0.5, segZ)
      setLitColorDirect(r, g, b, segLight, alpha)
    else
      setColorDirect(r, g, b, alpha)
    end
    local sx0, sy0 = projectWorldPoint(innerX, innerY, innerZ)
    local sx1, sy1 = projectWorldPoint(outerX, outerY, outerZ)
    if shouldSnap then
      sx0, sy0 = math.floor(sx0 + 0.5), math.floor(sy0 + 0.5)
      sx1, sy1 = math.floor(sx1 + 0.5), math.floor(sy1 + 0.5)
    end
    love.graphics.line(sx0, sy0, sx1, sy1)
  end

  drawEndCap(startAngle)
  drawEndCap(startAngle + spanAngle)
end

local function drawMoonOrbitIntro(frontPass)
  local showDuration = 5.0
  local fadeDuration = 1.5
  local t = state.time or 0
  if t >= showDuration + fadeDuration then
    return
  end
  local alpha
  if t < showDuration then
    alpha = 1.0
  else
    alpha = 1.0 - smoothstep((t - showDuration) / fadeDuration)
  end
  if alpha <= 0 then
    return
  end
  local moon = state.moons and state.moons[1]
  if not moon then
    return
  end
  local ox, oy = orbiterOrbitOrigin(moon)

  drawOrbitalPathSegment(
    moon,
    ox, oy, 0,
    0, WORLD.twoPi,
    frontPass,
    swatch.brightest[1], swatch.brightest[2], swatch.brightest[3],
    alpha * 0.72,
    0,
    0.05,
    true,
    false
  )
end

local function drawSelectedOrbit(frontPass)
  local orbiter = state.selectedOrbiter
  if not orbiter then
    return
  end

  love.graphics.setLineWidth(1)
  local originX, originY, originZ = orbiterOrbitOrigin(orbiter)
  drawOrbitalPathSegment(
    orbiter,
    originX,
    originY,
    originZ + (orbiter.zBase or 0),
    0,
    WORLD.twoPi,
    frontPass,
    SELECTED_ORBIT_COLOR[1],
    SELECTED_ORBIT_COLOR[2],
    SELECTED_ORBIT_COLOR[3],
    0.84,
    0
  )
end

local function timingGhostVisualState(moon)
  local phaseDistance = Systems.MoonTiming.distanceFromTargetPhase(moon, WORLD.twoPi)
  local inPerfect = phaseDistance <= Systems.MoonTiming.config.perfectWindow
  local inGood = phaseDistance <= Systems.MoonTiming.config.goodWindow

  local borderColor = swatch.brightest
  local zoneColor = swatch.brightest
  if inGood and (not inPerfect) then
    borderColor = swatch.mid -- third brightest cue on non-perfect overlap
  end
  if inPerfect then
    zoneColor = swatch.bright -- second brightest cue when intersecting the timing zone
  end

  return borderColor, zoneColor
end

function drawSingleMoonTimingGhost(frontPass)
  if state.gameOver then
    return
  end
  local moon = Systems.MoonTiming.getSingleMoon(state, WORLD.twoPi)
  if not moon then
    return
  end
  if not Systems.MoonTiming.isZoneVisible(moon) then
    return
  end

  local originX, originY, originZ = orbiterOrbitOrigin(moon)
  local goodSpan = Systems.MoonTiming.goodSpanAngle(WORLD.twoPi)
  local perfectSpan = Systems.MoonTiming.perfectSpanAngle(WORLD.twoPi)
  local ghostSegmentStep = 0.06
  local center = Systems.MoonTiming.windowCenterAngle(moon, WORLD.twoPi)
  local startAngle = center - goodSpan * 0.5
  local perfectStart = center - perfectSpan * 0.5
  local halfWidth = math.min(Systems.MoonTiming.config.ghostHalfWidth, math.max(1.4, moon.radius * 0.05))
  local borderColor, zoneColor = timingGhostVisualState(moon)

  love.graphics.setLineWidth(1)
  drawOrbitalCapsuleBorder(
    moon,
    originX,
    originY,
    originZ + (moon.zBase or 0),
    startAngle,
    goodSpan,
    frontPass,
    borderColor[1],
    borderColor[2],
    borderColor[3],
    0.64,
    halfWidth,
    ghostSegmentStep,
    false,
    false
  )

  drawOrbitalCapsuleBorder(
    moon,
    originX,
    originY,
    originZ + (moon.zBase or 0),
    perfectStart,
    perfectSpan,
    frontPass,
    zoneColor[1],
    zoneColor[2],
    zoneColor[3],
    0.98,
    halfWidth * 0.50,
    ghostSegmentStep,
    false,
    false
  )

  -- Perfect window is the only filled subsection.
  drawOrbitalPathSegment(
    moon,
    originX,
    originY,
    originZ + (moon.zBase or 0),
    perfectStart,
    perfectSpan,
    frontPass,
    zoneColor[1],
    zoneColor[2],
    zoneColor[3],
    0.90,
    0,
    ghostSegmentStep,
    false,
    false
  )
  drawOrbitalPathSegment(
    moon,
    originX,
    originY,
    originZ + (moon.zBase or 0),
    perfectStart,
    perfectSpan,
    frontPass,
    zoneColor[1],
    zoneColor[2],
    zoneColor[3],
    0.72,
    -halfWidth * 0.18,
    ghostSegmentStep,
    false,
    false
  )
  drawOrbitalPathSegment(
    moon,
    originX,
    originY,
    originZ + (moon.zBase or 0),
    perfectStart,
    perfectSpan,
    frontPass,
    zoneColor[1],
    zoneColor[2],
    zoneColor[3],
    0.72,
    halfWidth * 0.18,
    ghostSegmentStep,
    false,
    false
  )
end

local function drawLitSphere(x, y, z, radius, r, g, b, lightScale, segments)
  local px, py, projectScale = projectWorldPoint(x, y, z or 0)
  local pr = math.max(0.6, radius * projectScale)
  local sideCount = segments or 24
  local shadeStyle = activeSphereShadeStyle()
  local lightX, lightY, lightZ = sideLightWorldPosition()
  local lightPx, lightPy = projectWorldPoint(lightX, lightY, lightProjectionZ(lightZ))
  local objDepth = (z or 0) * WORLD.cameraLightZScale
  local lightDepth = lightDepthForZ(lightZ)
  local lx = lightPx - px
  local ly = -(lightPy - py)
  local lz = (lightDepth - objDepth) / WORLD.cameraLightZScale
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
  local inEclipse = shadowFactor <= WORLD.bodyShadeEclipseThreshold

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
    sphereShader:send("darkFloor", clamp(shadeStyle.darkFloor or WORLD.bodyShadeDarkFloorTone, 0, 1))
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
  local t = 1 - clamp(state.planetBounceTime / GAMEPLAY.planetBounceDuration, 0, 1)
  local kick = math.sin(t * math.pi)
  local danger = dangerBlendForRpm(state.currentRpm or 0)
  local stress = instabilityStressBlend()
  local pulse = 0.5 + 0.5 * math.sin(state.time * (2.6 + danger * 4.8 + stress * 4.6))
  local pulseMix = smoothstep(pulse)
  local bounceScale = 1 + kick * 0.14 * (1 - t) + danger * (0.02 + pulseMix * 0.05) + stress * (0.01 + pulseMix * 0.03)
  local px, py, projScale = projectWorldPoint(cx, cy, 0)
  local pr = math.max(3, BODY_VISUAL.planetRadius * bounceScale * projScale)

  setColorDirect(0, 0, 0, 1)
  love.graphics.circle("fill", px, py, pr, 44)
  if danger > 0 or stress > 0 then
    local tension = clamp(danger * 0.6 + stress, 0, 1)
    setColorDirect(
      lerp(swatch.mid[1], swatch.brightest[1], tension),
      lerp(swatch.mid[2], swatch.bright[2], tension),
      lerp(swatch.mid[3], swatch.bright[3], tension),
      0.10 + (0.18 + 0.24 * pulseMix) * tension
    )
    love.graphics.circle("line", px, py, pr + 4 + 6 * danger + 7 * stress, 44)
    local innerPulse = smoothstep(0.5 + 0.5 * math.sin(state.time * (4.2 + stress * 6.8)))
    setColorDirect(
      swatch.brightest[1],
      swatch.brightest[2],
      swatch.brightest[3],
      clamp(0.04 + stress * 0.14 * innerPulse, 0, 0.22)
    )
    love.graphics.circle("line", px, py, pr + 2 + 4 * stress, 44)
  end
  state.planetVisualRadius = pr * zoom
end

local function activeGravityRippleParams()
  local ripples = state.gravityRipples
  local ripple = ripples[#ripples]
  if not ripple then
    return false, 0, 0, 0, 0
  end

  local t = clamp(ripple.age / ripple.life, 0, 1)
  local travel = smoothstep(t)
  local coreR = clamp((state.planetVisualRadius or BODY_VISUAL.planetRadius) / WORLD.gameH, 0.002, 0.45)
  local maxDx = math.max(cx, WORLD.gameW - cx)
  local maxDy = math.max(cy, WORLD.gameH - cy)
  local endPadding = ripple.endPadding or GAMEPLAY.gravityRippleEndPadding
  local edgeR = math.sqrt(maxDx * maxDx + maxDy * maxDy) / WORLD.gameH + endPadding
  local startRadiusScale = ripple.startRadiusScale or 1.15
  local radius = lerp(coreR * startRadiusScale, edgeR, travel)
  local widthStart = ripple.widthStart or GAMEPLAY.gravityRippleWidthStart
  local widthEnd = ripple.widthEnd or GAMEPLAY.gravityRippleWidthEnd
  local halfWidth = lerp(widthStart, widthEnd, travel)
  local rampIn = smoothstep(clamp(t / 0.08, 0, 1))
  local rampOut = 1 - smoothstep(clamp((t - 0.78) / 0.22, 0, 1))
  local strength = rampIn * rampOut
  local radialStrength = ripple.radialStrength or GAMEPLAY.gravityRippleRadialStrength
  local swirlStrength = ripple.swirlStrength or GAMEPLAY.gravityRippleSwirlStrength
  return true,
    radius,
    halfWidth,
    radialStrength * strength,
    swirlStrength * strength
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
  return orbiter.boostDurations and #orbiter.boostDurations > 0
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

  local danger = dangerBlendForRpm(state.currentRpm or 0)
  local tier = dangerTierForRpm(state.currentRpm or 0)
  local perfectFlash = clamp((state.perfectFlashTimer or 0) / 0.24, 0, 1)
  local goodFlash = clamp((state.goodFlashTimer or 0) / 0.18, 0, 1)
  local hitBoost = clamp((state.hitTrailTimer or 0) / 0.36, 0, 1) + perfectFlash * 0.48 + goodFlash * 0.24
  hitBoost = clamp(hitBoost, 0, 1.35)

  -- Trail length and visibility tied to RPM
  local currentRpm = state.currentRpm or 0
  local rpmTrailFactor = clamp((currentRpm - 5) / 45, 0, 1.5) 
  
  local streakBoost = hitBoost * 22
  local baseTrail = 24 + (rpmTrailFactor * 60)
  local trailLen = math.min(moon.radius * 8.0, baseTrail + danger * 30 + streakBoost)
  
  local headAlpha = clamp(0.35 + (rpmTrailFactor * 0.5) + danger * 0.3 + hitBoost * 0.4, 0.35, 1.0)
  local tailAlpha = clamp(0.08 + (rpmTrailFactor * 0.2) + danger * 0.1, 0.05, 0.5)
  local originX, originY, originZ = orbiterOrbitOrigin(moon)
  drawOrbitalTrail(moon, trailLen, headAlpha, tailAlpha, originX, originY, originZ, moon.light)

  local childSatellites = moon.childSatellites or {}
  local showChildOrbitPaths = (not state.singleMoonMode) and state.selectedOrbiter == moon
  love.graphics.setLineWidth(1)
  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, false)
    end
  end

  local moonR, moonG, moonB = computeOrbiterColor(moon.angle)
  local moonLight = moon.light * (1 + danger * 0.2 + hitBoost * 0.22)
  local flicker = 1
  if tier >= 3 then
    flicker = 0.9 + 0.1 * math.sin(state.time * 50)
  end
  local haloPx, haloPy, haloScale = projectWorldPoint(moon.x, moon.y, moon.z)
  local haloR = BODY_VISUAL.moonRadius * haloScale * (1.4 + danger * 0.5 + hitBoost * 0.8)
  setColorDirect(
    lerp(swatch.bright[1], swatch.brightest[1], hitBoost),
    lerp(swatch.bright[2], swatch.brightest[2], hitBoost),
    lerp(swatch.bright[3], swatch.brightest[3], hitBoost),
    clamp(0.08 + danger * 0.14 + hitBoost * 0.22, 0, 0.65)
  )
  love.graphics.circle("fill", haloPx, haloPy, haloR, 24)
  drawLitSphere(
    moon.x,
    moon.y,
    moon.z,
    BODY_VISUAL.moonRadius * flicker,
    moonR,
    moonG,
    moonB,
    moonLight,
    20
  )

  if showChildOrbitPaths then
    for _, child in ipairs(childSatellites) do
      drawChildOrbitPath(child, true)
    end
  end
end

local function orbiterHitRadius(orbiter)
  if orbiter.kind ~= "moon" then
    return nil
  end
  local baseRadius = BODY_VISUAL.moonRadius
  local margin = 2
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

  for _, moon in ipairs(state.moons) do
    append(moon)
  end

  table.sort(renderOrbiters, depthSortOrbiters)
  return renderOrbiters
end

function drawOrbiterByKind(orbiter)
  if orbiter.kind == "moon" then
    drawMoon(orbiter)
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
  local viewportRight = offsetX + WORLD.gameW * scale
  local viewportBottom = offsetY + WORLD.gameH * scale
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

function drawStabilityGauge()
  return
end

function drawSingleMoonTimingDial(centerX, topY, uiScale)
  if state.gameOver then
    return 0
  end
  local moon = Systems.MoonTiming.getSingleMoon(state, WORLD.twoPi)
  if not moon then
    return 0
  end

  local radius = math.max(8, math.floor(Systems.MoonTiming.config.dialRadius * uiScale + 0.5))
  local centerY = topY + radius
  local phase = Systems.MoonTiming.phase(moon, WORLD.twoPi)
  local targetPhase = Systems.MoonTiming.targetPhase(moon, WORLD.twoPi)
  local distanceFromTarget = Systems.MoonTiming.distanceFromTargetPhase(moon, WORLD.twoPi)
  local zoneVisible = Systems.MoonTiming.isZoneVisible(moon)
  local handAngle = -math.pi * 0.5 + phase * WORLD.twoPi
  local targetAngle = -math.pi * 0.5 + targetPhase * WORLD.twoPi
  local goodHalfAngle = Systems.MoonTiming.goodSpanAngle(WORLD.twoPi) * 0.5
  local perfectHalfAngle = Systems.MoonTiming.perfectSpanAngle(WORLD.twoPi) * 0.5
  local windowStart = targetAngle - goodHalfAngle
  local windowEnd = targetAngle + goodHalfAngle
  local perfectStart = targetAngle - perfectHalfAngle
  local perfectEnd = targetAngle + perfectHalfAngle

  love.graphics.setLineWidth(1)
  setColorScaled(swatch.brightest, 1, 0.70)
  love.graphics.circle("line", centerX, centerY, radius, Systems.MoonTiming.config.dialSegments)

  if zoneVisible then
    -- Keep the timing dial focused on the window: outline for full window,
    -- orange fill only for the perfect subsection.
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 0.72)
    love.graphics.arc("line", "open", centerX, centerY, radius, windowStart, windowEnd, Systems.MoonTiming.config.dialSegments)
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 0.34)
    love.graphics.arc("fill", "pie", centerX, centerY, math.max(1, radius - 2), perfectStart, perfectEnd, Systems.MoonTiming.config.dialSegments)
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 0.92)
    love.graphics.arc("line", "open", centerX, centerY, math.max(1, radius - 1), perfectStart, perfectEnd, Systems.MoonTiming.config.dialSegments)
  end

  local handR = radius - 1
  local handX = centerX + math.cos(handAngle) * handR
  local handY = centerY + math.sin(handAngle) * handR
  if zoneVisible and distanceFromTarget <= SLICE.perfectWindow then
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 1)
  elseif zoneVisible and distanceFromTarget <= SLICE.goodWindow then
    setColorDirect(swatch.bright[1], swatch.bright[2], swatch.bright[3], 0.94)
  else
    setColorScaled(swatch.bright, 1, 0.92)
  end
  love.graphics.line(centerX, centerY, handX, handY)

  -- No target-point marker; keep the indicator about timing windows only.
  setColorScaled(swatch.brightest, 1, 0.92)
  love.graphics.circle("fill", centerX, centerY, math.max(1, math.floor(uiScale + 0.5)), 12)
  return radius * 2 + math.floor(6 * uiScale)
end


local function drawInstabilityMeter(meterX, meterY, uiScale)
  local font = love.graphics.getFont()
  local lineH = math.floor(font:getHeight())
  local meterW = math.max(180, math.floor(290 * uiScale))
  local meterH = math.max(10, math.floor(12 * uiScale))
  local maxValue = state.instabilityMax or RUN_PRESSURE.instability.max
  local displayInstability = clamp(state.instabilityDisplay or 0, 0, maxValue)
  local liveInstability = clamp(state.instability or 0, 0, maxValue)
  local displayStability = maxValue - displayInstability
  local liveStability = maxValue - liveInstability
  local ratio = clamp(displayStability / math.max(1, maxValue), 0, 1)
  local dangerRatio = 1 - ratio
  local stress = instabilityStressBlend()
  local tier = instabilityTier()
  local pulse = smoothstep(0.5 + 0.5 * math.sin(state.time * (1.5 + tier * 2.2)))
  local perfectFlash = clamp((state.perfectFlashTimer or 0) / 0.24, 0, 1)
  local goodFlash = clamp((state.goodFlashTimer or 0) / 0.18, 0, 1)
  local relief = math.max(perfectFlash, goodFlash * 0.6)

  local label = string.format("Stability %d / %d", math.floor(liveStability + 0.5), maxValue)
  setColorDirect(
    lerp(swatch.brightest[1], 1, dangerRatio),
    lerp(swatch.brightest[2], 0.42, dangerRatio),
    lerp(swatch.brightest[3], 0.32, dangerRatio),
    0.92
  )
  drawText(label, meterX, meterY - lineH - math.floor(4 * uiScale))

  local backAlpha = tier == 0 and 0.90 or (tier == 1 and 0.92 or 0.95)
  setColorScaled(swatch.darkest, 1, backAlpha)
  love.graphics.rectangle("fill", meterX, meterY, meterW, meterH)

  local fillPad = math.max(1, math.floor(uiScale))
  local fillW = math.max(1, meterW - fillPad * 2)
  local fillH = math.max(1, meterH - fillPad * 2)
  local currentFillW = math.max(0, math.floor(fillW * ratio + 0.5))
  if currentFillW > 0 then
    local fillR = lerp(swatch.dim[1], 1, dangerRatio)
    local fillG = lerp(swatch.dim[2], tier >= 2 and 0.30 or 0.42, dangerRatio)
    local fillB = lerp(swatch.mid[3], tier >= 2 and 0.22 or 0.32, dangerRatio)
    setColorDirect(fillR, fillG, fillB, lerp(0.34, 0.92, dangerRatio))
    love.graphics.rectangle("fill", meterX + fillPad, meterY + fillPad, currentFillW, fillH)
  end

  setColorDirect(
    lerp(swatch.bright[1], swatch.brightest[1], stress),
    lerp(swatch.bright[2], swatch.mid[2], stress),
    lerp(swatch.bright[3], swatch.mid[3], stress),
    0.62 + 0.24 * stress
  )
  love.graphics.rectangle("line", meterX, meterY, meterW, meterH)

  if stress > 0 then
    local glowAlpha = stress * (0.12 + 0.20 * pulse)
    setColorDirect(1, 0.36 + 0.20 * pulse, 0.28, glowAlpha)
    love.graphics.rectangle("line", meterX - 2, meterY - 2, meterW + 4, meterH + 4, 2, 2)
  end

  local softTick = clamp((state.instabilitySoftTickTimer or 0) / RUN_PRESSURE.instability.softTickSeconds, 0, 1)
  if softTick > 0 then
    setColorDirect(0.94, 0.98, 1, 0.20 * softTick)
    love.graphics.rectangle("line", meterX - 3, meterY - 3, meterW + 6, meterH + 6)
  end

  local spike = clamp((state.instabilitySpikeTimer or 0) / RUN_PRESSURE.instability.spikeFlashSeconds, 0, 1)
  if spike > 0 then
    setColorDirect(1, 0.30, 0.24, 0.34 * spike)
    love.graphics.rectangle("fill", meterX - 1, meterY - 1, meterW + 2, meterH + 2)
  end

  if relief > 0 then
    local reliefW = math.max(2, math.floor(meterW * (0.08 + 0.08 * relief)))
    setColorDirect(0.86, 0.96, 1.0, 0.20 * relief)
    love.graphics.rectangle("fill", meterX + math.max(0, currentFillW - reliefW), meterY - 1, reliefW, meterH + 2)
  end

  for i = 1, #state.instabilityShaveFx do
    local fx = state.instabilityShaveFx[i]
    local t = clamp(fx.age / fx.life, 0, 1)
    local fade = 1 - smoothstep(t)
    local fromStability = 1 - fx.fromRatio
    local toStability = 1 - fx.toRatio
    local fxStart = math.min(fromStability, toStability)
    local fxEnd = math.max(fromStability, toStability)
    local fxX = meterX + fillPad + math.floor(fillW * fxStart + 0.5)
    local fxW = math.max(1, math.floor(fillW * (fxEnd - fxStart) + 0.5))
    local lift = math.floor(2 + 20 * smoothstep(t))
    setColorDirect(1, 1, 1, 0.82 * fade)
    love.graphics.rectangle("fill", fxX, meterY - lift, fxW, fillH + 2)
  end
end

local function drawHud()
  local font = love.graphics.getFont()
  local lineH = math.floor(font:getHeight())
  local uiScale = scale >= 1 and scale or 1
  local centerX = offsetX + (WORLD.gameW * scale) * 0.5
  local topY = offsetY + math.floor(8 * uiScale)

  -- Draw 5 perfect hit streak dots
  local streak = math.min(5, state.perfectStreak or 0)
  local dotRadius = math.max(1, math.floor(3 * uiScale))
  local dotGap = math.floor(8 * uiScale)
  local totalDotsW = 5 * dotRadius * 2 + 4 * dotGap
  local dotsStartX = centerX - totalDotsW * 0.5 + dotRadius
  local dotsY = topY + dotRadius

  for i = 1, 5 do
    local dx = dotsStartX + (i - 1) * (dotRadius * 2 + dotGap)
    if i <= streak then
      setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 0.95)
      love.graphics.circle("fill", dx, dotsY, dotRadius, 12)
      -- soft glow
      setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 0.3)
      love.graphics.circle("fill", dx, dotsY, dotRadius * 1.8, 12)
    else
      setColorDirect(swatch.mid[1], swatch.mid[2], swatch.mid[3], 0.4)
      love.graphics.circle("fill", dx, dotsY, dotRadius, 12)
    end
  end

  local totalRpm = state.currentRpm or 0
  local danger = dangerBlendForRpm(totalRpm)
  local tier = dangerTierForRpm(totalRpm)
  local pulse = smoothstep(0.5 + 0.5 * math.sin(state.time * (6 + tier * 2.2)))

  -- Per-digit RPM number with layered tension animations
  local counterFont = getOrbitCounterFont()
  local rpmNumText = tostring(math.floor(totalRpm))
  local rpmY = topY + dotRadius * 2 + math.floor(6 * uiScale)
  local charH = counterFont:getHeight()
  local proximity = clamp(
    (totalRpm - SLICE.calmRpm) / math.max(1, SLICE.collapseRpm - SLICE.calmRpm),
    0, 1
  )

  -- Split into individual characters and measure widths
  local digits = {}
  local charWidths = {}
  local totalNumWidth = 0
  love.graphics.setFont(counterFont)
  for c in rpmNumText:gmatch(".") do
    digits[#digits + 1] = c
    charWidths[#charWidths + 1] = counterFont:getWidth(c)
    totalNumWidth = totalNumWidth + charWidths[#charWidths]
  end
  local numDigits = #digits

  -- Global blink layer at extreme proximity (whole number flickers together)
  local globalBlinkAlpha = 1.0
  if proximity > 0.80 then
    local blinkSpeed = 5 + (proximity - 0.80) * 70
    globalBlinkAlpha = 0.76 + 0.24 * (0.5 + 0.5 * math.sin(state.time * blinkSpeed))
  end

  -- Draw each digit with independent animation
  local digitStartX = math.floor(centerX - totalNumWidth * 0.5)
  local curX = digitStartX
  for i = 1, numDigits do
    local digitChar = digits[i]
    local charW = charWidths[i]

    -- Rank: rightmost digit = 1.0 (most unstable), leftmost approaches 0.25
    local posRatio = (i - 1) / math.max(1, numDigits - 1) -- 0=left, 1=right
    local rank = 0.25 + posRatio * 0.75

    -- Golden-ratio phase spacing so digits never lock in sync
    local phase = (i - 1) * 2.39996323

    -- === Layer 1: Micro-jitter (high freq, tiny, multi-sine noise) ===
    local mFreq = 24 + proximity * 58 + rank * 16
    local mAmp  = proximity * proximity * rank * (1.6 * uiScale)
    local jx = (  math.sin(state.time * mFreq          + phase        ) * 0.65
               +  math.sin(state.time * mFreq * 1.618   + phase * 1.41 ) * 0.25
               +  math.sin(state.time * mFreq * 2.414   + phase * 0.73 ) * 0.10 ) * mAmp
    local jy = (  math.sin(state.time * mFreq * 1.31    + phase * 2.09 ) * 0.60
               +  math.sin(state.time * mFreq * 0.732   + phase * 0.85 ) * 0.30
               +  math.sin(state.time * mFreq * 3.1     + phase * 1.55 ) * 0.10 ) * mAmp * 0.75

    -- === Layer 2: Vertical bounce (low freq, rises sharply with proximity) ===
    local bFreq = 2.2 + proximity * 8 + rank * 3.5
    local bAmp  = proximity * proximity * rank * (5 * uiScale)
    local bounceY = -math.abs(math.sin(state.time * bFreq + phase * 1.6)) * bAmp

    -- === Layer 3: Digital slip (brief lurch — feels like display struggling) ===
    local slipY = 0
    if proximity > 0.68 then
      local slipFactor = (proximity - 0.68) / 0.32
      local slipRate   = 1.6 + rank * 3.4
      local slipT      = (state.time * slipRate + phase * 0.48) % 1.0
      if slipT < 0.16 then
        slipY = math.sin(slipT / 0.16 * math.pi) * slipFactor * rank * (6 * uiScale)
      end
    end

    -- === Layer 4: Scale pulse (each digit breathes at own rate) ===
    local sclFreq = 1.6 + proximity * 5.5 + rank * 2.8
    local sclAmp  = 0.012 + proximity * 0.060 * rank
    local scl = 1.0 + math.sin(state.time * sclFreq + phase * 1.73) * sclAmp

    -- === Layer 5: Rotation tilt (small lean, more dramatic near threshold) ===
    local rotFreq = 1.1 + proximity * 3.8 + rank * 1.9
    local rotAmp  = proximity * proximity * rank * 0.060  -- max ~3.4 degrees
    local rot = math.sin(state.time * rotFreq + phase * 2.61) * rotAmp

    -- === Layer 6: Per-digit alpha flicker (rightmost flickers first/hardest) ===
    local flickerAlpha = 1.0
    if proximity > 0.52 then
      local ff     = (proximity - 0.52) / 0.48
      local fFreq  = 7 + ff * 32 * rank
      flickerAlpha = 1.0 - ff * rank * 0.30 * (0.5 + 0.5 * math.sin(state.time * fFreq + phase * 3.14))
    end

    -- === Color: rightmost digits shift redder slightly faster ===
    local digitDanger = clamp(danger + rank * proximity * 0.20, 0, 1)
    setColorDirect(
      lerp(swatch.brightest[1], 1,    digitDanger),
      lerp(swatch.brightest[2], 0.30, digitDanger),
      lerp(swatch.brightest[3], 0.25, digitDanger),
      globalBlinkAlpha * flickerAlpha * 0.97
    )

    -- Draw using love.graphics.print's built-in transform args:
    -- (text, x, y, rotation, sx, sy, ox, oy)
    -- ox/oy offsets the origin to the character center for correct rotation/scale pivot
    local ox = charW * 0.5
    local oy = charH * 0.5
    love.graphics.print(
      digitChar,
      math.floor(curX + charW * 0.5 + jx),
      math.floor(rpmY + charH * 0.5 + jy + bounceY + slipY),
      rot,
      scl, scl,
      ox, oy
    )

    curX = curX + charW
  end

  -- Small "rpm" label below — subtle sympathetic jitter
  love.graphics.setFont(font)
  local rpmLabel = "rpm"
  local labelJy = proximity * proximity * math.sin(state.time * 7.4 + 1.0) * (1.8 * uiScale)
  setColorDirect(swatch.bright[1], swatch.bright[2], swatch.bright[3],
    0.48 + 0.32 * proximity)
  drawText(rpmLabel,
    math.floor(centerX - font:getWidth(rpmLabel) * 0.5),
    math.floor(rpmY + charH - math.floor(2 * uiScale) + labelJy))

  -- Timing dial + stability meter (top-left)
  local meterX = math.floor(offsetX + 14 * uiScale)
  local meterW = math.max(180, math.floor(290 * uiScale))
  local meterH = math.max(10, math.floor(12 * uiScale))
  local meterY = topY + lineH + math.floor(8 * uiScale)
  local dialRadius = math.max(8, math.floor(Systems.MoonTiming.config.dialRadius * uiScale + 0.5))
  local dialCenterX = meterX + math.floor(meterW * 0.5)
  local dialTopY = meterY + meterH + math.floor(8 * uiScale)
  drawSingleMoonTimingDial(dialCenterX, dialTopY, uiScale)
  drawInstabilityMeter(meterX, meterY, uiScale)

  -- Objectives panel — top right
  local objTitle = "objectives"
  local activeObjectives = orderedActiveObjectives()
  local variantLabel = activeMoonVariantConfig().label
  local objLines = {}
  local maxObjectiveLines = 6
  for i = 1, math.min(#activeObjectives, maxObjectiveLines) do
    local objectiveId = activeObjectives[i]
    local def = OBJECTIVE_DEFS[objectiveId]
    if def then
      local prefix = objectiveIsOptional(objectiveId) and "* bonus " or "* "
      objLines[#objLines + 1] = {
        text = prefix .. def.label,
        optional = objectiveIsOptional(objectiveId),
      }
    end
  end
  if #activeObjectives > maxObjectiveLines then
    objLines[#objLines + 1] = {
      text = string.format("* +%d more", #activeObjectives - maxObjectiveLines),
      optional = true,
    }
  end
  if #objLines == 0 then
    objLines[#objLines + 1] = {text = "* no active objectives", optional = true}
  end

  local objW = math.max(font:getWidth(objTitle), font:getWidth(variantLabel))
  for i = 1, #objLines do
    objW = math.max(objW, font:getWidth(objLines[i].text))
  end
  local viewportRight = offsetX + WORLD.gameW * scale
  local objX = math.floor(viewportRight - objW - 14 * uiScale)
  local objY = topY
  setColorScaled(swatch.brightest, 1, 0.55)
  drawText(objTitle, objX, objY)
  setColorScaled(palette.text, 1, 0.72)
  drawText(variantLabel, objX, objY + lineH + math.floor(2 * uiScale))
  for i = 1, #objLines do
    local rowY = objY + lineH * (i + 1) + math.floor(4 * uiScale) + (i - 1) * math.floor(2 * uiScale)
    local alpha = objLines[i].optional and 0.58 or 0.90
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], alpha)
    drawText(objLines[i].text, objX, rowY)
  end

  local viewportBottom = offsetY + WORLD.gameH * scale
  -- Bottom-left status
  local helpX = math.floor(offsetX + 14 * uiScale)
  if tier >= 3 then
    setColorDirect(1, 0.34 + 0.20 * pulse, 0.30, 0.9)
    drawText("REDLINE", helpX, math.floor(viewportBottom - lineH - 2 * uiScale))
  else
    setColorScaled(palette.muted, 1, 0.78)
    drawText(string.format("Collapse Shards %d", state.totalShards or 0), helpX, math.floor(viewportBottom - lineH - 2 * uiScale))
  end
  local choiceSummary = pendingChoiceSummary()
  if choiceSummary then
    setColorScaled(swatch.brightest, 1, 0.82)
    drawText("choice ready: " .. choiceSummary, helpX, math.floor(viewportBottom - lineH * 2 - 4 * uiScale))
  end
  if (state.objectiveNoticeTimer or 0) > 0 and state.lastObjectiveCompletionText then
    local t = clamp((state.objectiveNoticeTimer or 0) / 2.2, 0, 1)
    local rise = math.floor((1 - t) * 14 * uiScale)
    setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], 0.88 * t)
    drawText(state.lastObjectiveCompletionText, helpX, math.floor(viewportBottom - lineH * 3 - 8 * uiScale - rise))
  end
end

local function drawPanelButton(btn, label, uiScale, font, mouseX, mouseY)
  local hovered = pointInRect(mouseX, mouseY, btn)
  if hovered then
    setColorScaled(swatch.brightest, 1, 0.96)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
  end
  setColorScaled(swatch.brightest, 1, 0.92)
  local labelW = font:getWidth(label)
  drawText(label, btn.x + math.floor((btn.w - labelW) * 0.5), btn.y + math.floor(3 * uiScale))
  return hovered
end

local function skillTreeOwnedForNode(nodeId)
  return isSkillUnlocked(nodeId)
end

local function buySkillTreeNode(nodeId)
  return unlockSkillNode(nodeId)
end

local function skillTreePanelRect(uiScale)
  local w, h = love.graphics.getDimensions()
  local margin = math.floor(18 * uiScale)
  return {
    x = margin,
    y = margin,
    w = w - margin * 2,
    h = h - margin * 2,
  }
end

local function skillTreeNodeGeometry(node, uiScale, panel)
  local radius = math.max(15, math.floor(SKILL_TREE_NODE_DIAMETER * uiScale * 0.5 + 0.5))
  local x = panel.x + panel.w * 0.5 + skillTree.panX + node.x * uiScale
  local y = panel.y + panel.h * 0.5 + skillTree.panY + node.y * uiScale
  return x, y, radius
end

local function hoveredSkillTreeNode(mx, my, uiScale, panel)
  for i = 1, #SKILL_TREE_NODES do
    local node = SKILL_TREE_NODES[i]
    local x, y, radius = skillTreeNodeGeometry(node, uiScale, panel)
    local dx = mx - x
    local dy = my - y
    if dx * dx + dy * dy <= radius * radius then
      return node, x, y, radius
    end
  end
  return nil, 0, 0, 0
end

function drawGameOverOverlay()
  if not state.gameOver then
    ui.restartBtn.visible = false
    ui.skillsBtn.visible = false
    return
  end

  local w, h = love.graphics.getDimensions()
  setColorDirect(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local panelW = math.floor(470 * uiScale)
  local panelH = math.floor(360 * uiScale)
  local panelX = math.floor((w - panelW) * 0.5)
  local panelY = math.floor((h - panelH) * 0.5)
  local pad = math.floor(12 * uiScale)

  setColorScaled(swatch.darkest, 1, 0.96)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
  setColorScaled(swatch.brightest, 1, 0.96)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

  local completedCount = state.objectivesCompletedThisRun or 0
  local title = completedCount > 0 and "run complete" or "collapse"
  local subtitle = completedCount > 0
    and string.format("%d objectives completed this run", completedCount)
    or string.format(
      "instability reached %d / %d",
      math.floor(state.instability or 0),
      state.instabilityMax or RUN_PRESSURE.instability.max
    )
  local titleColor = state.objectiveReached and swatch.brightest or swatch.brightest
  setColorScaled(titleColor, 1, 1)
  drawText(title, panelX + pad, panelY + pad)
  setColorScaled(palette.text, 1, 0.82)
  drawText(subtitle, panelX + pad, panelY + pad + font:getHeight() + math.floor(2 * uiScale))

  local lineH = font:getHeight()
  local statY = panelY + pad + lineH * 2 + math.floor(8 * uiScale)
  local labelW = math.floor(220 * uiScale)
  local valueX = panelX + pad + labelW
  local stats = {
    {"max rpm reached",   string.format("%.1f", state.maxRpmReached or 0)},
    {"max instability",   string.format("%.1f", state.maxInstabilityReached or 0)},
    {"perfect hits",      tostring(state.perfectHits or 0)},
    {"good hits",         tostring(state.goodHits or 0)},
    {"orbits this run",   tostring(state.orbitsEarnedThisRun or 0)},
    {"shards gained",     tostring(state.shardsGainedThisRun or 0)},
    {"total shards",      tostring(state.totalShards or 0)},
  }

  for i = 1, #stats do
    local rowY = statY + (i - 1) * (lineH + math.floor(3 * uiScale))
    local row = stats[i]
    setColorScaled(palette.text, 1, 0.82)
    drawText(row[1], panelX + pad, rowY)
    setColorScaled(palette.accent, 1, 1)
    drawText(row[2], valueX, rowY)
  end

  local prompt = "press r to restart   press k for skills"
  setColorScaled(swatch.brightest, 1, 0.90)
  drawText(prompt, panelX + pad, panelY + panelH - math.floor((lineH + 44) * uiScale))
  if #state.pendingSkillChoices > 0 then
    setColorScaled(palette.text, 1, 0.86)
    drawText("new upgrade choice available", panelX + pad, panelY + panelH - math.floor((lineH + 66) * uiScale))
  end

  local btnW = math.floor(142 * uiScale)
  local btnH = math.floor((font:getHeight() + 8) * uiScale)
  local btnGap = math.floor(12 * uiScale)
  local rowTotalW = btnW * 2 + btnGap
  local rowX = panelX + math.floor((panelW - rowTotalW) * 0.5)
  local btnY = panelY + panelH - btnH - pad

  ui.restartBtn.x = rowX
  ui.restartBtn.y = btnY
  ui.restartBtn.w = btnW
  ui.restartBtn.h = btnH
  ui.restartBtn.visible = true
  ui.skillsBtn.x = rowX + btnW + btnGap
  ui.skillsBtn.y = btnY
  ui.skillsBtn.w = btnW
  ui.skillsBtn.h = btnH
  ui.skillsBtn.visible = true

  local mouseX, mouseY = love.mouse.getPosition()
  drawPanelButton(ui.restartBtn, "restart", uiScale, font, mouseX, mouseY)
  local skillsLabel = (#state.pendingSkillChoices > 0) and "choose" or "skills"
  drawPanelButton(ui.skillsBtn, skillsLabel, uiScale, font, mouseX, mouseY)
end

local function drawSkillTreeScene()
  ui.restartBtn.visible = false
  ui.skillsBtn.visible = false

  local font = love.graphics.getFont()
  local uiScale = scale >= 1 and scale or 1
  local panel = skillTreePanelRect(uiScale)
  local lineH = math.floor(font:getHeight())
  local pad = math.floor(12 * uiScale)
  local mouseX, mouseY = love.mouse.getPosition()

  setColorDirect(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())

  setColorScaled(swatch.darkest, 1, 0.96)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h)
  setColorScaled(swatch.brightest, 1, 0.96)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h)

  local tierId = activeChoiceTierId()
  local tierInfo = tierId and SKILL_CHOICE_TIERS[tierId] or nil
  local subtitle = tierInfo and ("choose: " .. tierInfo.title) or "no pending choice (preview mode)"
  if tierInfo and #state.pendingSkillChoices > 1 then
    subtitle = string.format("%s (+%d queued)", subtitle, #state.pendingSkillChoices - 1)
  end
  local topRightText = string.format("shards %d", state.totalShards or 0)

  setColorScaled(swatch.brightest, 1, 1)
  drawText("skill tree", panel.x + pad, panel.y + pad)
  setColorScaled(palette.text, 1, 0.82)
  drawText(subtitle, panel.x + pad, panel.y + pad + lineH + math.floor(2 * uiScale))
  drawText(topRightText, panel.x + panel.w - pad - font:getWidth(topRightText), panel.y + pad)
  setColorScaled(palette.text, 1, 0.72)
  drawText(activeMoonVariantConfig().label, panel.x + panel.w - pad - font:getWidth(activeMoonVariantConfig().label), panel.y + pad + lineH + math.floor(2 * uiScale))

  local hoveredTooltipLines
  local hoveredTooltipBtn
  local hoveredNode, hoveredX, hoveredY, hoveredRadius = hoveredSkillTreeNode(mouseX, mouseY, uiScale, panel)
  local nodeGeometryById = {}

  for i = 1, #SKILL_TREE_NODES do
    local node = SKILL_TREE_NODES[i]
    local x, y, radius = skillTreeNodeGeometry(node, uiScale, panel)
    nodeGeometryById[node.id] = {x = x, y = y, radius = radius}
  end

  love.graphics.setLineWidth(1)
  for i = 1, #SKILL_TREE_LINKS do
    local link = SKILL_TREE_LINKS[i]
    local fromGeo = nodeGeometryById[link[1]]
    local toGeo = nodeGeometryById[link[2]]
    if fromGeo and toGeo then
      local fromOwned = isSkillUnlocked(link[1])
      local toOwned = isSkillUnlocked(link[2])
      local alpha = (fromOwned or toOwned) and 0.74 or 0.30
      setColorDirect(swatch.brightest[1], swatch.brightest[2], swatch.brightest[3], alpha)
      love.graphics.line(fromGeo.x, fromGeo.y, toGeo.x, toGeo.y)
    end
  end

  for i = 1, #SKILL_TREE_NODES do
    local node = SKILL_TREE_NODES[i]
    local geo = nodeGeometryById[node.id]
    local x, y, radius = geo.x, geo.y, geo.radius
    local owned = skillTreeOwnedForNode(node.id)
    local locked = isSkillLockedByChoice(node.id)
    local canBuy, reason = canUnlockSkillNode(node.id)
    local hovered = node == hoveredNode
    local alpha = owned and 1 or (canBuy and 0.95 or (locked and 0.24 or 0.42))
    local fxPulse = 0
    for j = 1, #state.skillUnlockFx do
      local fx = state.skillUnlockFx[j]
      if fx.skillId == node.id then
        local t = clamp((fx.age or 0) / math.max(0.001, fx.life or PROGRESSION.unlockNodeFxSeconds), 0, 1)
        fxPulse = math.max(fxPulse, 1 - smoothstep(t))
      end
    end
    local radiusScale = 1 + fxPulse * 0.18
    local drawRadius = radius * radiusScale

    setColorScaled(swatch.nearDark, 1, 0.95)
    love.graphics.circle("fill", x, y, drawRadius, 36)
    setColorScaled(swatch.brightest, 1, hovered and 1 or alpha)
    love.graphics.circle("line", x, y, drawRadius, 36)

    if fxPulse > 0 then
      setColorDirect(
        swatch.brightest[1],
        swatch.brightest[2],
        swatch.brightest[3],
        0.84 * fxPulse
      )
      local ringRadius = drawRadius + PROGRESSION.unlockNodeFxRingRadius * (1 - fxPulse) * uiScale * 0.22
      love.graphics.circle("line", x, y, ringRadius, 40)
    end

    if owned then
      setColorScaled(palette.accent, 1, 0.95)
      love.graphics.circle("fill", x, y, math.max(3, math.floor(radius * 0.25)), 24)
    end

    setColorScaled(palette.text, 1, alpha)
    local labelW = font:getWidth(node.label)
    drawText(node.label, x - labelW * 0.5, y + radius + math.floor(5 * uiScale))
    local status
    if owned then
      status = "unlocked"
    elseif locked then
      status = "locked by choice"
    elseif canBuy then
      status = "unlock"
    elseif reason == "between-runs" then
      status = "between runs"
    elseif reason == "tier-locked" and isChoiceQueued(node.tier) then
      status = "queued"
    elseif tierId ~= node.tier then
      status = "future tier"
    else
      status = "locked"
    end
    local statusW = font:getWidth(status)
    setColorScaled(palette.text, 1, owned and 0.9 or alpha)
    drawText(status, x - statusW * 0.5, y - math.floor(lineH * 0.5))
  end

  if hoveredNode and (not skillTree.dragging) then
    hoveredTooltipLines = cloneTable(hoveredNode.tooltipLines)
    local owned = isSkillUnlocked(hoveredNode.id)
    local locked = isSkillLockedByChoice(hoveredNode.id)
    local canBuy, reason = canUnlockSkillNode(hoveredNode.id)
    local statusText = owned and "Unlocked"
      or (locked and "Locked by prior choice")
      or (canBuy and "Ready to unlock")
      or (reason == "between-runs" and "Available after collapse")
      or (reason == "tier-locked" and "Waiting for this tier")
      or "Locked"
    hoveredTooltipLines[#hoveredTooltipLines + 1] = {
      pre = "status ",
      hi = statusText,
      post = "",
    }
    hoveredTooltipBtn = {
      x = hoveredX - hoveredRadius,
      y = hoveredY - hoveredRadius,
      w = hoveredRadius * 2,
      h = hoveredRadius * 2,
    }
  end
  drawHoverTooltip(hoveredTooltipLines, hoveredTooltipBtn, uiScale, lineH, false)

  local btnW = math.floor(132 * uiScale)
  local btnH = math.floor((lineH + 8) * uiScale)
  local btnGap = math.floor(12 * uiScale)
  local btnY = panel.y + panel.h - btnH - pad

  ui.skillTreeBackBtn.x = panel.x + pad
  ui.skillTreeBackBtn.y = btnY
  ui.skillTreeBackBtn.w = btnW
  ui.skillTreeBackBtn.h = btnH
  ui.skillTreeBackBtn.visible = true

  ui.skillTreeRestartBtn.x = ui.skillTreeBackBtn.x + btnW + btnGap
  ui.skillTreeRestartBtn.y = btnY
  ui.skillTreeRestartBtn.w = math.floor(btnW * 1.15)
  ui.skillTreeRestartBtn.h = btnH
  ui.skillTreeRestartBtn.visible = true

  drawPanelButton(ui.skillTreeBackBtn, "back", uiScale, font, mouseX, mouseY)
  drawPanelButton(ui.skillTreeRestartBtn, "restart", uiScale, font, mouseX, mouseY)
end

local function drawTimingWorldFx()
  local font = love.graphics.getFont()
  for i = 1, #state.timingRings do
    local ring = state.timingRings[i]
    local t = clamp(ring.age / ring.life, 0, 1)
    local alpha = (1 - smoothstep(t)) * (ring.alpha or 0.8)
    local radius = lerp(ring.radiusStart, ring.radiusEnd, t)
    local px, py, pScale = projectWorldPoint(ring.x, ring.y, ring.z)
    setColorDirect(ring.color[1], ring.color[2], ring.color[3], alpha)
    love.graphics.setLineWidth(math.max(1, pScale))
    love.graphics.circle("line", px, py, radius * pScale, 22)
  end
  love.graphics.setLineWidth(1)

  for i = 1, #state.timingPopups do
    local popup = state.timingPopups[i]
    local t = clamp(popup.age / popup.life, 0, 1)
    local alpha = 1 - smoothstep(t)
    local px, py = projectWorldPoint(popup.x, popup.y, popup.z)
    local text = popup.text or ""
    local drawX = px - font:getWidth(text) * 0.5
    setColorDirect(popup.color[1], popup.color[2], popup.color[3], alpha)
    drawText(text, drawX, py)
  end
end

local function drawDangerOverlay()
  local stress = instabilityStressBlend()
  local tier = instabilityTier()
  local pulse = 0.5 + 0.5 * math.sin(state.time * (4 + tier * 3.5))
  local pulseMix = smoothstep(pulse)
  local missFlash = clamp((state.missFlashTimer or 0) / 0.13, 0, 1)
  local spikeFlash = clamp((state.instabilitySpikeTimer or 0) / RUN_PRESSURE.instability.spikeFlashSeconds, 0, 1)
  local collapseFlash = clamp((state.collapseFreezeTimer or 0) / math.max(0.0001, SLICE.collapseFreezeSeconds), 0, 1)
  local flash = math.max(missFlash, spikeFlash, collapseFlash)
  if stress <= 0 and flash <= 0 then
    return
  end

  local w, h = love.graphics.getDimensions()
  local ambientStress = clamp(stress * (0.02 + 0.04 * pulseMix), 0, 0.10)
  if ambientStress > 0 then
    setColorDirect(0.10, 0.02, 0.03, ambientStress)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end

  if flash > 0 then
    local isCollapse = collapseFlash >= missFlash and collapseFlash >= spikeFlash
    if isCollapse then
      setColorDirect(1, 0.34, 0.26, 0.26 * flash)
    elseif spikeFlash >= missFlash then
      setColorDirect(0.55, 0.16, 0.18, 0.20 * flash)
    else
      setColorDirect(0.35, 0.14, 0.18, 0.18 * flash)
    end
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
end

local function drawTimingGhostOverlayUiPass()
  if scene ~= SCENE_GAME then
    return
  end
  if state.gameOver then
    return
  end

  local shakeX = state.screenShakeX or 0
  local shakeY = state.screenShakeY or 0
  local prevLineStyle = love.graphics.getLineStyle()
  local prevLineJoin = love.graphics.getLineJoin()
  love.graphics.setLineStyle("smooth")
  love.graphics.setLineJoin("miter")
  love.graphics.push()
  love.graphics.translate(offsetX + shakeX, offsetY + shakeY)
  love.graphics.scale(scale, scale)
  love.graphics.translate(cx, cy)
  love.graphics.scale(zoom, zoom)
  love.graphics.translate(-cx, -cy)
  drawSingleMoonTimingGhost(false)
  drawSingleMoonTimingGhost(true)
  love.graphics.pop()
  love.graphics.setLineStyle(prevLineStyle)
  love.graphics.setLineJoin(prevLineJoin)
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
  local ok, source = pcall(love.audio.newSource, Assets.audio.music, "stream")
  if not ok or not source then
    bgMusic = nil
    bgMusicFirstPass = false
    return
  end

  bgMusic = source
  bgMusic:setLooping(false)
  bgMusic:setVolume(AUDIO.bgMusicVolume)
  bgMusic:play()
  bgMusicFirstPass = true
  bgMusicPrevPos = 0
end

local function updateBackgroundMusic(dt)
  if not bgMusic then
    return
  end

  bgMusicDuckTimer = math.max(0, bgMusicDuckTimer - dt)
  local duckT = bgMusicDuckTimer > 0 and (bgMusicDuckTimer / AUDIO.bgMusicDuckSeconds) or 0
  local duckGain = lerp(1, AUDIO.bgMusicDuckGain, duckT)

  if bgMusicFirstPass then
    if not bgMusic:isPlaying() then
      bgMusicFirstPass = false
      bgMusic:setLooping(true)
      bgMusic:play()
      bgMusicPrevPos = 0
    end
    bgMusic:setVolume(AUDIO.bgMusicVolume * duckGain)
    return
  end

  local duration = bgMusic:getDuration("seconds")
  if not duration or duration <= 0 then
    bgMusic:setVolume(AUDIO.bgMusicVolume * duckGain)
    return
  end

  local pos = bgMusic:tell("seconds")
  local remaining = duration - pos
  local fadeWindow = AUDIO.bgMusicLoopFadeSeconds
  local fadeOut = remaining < fadeWindow and (remaining / fadeWindow) or 1
  local fadeIn = pos < fadeWindow and (pos / fadeWindow) or 1
  local loopGain = clamp(math.min(fadeOut, fadeIn), 0, 1)
  bgMusic:setVolume(AUDIO.bgMusicVolume * loopGain * duckGain)
  bgMusicPrevPos = pos
end

function initClickFx()
  local ok, source = pcall(love.audio.newSource, Assets.audio.clickFx, "static")
  if not ok or not source then
    clickFx = nil
    return
  end
  clickFx = source
end

function initPerfectHitFx()
  local ok, source = pcall(love.audio.newSource, Assets.audio.perfectHitFx, "static")
  if not ok or not source then
    perfectHitFx = nil
    return
  end
  source:setVolume(AUDIO.perfectHitFxVolume)
  perfectHitFx = source
end

function initMissFx()
  local ok, source = pcall(love.audio.newSource, Assets.audio.missFx, "static")
  if not ok or not source then
    missFx = nil
    return
  end
  source:setVolume(AUDIO.missFxVolume)
  missFx = source
end

function initUnlockSkillFx()
  local ok, source = pcall(love.audio.newSource, Assets.audio.unlockSkillFx, "static")
  if not ok or not source then
    unlockSkillFx = nil
    return
  end
  source:setVolume(AUDIO.unlockSkillFxVolume)
  unlockSkillFx = source
end

playUnlockSkillFx = function()
  if not unlockSkillFx then
    return
  end
  local voice = unlockSkillFx:clone()
  voice:setPitch(lerp(AUDIO.unlockSkillFxPitchMin, AUDIO.unlockSkillFxPitchMax, love.math.random()))
  voice:setVolume(AUDIO.unlockSkillFxVolume)
  love.audio.play(voice)
  bgMusicDuckTimer = AUDIO.bgMusicDuckSeconds
end

function playClickFx(isClosing)
  if not clickFx then
    return
  end
  local voice = clickFx:clone()
  if isClosing then
    voice:setPitch(AUDIO.clickFxPitchClose)
    voice:setVolume(AUDIO.clickFxVolumeClose)
  else
    voice:setPitch(AUDIO.clickFxPitchOpen)
    voice:setVolume(AUDIO.clickFxVolumeOpen)
  end
  love.audio.play(voice)
end

function playMenuBuyClickFx()
  if not clickFx then
    return
  end
  local voice = clickFx:clone()
  local pitch = lerp(AUDIO.clickFxMenuPitchMin, AUDIO.clickFxMenuPitchMax, love.math.random())
  voice:setPitch(pitch)
  voice:setVolume(AUDIO.clickFxVolumeOpen)
  love.audio.play(voice)
end

function updateUpgradeFx(dt)
  for i = #perfectHitFxInstances, 1, -1 do
    local entry = perfectHitFxInstances[i]
    local source = entry.source
    if not source:isPlaying() then
      table.remove(perfectHitFxInstances, i)
    else
      entry.age = entry.age + dt
      local duration = math.max(0.0001, entry.duration or 0.0001)
      local t = clamp(entry.age / duration, 0, 1)
      if t >= 0.8 then
        local fadeT = clamp((t - 0.8) / 0.2, 0, 1)
        source:setVolume((entry.baseVolume or AUDIO.perfectHitFxVolume) * (1 - fadeT))
      else
        source:setVolume(entry.baseVolume or AUDIO.perfectHitFxVolume)
      end
    end
  end
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  uiFont = love.graphics.newFont(Assets.fonts.ui, WORLD.uiFontSize, "mono")
  uiFont:setFilter("nearest", "nearest")
  love.graphics.setFont(uiFont)
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("none")
  setBorderlessFullscreen(false)

  canvas = love.graphics.newCanvas(WORLD.gameW, WORLD.gameH)
  canvas:setFilter("nearest", "nearest")
  initSphereShader()
  initGravityWellShader()
  initBackgroundMusic()
  initClickFx()
  initPerfectHitFx()
  initMissFx()
  initUnlockSkillFx()
  persistence.totalShards = loadTotalShards()
  state.totalShards = persistence.totalShards
  initGameSystems()

  recomputeViewport()

  for _ = 1, 72 do
    table.insert(state.stars, {
      x = love.math.random(0, WORLD.gameW - 1),
      y = love.math.random(0, WORLD.gameH - 1),
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
  if scene == SCENE_SKILL_TREE then
    if key == "escape" or key == "k" then
      scene = SCENE_GAME
      skillTree.dragging = false
      playClickFx(true)
    elseif key == "r" then
      restartRun()
    end
    return
  end

  if key == "space" then
    if state.gameOver or state.collapseSequenceActive then
      return
    end
    tryTimedSingleMoonBoost()
    return
  elseif key == "r" then
    restartRun()
    return
  elseif key == "k" then
    scene = SCENE_SKILL_TREE
    skillTree.dragging = false
    playClickFx(false)
    return
  elseif key == "escape" then
    love.event.quit()
    return
  elseif key == "b" then
    setBorderlessFullscreen(not state.borderlessFullscreen)
  elseif key == "l" then
    toggleSphereShadeStyle()
  end
end

function love.wheelmoved(_, wy)
  if scene ~= SCENE_GAME then
    return
  end
  zoom = clamp(zoom + wy * 0.1, WORLD.zoomMin, WORLD.zoomMax)
end

function love.update(dt)
  dt = math.min(dt, 0.05)
  updateBackgroundMusic(dt)
  updateUpgradeFx(dt)
  state.time = state.time + dt
  state.planetBounceTime = math.max(0, state.planetBounceTime - dt)

  if scene == SCENE_SKILL_TREE then
    updateTimingFeedback(dt)
    state.screenShakeX = 0
    state.screenShakeY = 0
    return
  end

  if state.gameOver then
    updateBrokenMoon(dt)
    updateTimingFeedback(dt)
  elseif state.collapseSequenceActive then
    updateTimingFeedback(dt)
    state.collapseTimer = math.max(0, state.collapseTimer - dt)
    state.collapseFreezeTimer = math.max(0, (state.collapseFreezeTimer or 0) - dt)
    if (state.collapseFreezeTimer or 0) <= 0 then
      updateBrokenMoon(dt)
    end
    if state.collapseTimer <= 0 then
      completeRpmCollapse()
    end
  else
    updateSingleMoonTiming(dt)
    syncSingleMoonSpeed()
    if runtime.orbiters then
      runtime.orbiters:update(dt)
    end

    state.temporaryRpm, state.currentRpm = computeRpmBreakdown()
    state.maxRpmReached = math.max(state.maxRpmReached or 0, state.currentRpm or 0)
    if instabilityRatio() >= PROGRESSION.criticalInstabilityRatio then
      state.runCriticalInstabilitySeen = true
    end
    if state.runCriticalInstabilitySeen then
      state.maxRpmAfterCritical = math.max(state.maxRpmAfterCritical or 0, state.currentRpm or 0)
      if instabilityRatio() <= 0.60 and (state.maxRpmAfterCritical or 0) >= 100 then
        state.runRecoveredFromCritical = true
      end
    end
    evaluateActiveObjectives(false)
    updatePassiveInstability(dt)
    if (state.currentRpm or 0) >= SLICE.redlineRpm then
      state.redlineFlashTimer = math.max(state.redlineFlashTimer or 0, 0.06)
    end
  end
  updateInstabilityEffects(dt)
  updateOrbitGainFx(dt)
end

function love.mousepressed(x, y, button)
  if scene == SCENE_SKILL_TREE then
    if button ~= 1 then
      return
    end
    if ui.skillTreeBackBtn.visible and pointInRect(x, y, ui.skillTreeBackBtn) then
      scene = SCENE_GAME
      skillTree.dragging = false
      playClickFx(true)
      return
    end
    if ui.skillTreeRestartBtn.visible and pointInRect(x, y, ui.skillTreeRestartBtn) then
      restartRun()
      playMenuBuyClickFx()
      return
    end
    local uiScale = scale >= 1 and scale or 1
    local panel = skillTreePanelRect(uiScale)
    if not pointInRect(x, y, panel) then
      return
    end
    local hoveredNode = hoveredSkillTreeNode(x, y, uiScale, panel)
    if hoveredNode then
      if buySkillTreeNode(hoveredNode.id) then
        -- Unlock SFX is played by unlockSkillNode.
      else
        playClickFx(true)
      end
      return
    end
    skillTree.dragging = true
    return
  end

  if button ~= 1 then
    return
  end

  if state.gameOver then
    if ui.skillsBtn.visible and pointInRect(x, y, ui.skillsBtn) then
      scene = SCENE_SKILL_TREE
      skillTree.dragging = false
      playClickFx(false)
      return
    end
    if ui.restartBtn.visible and pointInRect(x, y, ui.restartBtn) then
      restartRun()
      playMenuBuyClickFx()
      return
    end
    return
  end

  if state.collapseSequenceActive then
    return
  end

  local gx, gy = toGameSpace(x, y)
  if gx < 0 or gy < 0 or gx > WORLD.gameW or gy > WORLD.gameH then
    return
  end

  local wx, wy = toWorldSpace(x, y)
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
        return
      end
    end
  end

  if state.selectedOrbiter then
    playClickFx(true)
  end
  state.selectedOrbiter = nil
end

function love.mousereleased(_, _, button)
  if button == 1 then
    skillTree.dragging = false
  end
end

function love.mousemoved(_, _, dx, dy)
  if scene == SCENE_SKILL_TREE and skillTree.dragging then
    skillTree.panX = skillTree.panX + dx
    skillTree.panY = skillTree.panY + dy
  end
end

function love.draw()
  love.graphics.setFont(uiFont)
  love.graphics.setCanvas(canvas)
  drawBackground()

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(zoom, zoom)
  love.graphics.translate(-cx, -cy)

  drawMoonOrbitIntro(false)
  drawSingleMoonTimingGhost(false)
  drawSelectedOrbit(false)

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
  drawSelectedOrbit(true)
  drawSingleMoonTimingGhost(true)

  for i = firstFront, #renderOrbiters do
    drawOrbiterByKind(renderOrbiters[i])
  end
  drawMoonOrbitIntro(true)
  drawTimingWorldFx()
  love.graphics.pop()

  drawOrbitGainFx()

  love.graphics.setCanvas()
  love.graphics.clear(palette.space)
  love.graphics.setColor(1, 1, 1, 1)
  local shakeX = scene == SCENE_GAME and (state.screenShakeX or 0) or 0
  local shakeY = scene == SCENE_GAME and (state.screenShakeY or 0) or 0
  local rippleActive, waveCenterR, waveHalfWidth, waveRadialStrength, waveSwirlStrength = activeGravityRippleParams()
  if gravityWellShader then
    local coreR = clamp((state.planetVisualRadius or BODY_VISUAL.planetRadius) / WORLD.gameH, 0.002, 0.45)
    local stress = instabilityStressBlend()
    local tier = instabilityTier()
    local missFlash = clamp((state.missFlashTimer or 0) / 0.18, 0, 1)
    local perfectFlash = clamp((state.perfectFlashTimer or 0) / 0.24, 0, 1)
    local pullPulse = smoothstep(0.5 + 0.5 * math.sin(state.time * (2.1 + 4.2 * stress + tier)))
    local stressBoost = stress * (0.22 + 0.24 * pullPulse) + missFlash * 0.26
    local reliefDamp = perfectFlash * 0.18
    local innerR = clamp(coreR * GAMEPLAY.gravityWellInnerScale, 0.001, coreR - 0.0005)
    local outerR = clamp(coreR * (GAMEPLAY.gravityWellRadiusScale + 0.32 * stress + 0.08 * missFlash), coreR + 0.01, 0.95)
    local radialStrength = GAMEPLAY.gravityWellRadialStrength * (1 + stressBoost - reliefDamp)
    local swirlStrength = GAMEPLAY.gravityWellSwirlStrength * (1 + stressBoost * 1.15 - reliefDamp)
    local prevShader = love.graphics.getShader()
    love.graphics.setShader(gravityWellShader)
    gravityWellShader:send("centerUv", {cx / WORLD.gameW, cy / WORLD.gameH})
    gravityWellShader:send("aspect", WORLD.gameW / WORLD.gameH)
    gravityWellShader:send("innerR", innerR)
    gravityWellShader:send("coreR", coreR)
    gravityWellShader:send("outerR", outerR)
    gravityWellShader:send("radialStrength", radialStrength)
    gravityWellShader:send("swirlStrength", swirlStrength)
    gravityWellShader:send("waveCenterR", rippleActive and waveCenterR or 0)
    gravityWellShader:send("waveHalfWidth", rippleActive and waveHalfWidth or 0)
    gravityWellShader:send("waveRadialStrength", rippleActive and waveRadialStrength or 0)
    gravityWellShader:send("waveSwirlStrength", rippleActive and waveSwirlStrength or 0)
    love.graphics.draw(canvas, offsetX + shakeX, offsetY + shakeY, 0, scale, scale)
    love.graphics.setShader(prevShader)
  else
    love.graphics.draw(canvas, offsetX + shakeX, offsetY + shakeY, 0, scale, scale)
  end
  drawDangerOverlay()

  love.graphics.setFont(getUiScreenFont())
  if scene == SCENE_SKILL_TREE then
    drawSkillTreeScene()
    return
  end

  ui.skillTreeBackBtn.visible = false
  ui.skillTreeRestartBtn.visible = false
  drawHud()
  drawGameOverOverlay()
end
