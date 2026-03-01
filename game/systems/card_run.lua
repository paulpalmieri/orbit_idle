local CardRunSystem = {}
CardRunSystem.__index = CardRunSystem

local function shuffleInPlace(list)
  for i = #list, 2, -1 do
    local j = love.math.random(1, i)
    list[i], list[j] = list[j], list[i]
  end
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

function CardRunSystem:isMoonBody(orbiter)
  return orbiter and (orbiter.bodyKind == "moon" or orbiter.bodyKind == "heavy_moon")
end

function CardRunSystem:countMoonBodies()
  local count = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    if self:isMoonBody(orbiters[i]) then
      count = count + 1
    end
  end
  return count
end

function CardRunSystem:countAnchors()
  local count = 0
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    if orbiters[i].bodyKind == "anchor" then
      count = count + 1
    end
  end
  return count
end

function CardRunSystem:effectiveBodyRpm(orbiter)
  if not orbiter then
    return 0
  end
  local rpm = orbiter.baseRpm or 0
  if self:isMoonBody(orbiter) then
    rpm = rpm + self.state.permanentMoonSpin + self.state.turnOverclockRpm
  end
  return math.max(0, rpm)
end

function CardRunSystem:syncOrbiterSpeedsFromBodies()
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    local orbiter = orbiters[i]
    orbiter.speed = self:effectiveBodyRpm(orbiter) * self.config.RPM_TO_RAD_PER_SECOND
  end
end

function CardRunSystem:computeTotalRpm()
  local total = self.state.coreRpm + self.state.turnBurstRpm
  local orbiters = self:collectAllOrbiters()
  for i = 1, #orbiters do
    total = total + self:effectiveBodyRpm(orbiters[i])
  end
  return total
end

