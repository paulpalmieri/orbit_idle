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

function CardRunSystem.new(opts)
  opts = opts or {}
  local self = {
    state = assert(opts.state, "CardRunSystem requires state"),
    config = assert(opts.config, "CardRunSystem requires config"),
    orbiters = assert(opts.orbiters, "CardRunSystem requires orbiter callbacks"),
    getRunDeck = opts.getRunDeck,
    onCardPlayed = opts.onCardPlayed,
    onRunFinished = opts.onRunFinished,
  }
  self.state.runRewardClaimed = self.state.runRewardClaimed == true
  self.state.currency = math.max(0, math.floor(tonumber(self.state.currency) or 0))
  return setmetatable(self, CardRunSystem)
end

function CardRunSystem:collectAllOrbiters()
  local pool = {}
  for _, megaPlanet in ipairs(self.state.megaPlanets) do
    pool[#pool + 1] = megaPlanet
  end
  for _, planet in ipairs(self.state.planets) do
    pool[#pool + 1] = planet
  end
  for _, moon in ipairs(self.state.moons) do
    pool[#pool + 1] = moon
    local childSatellites = moon.childSatellites or {}
    for _, child in ipairs(childSatellites) do
      pool[#pool + 1] = child
    end
  end
  for _, satellite in ipairs(self.state.satellites) do
    pool[#pool + 1] = satellite
  end
  return pool
end

function CardRunSystem:isCardBody(orbiter)
  return orbiter and orbiter.cardBody == true
end

function CardRunSystem:isMoonBody(orbiter)
  return self:isCardBody(orbiter)
end

function CardRunSystem:getBodyCount()
  local count = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    if self:isCardBody(orbiters[i]) then
      count = count + 1
    end
  end
  return count
end

function CardRunSystem:countMoonBodies()
  local count = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) and orbiter.orbitClass == "Moon" then
      count = count + 1
    end
  end
  return count
end

function CardRunSystem:countBodiesByClass(orbitClass)
  local count = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) and orbiter.orbitClass == orbitClass then
      count = count + 1
    end
  end
  return count
end

function CardRunSystem:countAnchors()
  local count = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) and orbiter.bodyKind == "anchor" then
      count = count + 1
    end
  end
  return count
end

function CardRunSystem:effectiveBodyRpm(orbiter)
  if not self:isCardBody(orbiter) then
    return 0
  end
  local rpm = (orbiter.baseRpm or 0)
    + (orbiter.runRpmBonus or 0)
    + (self.state.globalRunRpmBuff or 0)
    + (self.state.globalTurnRpmBuff or 0)
    + (orbiter.turnRpmBonus or 0)
  return math.max(0, rpm)
end

function CardRunSystem:getHandRpmBonus(handIndex)
  local handBonuses = self.state.handRpmBonus or {}
  return math.max(0, math.floor(tonumber(handBonuses[handIndex]) or 0))
end

function CardRunSystem:getCardRpmBonus(cardDef, handIndex)
  if not cardDef then
    return 0
  end
  local bonus = self:getHandRpmBonus(handIndex)
  if self:isBodyCard(cardDef) then
    bonus = bonus + math.max(0, math.floor(tonumber(self.state.nextBodyRpmBonus) or 0))
  end
  return bonus
end

function CardRunSystem:getCardHeatDelta(cardDef)
  if not cardDef then
    return 0
  end

  local heatGain = math.max(0, math.floor(tonumber(cardDef.heat) or 0))
  local vent = 0
  local effect = cardDef.effect or {}

  if effect.type == "vent" then
    vent = math.max(0, math.floor(tonumber(effect.amount) or 0))
  end

  if self:isBodyCard(cardDef) then
    local reduction = math.max(0, math.floor(tonumber(self.state.nextBodyHeatReduction) or 0))
    if reduction > 0 then
      heatGain = math.max(0, heatGain - reduction)
    end
  end

  local afterVent = math.max(0, (self.state.heat or 0) - vent)
  local heatCap = self.state.heatCap or self.config.HEAT_CAP
  local finalHeat = math.min(heatCap, afterVent + heatGain)
  return finalHeat - (self.state.heat or 0)
end

function CardRunSystem:syncOrbiterSpeedsFromBodies()
  local orbiters = self:collectAllOrbiters()
  local classDefaults = self.config.ORBIT_CLASS_DEFAULTS or {}
  local globalFloor = self.config.MIN_BODY_VISUAL_RPM or 1.8

  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) then
      local effectiveRpm = self:effectiveBodyRpm(orbiter)
      local classDef = classDefaults[orbiter.orbitClass or ""] or {}
      local speedMul = orbiter.speedMultiplier or classDef.speedMultiplier or 1
      local minVisualRpm = math.max(globalFloor, orbiter.minVisualRpm or classDef.minVisualRpm or globalFloor)
      local visualRpm = math.max(minVisualRpm, effectiveRpm * speedMul)
      orbiter.boardRpm = effectiveRpm
      orbiter.visualRpm = visualRpm
      orbiter.speed = visualRpm * self.config.RPM_TO_RAD_PER_SECOND
    end
  end
end

function CardRunSystem:computeTotalRpm()
  local total = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    total = total + self:effectiveBodyRpm(orbiters[i])
  end
  return total
end

function CardRunSystem:updateHighestRpm()
  local current = math.floor(self:computeTotalRpm() + 0.5)
  if current > (self.state.highestRpm or 0) then
    self.state.highestRpm = current
  end
  return current
end

function CardRunSystem:triggerGravityPulse()
  self.state.speedWaveRipples[#self.state.speedWaveRipples + 1] = {
    age = 0,
    life = self.config.SPEED_WAVE_RIPPLE_LIFETIME,
  }
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
    self.state.handRpmBonus[#self.state.handRpmBonus + 1] = 0
  end
end

function CardRunSystem:discardCurrentHand()
  for i = #self.state.hand, 1, -1 do
    self.state.discardPile[#self.state.discardPile + 1] = self.state.hand[i]
    self.state.hand[i] = nil
    self.state.handRpmBonus[i] = nil
  end
end

function CardRunSystem:clearTurnBodyBonuses()
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) then
      orbiter.turnRpmBonus = 0
    end
  end
end

function CardRunSystem:resetTurnModifiers()
  self.state.globalTurnRpmBuff = 0
  self.state.nextBodyRpmBonus = 0
  self.state.nextBodyHeatReduction = 0
  self:clearTurnBodyBonuses()
end

function CardRunSystem:finishRun(outcome)
  self.state.runComplete = true
  self.state.runOutcome = outcome
  self.state.runWon = outcome ~= "collapse" and self.state.highestRpm >= self.state.objectiveRpm
  self.state.rewardRpm = self.state.highestRpm
  if not self.state.runRewardClaimed then
    self.state.currency = self.state.currency + self.state.rewardRpm
    self.state.runRewardClaimed = true
  end
  if self.onRunFinished then
    self.onRunFinished(outcome, self.state.rewardRpm)
  end
end

function CardRunSystem:ventHeat(amount)
  local ventAmount = math.max(0, math.floor(tonumber(amount) or 0))
  if ventAmount <= 0 then
    return
  end
  self.state.heat = math.max(0, self.state.heat - ventAmount)
end

function CardRunSystem:addHeat(amount)
  local heatGain = math.max(0, math.floor(tonumber(amount) or 0))
  if heatGain <= 0 then
    return
  end
  self.state.heat = self.state.heat + heatGain
  if self.state.heat >= self.state.heatCap then
    self.state.heat = self.state.heatCap
    self:updateHighestRpm()
    self:finishRun("collapse")
  end
end

function CardRunSystem:isBodyCard(cardDef)
  if not cardDef then
    return false
  end
  if not cardDef.orbitClass then
    return false
  end
  local count = math.floor(tonumber(cardDef.spawnCount) or 1)
  if count <= 0 then
    return false
  end
  return true
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

function CardRunSystem:canSpawnBody(cardDef)
  if not cardDef then
    return false
  end

  local classDefaults = self.config.ORBIT_CLASS_DEFAULTS or {}
  local classDef = classDefaults[cardDef.orbitClass or ""]
  if not classDef then
    return false
  end

  local kind = classDef.kind or "moon"
  local spawnCount = math.max(1, math.floor(tonumber(cardDef.spawnCount) or 1))
  local list = self:listForKind(kind)
  if not list then
    return false
  end

  local cap = self:capacityForKind(kind)
  if cap and (#list + spawnCount) > cap then
    return false
  end

  return true
end

function CardRunSystem:canResolveCard(cardDef)
  if not cardDef then
    return false
  end
  if self:isBodyCard(cardDef) and not self:canSpawnBody(cardDef) then
    return false
  end
  return true
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

function CardRunSystem:configureBodyVisual(orbiter, cardDef, classDef, spawnIndex, spawnCount, rpmBonus)
  local classCount = self:countBodiesByClass(cardDef.orbitClass)

  local radiusProfile = cardDef.radiusProfile or {}
  local flatnessProfile = cardDef.flatnessProfile or {}
  local sizeProfile = cardDef.sizeProfile or {}

  local radiusMul = tonumber(radiusProfile.mul) or 1
  local flatnessMul = tonumber(flatnessProfile.mul) or 1
  local sizeMul = tonumber(sizeProfile.mul) or 1

  local radius = (classDef.baseRadius + classCount * classDef.radiusStep) * radiusMul
  radius = radius + (love.math.random() * 2 - 1) * (classDef.radiusJitter or 0)

  local flatten = classDef.flatten * flatnessMul
  flatten = flatten + (love.math.random() * 2 - 1) * (classDef.flattenJitter or 0)
  flatten = clamp(flatten, 0.45, 0.98)

  local size = classDef.size * sizeMul + (love.math.random() * 2 - 1) * (classDef.sizeJitter or 0)
  size = math.max(1.6, size)

  local baseRpm = math.max(1, (tonumber(cardDef.rpm) or 1) + rpmBonus)

  orbiter.cardBody = true
  orbiter.bodyKind = cardDef.id
  orbiter.cardName = cardDef.name
  orbiter.orbitClass = cardDef.orbitClass
  orbiter.baseRpm = baseRpm
  orbiter.runRpmBonus = orbiter.runRpmBonus or 0
  orbiter.turnRpmBonus = orbiter.turnRpmBonus or 0

  orbiter.radius = radius
  orbiter.flatten = flatten
  orbiter.depthScale = classDef.depthScale
  orbiter.visualRadius = size
  orbiter.visualSegments = math.max(12, math.floor(14 + size * 0.95))
  orbiter.speedMultiplier = classDef.speedMultiplier
  orbiter.minVisualRpm = math.max(self.config.MIN_BODY_VISUAL_RPM or 1.8, classDef.minVisualRpm or 1.8)
  orbiter.trailMultiplier = classDef.trailMultiplier or 1

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

function CardRunSystem:spawnBodiesFromCard(cardDef, rpmBonus)
  local classDefaults = self.config.ORBIT_CLASS_DEFAULTS or {}
  local classDef = classDefaults[cardDef.orbitClass or ""]
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
    self:configureBodyVisual(orbiter, cardDef, classDef, spawnIndex, spawnCount, rpmBonus)
    spawned[#spawned + 1] = orbiter
  end

  return spawned
end

function CardRunSystem:pickHighestBodyRpmTarget()
  local orbiters = self:collectAllOrbiters()
  local best
  local bestRpm = -math.huge
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    if self:isCardBody(orbiter) then
      local rpm = self:effectiveBodyRpm(orbiter)
      if rpm > bestRpm then
        bestRpm = rpm
        best = orbiter
      end
    end
  end
  return best
end

function CardRunSystem:pickPrecisionTarget()
  local selected = self.state.selectedOrbiter
  if self:isCardBody(selected) then
    return selected
  end
  return self:pickHighestBodyRpmTarget()
end

function CardRunSystem:applyHandRpmBuff(amount, picks, skipIndex)
  local remaining = math.max(0, math.floor(tonumber(picks) or 0))
  if remaining <= 0 then
    return
  end

  local buff = math.max(0, math.floor(tonumber(amount) or 0))
  if buff <= 0 then
    return
  end

  for i = 1, #self.state.hand do
    if i ~= skipIndex then
      local cardId = self.state.hand[i]
      local cardDef = self.config.CARD_DEFS[cardId]
      if self:isBodyCard(cardDef) then
        self.state.handRpmBonus[i] = (self.state.handRpmBonus[i] or 0) + buff
        remaining = remaining - 1
        if remaining <= 0 then
          return
        end
      end
    end
  end
end

function CardRunSystem:applyCard(cardDef, handIndex)
  if not cardDef then
    return false
  end

  local isBody = self:isBodyCard(cardDef)
  local rpmBonus = self:getHandRpmBonus(handIndex)
  local heatGain = math.max(0, math.floor(tonumber(cardDef.heat) or 0))

  if isBody and (self.state.nextBodyRpmBonus or 0) > 0 then
    rpmBonus = rpmBonus + math.max(0, math.floor(tonumber(self.state.nextBodyRpmBonus) or 0))
    self.state.nextBodyRpmBonus = 0
  end

  if isBody and (self.state.nextBodyHeatReduction or 0) > 0 then
    local reduction = math.max(0, math.floor(tonumber(self.state.nextBodyHeatReduction) or 0))
    heatGain = math.max(0, heatGain - reduction)
    self.state.nextBodyHeatReduction = 0
  end

  local spawnedBodies = {}
  if isBody then
    spawnedBodies = self:spawnBodiesFromCard(cardDef, rpmBonus)
    if not spawnedBodies then
      return false
    end
  end

  local effect = cardDef.effect or {type = "none"}
  if effect.type == "vent" then
    self:ventHeat(effect.amount)
  elseif effect.type == "global_run_rpm" then
    self.state.globalRunRpmBuff = self.state.globalRunRpmBuff + math.max(0, math.floor(tonumber(effect.amount) or 0))
  elseif effect.type == "global_turn_rpm" then
    self.state.globalTurnRpmBuff = self.state.globalTurnRpmBuff + math.max(0, math.floor(tonumber(effect.amount) or 0))
  elseif effect.type == "hand_rpm_buff" then
    self:applyHandRpmBuff(effect.amount, effect.picks, handIndex)
  elseif effect.type == "precision_target_run_rpm" then
    local target = self:pickPrecisionTarget()
    if target then
      target.runRpmBonus = (target.runRpmBonus or 0) + math.max(0, math.floor(tonumber(effect.amount) or 0))
    end
  elseif effect.type == "next_body_modifier" then
    self.state.nextBodyRpmBonus = self.state.nextBodyRpmBonus + math.max(0, math.floor(tonumber(effect.rpm) or 0))
    local heatDelta = math.floor(tonumber(effect.heat) or 0)
    if heatDelta < 0 then
      self.state.nextBodyHeatReduction = self.state.nextBodyHeatReduction + math.abs(heatDelta)
    elseif heatDelta > 0 then
      self:addHeat(heatDelta)
    end
  elseif effect.type == "resonator_turn_burst" then
    local amountPerBody = math.max(0, math.floor(tonumber(effect.amountPerBody) or 0))
    if amountPerBody > 0 then
      local target = spawnedBodies[#spawnedBodies] or self:pickHighestBodyRpmTarget()
      if target then
        local bodyCount = self:getBodyCount()
        target.turnRpmBonus = (target.turnRpmBonus or 0) + bodyCount * amountPerBody
      end
    end
  end

  self:addHeat(heatGain)

  self:syncOrbiterSpeedsFromBodies()
  self:updateHighestRpm()
  return true
end

function CardRunSystem:beginTurn(turnNumber)
  self.state.turn = turnNumber
  self.state.energy = self.config.TURN_ENERGY
  self:resetTurnModifiers()
  self:syncOrbiterSpeedsFromBodies()
  self:updateHighestRpm()
  self:drawCards(self.config.STARTING_HAND_SIZE)
  if self.state.turn == self.state.maxTurns and not self.state.lastTurnPulsePlayed then
    self:triggerGravityPulse()
    self.state.lastTurnPulsePlayed = true
  end
end

function CardRunSystem:endPlayerTurn()
  if self.state.runComplete then
    return
  end

  local endTurnHeat = math.max(0, self.config.END_TURN_HEAT_GAIN - self:countAnchors())
  self:addHeat(endTurnHeat)
  self:syncOrbiterSpeedsFromBodies()
  self:updateHighestRpm()
  if self.state.runComplete then
    return
  end

  self:discardCurrentHand()
  if self.state.turn >= self.state.maxTurns then
    self:finishRun("completed")
    return
  end
  self:beginTurn(self.state.turn + 1)
end

function CardRunSystem:currentCardCost(cardDef)
  if not cardDef then
    return 0
  end
  return math.max(0, math.floor(tonumber(cardDef.cost) or 0))
end

function CardRunSystem:playCard(handIndex)
  if self.state.runComplete then
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

  local beforeRpm = math.floor(self:computeTotalRpm() + 0.5)
  local effectiveCost = self:currentCardCost(cardDef)
  if self.state.energy < effectiveCost then
    return false
  end

  self.state.energy = self.state.energy - effectiveCost

  if not self:applyCard(cardDef, handIndex) then
    self.state.energy = self.state.energy + effectiveCost
    return false
  end

  table.remove(self.state.hand, handIndex)
  table.remove(self.state.handRpmBonus, handIndex)
  self.state.discardPile[#self.state.discardPile + 1] = cardId

  local afterRpm = math.floor(self:computeTotalRpm() + 0.5)
  self.state.rpmRollFrom = beforeRpm
  self.state.rpmRollTo = afterRpm
  self.state.rpmRollTimer = self.state.rpmRollDuration

  if self.onCardPlayed then
    self.onCardPlayed(cardDef)
  end

  return true
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
  self.state.handRpmBonus = {}
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

  self.state.maxTurns = self.config.MAX_TURNS
  self.state.objectiveRpm = self.config.OBJECTIVE_RPM
  self.state.coreRpm = 0
  self.state.heat = 0
  self.state.heatCap = self.config.HEAT_CAP
  self.state.globalRunRpmBuff = 0
  self.state.globalTurnRpmBuff = 0
  self.state.nextBodyRpmBonus = 0
  self.state.nextBodyHeatReduction = 0
  self.state.highestRpm = 0
  self.state.rewardRpm = 0
  self.state.runOutcome = ""
  self.state.turn = 1
  self.state.energy = self.config.TURN_ENERGY
  self.state.runComplete = false
  self.state.runWon = false
  self.state.lastTurnPulsePlayed = false
  self.state.runRewardClaimed = false
  self.state.rpmRollFrom = 0
  self.state.rpmRollTo = 0
  self.state.rpmRollTimer = 0

  self:syncOrbiterSpeedsFromBodies()
  self:updateHighestRpm()
  self:beginTurn(1)
end

return CardRunSystem
