local M = {}

M.GAME_W = 1280
M.GAME_H = 720
M.TWO_PI = math.pi * 2

M.CAMERA_LIGHT_HEIGHT = 280
M.CAMERA_LIGHT_Z_SCALE = 220
M.CAMERA_LIGHT_AMBIENT = 0.10
M.CAMERA_LIGHT_INTENSITY = 2.85
M.CAMERA_LIGHT_FALLOFF = 1 / (900 * 900)
M.LIGHT_ORBIT_PERIOD_SECONDS = 120
M.LIGHT_ORBIT_RADIUS_X = M.GAME_W * 0.62
M.LIGHT_ORBIT_RADIUS_Y = M.GAME_H * 0.42
M.LIGHT_ORBIT_Z_BASE = 0.38
M.LIGHT_ORBIT_Z_VARIATION = 0.16
M.LIGHT_SOURCE_MARKER_RADIUS = 8
M.LIGHT_SOURCE_HIT_PADDING = 6

M.ZOOM_MIN = 0.55
M.ZOOM_MAX = 2
M.PERSPECTIVE_Z_STRENGTH = 0.10
M.PERSPECTIVE_MIN_SCALE = 0.88
M.PERSPECTIVE_MAX_SCALE = 1.18
M.DEPTH_SORT_HYSTERESIS = 0.035

M.BODY_SHADE_DARK_FLOOR_TONE = 0.22
M.BODY_SHADE_ECLIPSE_THRESHOLD = 0.16
M.BODY_SHADE_CONTRAST = 1.75

M.ORBIT_CONFIGS = {
  megaPlanet = {
    bandCapacity = 1,
    baseRadius = 440,
    bandStep = 90,
    fixedAltitude = true,
    tiltMin = 0.24,
    tiltRange = 0.5,
    speedMin = 0.08,
    speedRange = 0.04,
  },
  planet = {
    bandCapacity = 2,
    baseRadius = 180,
    bandStep = 56,
    fixedAltitude = true,
    tiltMin = 0.28,
    tiltRange = 0.9,
    speedMin = 0.16,
    speedRange = 0.08,
  },
  moon = {
    bandCapacity = 4,
    baseRadius = 100,
    bandStep = 34,
    fixedAltitude = true,
    tiltMin = 0.35,
    tiltRange = 1.1,
    speedMin = 0.42,
    speedRange = 0.15,
  },
  satellite = {
    bandCapacity = 6,
    baseRadius = 40,
    bandStep = 8,
    fixedAltitude = true,
    altitudeCapacity = 6,
    altitudeSlotStep = 0.11,
    altitudeBandStep = 0.20,
    tiltMin = 0.30,
    tiltRange = 1.2,
    speedMin = 0.70,
    speedRange = 0.20,
  },
  moonChildSatellite = {
    bandCapacity = 4,
    baseRadius = 10,
    bandStep = 2.0,
    altitudeCapacity = 4,
    altitudeSlotStep = 0.08,
    altitudeBandStep = 0.12,
    tiltMin = 0.30,
    tiltRange = 1.2,
    speedMin = 0.90,
    speedRange = 0.55,
  },
}

M.BODY_VISUAL = {
  planetRadius = 30,
  orbitPlanetRadius = 24,
  megaPlanetRadius = 150,
  moonRadius = 10,
  satelliteRadius = 4,
  moonChildSatelliteRadius = 1.8,
}

M.PLANET_IMPULSE_MULTIPLIER = 2
M.PLANET_IMPULSE_TARGET_BOOST = M.PLANET_IMPULSE_MULTIPLIER - 1
M.PLANET_IMPULSE_DURATION = 10
M.PLANET_IMPULSE_RISE_RATE = 4.5
M.PLANET_IMPULSE_FALL_RATE = 6.5
M.PLANET_BOUNCE_DURATION = 0.12

M.GRAVITY_WELL_INNER_SCALE = 0.06
M.GRAVITY_WELL_RADIUS_SCALE = 1.18
M.GRAVITY_WELL_RADIAL_STRENGTH = 0.009
M.GRAVITY_WELL_SWIRL_STRENGTH = 0.00028

