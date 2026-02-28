local MoonTiming = {
  config = {
    windowRatio = 0.25,
    transientBoostDuration = 0.75,
    transientBoostAmount = 0.50,
    permanentSpeedGain = 0.25,
    zoneRespawnDelay = 1.0,
    fillDuration = 0.24,
    ghostHalfWidth = 2.8,
    ghostAlpha = 0.88,
    dialRadius = 14,
    dialSegments = 28,
  },
}

function MoonTiming.ensureState(moon, twoPi)
  if not moon then
    return
  end
  if moon.timingAnchorAngle == nil then
    moon.timingAnchorAngle = moon.angle
  end
  if moon.timingZoneCenterAngle == nil then
    moon.timingZoneCenterAngle = moon.timingAnchorAngle
  end
  if moon.timingCooldownTimer == nil then
    moon.timingCooldownTimer = 0
  end
  if moon.timingChargeTimer == nil then
    moon.timingChargeTimer = 0
  end
  if moon.timingNeedsZoneRoll == nil then
    moon.timingNeedsZoneRoll = false
  end
end

local function shortestAngleDistance(a, b, twoPi)
  return ((a - b + math.pi) % twoPi) - math.pi
end

local function rollZoneCenter(moon, twoPi)
  MoonTiming.ensureState(moon, twoPi)
  local previous = moon.timingZoneCenterAngle or moon.timingAnchorAngle
  local minSeparation = twoPi * 0.12
  local candidate = previous
  for _ = 1, 8 do
    candidate = moon.timingAnchorAngle + love.math.random() * twoPi
    if math.abs(shortestAngleDistance(candidate, previous, twoPi)) >= minSeparation then
      break
    end
  end
  moon.timingZoneCenterAngle = candidate
end

function MoonTiming.getSingleMoon(state, twoPi)
  if not state then
    return nil
  end
  if #(state.moons or {}) ~= 1 then
    return nil
  end

  local moon = state.moons[1]
  if not moon then
    return nil
  end

  MoonTiming.ensureState(moon, twoPi)
  return moon
end

function MoonTiming.phase(moon, twoPi)
  if not moon then
    return 0
  end

  MoonTiming.ensureState(moon, twoPi)
  local phase = (moon.angle - moon.timingAnchorAngle) / twoPi
  return phase - math.floor(phase)
end

function MoonTiming.orbitIndex(moon, twoPi)
  if not moon then
    return 0
  end
  MoonTiming.ensureState(moon, twoPi)
  return math.floor((moon.angle - moon.timingAnchorAngle) / twoPi)
end

function MoonTiming.windowCenterAngle(moon, twoPi)
  if not moon then
    return 0
  end
  MoonTiming.ensureState(moon, twoPi)
  return moon.timingZoneCenterAngle
end

function MoonTiming.windowSpanAngle(twoPi)
  return twoPi * MoonTiming.config.windowRatio
end

function MoonTiming.isZoneVisible(moon)
  if not moon then
    return false
  end
  return (moon.timingCooldownTimer or 0) <= 0
end

function MoonTiming.isCharging(moon)
  if not moon then
    return false
  end
  return (moon.timingChargeTimer or 0) > 0
end

function MoonTiming.chargeProgress(moon)
  if not moon then
    return 0
  end
  local timer = moon.timingChargeTimer or 0
  if timer <= 0 then
    return 0
  end
  return math.min(1, timer / MoonTiming.config.fillDuration)
end

function MoonTiming.isInWindow(moon, twoPi)
  if not moon then
    return false
  end

  MoonTiming.ensureState(moon, twoPi)
  if not MoonTiming.isZoneVisible(moon) then
    return false
  end

  local halfSpan = MoonTiming.windowSpanAngle(twoPi) * 0.5
  local center = MoonTiming.windowCenterAngle(moon, twoPi)
  local distanceFromCenter = math.abs(shortestAngleDistance(moon.angle, center, twoPi))
  return distanceFromCenter <= halfSpan
end

function MoonTiming.tryStartCharge(moon, twoPi)
  if not moon then
    return false
  end

  MoonTiming.ensureState(moon, twoPi)
  if not MoonTiming.isZoneVisible(moon) or MoonTiming.isCharging(moon) then
    return false
  end

  if not MoonTiming.isInWindow(moon, twoPi) then
    return false
  end

  moon.timingChargeTimer = 0.0001
  return true
end

function MoonTiming.update(moon, dt, twoPi)
  if not moon then
    return false
  end

  MoonTiming.ensureState(moon, twoPi)

  if MoonTiming.isCharging(moon) then
    moon.timingChargeTimer = moon.timingChargeTimer + dt
    if moon.timingChargeTimer >= MoonTiming.config.fillDuration then
      moon.timingChargeTimer = 0
      moon.timingCooldownTimer = MoonTiming.config.zoneRespawnDelay
      moon.timingNeedsZoneRoll = true
      return true
    end
    return false
  end

  if moon.timingCooldownTimer > 0 then
    moon.timingCooldownTimer = math.max(0, moon.timingCooldownTimer - dt)
    if moon.timingCooldownTimer <= 0 and moon.timingNeedsZoneRoll then
      rollZoneCenter(moon, twoPi)
      moon.timingNeedsZoneRoll = false
    end
  end

  return false
end

return MoonTiming
