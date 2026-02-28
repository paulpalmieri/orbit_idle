local OrbiterSystem = {}
OrbiterSystem.__index = OrbiterSystem

local function normalizeKindForStat(kind)
  return (kind or ""):gsub("-", "_")
end

local function createEmptyBoostTable()
  return {}
end

local function newOrbiterFromOrbital(orbital, kind)
  return {
    angle = orbital.angle,
    radius = orbital.radius,
    flatten = orbital.flatten,
    depthScale = orbital.depthScale,
    zBase = orbital.zBase or 0,
    plane = orbital.plane,
    speed = orbital.speed,
    boost = 0,
    boostDurations = createEmptyBoostTable(),
    x = 0,
    y = 0,
    z = 0,
    light = 1,
    kind = kind,
    revolutions = 0,
  }
end

function OrbiterSystem.new(opts)
  opts = opts or {}
  local self = {
    state = assert(opts.state, "OrbiterSystem requires state"),
    economy = assert(opts.economy, "OrbiterSystem requires economy"),
    modifiers = assert(opts.modifiers, "OrbiterSystem requires modifiers"),
    orbitConfigs = assert(opts.orbitConfigs, "OrbiterSystem requires orbitConfigs"),
    bodyVisual = assert(opts.bodyVisual, "OrbiterSystem requires bodyVisual"),
    twoPi = assert(opts.twoPi, "OrbiterSystem requires twoPi"),
    maxMoons = assert(opts.maxMoons, "OrbiterSystem requires maxMoons"),
    maxSatellites = assert(opts.maxSatellites, "OrbiterSystem requires maxSatellites"),
    impulseDuration = assert(opts.impulseDuration, "OrbiterSystem requires impulseDuration"),
    impulseTargetBoost = assert(opts.impulseTargetBoost, "OrbiterSystem requires impulseTargetBoost"),
    impulseRiseRate = assert(opts.impulseRiseRate, "OrbiterSystem requires impulseRiseRate"),
    impulseFallRate = assert(opts.impulseFallRate, "OrbiterSystem requires impulseFallRate"),
    createOrbitalParams = assert(opts.createOrbitalParams, "OrbiterSystem requires createOrbitalParams"),
    updateOrbiterPosition = assert(opts.updateOrbiterPosition, "OrbiterSystem requires updateOrbiterPosition"),
    assignRenderOrder = assert(opts.assignRenderOrder, "OrbiterSystem requires assignRenderOrder"),
    getStabilitySpeedMultiplier = assert(opts.getStabilitySpeedMultiplier, "OrbiterSystem requires getStabilitySpeedMultiplier"),
    getTransientBoost = opts.getTransientBoost,
    onOrbitGainFx = opts.onOrbitGainFx,
    onOrbitsEarned = opts.onOrbitsEarned,
  }

  self.state.orbitGainCarry = tonumber(self.state.orbitGainCarry) or 0
  return setmetatable(self, OrbiterSystem)
end

function OrbiterSystem:getSpeedMultiplierForKind(kind)
  local normalizedKind = normalizeKindForStat(kind)
  local globalMul = self.modifiers:getMul("speed_global")
  local kindMul = self.modifiers:getMul("speed_" .. normalizedKind)
  return globalMul * kindMul
end

function OrbiterSystem:getOrbitGainReward(turnsGained)
  local baseTurns = math.max(0, tonumber(turnsGained) or 0)
  if baseTurns <= 0 then
    return 0
  end

  local mul = self.modifiers:getMul("orbit_gain")
  local add = self.modifiers:getAdd("orbit_gain")
  local rawReward = baseTurns * mul + add
  local withCarry = rawReward + (self.state.orbitGainCarry or 0)
  local payout = math.max(0, math.floor(withCarry + 1e-9))
  self.state.orbitGainCarry = withCarry - payout
  return payout
end

function OrbiterSystem:updateOrbiterBoost(orbiter, dt)
  local durations = orbiter.boostDurations or createEmptyBoostTable()
  for i = #durations, 1, -1 do
    durations[i] = durations[i] - dt
    if durations[i] <= 0 then
      table.remove(durations, i)
    end
  end
  orbiter.boostDurations = durations

  local activeStacks = #durations
  local targetBoost = activeStacks * self.impulseTargetBoost
  local blendRate = activeStacks > 0 and self.impulseRiseRate or self.impulseFallRate
  local blend = math.min(1, dt * blendRate)
  orbiter.boost = orbiter.boost + (targetBoost - orbiter.boost) * blend

  if activeStacks == 0 and orbiter.boost < 0.001 then
    orbiter.boost = 0
  end
end

function OrbiterSystem:_notifyOrbitGain(orbiter, turnsGained, fxRadius)
  if turnsGained <= 0 then
    return
  end

  local reward = self:getOrbitGainReward(turnsGained)
  if reward > 0 then
    self.state.orbits = self.state.orbits + reward
    if self.onOrbitsEarned then
      self.onOrbitsEarned(reward)
    end
    if self.onOrbitGainFx then
      self.onOrbitGainFx(orbiter.x, orbiter.y, reward, fxRadius)
    end
  end

  orbiter.revolutions = (orbiter.revolutions or 0) + turnsGained
end