M.SPEED_WAVE_RIPPLE_LIFETIME = 1.1
M.SPEED_WAVE_RIPPLE_WIDTH_START = 0.020
M.SPEED_WAVE_RIPPLE_WIDTH_END = 0.092
M.SPEED_WAVE_RIPPLE_RADIAL_STRENGTH = 0.062
M.SPEED_WAVE_RIPPLE_SWIRL_STRENGTH = 0.0018
M.SPEED_WAVE_RIPPLE_END_PADDING = 0.12

M.PLANET_COLOR_CYCLE_SECONDS = 30
M.ORBIT_ICON_CYCLE_SECONDS = 1.8
M.ORBIT_ICON_FLATTEN = 0.84
M.ORBIT_ICON_SIZE = 6
M.TRAIL_LAG_SECONDS = 1.0
M.TRAIL_MAX_ARC_TURNS = 2.3
M.TRAIL_MAX_ARC_TURNS_SIMULATION = 0.75

M.UI_FONT_SIZE = 18
M.MAX_MOONS = 64
M.MAX_SATELLITES = 64
M.MAX_PLANETS = 64
M.STARTING_HAND_SIZE = 5
M.EPOCH_ENERGY = 5
M.MAX_EPOCHS = 6
M.HEAT_CAP = 10
M.EPOCH_SIMULATION_DURATION = 3.2
M.EPOCH_SETTLE_DURATION = 0.65
M.PLANNING_LINEAR_SPEED = 4

M.CARD_W = 124
M.CARD_H = 176
M.CARD_GAP = 12
M.END_TURN_W = 118
M.END_TURN_H = 34

M.ORBIT_CLASS_DEFAULTS = {
  Moon = {
    kind = "moon",
    baseRadius = 174,
    radiusStep = 14,
    radiusJitter = 9,
    flatten = 0.86,
    flattenJitter = 0.06,
    depthScale = 0.46,
    size = 10.4,
    sizeJitter = 1.0,
    trailMultiplier = 1.00,
  },
  Runner = {
    kind = "satellite",
    baseRadius = 230,
    radiusStep = 15,
    radiusJitter = 10,
    flatten = 0.68,
    flattenJitter = 0.09,
    depthScale = 0.40,
    size = 5.0,
    sizeJitter = 0.8,
    trailMultiplier = 1.20,
  },
  Heavy = {
    kind = "planet",
    baseRadius = 212,
    radiusStep = 20,
    radiusJitter = 11,
    flatten = 0.82,
    flattenJitter = 0.05,
    depthScale = 0.42,
    size = 18.8,
    sizeJitter = 1.6,
    trailMultiplier = 0.95,
  },
}

