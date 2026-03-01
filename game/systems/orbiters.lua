local OrbiterSystem = {}
OrbiterSystem.__index = OrbiterSystem

local function normalizeKindForStat(kind)
  return (kind or ""):gsub("-", "_")
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
    boostDurations = {},
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
    modifiers = assert(opts.modifiers, "OrbiterSystem requires modifiers"),
    orbitConfigs = assert(opts.orbitConfigs, "OrbiterSystem requires orbitConfigs"),
    bodyVisual = assert(opts.bodyVisual, "OrbiterSystem requires bodyVisual"),
    twoPi = assert(opts.twoPi, "OrbiterSystem requires twoPi"),
    maxMoons = assert(opts.maxMoons, "OrbiterSystem requires maxMoons"),
    createOrbitalParams = assert(opts.createOrbitalParams, "OrbiterSystem requires createOrbitalParams"),
    updateOrbiterPosition = assert(opts.updateOrbiterPosition, "OrbiterSystem requires updateOrbiterPosition"),
    assignRenderOrder = assert(opts.assignRenderOrder, "OrbiterSystem requires assignRenderOrder"),
    getStabilitySpeedMultiplier = opts.getStabilitySpeedMultiplier,
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

function OrbiterSystem:_notifyOrbitGain(orbiter, turnsGained, fxRadius)
  if turnsGained <= 0 then
    return
  end

  local reward = self:getOrbitGainReward(turnsGained)
  if reward > 0 then
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
  local kindSpeedMul = self:getSpeedMultiplierForKind(orbiter.kind)
  local stabilityMul = 1
  if self.getStabilitySpeedMultiplier then
    stabilityMul = self.getStabilitySpeedMultiplier() or 1
  end

  local effectiveSpeed = orbiter.speed * kindSpeedMul * stabilityMul
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

function OrbiterSystem:addMoon(parentOrbiter)
  if #self.state.moons >= self.maxMoons then
    return false
  end



  local moon = self:_addOrbiter(self.state.moons, self.orbitConfigs.moon, "moon")
  moon.parentOrbiter = parentOrbiter
  moon.childSatellites = {}
  moon.timingAnchorAngle = moon.angle
  self.updateOrbiterPosition(moon)
  return true
end

function OrbiterSystem:update(dt)
  for _, moon in ipairs(self.state.moons) do
    self:_advanceOrbiter(moon, dt, self.bodyVisual.moonRadius)
  end
end

return OrbiterSystem
