local MoonTiming = {
  config = {
    perfectWindow = 0.035,
    goodWindow = 0.085,
    zoneRespawnDelay = 0.12,
    zoneMinSeparation = 0.10,
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
    moon.timingZoneCenterAngle = moon.timingAnchorAngle - math.pi * 0.5
  end
  if moon.timingCooldownTimer == nil then
    moon.timingCooldownTimer = 0
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
  local minSeparation = twoPi * MoonTiming.config.zoneMinSeparation
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
  return MoonTiming.goodSpanAngle(twoPi)
end

function MoonTiming.goodSpanAngle(twoPi)
  return twoPi * MoonTiming.config.goodWindow * 2
end

function MoonTiming.perfectSpanAngle(twoPi)
  return twoPi * MoonTiming.config.perfectWindow * 2
end

function MoonTiming.isZoneVisible(moon)
  if not moon then
    return false
  end
  return (moon.timingCooldownTimer or 0) <= 0
end

function MoonTiming.isCharging(moon)
  return false
end

function MoonTiming.chargeProgress(moon)
  return 0
end

function MoonTiming.phaseDistanceNormalized(a, b)
  local delta = math.abs(a - b)
  if delta > 0.5 then
    delta = 1 - delta
  end
  return delta
end

function MoonTiming.targetPhase(moon, twoPi)
  if not moon then
    return 0
  end
  MoonTiming.ensureState(moon, twoPi)
  local target = (moon.timingZoneCenterAngle - moon.timingAnchorAngle) / twoPi
  return target - math.floor(target)
end

function MoonTiming.distanceFromTargetPhase(moon, twoPi)
  if not moon then
    return 1
  end
  local phase = MoonTiming.phase(moon, twoPi)
  local target = MoonTiming.targetPhase(moon, twoPi)
  return MoonTiming.phaseDistanceNormalized(phase, target)
end

function MoonTiming.rollTarget(moon, twoPi)
  if not moon then
    return
  end
  rollZoneCenter(moon, twoPi)
end

function MoonTiming.isInWindow(moon, twoPi)
  if not moon then
    return false
  end

  MoonTiming.ensureState(moon, twoPi)
  if not MoonTiming.isZoneVisible(moon) then
    return false
  end

  return MoonTiming.distanceFromTargetPhase(moon, twoPi) <= MoonTiming.config.goodWindow
end

function MoonTiming.evaluateTap(moon, twoPi)
  if not moon then
    return {
      result = "miss",
      phaseDistance = 1,
      goodWindow = MoonTiming.config.goodWindow,
      perfectWindow = MoonTiming.config.perfectWindow,
    }
  end

  MoonTiming.ensureState(moon, twoPi)
  local phaseDistance = MoonTiming.distanceFromTargetPhase(moon, twoPi)
  local result = "miss"
  if MoonTiming.isZoneVisible(moon) then
    if phaseDistance <= MoonTiming.config.perfectWindow then
      result = "perfect"
    elseif phaseDistance <= MoonTiming.config.goodWindow then
      result = "good"
    end
  end

  if result ~= "miss" then
    moon.timingCooldownTimer = MoonTiming.config.zoneRespawnDelay
    moon.timingNeedsZoneRoll = true
    if moon.timingCooldownTimer <= 0 then
      rollZoneCenter(moon, twoPi)
      moon.timingNeedsZoneRoll = false
    end
  end

  return {
    result = result,
    phaseDistance = phaseDistance,
    goodWindow = MoonTiming.config.goodWindow,
    perfectWindow = MoonTiming.config.perfectWindow,
  }
end

function MoonTiming.tryStartCharge(moon, twoPi)
  return MoonTiming.evaluateTap(moon, twoPi).result ~= "miss"
end

function MoonTiming.update(moon, dt, twoPi)
  if not moon then
    return false
  end

  MoonTiming.ensureState(moon, twoPi)

  if moon.timingCooldownTimer > 0 then
    moon.timingCooldownTimer = math.max(0, moon.timingCooldownTimer - dt)
    if moon.timingCooldownTimer <= 0 and moon.timingNeedsZoneRoll then
      rollZoneCenter(moon, twoPi)
      moon.timingNeedsZoneRoll = false
    end
  end

  return true
end

return MoonTiming