M.CARD_DEFS = {
  moon = {
    id = "moon",
    name = "moon",
    type = "body",
    orbitClass = "Moon",
    bodyClass = "Moon",
    cost = 1,
    starterCopies = 4,
    ope = 3,
    yieldPerOrbit = 1,
    heat = 0,
    radiusProfile = {label = "medium", mul = 1.00},
    flatnessProfile = {label = "slight", mul = 1.00},
    sizeProfile = {label = "medium", mul = 1.00},
    effect = {type = "none"},
    line = "body - moon",
    tooltip = "body - moon. ope 3. yield/orbit 1.",
  },
  runner = {
    id = "runner",
    name = "runner",
    type = "body",
    orbitClass = "Runner",
    bodyClass = "Runner",
    cost = 1,
    starterCopies = 2,
    ope = 4,
    yieldPerOrbit = 0,
    heat = 0,
    radiusProfile = {label = "large", mul = 1.12},
    flatnessProfile = {label = "flat", mul = 0.92},
    sizeProfile = {label = "small", mul = 0.82},
    effect = {type = "runner_final_orbit_next_epoch_ope", amount = 1},
    line = "body - runner",
    tooltip = "after final orbit this epoch, another body gains +1 ope next epoch.",
  },
  heavy_moon = {
    id = "heavy_moon",
    name = "heavy moon",
    type = "body",
    orbitClass = "Heavy",
    bodyClass = "Heavy",
    cost = 2,
    starterCopies = 1,
    shopPrice = 44,
    ope = 2,
    yieldPerOrbit = 3,
    heat = 2,
    radiusProfile = {label = "medium-large", mul = 1.04},
    flatnessProfile = {label = "weighty", mul = 1.00},
    sizeProfile = {label = "large", mul = 1.12},
    effect = {type = "none"},
    line = "body - heavy",
    tooltip = "body - heavy. ope 2. yield/orbit 3. heat 2.",
  },
  satellite_seed = {
    id = "satellite_seed",
    name = "satellite seed",
    type = "satellite",
    cost = 1,
    starterCopies = 1,
    shopPrice = 30,
    heat = 0,
    targetClasses = {"Moon", "Heavy"},
    effect = {
      type = "attach_satellite",
      satelliteClass = "seed",
      ope = 1,
      yieldPerOrbit = 1,
    },
    line = "attach: +1 ope, +1 yield/orbit",
    tooltip = "attach to moon or heavy. host gains +1 ope and +1 yield/orbit.",
  },
  sync_burst = {
    id = "sync_burst",
    name = "sync burst",
    type = "action",
    cost = 1,
    starterCopies = 1,
    shopPrice = 32,
    heat = 1,
    effect = {type = "next_body_or_satellite_twice"},
    line = "next body/satellite triggers twice",
    tooltip = "if body: summon a second copy. if satellite: apply its bonus twice.",
  },
  vent = {
    id = "vent",
    name = "vent",
    type = "action",
    cost = 0,
    starterCopies = 1,
    shopPrice = 20,
    heat = 0,
    effect = {type = "vent_and_draw", vent = 2, draw = 1},
    line = "-2 heat, draw 1",
    tooltip = "reduce heat by 2 and draw 1 card.",
  },
  twin_moons = {
    id = "twin_moons",
    name = "twin moons",
    type = "body",
    orbitClass = "Moon",
    bodyClass = "Moon",
    cost = 2,
    shopPrice = 38,
    ope = 2,
    yieldPerOrbit = 1,
    heat = 0,
    spawnCount = 2,
    radiusProfile = {label = "small", mul = 0.90},
    flatnessProfile = {label = "slight", mul = 1.00},
    sizeProfile = {label = "small", mul = 0.80},
    effect = {type = "none"},
    line = "summon 2 small moons",
    tooltip = "summon 2 moons. each has ope 2 and yield/orbit 1.",
  },
  echo_satellite = {
    id = "echo_satellite",
    name = "echo satellite",
    type = "satellite",
    cost = 1,
    shopPrice = 26,
    heat = 0,
    targetClasses = {"Moon", "Heavy"},
    effect = {
      type = "attach_satellite",
      satelliteClass = "echo",
      firstPayoutYield = 2,
    },
    line = "first payout each epoch: +2 yield",
    tooltip = "attach to moon or heavy. first host payout each epoch gains +2 yield.",
  },
  overclock = {
    id = "overclock",
    name = "overclock",
    type = "action",
    cost = 1,
    shopPrice = 32,
    heat = 2,
    effect = {type = "grant_this_epoch_ope", amount = 3},
    line = "a body gains +3 ope this epoch",
    tooltip = "grant +3 ope to a body for this epoch.",
  },
  cold_ring = {
    id = "cold_ring",
    name = "cold ring",
    type = "satellite",
    cost = 1,
    shopPrice = 30,
    heat = 0,
    targetClasses = {"Moon", "Heavy"},
    effect = {
      type = "attach_satellite",
      satelliteClass = "cold_ring",
      yieldPerOrbit = 1,
      finalOrbitHeatDelta = -1,
    },
    line = "attach: +1 yield/orbit, -1 heat on final orbit",
    tooltip = "attach to moon or heavy. host gets +1 yield/orbit and vents 1 heat at final orbit.",
  },
  align = {
    id = "align",
    name = "align",
    type = "action",
    cost = 1,
    shopPrice = 24,
    heat = 0,
    effect = {type = "draw_and_free_satellite", draw = 2},
    line = "draw 2. next satellite costs 0 this epoch.",
    tooltip = "draw 2 cards. the next satellite played this epoch costs 0.",
  },
}

