local M = {}

M.GAME_W = 1280
M.GAME_H = 720
M.TWO_PI = math.pi * 2
M.RAD_PER_SECOND_TO_RPM = 60 / M.TWO_PI
M.RPM_TO_RAD_PER_SECOND = M.TWO_PI / 60

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
M.TRAIL_LAG_SECONDS = 2.0
M.TRAIL_MAX_ARC_TURNS = 2.3

M.UI_FONT_SIZE = 24
M.MAX_MOONS = 64
M.MAX_SATELLITES = 64
M.MAX_PLANETS = 64
M.STARTING_HAND_SIZE = 5
M.TURN_ENERGY = 5
M.MAX_TURNS = 4
M.OBJECTIVE_RPM = 40
M.CORE_BASE_RPM = 0
M.HEAT_CAP = 10
M.END_TURN_HEAT_GAIN = 1
M.MIN_BODY_VISUAL_RPM = 1.8

M.CARD_W = 124
M.CARD_H = 176
M.CARD_GAP = 12
M.END_TURN_W = 118
M.END_TURN_H = 34

M.ORBIT_CLASS_DEFAULTS = {
  Runner = {
    kind = "satellite",
    baseRadius = 242,
    radiusStep = 16,
    radiusJitter = 12,
    flatten = 0.64,
    flattenJitter = 0.10,
    depthScale = 0.36,
    size = 5.2,
    sizeJitter = 0.8,
    speedMultiplier = 2.05,
    minVisualRpm = 3.2,
    trailMultiplier = 1.20,
  },
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
    speedMultiplier = 1.24,
    minVisualRpm = 2.4,
    trailMultiplier = 1.00,
  },
  Core = {
    kind = "satellite",
    baseRadius = 112,
    radiusStep = 10,
    radiusJitter = 8,
    flatten = 0.93,
    flattenJitter = 0.04,
    depthScale = 0.54,
    size = 7.1,
    sizeJitter = 0.7,
    speedMultiplier = 2.70,
    minVisualRpm = 3.8,
    trailMultiplier = 1.30,
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
    speedMultiplier = 0.90,
    minVisualRpm = 1.8,
    trailMultiplier = 0.95,
  },
}