function CardRunSystem:updateHighestRpm()
  local current = math.floor(self:computeTotalRpm() + 0.5)
  if current > self.state.highestRpm then
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
    self.state.hand[#self.state.hand + 1] = table.remove(self.state.drawPile)
  end
end

function CardRunSystem:discardCurrentHand()
  for i = #self.state.hand, 1, -1 do
    self.state.discardPile[#self.state.discardPile + 1] = self.state.hand[i]
    self.state.hand[i] = nil
  end
end

function CardRunSystem:resetTurnModifiers()
  self.state.turnOverclockRpm = 0
  self.state.turnBurstRpm = 0
  self.state.nextCardHeatReduction = 0
  self.state.nextMoonCostReduction = 0
  self.state.nextMoonRpmBonus = 0
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
  if amount <= 0 then
    return
  end
  self.state.heat = math.max(0, self.state.heat - amount)
end

function CardRunSystem:addHeat(amount)
  if amount <= 0 then
    return
  end
  self.state.heat = self.state.heat + amount
  if self.state.heat >= self.state.heatCap then
    self.state.heat = self.state.heatCap
    self:updateHighestRpm()
    self:finishRun("collapse")
  end
end

function CardRunSystem:tagBody(orbiter, bodyKind, baseRpm)
  if not orbiter then
    return
  end
  orbiter.bodyKind = bodyKind
  orbiter.baseRpm = baseRpm
end

function CardRunSystem:summonMoon(baseRpm)
  local before = #self.state.moons
  if not self.orbiters.addMoon(nil) then
    return false
  end
  self:tagBody(self.state.moons[before + 1], "moon", baseRpm)
  return true
end

function CardRunSystem:summonHeavyMoon(baseRpm)
  local before = #self.state.planets
  if not self.orbiters.addPlanet() then
    return false
  end
  self:tagBody(self.state.planets[before + 1], "heavy_moon", baseRpm)
  return true
end

function CardRunSystem:summonAnchor(baseRpm)
  local before = #self.state.satellites
  if not self.orbiters.addSatellite() then
    return false
  end
  self:tagBody(self.state.satellites[before + 1], "anchor", baseRpm)
  return true
end

function CardRunSystem:applyCard(cardDef, moonBonusRpm)
  local heatGain = 0
  local id = cardDef.id
  if id == "moonseed" then
    if not self:summonMoon(4 + moonBonusRpm) then
      return false
    end
    heatGain = 1
  elseif id == "coolant_vent" then
    self:ventHeat(2)
  elseif id == "spin_up" then
    self.state.permanentMoonSpin = self.state.permanentMoonSpin + 1
    heatGain = 1
  elseif id == "overclock" then
    self.state.turnOverclockRpm = self.state.turnOverclockRpm + 2
    heatGain = 1
  elseif id == "heavy_moon" then
    if not self:summonHeavyMoon(6 + moonBonusRpm) then
      return false
    end
    heatGain = 2
  elseif id == "twin_seed" then
    if not self:summonMoon(3 + moonBonusRpm) then
      return false
    end
    if not self:summonMoon(3 + moonBonusRpm) then
      return false
    end
    heatGain = 2
  elseif id == "precision_spin" then
    self.state.permanentMoonSpin = self.state.permanentMoonSpin + 2
    heatGain = 2
  elseif id == "cold_sink" then
    self:ventHeat(4)
  elseif id == "redline" then
    self.state.turnOverclockRpm = self.state.turnOverclockRpm + 4
    heatGain = 2
  elseif id == "containment" then
    self:ventHeat(2)
    self.state.nextCardHeatReduction = self.state.nextCardHeatReduction + 1
  elseif id == "compression" then
    self.state.nextMoonCostReduction = self.state.nextMoonCostReduction + 1
    self.state.nextMoonRpmBonus = self.state.nextMoonRpmBonus + 2
  elseif id == "reactor_feed" then
    self.state.energy = self.state.energy + 1
    heatGain = 1
  elseif id == "resonant_burst" then
    self.state.turnBurstRpm = self.state.turnBurstRpm + self:countMoonBodies() * 2
    heatGain = 2
  elseif id == "anchor" then
    if not self:summonAnchor(2) then
      return false
    end
  else
    return false
  end

  local heatReduction = self.state.nextCardHeatReduction
  if heatReduction > 0 then
    heatGain = math.max(0, heatGain - heatReduction)
    self.state.nextCardHeatReduction = 0
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
  local cost = cardDef.cost or 0
  if cardDef.isMoonCard and self.state.nextMoonCostReduction > 0 then
    cost = math.max(0, cost - self.state.nextMoonCostReduction)
  end
  return cost
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

  local beforeRpm = math.floor(self:computeTotalRpm() + 0.5)
  local moonCostReduction = self.state.nextMoonCostReduction
  local moonRpmBonus = 0
  if cardDef.isMoonCard and moonCostReduction > 0 then
    moonRpmBonus = self.state.nextMoonRpmBonus
  end

  local effectiveCost = self:currentCardCost(cardDef)
  if self.state.energy < effectiveCost then
    return false
  end

  self.state.energy = self.state.energy - effectiveCost
  if cardDef.isMoonCard and moonCostReduction > 0 then
    self.state.nextMoonCostReduction = 0
    self.state.nextMoonRpmBonus = 0
  end

  if not self:applyCard(cardDef, moonRpmBonus) then
    self.state.energy = self.state.energy + effectiveCost
    return false
  end

  table.remove(self.state.hand, handIndex)
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
  self.state.coreRpm = self.config.CORE_BASE_RPM
  self.state.heat = 0
  self.state.heatCap = self.config.HEAT_CAP
  self.state.permanentMoonSpin = 0
  self.state.turnOverclockRpm = 0
  self.state.turnBurstRpm = 0
  self.state.nextCardHeatReduction = 0
  self.state.nextMoonCostReduction = 0
  self.state.nextMoonRpmBonus = 0
  self.state.highestRpm = self.config.CORE_BASE_RPM
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