M.STARTER_CARD_ORDER = {
  "moon",
  "runner",
  "heavy_moon",
  "satellite_seed",
  "sync_burst",
  "vent",
}

M.SHOP_CARD_ORDER = {
  "twin_moons",
  "echo_satellite",
  "overclock",
  "cold_ring",
  "align",
}

M.STARTING_DECK = {}
do
  for i = 1, #M.STARTER_CARD_ORDER do
    local id = M.STARTER_CARD_ORDER[i]
    local copies = M.CARD_DEFS[id].starterCopies or 0
    for _ = 1, copies do
      M.STARTING_DECK[#M.STARTING_DECK + 1] = id
    end
  end
end

M.BG_MUSIC_VOLUME = 0.72
M.BG_MUSIC_LOOP_FADE_SECONDS = 0.28
M.BG_MUSIC_DUCK_SECONDS = 0.22
M.BG_MUSIC_DUCK_GAIN = 0.42

M.UPGRADE_FX_VOLUME = 0.9
M.UPGRADE_FX_FADE_IN_SECONDS = 0.03
M.UPGRADE_FX_START_OFFSET_SECONDS = 0.008

M.CLICK_FX_VOLUME_OPEN = 0.50
M.CLICK_FX_VOLUME_CLOSE = 0.43
M.CLICK_FX_PITCH_OPEN = 1.0
M.CLICK_FX_PITCH_CLOSE = 0.88
M.CLICK_FX_MENU_PITCH_MIN = 0.92
M.CLICK_FX_MENU_PITCH_MAX = 1.08

M.SELECTED_ORBIT_COLOR = {1.0000, 0.5098, 0.4549, 1}
M.SPHERE_SHADE_STYLE_OFF = {
  contrast = 1.08,
  darkFloor = M.BODY_SHADE_DARK_FLOOR_TONE,
  toneSteps = 0,
  facetSides = 0,
  ditherStrength = 0,
  ditherScale = 1,
}
M.SPHERE_SHADE_STYLE_ON = {
  contrast = 0.94,
  darkFloor = M.BODY_SHADE_DARK_FLOOR_TONE + 0.01,
  toneSteps = 12,
  facetSides = 0,
  ditherStrength = 0.012,
  ditherScale = 1.60,
}

M.swatch = {
  brightest = {1.0000, 0.5098, 0.4549, 1},
  bright = {0.8353, 0.2353, 0.4157, 1},
  mid = {0.4863, 0.0941, 0.2353, 1},
  dim = {0.2745, 0.0549, 0.1686, 1},
  dimmest = {0.1922, 0.0196, 0.1176, 1},
  nearDark = {0.1216, 0.0196, 0.0627, 1},
  darkest = {0.0745, 0.0078, 0.0314, 1},
}

M.palette = {
  space = M.swatch.darkest,
  nebulaA = M.swatch.nearDark,
  nebulaB = M.swatch.dimmest,
  starA = M.swatch.mid,
  starB = M.swatch.brightest,
  orbit = M.swatch.dim,
  panel = M.swatch.brightest,
  panelEdge = M.swatch.brightest,
  text = M.swatch.brightest,
  muted = M.swatch.brightest,
  accent = M.swatch.mid,
  planetCore = M.swatch.mid,
  planetDark = M.swatch.dimmest,
  planetMid = M.swatch.dim,
  planetLight = M.swatch.brightest,
  moonFront = M.swatch.brightest,
  moonBack = M.swatch.mid,
  satelliteFront = M.swatch.brightest,
  satelliteBack = M.swatch.dim,
  trail = {M.swatch.bright[1], M.swatch.bright[2], M.swatch.bright[3], 0.35},
  satelliteTrail = {M.swatch.mid[1], M.swatch.mid[2], M.swatch.mid[3], 0.35},
}

M.paletteSwatches = {
  M.swatch.brightest,
  M.swatch.bright,
  M.swatch.mid,
  M.swatch.dim,
  M.swatch.dimmest,
  M.swatch.nearDark,
  M.swatch.darkest,
}

M.orbitColorCycle = {
  M.swatch.brightest,
  M.swatch.bright,
  M.swatch.mid,
  M.swatch.dim,
  M.swatch.dimmest,
}

return M
