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

M.UI_FONT_SIZE = 24
M.MAX_MOONS = 64
M.MAX_SATELLITES = 64
M.STARTING_HAND_SIZE = 5
M.TURN_ENERGY = 5
M.MAX_TURNS = 4
M.OBJECTIVE_RPM = 40
M.CORE_BASE_RPM = 6
M.HEAT_CAP = 10
M.END_TURN_HEAT_GAIN = 1

M.CARD_W = 176
M.CARD_H = 104
M.CARD_GAP = 10
M.END_TURN_W = 118
M.END_TURN_H = 34

M.CARD_DEFS = {
  moonseed = {
    id = "moonseed",
    name = "moonseed",
    cost = 2,
    starterCopies = 4,
    isMoonCard = true,
    line = "summon moon 4 rpm",
    tooltip = "Summon a Moon with 4 RPM. Gain 1 Heat.",
  },
  coolant_vent = {
    id = "coolant_vent",
    name = "coolant vent",
    cost = 1,
    starterCopies = 4,
    line = "vent 2",
    tooltip = "Vent 2.",
  },
  spin_up = {
    id = "spin_up",
    name = "spin up",
    cost = 1,
    starterCopies = 2,
    line = "spin +1",
    tooltip = "All Moons gain +1 RPM permanently this run. Gain 1 Heat.",
  },
  overclock = {
    id = "overclock",
    name = "overclock",
    cost = 1,
    starterCopies = 2,
    line = "overclock +2",
    tooltip = "This turn, all Moons gain +2 RPM. Gain 1 Heat.",
  },
  heavy_moon = {
    id = "heavy_moon",
    name = "heavy moon",
    cost = 2,
    shopPrice = 30,
    isMoonCard = true,
    line = "summon heavy 6 rpm",
    tooltip = "Summon Heavy Moon with 6 RPM. Gain 2 Heat.",
  },
  twin_seed = {
    id = "twin_seed",
    name = "twin seed",
    cost = 3,
    shopPrice = 35,
    isMoonCard = true,
    line = "summon 2x moon 3",
    tooltip = "Summon 2 Moons with 3 RPM each. Gain 2 Heat.",
  },
  precision_spin = {
    id = "precision_spin",
    name = "precision spin",
    cost = 1,
    shopPrice = 35,
    line = "spin +2",
    tooltip = "All Moons gain +2 RPM permanently this run. Gain 2 Heat.",
  },
  cold_sink = {
    id = "cold_sink",
    name = "cold sink",
    cost = 1,
    shopPrice = 25,
    line = "vent 4",
    tooltip = "Vent 4.",
  },
  redline = {
    id = "redline",
    name = "redline",
    cost = 1,
    shopPrice = 40,
    line = "overclock +4",
    tooltip = "This turn, all Moons gain +4 RPM. Gain 2 Heat.",
  },
  containment = {
    id = "containment",
    name = "containment",
    cost = 1,
    shopPrice = 30,
    line = "vent 2, next -1 heat",
    tooltip = "Vent 2. Next card this turn gains -1 Heat.",
  },
  compression = {
    id = "compression",
    name = "compression",
    cost = 1,
    shopPrice = 35,
    line = "next moon cheaper +2",
    tooltip = "Next Moon card this turn costs 1 less and gains +2 RPM.",
  },
  reactor_feed = {
    id = "reactor_feed",
    name = "reactor feed",
    cost = 0,
    shopPrice = 30,
    line = "+1 energy this turn",
    tooltip = "Gain +1 Energy this turn. Gain 1 Heat.",
  },
  resonant_burst = {
    id = "resonant_burst",
    name = "resonant burst",
    cost = 2,
    shopPrice = 45,
    line = "+2 rpm this turn/moon",
    tooltip = "Gain +2 RPM this turn per Moon. Gain 2 Heat.",
  },
  anchor = {
    id = "anchor",
    name = "anchor",
    cost = 2,
    shopPrice = 40,
    line = "summon anchor 2 rpm",
    tooltip = "Summon Anchor with 2 RPM. End-turn Heat gain -1.",
  },
}

M.STARTER_CARD_ORDER = {"moonseed", "coolant_vent", "spin_up", "overclock"}
M.SHOP_CARD_ORDER = {
  "heavy_moon",
  "twin_seed",
  "precision_spin",
  "cold_sink",
  "redline",
  "containment",
  "compression",
  "reactor_feed",
  "resonant_burst",
  "anchor",
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
