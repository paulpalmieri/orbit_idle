local UpgradeSystem = {}
UpgradeSystem.__index = UpgradeSystem

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function smoothstep(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

function UpgradeSystem.new(opts)
  opts = opts or {}
  local self = {
    state = assert(opts.state, "UpgradeSystem requires state"),
    economy = assert(opts.economy, "UpgradeSystem requires economy"),
    modifiers = assert(opts.modifiers, "UpgradeSystem requires modifiers"),
    stability = assert(opts.stability, "UpgradeSystem requires stability config"),
    speedWaveDuration = assert(opts.speedWaveDuration, "UpgradeSystem requires speedWaveDuration"),
    speedWaveMultiplier = assert(opts.speedWaveMultiplier, "UpgradeSystem requires speedWaveMultiplier"),
    speedWaveClickThreshold = assert(opts.speedWaveClickThreshold, "UpgradeSystem requires speedWaveClickThreshold"),
    speedWaveRippleLifetime = assert(opts.speedWaveRippleLifetime, "UpgradeSystem requires speedWaveRippleLifetime"),
    speedWaveTextLifetime = assert(opts.speedWaveTextLifetime, "UpgradeSystem requires speedWaveTextLifetime"),
    planetBounceDuration = assert(opts.planetBounceDuration, "UpgradeSystem requires planetBounceDuration"),
    onUpgradePurchased = opts.onUpgradePurchased,
    onPlanetImpulse = opts.onPlanetImpulse,
    mousePositionProvider = opts.mousePositionProvider,
  }

  return setmetatable(self, UpgradeSystem)
end

function UpgradeSystem:_mousePosition()
  if self.mousePositionProvider then
    return self.mousePositionProvider()
  end
  return 0, 0
end

function UpgradeSystem:spawnModifierRipple()
  local ripples = self.state.speedWaveRipples
  ripples[#ripples + 1] = {
    age = 0,
    life = self.speedWaveRippleLifetime,
  }
end

function UpgradeSystem:speedWaveCost()
  return self.economy:getCost("speedWave")
end

function UpgradeSystem:speedClickCost()
  return self.economy:getCost("speedClick")
end

function UpgradeSystem:blackHoleShaderCost()
  return self.economy:getCost("blackHoleShader")
end

function UpgradeSystem:buySpeedWave()
  if self.state.speedWaveUnlocked then
    return false
  end

  local bought = self.economy:trySpendCost("speedWave")
  if not bought then
    return false
  end

  self.state.speedWaveUnlocked = true
  self.state.planetClickCount = 0
  if self.onUpgradePurchased then
    self.onUpgradePurchased("speedWave")
  end
  return true
end

function UpgradeSystem:buySpeedClick()
  if self.state.speedClickUnlocked then
    return false
  end

  local bought = self.economy:trySpendCost("speedClick")
  if not bought then
    return false
  end

  self.state.speedClickUnlocked = true
  if self.onUpgradePurchased then
    self.onUpgradePurchased("speedClick")
  end
  return true
end

function UpgradeSystem:buyBlackHoleShader()
  if self.state.blackHoleShaderUnlocked then
    return false
  end

  local bought = self.economy:trySpendCost("blackHoleShader")
  if not bought then
    return false
  end

  self.state.blackHoleShaderUnlocked = true
  if self.onUpgradePurchased then
    self.onUpgradePurchased("blackHoleShader")
  end
  return true
end

function UpgradeSystem:getSpeedWaveBoost(orbiter)
  if self.state.speedWaveTimer <= 0 then
    return 0
  end
  if not orbiter then
    return 0
  end
  if orbiter.kind ~= "satellite" and orbiter.kind ~= "moon-satellite" then
    return 0
  end

  local mul = self.modifiers:getMul("speed_wave_multiplier")
  local boostedMultiplier = self.speedWaveMultiplier * mul
  return math.max(0, boostedMultiplier - 1)
end

function UpgradeSystem:triggerSpeedWave()
  local durationMul = self.modifiers:getMul("speed_wave_duration")
  self.state.speedWaveTimer = self.speedWaveDuration * durationMul
  self:spawnModifierRipple()

  local mx, my = self:_mousePosition()
  self.state.speedWaveText = {
    x = mx,
    y = my,
    age = 0,
    life = self.speedWaveTextLifetime,
  }
end

function UpgradeSystem:isBlackHoleUnstable()
  return self.state.stability < self.stability.unstableThreshold
end

function UpgradeSystem:stabilitySlowMultiplier()
  if self.state.stability >= self.stability.unstableThreshold then
    return 1
  end
  local t = 1 - (self.state.stability / self.stability.unstableThreshold)
  return lerp(1, self.stability.minSpeedMultiplier, smoothstep(t))
end

function UpgradeSystem:stabilityRecoveryBoostMultiplier()
  if self.state.stabilityBoostTimer <= 0 then
    return 1
  end
  local boosted = self.stability.recoveryBoostMultiplier * self.modifiers:getMul("stability_recovery_multiplier")
  local t = clamp(self.state.stabilityBoostTimer / self.stability.recoveryBoostDuration, 0, 1)
  return lerp(1, boosted, smoothstep(t))
end

function UpgradeSystem:blackHoleStabilitySpeedMultiplier()
  return self:stabilitySlowMultiplier() * self:stabilityRecoveryBoostMultiplier()
end

function UpgradeSystem:onBlackHoleStabilityClick()
  local clickGain = self.stability.clickGain * self.modifiers:getMul("stability_click_gain")
  local wasStable = self.state.stability >= self.stability.recoveryThreshold
  local wasMax = self.state.stability >= 1

  self.state.stability = clamp(self.state.stability + clickGain, 0, 1)
  self.state.stabilityIdleTimer = 0

  if (not wasStable) and self.state.stability >= self.stability.recoveryThreshold then
    self.state.stabilityBoostTimer = self.stability.recoveryBoostDuration
    self:spawnModifierRipple()
  end

  if (not wasMax) and self.state.stability >= 1 then
    self.state.stabilityMaxFxTimer = self.stability.maxFxDuration
    self:spawnModifierRipple()
  end
end

function UpgradeSystem:onPlanetClicked()
  self.state.planetBounceTime = self.planetBounceDuration
  self:onBlackHoleStabilityClick()

  if self.state.speedClickUnlocked and self.onPlanetImpulse then
    self.onPlanetImpulse()
  end

  if not self.state.speedWaveUnlocked then
    return
  end

  self.state.planetClickCount = self.state.planetClickCount + 1
  if self.state.planetClickCount % self.speedWaveClickThreshold == 0 then
    self:triggerSpeedWave()
  end
end

function UpgradeSystem:update(dt)
  self.state.speedWaveTimer = math.max(0, self.state.speedWaveTimer - dt)
  self.state.stabilityBoostTimer = math.max(0, self.state.stabilityBoostTimer - dt)
  self.state.stabilityMaxFxTimer = math.max(0, self.state.stabilityMaxFxTimer - dt)

  self.state.stabilityIdleTimer = self.state.stabilityIdleTimer + dt
  if self.state.stabilityIdleTimer > self.stability.idleSeconds then
    local drainMul = self.modifiers:getMul("stability_drain_multiplier")
    local drain = self.stability.drainPerSecond * drainMul
    self.state.stability = math.max(0, self.state.stability - drain * dt)
  end

  if self:isBlackHoleUnstable() then
    self.state.stabilityWaveTimer = self.state.stabilityWaveTimer + dt
    while self.state.stabilityWaveTimer >= self.stability.waveInterval do
      self.state.stabilityWaveTimer = self.state.stabilityWaveTimer - self.stability.waveInterval
      self:spawnModifierRipple()
    end
  else
    self.state.stabilityWaveTimer = 0
  end

  local ripples = self.state.speedWaveRipples
  for i = #ripples, 1, -1 do
    local ripple = ripples[i]
    ripple.age = ripple.age + dt
    if ripple.age >= ripple.life then
      table.remove(ripples, i)
    end
  end

  local popup = self.state.speedWaveText
  if popup then
    popup.age = popup.age + dt
    if popup.age >= popup.life then
      self.state.speedWaveText = nil
    end
  end
end

return UpgradeSystem
