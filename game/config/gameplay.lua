local world = {
  gameW = 1280,
  gameH = 720,
  twoPi = math.pi * 2,
  cameraLightHeight = 280,
  cameraLightZScale = 220,
  cameraLightAmbient = 0.10,
  cameraLightIntensity = 2.85,
  cameraLightFalloff = 1 / (900 * 900),
  lightSourceOffsetX = -540,
  lightSourceOffsetY = -240,
  lightSourceZ = 0.50,
  zoomMin = 0.55,
  zoomMax = 2,
  perspectiveZStrength = 0.10,
  perspectiveMinScale = 0.88,
  perspectiveMaxScale = 1.18,
  depthSortHysteresis = 0.035,
  bodyShadeDarkFloorTone = 0.22,
  bodyShadeEclipseThreshold = 0.16,
  bodyShadeContrast = 1.75,
  orbitPopLifetime = 1.44,
  planetColorCycleSeconds = 30,
  orbitIconCycleSeconds = 1.8,
  orbitIconFlatten = 0.84,
  orbitIconSize = 6,
  uiFontSize = 24,
}
world.radPerSecondToRpm = 60 / world.twoPi

local slice = {
  baseMoonRpm = 6.0,
  collapseRpm = 100,
  tempBurstDecayPerSecond = 10,
  highRiskRpm = 70,
  perfectWindow = 0.035,
  goodWindow = 0.085,
  perfectPermGain = 2.4,
  perfectBurstGain = 9.0,
  goodPermGain = 1.2,
  goodBurstGain = 5.0,
  calmRpm = 40,
  chargedRpm = 70,
  dangerousRpm = 90,
  redlineRpm = 99.99,
  collapseFreezeSeconds = 0.10,
  rewardRpmWeight = 0.35,
  rewardPerfectWeight = 1.5,
  minimumReward = 1,
  shardSaveFile = "collapse_shards.sav",
  singleMoonMode = true,
}

local gameplay = {
  planetBounceDuration = 0.12,
  gravityWellInnerScale = 0.01,
  gravityWellRadiusScale = 1.3,
  gravityWellRadialStrength = 0.03,
  gravityWellSwirlStrength = 0.0010,
  gravityRippleLifetime = 1.1,
  gravityRippleWidthStart = 0.020,
  gravityRippleWidthEnd = 0.092,
  gravityRippleRadialStrength = 0.062,
  gravityRippleSwirlStrength = 0.0018,
  gravityRippleEndPadding = 0.12,
  rpmCollapseThreshold = slice.collapseRpm,
  rpmInstabilityStartRatio = slice.dangerousRpm / slice.collapseRpm,
  rpmInstabilityShakeMax = 3.8,
  rpmInstabilityWaveIntervalStart = 0.72,
  rpmInstabilityWaveIntervalEnd = 0.32,
  rpmInstabilityWaveLife = 0.90,
  rpmInstabilityWaveWidthStart = 0.016,
  rpmInstabilityWaveWidthEnd = 0.078,
  rpmInstabilityWaveRadialStrength = 0.041,
  rpmInstabilityWaveSwirlStrength = 0.0012,
  rpmCollapseEndDelay = 1.45,
  rpmBarWidth = 220,
  rpmBarHeight = 8,
  rpmBarFillRiseRate = 13,
  rpmBarFillFallRate = 5,
}

local progression = {
  criticalInstabilityRatio = 0.82,
  unlockNodeFxSeconds = 0.52,
  unlockNodeFxRingRadius = 92,
}

local upgradeEffects = {
  stabilizer_lattice = {
    perfectStabilityMultiplier = 1.34,
  },
  tighter_burn = {
    perfectPermMultiplier = 1.26,
    perfectBurstMultiplier = 1.20,
  },
  resonant_core = {
    streakPermBonus = 0.45,
    streakBurstBonus = 0.85,
    streakCap = 6,
  },
  reinforced_orbit = {
    passiveInstabilityMultiplier = 0.82,
  },
}

local moonVariants = {
  standard = {
    id = "standard",
    label = "standard moon",
    permanentGainMul = 1.00,
    burstGainMul = 1.00,
    passiveInstabilityMul = 1.00,
  },
  heavy_moon = {
    id = "heavy_moon",
    label = "heavy moon",
    permanentGainMul = 0.84,
    burstGainMul = 0.72,
    passiveInstabilityMul = 0.80,
  },
  glass_moon = {
    id = "glass_moon",
    label = "glass moon",
    permanentGainMul = 1.22,
    burstGainMul = 1.34,
    passiveInstabilityMul = 1.32,
  },
}

local runPressure = {
  instability = {
    start = 0,
    max = 100,
    passiveBasePerSecond = 2.5,
    passiveRpmFactor = 0.06,
    onPerfect = -8,
    onGood = -3,
    onMiss = 7,
    stressStartRatio = 0.30,
    meterRiseRate = 8.5,
    meterFallRate = 12.0,
    softTickSeconds = 0.18,
    spikeFlashSeconds = 0.22,
    shakeMax = 3.8,
    waveIntervalStart = 0.90,
    waveIntervalEnd = 0.34,
    waveLife = 0.90,
    waveWidthStart = 0.016,
    waveWidthEnd = 0.078,
    waveRadialStrength = 0.041,
    waveSwirlStrength = 0.0012,
  },
}

local economy = {
  moonCost = 50,
  maxMoons = 1,
}

local audio = {
  bgMusicVolume = 0.72,
  bgMusicLoopFadeSeconds = 0.28,
  bgMusicDuckSeconds = 0.22,
  bgMusicDuckGain = 0.42,
  clickFxVolumeOpen = 0.50,
  clickFxVolumeClose = 0.43,
  clickFxPitchOpen = 1.0,
  clickFxPitchClose = 0.88,
  clickFxMenuPitchMin = 0.92,
  clickFxMenuPitchMax = 1.08,
  perfectHitFxVolume = 0.62,
  perfectHitPitchMin = 0.97,
  perfectHitPitchMax = 1.30,
  perfectHitComboSaturation = 12,
  perfectHitComboVolumeBoost = 0.24,
  missFxVolume = 0.58,
  missFxPitchMin = 0.90,
  missFxPitchMax = 1.02,
  unlockSkillFxVolume = 0.62,
  unlockSkillFxPitchMin = 0.96,
  unlockSkillFxPitchMax = 1.08,
}

local orbitConfigs = {
  moon = {
    bandCapacity = 4,
    baseRadius = 100,
    bandStep = 34,
    fixedAltitude = true,
    tiltMin = 0.35,
    tiltRange = 1.1,
    flattenMin = 0.62,
    flattenMax = 0.90,
    planeMin = -0.35,
    planeRange = 0.70,
    speedMin = 0.42,
    speedRange = 0.15,
  },
}

local bodyVisual = {
  planetRadius = 30,
  moonRadius = 10,
}

return {
  world = world,
  gameplay = gameplay,
  slice = slice,
  progression = progression,
  upgradeEffects = upgradeEffects,
  moonVariants = moonVariants,
  runPressure = runPressure,
  economy = economy,
  audio = audio,
  orbitConfigs = orbitConfigs,
  bodyVisual = bodyVisual,
}