M.CARD_DEFS = {
  moon = {
    id = "moon",
    name = "moon",
    cost = 2,
    starterCopies = 4,
    orbitClass = "Moon",
    rpm = 4,
    heat = 1,
    radiusProfile = {label = "medium", mul = 1.00},
    flatnessProfile = {label = "slight", mul = 1.00},
    sizeProfile = {label = "medium", mul = 1.00},
    effect = {type = "none"},
    line = "moon body +4 rpm",
    tooltip = "Summon a Moon body. +4 RPM, +1 Heat.",
  },
  vent_runner = {
    id = "vent_runner",
    name = "vent runner",
    cost = 1,
    starterCopies = 3,
    orbitClass = "Runner",
    rpm = 1,
    heat = 0,
    radiusProfile = {label = "large", mul = 1.12},
    flatnessProfile = {label = "flat", mul = 0.92},
    sizeProfile = {label = "small", mul = 0.82},
    effect = {type = "vent", amount = 2},
    line = "runner +1, vent 2",
    tooltip = "Summon a lively Runner. Vent 2.",
  },
  spin_core = {
    id = "spin_core",
    name = "spin core",
    cost = 1,
    starterCopies = 2,
    orbitClass = "Core",
    rpm = 2,
    heat = 1,
    radiusProfile = {label = "tight", mul = 0.90},
    flatnessProfile = {label = "tight", mul = 1.05},
    sizeProfile = {label = "small", mul = 0.90},
    effect = {type = "global_run_rpm", amount = 1},
    line = "core +2, all +1 run",
    tooltip = "Summon Core. All bodies gain +1 RPM this run.",
  },
  overclock_core = {
    id = "overclock_core",
    name = "overclock core",
    cost = 1,
    starterCopies = 2,
    orbitClass = "Core",
    rpm = 2,
    heat = 1,
    radiusProfile = {label = "tight", mul = 0.86},
    flatnessProfile = {label = "tight", mul = 1.06},
    sizeProfile = {label = "small", mul = 0.92},
    effect = {type = "global_turn_rpm", amount = 2},
    line = "core +2, all +2 turn",
    tooltip = "Summon Core. All bodies gain +2 RPM this turn.",
  },
  tuner = {
    id = "tuner",
    name = "tuner",
    cost = 1,
    starterCopies = 1,
    orbitClass = "Runner",
    rpm = 1,
    heat = 0,
    radiusProfile = {label = "wide", mul = 1.18},
    flatnessProfile = {label = "elegant", mul = 0.90},
    sizeProfile = {label = "small", mul = 0.86},
    effect = {type = "hand_rpm_buff", amount = 1, picks = 2},
    line = "runner +1, hand +1x2",
    tooltip = "Summon Runner. Up to 2 cards in hand gain +1 RPM.",
  },
  heavy_moon = {
    id = "heavy_moon",
    name = "heavy moon",
    cost = 2,
    shopPrice = 30,
    orbitClass = "Heavy",
    rpm = 6,
    heat = 2,
    radiusProfile = {label = "medium-large", mul = 1.04},
    flatnessProfile = {label = "weighty", mul = 1.00},
    sizeProfile = {label = "large", mul = 1.12},
    effect = {type = "none"},
    line = "heavy body +6 rpm",
    tooltip = "Summon a Heavy body. +6 RPM, +2 Heat.",
  },
  twin_moons = {
    id = "twin_moons",
    name = "twin moons",
    cost = 3,
    shopPrice = 35,
    orbitClass = "Moon",
    rpm = 3,
    heat = 2,
    spawnCount = 2,
    radiusProfile = {label = "medium", mul = 1.02},
    flatnessProfile = {label = "slight", mul = 1.00},
    sizeProfile = {label = "small-medium", mul = 0.88},
    effect = {type = "none"},
    line = "summon 2 moons at +3",
    tooltip = "Summon two mirrored Moon bodies at +3 RPM each.",
  },
  cold_sink = {
    id = "cold_sink",
    name = "cold sink",
    cost = 1,
    shopPrice = 25,
    orbitClass = "Runner",
    rpm = 2,
    heat = 0,
    radiusProfile = {label = "broad", mul = 1.16},
    flatnessProfile = {label = "calm", mul = 0.88},
    sizeProfile = {label = "small", mul = 0.84},
    effect = {type = "vent", amount = 3},
    line = "runner +2, vent 3",
    tooltip = "Summon Runner. Vent 3.",
  },
  precision_core = {
    id = "precision_core",
    name = "precision core",
    cost = 1,
    shopPrice = 35,
    orbitClass = "Core",
    rpm = 2,
    heat = 1,
    radiusProfile = {label = "tight", mul = 0.84},
    flatnessProfile = {label = "precise", mul = 1.08},
    sizeProfile = {label = "small", mul = 0.90},
    effect = {type = "precision_target_run_rpm", amount = 3},
    line = "core +2, one body +3 run",
    tooltip = "Summon Core. Choose a body: it gains +3 RPM this run.",
  },
  calibrator = {
    id = "calibrator",
    name = "calibrator",
    cost = 1,
    shopPrice = 35,
    orbitClass = "Runner",
    rpm = 1,
    heat = 0,
    radiusProfile = {label = "stable", mul = 1.10},
    flatnessProfile = {label = "stable", mul = 0.96},
    sizeProfile = {label = "small", mul = 0.86},
    effect = {type = "next_body_modifier", rpm = 2, heat = -1},
    line = "runner +1, next body +2 -1h",
    tooltip = "Summon Runner. Next body this turn gains +2 RPM and -1 Heat.",
  },
  redline_core = {
    id = "redline_core",
    name = "redline core",
    cost = 1,
    shopPrice = 40,
    orbitClass = "Core",
    rpm = 3,
    heat = 2,
    radiusProfile = {label = "very tight", mul = 0.78},
    flatnessProfile = {label = "aggressive", mul = 1.10},
    sizeProfile = {label = "small", mul = 0.94},
    effect = {type = "global_turn_rpm", amount = 4},
    line = "core +3, all +4 turn",
    tooltip = "Summon Core. All bodies gain +4 RPM this turn.",
  },
  anchor = {
    id = "anchor",
    name = "anchor",
    cost = 2,
    shopPrice = 40,
    orbitClass = "Heavy",
    rpm = 2,
    heat = 0,
    radiusProfile = {label = "stable", mul = 0.98},
    flatnessProfile = {label = "grounded", mul = 1.04},
    sizeProfile = {label = "large", mul = 1.08},
    effect = {type = "reduce_end_turn_heat", amount = 1},
    line = "heavy +2, end heat -1",
    tooltip = "Summon a stabilizing Heavy body. End-turn Heat gain -1.",
  },
  resonator = {
    id = "resonator",
    name = "resonator",
    cost = 2,
    shopPrice = 45,
    orbitClass = "Core",
    rpm = 2,
    heat = 2,
    radiusProfile = {label = "pulsing", mul = 0.94},
    flatnessProfile = {label = "tight", mul = 1.04},
    sizeProfile = {label = "small-medium", mul = 1.00},
    effect = {type = "resonator_turn_burst", amountPerBody = 1},
    line = "core +2, +1 per body turn",
    tooltip = "Summon Core. Gains +1 RPM this turn per body you control.",
  },
}

M.STARTER_CARD_ORDER = {"moon", "vent_runner", "spin_core", "overclock_core", "tuner"}
M.SHOP_CARD_ORDER = {
  "heavy_moon",
  "twin_moons",
  "cold_sink",
  "precision_core",
  "calibrator",
  "redline_core",
  "anchor",
  "resonator",
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
