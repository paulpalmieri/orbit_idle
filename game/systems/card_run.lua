local CardRunSystem = {}
CardRunSystem.__index = CardRunSystem

local function shuffleInPlace(list)
  for i = #list, 2, -1 do
    local j = love.math.random(1, i)
    list[i], list[j] = list[j], list[i]
  end
end

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function smoothstep(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function smoothstepDerivative(t)
  t = clamp(t, 0, 1)
  return 6 * t * (1 - t)
end

function CardRunSystem.new(opts)
  opts = opts or {}
  local self = {
    state = assert(opts.state, "CardRunSystem requires state"),
    config = assert(opts.config, "CardRunSystem requires config"),
    orbiters = assert(opts.orbiters, "CardRunSystem requires orbiter callbacks"),
    getRunDeck = opts.getRunDeck,
    onCardPlayed = opts.onCardPlayed,
    onRunFinished = opts.onRunFinished,
    onPayout = opts.onPayout,
  }
  self.state.currency = math.max(0, math.floor(tonumber(self.state.currency) or 0))
  self.state.runRewardClaimed = self.state.runRewardClaimed == true
  self.state.nextBodyId = math.max(0, math.floor(tonumber(self.state.nextBodyId) or 0))
  return setmetatable(self, CardRunSystem)
end

function CardRunSystem:collectAllOrbiters()
  local pool = {}
  for _, megaPlanet in ipairs(self.state.megaPlanets or {}) do
    pool[#pool + 1] = megaPlanet
  end
  for _, planet in ipairs(self.state.planets or {}) do
    pool[#pool + 1] = planet
  end
  for _, moon in ipairs(self.state.moons or {}) do
    pool[#pool + 1] = moon
    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      pool[#pool + 1] = child
    end
  end
  for _, satellite in ipairs(self.state.satellites or {}) do
    pool[#pool + 1] = satellite
  end
  return pool
end

function CardRunSystem:isCardBody(orbiter)
  return orbiter and orbiter.cardBody == true
end

function CardRunSystem:isMoonBody(orbiter)
  return self:isCardBody(orbiter) and orbiter.orbitClass == "Moon"
end

function CardRunSystem:getBodies()
  local list = {}
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) then
      list[#list + 1] = orbiter
    end
  end
  return list
end

function CardRunSystem:getBodyCount()
  return #self:getBodies()
end

function CardRunSystem:bodyAttachmentStat(body, key)
  local total = 0
  local attachments = body.attachments or {}
  for i = 1, #attachments do
    total = total + math.max(0, math.floor(tonumber(attachments[i][key]) or 0))
  end
  return total
end

function CardRunSystem:effectiveBodyOpe(orbiter)
  if not self:isCardBody(orbiter) then
    return 0
  end
  local value = (orbiter.baseOpe or 0)
    + (orbiter.epochOpeBonus or 0)
    + (orbiter.thisEpochOpeBonus or 0)
    + self:bodyAttachmentStat(orbiter, "ope")
  return math.max(0, math.floor(value + 0.5))
end

function CardRunSystem:effectiveBodyYieldPerOrbit(orbiter)
  if not self:isCardBody(orbiter) then
    return 0
  end
  local value = (orbiter.baseYieldPerOrbit or 0)
    + (orbiter.epochYieldBonus or 0)
    + (orbiter.thisEpochYieldBonus or 0)
    + self:bodyAttachmentStat(orbiter, "yieldPerOrbit")
  return math.max(0, math.floor(value + 0.5))
end

function CardRunSystem:computeSystemOpe()
  local total = 0
  local bodies = self:getBodies()
  for i = 1, #bodies do
    total = total + self:effectiveBodyOpe(bodies[i])
  end
  return total
end

function CardRunSystem:triggerGravityPulse()
end

function CardRunSystem:countAnchors()
  return 0
end

function CardRunSystem:syncOrbiterSpeedsFromBodies()
end

function CardRunSystem:capacityForKind(kind)
  if kind == "moon" then
    return self.config.MAX_MOONS
  end
  if kind == "satellite" then
    return self.config.MAX_SATELLITES
  end
  if kind == "planet" then
    return self.config.MAX_PLANETS
  end
  return nil
end

function CardRunSystem:listForKind(kind)
  if kind == "moon" then
    return self.state.moons
  end
  if kind == "satellite" then
    return self.state.satellites
  end
  if kind == "planet" then
    return self.state.planets
  end
  return nil
end

function CardRunSystem:planningOmegaFor(orbiter)
  local baseLinear = tonumber(self.config.PLANNING_LINEAR_SPEED) or 8
  local radius = math.max(20, tonumber(orbiter.radius) or 20)
  local kindMul = 1
  if orbiter.kind == "satellite" or orbiter.kind == "moon-satellite" then
    kindMul = 1.25
  elseif orbiter.kind == "planet" then
    kindMul = 0.72
  end
  -- Keep planning motion aligned with trail direction (positive angular travel).
  return (baseLinear * kindMul) / radius
end

function CardRunSystem:updateOrbiterPositions()
  if not self.orbiters.updateOrbiterPosition then
    return
  end
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    self.orbiters.updateOrbiterPosition(orbiters[i])
  end
end

function CardRunSystem:updatePlanningMotion(dt)
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    local omega = self:planningOmegaFor(orbiter)
    orbiter.angle = (orbiter.angle or 0) + omega * dt
    orbiter.speed = math.abs(omega)
    if self.orbiters.updateOrbiterPosition then
      self.orbiters.updateOrbiterPosition(orbiter)
    end
  end
end

function CardRunSystem:refillDrawPileIfEmpty()
  if #self.state.drawPile > 0 or #self.state.discardPile == 0 then
    return
  end
  for i = 1, #self.state.discardPile do
    self.state.drawPile[#self.state.drawPile + 1] = self.state.discardPile[i]
  end
  for i = #self.state.discardPile, 1, -1 do
    self.state.discardPile[i] = nil
  end
  shuffleInPlace(self.state.drawPile)
end

function CardRunSystem:drawCards(count)
  for _ = 1, count do
    self:refillDrawPileIfEmpty()
    if #self.state.drawPile == 0 then
      return
    end
    local cardId = table.remove(self.state.drawPile)
    self.state.hand[#self.state.hand + 1] = cardId
  end
end

function CardRunSystem:discardCurrentHand()
  for i = #self.state.hand, 1, -1 do
    self.state.discardPile[#self.state.discardPile + 1] = self.state.hand[i]
    self.state.hand[i] = nil
  end
end

function CardRunSystem:isBodyCard(cardDef)
  return cardDef and cardDef.type == "body"
end

function CardRunSystem:isSatelliteCard(cardDef)
  return cardDef and cardDef.type == "satellite"
end

function CardRunSystem:isActionCard(cardDef)
  return cardDef and cardDef.type == "action"
end

function CardRunSystem:classDefForCard(cardDef)
  local classDefaults = self.config.ORBIT_CLASS_DEFAULTS or {}
  return classDefaults[(cardDef and cardDef.orbitClass) or ""]
end

function CardRunSystem:kindForCard(cardDef)
  local classDef = self:classDefForCard(cardDef)
  if not classDef then
    return nil
  end
  return classDef.kind or "moon"
end

function CardRunSystem:canSpawnBody(cardDef)
  if not self:isBodyCard(cardDef) then
    return false
  end
  local kind = self:kindForCard(cardDef)
  local list = self:listForKind(kind)
  if not list then
    return false
  end
  local spawnCount = math.max(1, math.floor(tonumber(cardDef.spawnCount) or 1))
  local cap = self:capacityForKind(kind)
  if cap and (#list + spawnCount) > cap then
    return false
  end
  return true
end

function CardRunSystem:isBodyEligibleForClassTarget(orbiter, classes)
  if not self:isCardBody(orbiter) then
    return false
  end
  if not classes or #classes == 0 then
    return true
  end
  for i = 1, #classes do
    if orbiter.orbitClass == classes[i] then
      return true
    end
  end
  return false
end

function CardRunSystem:pickBodyTarget(classes, excludeBody)
  local selected = self.state.selectedOrbiter
  if selected and selected ~= excludeBody and self:isBodyEligibleForClassTarget(selected, classes) then
    return selected
  end

  local bodies = self:getBodies()
  for i = #bodies, 1, -1 do
    local body = bodies[i]
    if body ~= excludeBody and self:isBodyEligibleForClassTarget(body, classes) then
      return body
    end
  end

  return nil
end

function CardRunSystem:canAttachSatellite(cardDef)
  if not self:isSatelliteCard(cardDef) then
    return false
  end
  if #self.state.satellites >= (self.config.MAX_SATELLITES or math.huge) then
    return false
  end
  local target = self:pickBodyTarget(cardDef.targetClasses)
  return target ~= nil
end

function CardRunSystem:canResolveCard(cardDef)
  if not cardDef then
    return false
  end
  if self.state.phase ~= "planning" or self.state.runComplete then
    return false
  end
  if self:isBodyCard(cardDef) then
    return self:canSpawnBody(cardDef)
  end
  if self:isSatelliteCard(cardDef) then
    return self:canAttachSatellite(cardDef)
  end
  if self:isActionCard(cardDef) then
    local effect = cardDef.effect or {}
    if effect.type == "grant_this_epoch_ope" then
      return self:pickBodyTarget(nil) ~= nil
    end
  end
  return true
end

function CardRunSystem:currentCardCost(cardDef)
  if not cardDef then
    return 0
  end
  local baseCost = math.max(0, math.floor(tonumber(cardDef.cost) or 0))
  if self:isSatelliteCard(cardDef) and (self.state.nextSatelliteCostFree or 0) > 0 then
    return 0
  end
  return baseCost
end

function CardRunSystem:getCardHeatDelta(cardDef)
  if not cardDef then
    return 0
  end

  local heatGain = math.max(0, math.floor(tonumber(cardDef.heat) or 0))
  local effect = cardDef.effect or {}
  local vent = 0
  if effect.type == "vent_and_draw" then
    vent = math.max(0, math.floor(tonumber(effect.vent) or 0))
  end

  local afterVent = math.max(0, (self.state.heat or 0) - vent)
  local heatCap = self.state.heatCap or self.config.HEAT_CAP
  local finalHeat = math.min(heatCap, afterVent + heatGain)
  return finalHeat - (self.state.heat or 0)
end

function CardRunSystem:spawnBodyForKind(kind)
  if kind == "moon" then
    local before = #self.state.moons
    if not self.orbiters.addMoon(nil) then
      return nil
    end
    return self.state.moons[before + 1]
  end
  if kind == "planet" then
    local before = #self.state.planets
    if not self.orbiters.addPlanet() then
      return nil
    end
    return self.state.planets[before + 1]
  end
  if kind == "satellite" then
    local before = #self.state.satellites
    if not self.orbiters.addSatellite() then
      return nil
    end
    return self.state.satellites[before + 1]
  end
  return nil
end

function CardRunSystem:nextBodyId()
  self.state.nextBodyId = (self.state.nextBodyId or 0) + 1
  return self.state.nextBodyId
end

function CardRunSystem:configureBodyVisual(orbiter, cardDef, classDef, spawnIndex, spawnCount)
  local radiusProfile = cardDef.radiusProfile or {}
  local flatnessProfile = cardDef.flatnessProfile or {}
  local sizeProfile = cardDef.sizeProfile or {}

  local radiusMul = tonumber(radiusProfile.mul) or 1
  local flatnessMul = tonumber(flatnessProfile.mul) or 1
  local sizeMul = tonumber(sizeProfile.mul) or 1

  local classCount = 0
  local bodies = self:getBodies()
  for i = 1, #bodies do
    if bodies[i].orbitClass == cardDef.orbitClass then
      classCount = classCount + 1
    end
  end

  local radius = (classDef.baseRadius + classCount * classDef.radiusStep) * radiusMul
  radius = radius + (love.math.random() * 2 - 1) * (classDef.radiusJitter or 0)

  local flatten = classDef.flatten * flatnessMul
  flatten = flatten + (love.math.random() * 2 - 1) * (classDef.flattenJitter or 0)
  flatten = clamp(flatten, 0.45, 0.98)

  local size = classDef.size * sizeMul + (love.math.random() * 2 - 1) * (classDef.sizeJitter or 0)
  size = math.max(1.6, size)

  orbiter.cardBody = true
  orbiter.cardType = "body"
  orbiter.bodyKind = cardDef.id
  orbiter.cardName = cardDef.name
  orbiter.orbitClass = cardDef.orbitClass
  orbiter.bodyClass = cardDef.bodyClass or cardDef.orbitClass
  orbiter.baseOpe = math.max(0, math.floor(tonumber(cardDef.ope) or 0))
  orbiter.baseYieldPerOrbit = math.max(0, math.floor(tonumber(cardDef.yieldPerOrbit) or 0))
  orbiter.baseHeat = math.max(0, math.floor(tonumber(cardDef.heat) or 0))
  orbiter.epochOpeBonus = math.max(0, math.floor(tonumber(orbiter.epochOpeBonus) or 0))
  orbiter.thisEpochOpeBonus = 0
  orbiter.nextEpochOpeBonus = math.max(0, math.floor(tonumber(orbiter.nextEpochOpeBonus) or 0))
  orbiter.epochYieldBonus = math.max(0, math.floor(tonumber(orbiter.epochYieldBonus) or 0))
  orbiter.thisEpochYieldBonus = 0
  orbiter.nextEpochYieldBonus = math.max(0, math.floor(tonumber(orbiter.nextEpochYieldBonus) or 0))
  orbiter.attachments = orbiter.attachments or {}
  orbiter.epochPaid = false
  orbiter.bodyId = self:nextBodyId()

  local effect = cardDef.effect or {}
  if effect.type == "runner_final_orbit_next_epoch_ope" then
    orbiter.finalOrbitNextEpochOpe = math.max(0, math.floor(tonumber(effect.amount) or 0))
  else
    orbiter.finalOrbitNextEpochOpe = 0
  end

  orbiter.radius = radius
  orbiter.flatten = flatten
  orbiter.depthScale = classDef.depthScale
  orbiter.visualRadius = size
  orbiter.visualSegments = math.max(12, math.floor(14 + size * 0.95))
  orbiter.visualRole = cardDef.bodyClass or cardDef.orbitClass
  orbiter.spawnShape = {
    radius = radius,
    flatness = flatten,
    size = size,
  }

  if spawnCount > 1 then
    local phase = (spawnIndex - 1) / spawnCount
    orbiter.angle = love.math.random() * self.config.TWO_PI + phase * self.config.TWO_PI
    if spawnCount == 2 and spawnIndex == 2 then
      orbiter.plane = (orbiter.plane or 0) + math.pi
    end
  end

  if self.orbiters.updateOrbiterPosition then
    self.orbiters.updateOrbiterPosition(orbiter)
  end
end

function CardRunSystem:spawnBodiesFromCard(cardDef)
  local classDef = self:classDefForCard(cardDef)
  if not classDef then
    return nil
  end

  local kind = classDef.kind or "moon"
  local spawnCount = math.max(1, math.floor(tonumber(cardDef.spawnCount) or 1))
  local spawned = {}

  for spawnIndex = 1, spawnCount do
    local orbiter = self:spawnBodyForKind(kind)
    if not orbiter then
      return nil
    end
    self:configureBodyVisual(orbiter, cardDef, classDef, spawnIndex, spawnCount)
    spawned[#spawned + 1] = orbiter
  end

  return spawned
end

function CardRunSystem:createAttachmentVisual(host, attachmentDef)
  local before = #self.state.satellites
  if not self.orbiters.addSatellite() then
    return nil
  end
  local satellite = self.state.satellites[before + 1]
  if not satellite then
    return nil
  end

  local countOnHost = #(host.attachedVisuals or {})
  local radius = 9 + countOnHost * 2.5
  satellite.parentOrbiter = host
  satellite.cardBody = false
  satellite.kind = "satellite"
  satellite.cardType = "satellite"
  satellite.attachmentClass = attachmentDef.satelliteClass or "satellite"
  satellite.visualRole = "Satellite"
  satellite.radius = radius
  satellite.flatten = clamp((host.flatten or 0.85) * 0.96, 0.45, 0.98)
  satellite.depthScale = 0.22
  satellite.zBase = (host.zBase or 0) + 0.02
  satellite.visualRadius = 3.2
  satellite.visualSegments = 12
  satellite.spawnShape = {
    radius = radius,
    flatness = satellite.flatten,
    size = satellite.visualRadius,
  }
  satellite.angle = (host.angle or 0) + love.math.random() * self.config.TWO_PI

  host.attachedVisuals = host.attachedVisuals or {}
  host.attachedVisuals[#host.attachedVisuals + 1] = satellite

  if self.orbiters.updateOrbiterPosition then
    self.orbiters.updateOrbiterPosition(satellite)
  end

  return satellite
end

function CardRunSystem:attachSatelliteToBody(cardDef, multiplier)
  local target = self:pickBodyTarget(cardDef.targetClasses)
  if not target then
    return false
  end

  local effect = cardDef.effect or {}
  local amountMul = math.max(1, math.floor(tonumber(multiplier) or 1))
  local attachment = {
    cardId = cardDef.id,
    name = cardDef.name,
    satelliteClass = effect.satelliteClass,
    ope = math.max(0, math.floor(tonumber(effect.ope) or 0)) * amountMul,
    yieldPerOrbit = math.max(0, math.floor(tonumber(effect.yieldPerOrbit) or 0)) * amountMul,
    firstPayoutYield = math.max(0, math.floor(tonumber(effect.firstPayoutYield) or 0)) * amountMul,
    finalOrbitHeatDelta = math.floor(tonumber(effect.finalOrbitHeatDelta) or 0) * amountMul,
  }
  target.attachments = target.attachments or {}
  target.attachments[#target.attachments + 1] = attachment

  self:createAttachmentVisual(target, attachment)
  return true
end

function CardRunSystem:addHeat(amount)
  local heatGain = math.max(0, math.floor(tonumber(amount) or 0))
  if heatGain <= 0 then
    return
  end

  self.state.heat = (self.state.heat or 0) + heatGain
  local heatCap = self.state.heatCap or self.config.HEAT_CAP
  if self.state.heat >= heatCap then
    self.state.heat = heatCap
    self:finishRun("collapse")
  end
end

function CardRunSystem:ventHeat(amount)
  local ventAmount = math.max(0, math.floor(tonumber(amount) or 0))
  if ventAmount <= 0 then
    return
  end
  self.state.heat = math.max(0, (self.state.heat or 0) - ventAmount)
end

function CardRunSystem:applyActionCard(cardDef)
  local effect = cardDef.effect or {}

  if effect.type == "vent_and_draw" then
    self:ventHeat(effect.vent)
    self:drawCards(math.max(0, math.floor(tonumber(effect.draw) or 0)))
    return true
  end

  if effect.type == "next_body_or_satellite_twice" then
    self.state.nextBodyOrSatelliteTwice = math.max(0, math.floor(tonumber(self.state.nextBodyOrSatelliteTwice) or 0)) + 1
    return true
  end

  if effect.type == "grant_this_epoch_ope" then
    local target = self:pickBodyTarget(nil)
    if not target then
      return false
    end
    target.thisEpochOpeBonus = (target.thisEpochOpeBonus or 0) + math.max(0, math.floor(tonumber(effect.amount) or 0))
    return true
  end

  if effect.type == "draw_and_free_satellite" then
    self:drawCards(math.max(0, math.floor(tonumber(effect.draw) or 0)))
    self.state.nextSatelliteCostFree = math.max(0, math.floor(tonumber(self.state.nextSatelliteCostFree) or 0)) + 1
    return true
  end

  if effect.type == "draw_cards" then
    self:drawCards(math.max(0, math.floor(tonumber(effect.amount) or 0)))
    return true
  end

  return true
end

function CardRunSystem:applyCard(cardDef, usedFreeSatelliteCost)
  if not cardDef then
    return false
  end

  local heatGain = math.max(0, math.floor(tonumber(cardDef.heat) or 0))
  local success = true

  if self:isBodyCard(cardDef) then
    local copies = 1
    if (self.state.nextBodyOrSatelliteTwice or 0) > 0 then
      copies = 2
      self.state.nextBodyOrSatelliteTwice = self.state.nextBodyOrSatelliteTwice - 1
    end

    for _ = 1, copies do
      if not self:canSpawnBody(cardDef) then
        success = false
        break
      end
      local spawned = self:spawnBodiesFromCard(cardDef)
      if not spawned then
        success = false
        break
      end
    end
  elseif self:isSatelliteCard(cardDef) then
    local multiplier = 1
    if (self.state.nextBodyOrSatelliteTwice or 0) > 0 then
      multiplier = 2
      self.state.nextBodyOrSatelliteTwice = self.state.nextBodyOrSatelliteTwice - 1
    end

    success = self:attachSatelliteToBody(cardDef, multiplier)
    if success and usedFreeSatelliteCost then
      self.state.nextSatelliteCostFree = math.max(0, (self.state.nextSatelliteCostFree or 0) - 1)
    end
  elseif self:isActionCard(cardDef) then
    success = self:applyActionCard(cardDef)
  end

  if not success then
    return false
  end

  self:addHeat(heatGain)
  return true
end

function CardRunSystem:playCard(handIndex)
  if self.state.runComplete or self.state.phase ~= "planning" then
    return false
  end

  local cardId = self.state.hand[handIndex]
  if not cardId then
    return false
  end
  local cardDef = self.config.CARD_DEFS[cardId]
  if not cardDef then
    return false
  end

  if not self:canResolveCard(cardDef) then
    return false
  end

  local usedFreeSatelliteCost = self:isSatelliteCard(cardDef) and ((self.state.nextSatelliteCostFree or 0) > 0)
  local effectiveCost = self:currentCardCost(cardDef)
  if (self.state.energy or 0) < effectiveCost then
    return false
  end

  self.state.energy = self.state.energy - effectiveCost
  if not self:applyCard(cardDef, usedFreeSatelliteCost) then
    self.state.energy = self.state.energy + effectiveCost
    return false
  end

  table.remove(self.state.hand, handIndex)
  self.state.discardPile[#self.state.discardPile + 1] = cardId

  if self.onCardPlayed then
    self.onCardPlayed(cardDef)
  end

  return true
end

function CardRunSystem:startEpoch(epochNumber)
  self.state.epoch = epochNumber
  self.state.energy = self.config.EPOCH_ENERGY
  self.state.phase = "planning"
  self.state.phaseTimer = 0
  self.state.inputLocked = false

  local bodies = self:getBodies()
  for i = 1, #bodies do
    local body = bodies[i]
    body.thisEpochOpeBonus = 0
    body.thisEpochYieldBonus = 0
    body.epochOpeBonus = math.max(0, math.floor(tonumber(body.nextEpochOpeBonus) or 0))
    body.epochYieldBonus = math.max(0, math.floor(tonumber(body.nextEpochYieldBonus) or 0))
    body.nextEpochOpeBonus = 0
    body.nextEpochYieldBonus = 0
    body.epochPaid = false
  end

  self.state.nextBodyOrSatelliteTwice = 0
  self.state.nextSatelliteCostFree = 0

  self:discardCurrentHand()
  self:drawCards(self.config.STARTING_HAND_SIZE)
end

function CardRunSystem:buildSimulationPlan()
  local events = {}
  local entries = {}
  local bodies = self:getBodies()

  for i = 1, #bodies do
    local body = bodies[i]
    local cycles = self:effectiveBodyOpe(body)
    local entry = {
      body = body,
      startAngle = body.angle or 0,
      deltaAngle = self.config.TWO_PI * cycles,
      cycles = cycles,
    }
    entries[#entries + 1] = entry

    body.epochPaid = false

    if cycles > 0 then
      for orbitIndex = 1, cycles do
        events[#events + 1] = {
          body = body,
          progress = orbitIndex / cycles,
          orbitIndex = orbitIndex,
          isFinalOrbit = orbitIndex == cycles,
        }
      end
    end
  end

  table.sort(events, function(a, b)
    if a.progress == b.progress then
      return (a.body.bodyId or 0) < (b.body.bodyId or 0)
    end
    return a.progress < b.progress
  end)

  self.state.simulationEntries = entries
  self.state.simulationEvents = events
  self.state.simulationEventIndex = 1
  self.state.simulationProgress = 0
end

function CardRunSystem:applyFinalOrbitTriggers(body)
  if not body then
    return
  end

  local finalOrbitNextEpochOpe = math.max(0, math.floor(tonumber(body.finalOrbitNextEpochOpe) or 0))
  if finalOrbitNextEpochOpe > 0 then
    local target = self:pickBodyTarget(nil, body)
    if target then
      target.nextEpochOpeBonus = (target.nextEpochOpeBonus or 0) + finalOrbitNextEpochOpe
    end
  end

  local attachments = body.attachments or {}
  for i = 1, #attachments do
    local heatDelta = math.floor(tonumber(attachments[i].finalOrbitHeatDelta) or 0)
    if heatDelta < 0 then
      self:ventHeat(-heatDelta)
    elseif heatDelta > 0 then
      self:addHeat(heatDelta)
    end
  end
end

function CardRunSystem:resolveSimulationEvent(event)
  local body = event.body
  if not body then
    return
  end

  local payout = self:effectiveBodyYieldPerOrbit(body)
  if not body.epochPaid then
    payout = payout + self:bodyAttachmentStat(body, "firstPayoutYield")
    body.epochPaid = true
  end

  payout = math.max(0, math.floor(payout + 0.5))
  if payout > 0 then
    self.state.points = math.max(0, math.floor((self.state.points or 0) + payout))
    self.state.rewardPoints = self.state.points

    if self.onPayout then
      self.onPayout(body, payout, event.isFinalOrbit)
    end
  end

  if event.isFinalOrbit then
    self:applyFinalOrbitTriggers(body)
  end
end

function CardRunSystem:updateSimulationMotion(dt, progress, t)
  local simSet = {}
  local entries = self.state.simulationEntries or {}
  for i = 1, #entries do
    local entry = entries[i]
    simSet[entry.body] = entry
  end

  local speedScale = smoothstep(t)
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    local entry = simSet[orbiter]

    if entry then
      orbiter.angle = entry.startAngle + entry.deltaAngle * progress
      local derivative = smoothstepDerivative(t)
      local duration = math.max(0.001, tonumber(self.config.EPOCH_SIMULATION_DURATION) or 3.2)
      orbiter.speed = math.abs(entry.deltaAngle * derivative / duration)
    else
      local omega = self:planningOmegaFor(orbiter) * (1.5 + 2.2 * speedScale)
      orbiter.angle = (orbiter.angle or 0) + omega * dt
      orbiter.speed = math.abs(omega)
    end

    if self.orbiters.updateOrbiterPosition then
      self.orbiters.updateOrbiterPosition(orbiter)
    end
  end
end

function CardRunSystem:endEpoch()
  if self.state.runComplete or self.state.phase ~= "planning" then
    return false
  end

  self.state.phase = "simulating"
  self.state.phaseTimer = 0
  self.state.inputLocked = true
  self:buildSimulationPlan()
  return true
end

function CardRunSystem:finishRun(outcome)
  if self.state.runComplete then
    return
  end

  self.state.runComplete = true
  self.state.runOutcome = outcome
  self.state.runWon = outcome ~= "collapse"
  self.state.phase = "run_complete"
  self.state.inputLocked = false

  self.state.rewardPoints = math.max(0, math.floor(tonumber(self.state.points) or 0))

  if not self.state.runRewardClaimed then
    self.state.currency = (self.state.currency or 0) + self.state.rewardPoints
    self.state.runRewardClaimed = true
  end

  if self.onRunFinished then
    self.onRunFinished(outcome, self.state.rewardPoints)
  end
end

function CardRunSystem:updateSimulation(dt)
  local duration = math.max(0.001, tonumber(self.config.EPOCH_SIMULATION_DURATION) or 3.2)
  self.state.phaseTimer = (self.state.phaseTimer or 0) + dt

  local t = clamp(self.state.phaseTimer / duration, 0, 1)
  local progress = smoothstep(t)
  local prevProgress = self.state.simulationProgress or 0
  self.state.simulationProgress = progress

  self:updateSimulationMotion(dt, progress, t)

  local events = self.state.simulationEvents or {}
  local idx = self.state.simulationEventIndex or 1
  while idx <= #events do
    local event = events[idx]
    if event.progress > progress + 1e-6 then
      break
    end
    self:resolveSimulationEvent(event)
    idx = idx + 1
  end
  self.state.simulationEventIndex = idx

  if self.state.phaseTimer >= duration then
    while self.state.simulationEventIndex <= #events do
      self:resolveSimulationEvent(events[self.state.simulationEventIndex])
      self.state.simulationEventIndex = self.state.simulationEventIndex + 1
    end

    self.state.phase = "settling"
    self.state.phaseTimer = 0
  elseif progress < prevProgress then
    self.state.simulationProgress = prevProgress
  end
end

function CardRunSystem:updateSettling(dt)
  local duration = math.max(0.001, tonumber(self.config.EPOCH_SETTLE_DURATION) or 0.65)
  self.state.phaseTimer = (self.state.phaseTimer or 0) + dt

  local t = clamp(self.state.phaseTimer / duration, 0, 1)
  local settleBlend = 1 - smoothstep(t)

  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    local omega = self:planningOmegaFor(orbiter) * (1 + 1.8 * settleBlend)
    orbiter.angle = (orbiter.angle or 0) + omega * dt
    orbiter.speed = math.abs(omega)
    if self.orbiters.updateOrbiterPosition then
      self.orbiters.updateOrbiterPosition(orbiter)
    end
  end

  if self.state.phaseTimer >= duration then
    local nextEpoch = (self.state.epoch or 1) + 1
    if nextEpoch > (self.state.maxEpochs or self.config.MAX_EPOCHS) then
      self:finishRun("completed")
      return
    end

    self:startEpoch(nextEpoch)
  end
end

function CardRunSystem:update(dt)
  if self.state.runComplete then
    self:updatePlanningMotion(dt)
    return
  end

  if self.state.phase == "planning" then
    self:updatePlanningMotion(dt)
    return
  end

  if self.state.phase == "simulating" then
    self:updateSimulation(dt)
    return
  end

  if self.state.phase == "settling" then
    self:updateSettling(dt)
    return
  end

  self:updatePlanningMotion(dt)
end

function CardRunSystem:startCardRun()
  self.state.megaPlanets = {}
  self.state.planets = {}
  self.state.moons = {}
  self.state.satellites = {}
  self.state.renderOrbiters = {}
  self.state.nextRenderOrder = 0
  self.state.selectedOrbiter = nil
  self.state.selectedLightSource = false
  self.state.hand = {}
  self.state.drawPile = {}
  self.state.discardPile = {}
  self.state.cardHoverLift = {}
  self.state.speedWaveRipples = {}

  local runDeck = self.config.STARTING_DECK
  if self.getRunDeck then
    runDeck = self.getRunDeck() or runDeck
  end

  for i = 1, #runDeck do
    self.state.drawPile[#self.state.drawPile + 1] = runDeck[i]
  end
  shuffleInPlace(self.state.drawPile)

  self.state.maxEpochs = self.config.MAX_EPOCHS
  self.state.heat = 0
  self.state.heatCap = self.config.HEAT_CAP
  self.state.points = 0
  self.state.rewardPoints = 0
  self.state.runOutcome = ""
  self.state.runComplete = false
  self.state.runWon = false
  self.state.runRewardClaimed = false
  self.state.inputLocked = false

  self.state.phase = "planning"
  self.state.phaseTimer = 0
  self.state.simulationEntries = {}
  self.state.simulationEvents = {}
  self.state.simulationEventIndex = 1
  self.state.simulationProgress = 0
  self.state.nextBodyOrSatelliteTwice = 0
  self.state.nextSatelliteCostFree = 0

  self:startEpoch(1)
end

return CardRunSystem