function OrbiterSystem:_advanceOrbiter(orbiter, dt, fxRadius)
  local prevAngle = orbiter.angle
  self:updateOrbiterBoost(orbiter, dt)

  local transientBoost = 0
  if self.getTransientBoost then
    transientBoost = self.getTransientBoost(orbiter) or 0
  end

  local totalBoost = orbiter.boost + transientBoost
  local kindSpeedMul = self:getSpeedMultiplierForKind(orbiter.kind)
  local stabilityMul = self.getStabilitySpeedMultiplier()
  local effectiveSpeed = orbiter.speed * kindSpeedMul * (1 + totalBoost) * stabilityMul
  orbiter.angle = orbiter.angle + effectiveSpeed * dt

  local prevTurns = math.floor(prevAngle / self.twoPi)
  local newTurns = math.floor(orbiter.angle / self.twoPi)
  if newTurns > prevTurns then
    local turnsGained = newTurns - prevTurns
    self:_notifyOrbitGain(orbiter, turnsGained, fxRadius)
  end

  self.updateOrbiterPosition(orbiter)
end

function OrbiterSystem:_addOrbiter(list, config, kind)
  local orbital = self.createOrbitalParams(config, #list)
  local orbiter = newOrbiterFromOrbital(orbital, kind)
  self.updateOrbiterPosition(orbiter)
  self.assignRenderOrder(orbiter)
  list[#list + 1] = orbiter
  return orbiter
end

function OrbiterSystem:addMegaPlanet()
  local bought = self.economy:trySpendCost("megaPlanet")
  if not bought then
    return false
  end

  self:_addOrbiter(self.state.megaPlanets, self.orbitConfigs.megaPlanet, "mega-planet")
  return true
end

function OrbiterSystem:addPlanet()
  local bought = self.economy:trySpendCost("planet")
  if not bought then
    return false
  end

  self:_addOrbiter(self.state.planets, self.orbitConfigs.planet, "planet")
  return true
end

function OrbiterSystem:addMoon(parentOrbiter)
  if #self.state.moons >= self.maxMoons then
    return false
  end

  if parentOrbiter and parentOrbiter.kind ~= "planet" and parentOrbiter.kind ~= "mega-planet" then
    return false
  end

  if #self.state.moons > 0 then
    local bought = self.economy:trySpendCost("moon")
    if not bought then
      return false
    end
  end

  local moon = self:_addOrbiter(self.state.moons, self.orbitConfigs.moon, "moon")
  moon.parentOrbiter = parentOrbiter
  moon.childSatellites = {}
  moon.timingAnchorAngle = moon.angle
  self.updateOrbiterPosition(moon)
  return true
end

function OrbiterSystem:addSatellite()
  if #self.state.satellites >= self.maxSatellites then
    return false
  end

  local bought = self.economy:trySpendCost("satellite")
  if not bought then
    return false
  end

  self:_addOrbiter(self.state.satellites, self.orbitConfigs.satellite, "satellite")
  return true
end

function OrbiterSystem:addSatelliteToMoon(moon)
  if not moon or moon.kind ~= "moon" then
    return false
  end

  local bought = self.economy:trySpendCost("moonSatellite")
  if not bought then
    return false
  end

  moon.childSatellites = moon.childSatellites or {}
  local orbital = self.createOrbitalParams(self.orbitConfigs.moonChildSatellite, #moon.childSatellites)
  local child = newOrbiterFromOrbital(orbital, "moon-satellite")
  child.parentOrbiter = moon
  child.parentMoon = moon
  child.x = moon.x
  child.y = moon.y
  self.updateOrbiterPosition(child)
  self.assignRenderOrder(child)
  moon.childSatellites[#moon.childSatellites + 1] = child
  return true
end

function OrbiterSystem:pickImpulseTarget()
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

  if #pool == 0 then
    return nil
  end

  return pool[love.math.random(1, #pool)]
end

function OrbiterSystem:triggerPlanetImpulse()
  local target = self:pickImpulseTarget()
  if not target then
    return false
  end

  return self:injectBoost(target, self.impulseDuration)
end

function OrbiterSystem:injectBoost(orbiter, duration)
  if not orbiter then
    return false
  end

  local boostDuration = math.max(0, tonumber(duration) or 0)
  if boostDuration <= 0 then
    return false
  end

  orbiter.boostDurations = orbiter.boostDurations or createEmptyBoostTable()
  orbiter.boostDurations[#orbiter.boostDurations + 1] = boostDuration
  return true
end

function OrbiterSystem:update(dt)
  for _, megaPlanet in ipairs(self.state.megaPlanets) do
    self:_advanceOrbiter(megaPlanet, dt, self.bodyVisual.megaPlanetRadius)
  end

  for _, planet in ipairs(self.state.planets) do
    self:_advanceOrbiter(planet, dt, self.bodyVisual.orbitPlanetRadius)
  end

  for _, moon in ipairs(self.state.moons) do
    self:_advanceOrbiter(moon, dt, self.bodyVisual.moonRadius)

    local children = moon.childSatellites or {}
    for _, child in ipairs(children) do
      child.parentOrbiter = moon
      child.parentMoon = moon
      self:_advanceOrbiter(child, dt, self.bodyVisual.moonChildSatelliteRadius)
    end
  end

  for _, satellite in ipairs(self.state.satellites) do
    self:_advanceOrbiter(satellite, dt, self.bodyVisual.satelliteRadius)
  end
end

return OrbiterSystem
