local ProgressionContent = {}

function ProgressionContent.build(upgradeEffects)
  local skillChoiceTiers = {
    starter = {
      id = "starter",
      title = "first upgrade choice",
      options = {"stabilizer_lattice", "tighter_burn"},
      exclusive = true,
    },
    focus = {
      id = "focus",
      title = "build identity choice",
      options = {"resonant_core", "reinforced_orbit"},
      exclusive = true,
    },
    variant = {
      id = "variant",
      title = "moon variant unlock",
      options = {"heavy_moon", "glass_moon"},
      exclusive = true,
    },
  }

  local objectiveDefs = {
    reach_60_rpm = {
      label = "reach 60 rpm",
      type = "rpm",
      target = 60,
      reward = 1,
    },
    reach_80_rpm = {
      label = "reach 80 rpm",
      type = "rpm",
      target = 80,
      reward = 1,
    },
    reach_100_rpm = {
      label = "reach 100 rpm",
      type = "rpm",
      target = 100,
      reward = 1,
    },
    reach_120_rpm = {
      label = "reach 120 rpm",
      type = "rpm",
      target = 120,
      reward = 1,
      category = "path",
    },
    perfect_6_run = {
      label = "land 6 perfect hits in one run",
      type = "perfect_hits",
      target = 6,
      reward = 1,
      category = "path",
    },
    trial_collapse_above_90 = {
      label = "reach 100 rpm and collapse above 90 rpm",
      type = "collapse_after_rpm",
      peakRequired = 100,
      collapseMin = 90,
      reward = 1,
    },
    trial_perfect_8_run = {
      label = "land 8 perfect hits before collapse",
      type = "perfect_hits",
      target = 8,
      reward = 1,
      optional = true,
    },
    variant_heavy_110 = {
      label = "reach 110 rpm with heavy moon",
      type = "rpm",
      target = 110,
      reward = 1,
      requiredVariant = "heavy_moon",
    },
    variant_glass_130 = {
      label = "break 130 rpm with glass moon",
      type = "rpm",
      target = 130,
      reward = 1,
      requiredVariant = "glass_moon",
    },
    reach_150_rpm = {
      label = "reach 150 rpm",
      type = "rpm",
      target = 150,
      reward = 1,
    },
    perfect_10_run = {
      label = "land 10 perfect hits in one run",
      type = "perfect_hits",
      target = 10,
      reward = 1,
    },
    collapse_after_120 = {
      label = "collapse after reaching 120+ rpm",
      type = "collapse_after_rpm",
      peakRequired = 120,
      collapseMin = 1,
      reward = 1,
    },
    recover_critical_100 = {
      label = "recover from critical stability and still reach 100 rpm",
      type = "critical_recover_rpm",
      target = 100,
      reward = 1,
    },
    two_objectives_single_run = {
      label = "complete 2 objectives in one run",
      type = "objectives_in_run",
      target = 2,
      reward = 1,
    },
  }

  local objectiveOrder = {
    "reach_60_rpm",
    "reach_80_rpm",
    "reach_100_rpm",
    "reach_120_rpm",
    "perfect_6_run",
    "trial_collapse_above_90",
    "trial_perfect_8_run",
    "variant_heavy_110",
    "variant_glass_130",
    "reach_150_rpm",
    "perfect_10_run",
    "collapse_after_120",
    "recover_critical_100",
    "two_objectives_single_run",
  }

  local skillTreeNodes = {
    {
      id = "stabilizer_lattice",
      tier = "starter",
      label = "stabilizer lattice",
      x = -250,
      y = -84,
      tooltipLines = {
        {
          pre = "Perfect hits restore ",
          hi = string.format("+%d%% more stability", math.floor((upgradeEffects.stabilizer_lattice.perfectStabilityMultiplier - 1) * 100 + 0.5)),
          post = ".",
        },
        {
          pre = "Safer line for longer runs and cleaner finishes.",
          hi = "",
          post = "",
        },
      },
    },
    {
      id = "tighter_burn",
      tier = "starter",
      label = "tighter burn",
      x = -250,
      y = 84,
      tooltipLines = {
        {
          pre = "Perfect hits grant ",
          hi = string.format("+%d%% speed", math.floor((upgradeEffects.tighter_burn.perfectPermMultiplier - 1) * 100 + 0.5)),
          post = " from permanent gains.",
        },
        {
          pre = "Burst gain also receives a smaller bonus.",
          hi = "",
          post = ".",
        },
      },
    },
    {
      id = "reinforced_orbit",
      tier = "focus",
      label = "reinforced orbit",
      x = -6,
      y = -84,
      tooltipLines = {
        {
          pre = "Instability rises ",
          hi = string.format("%d%% slower", math.floor((1 - upgradeEffects.reinforced_orbit.passiveInstabilityMultiplier) * 100 + 0.5)),
          post = " at all speeds.",
        },
        {
          pre = "Best for threshold consistency and trial objectives.",
          hi = "",
          post = "",
        },
      },
    },
    {
      id = "resonant_core",
      tier = "focus",
      label = "resonant core",
      x = -6,
      y = 84,
      tooltipLines = {
        {
          pre = "Consecutive perfects gain escalating speed bonuses.",
          hi = "",
          post = "",
        },
        {
          pre = "Amplifies streak-based high burst runs.",
          hi = "",
          post = "",
        },
      },
    },
    {
      id = "heavy_moon",
      tier = "variant",
      label = "heavy moon",
      x = 232,
      y = -84,
      tooltipLines = {
        {
          pre = "Slower acceleration, lower peak burst, easier control.",
          hi = "",
          post = "",
        },
        {
          pre = "Good for precision contracts.",
          hi = "",
          post = "",
        },
      },
    },
    {
      id = "glass_moon",
      tier = "variant",
      label = "glass moon",
      x = 232,
      y = 84,
      tooltipLines = {
        {
          pre = "Higher acceleration with harsher stability pressure.",
          hi = "",
          post = "",
        },
        {
          pre = "Best for aggressive speed spikes.",
          hi = "",
          post = "",
        },
      },
    },
  }

  local skillTreeLinks = {
    {"stabilizer_lattice", "reinforced_orbit"},
    {"tighter_burn", "resonant_core"},
    {"reinforced_orbit", "heavy_moon"},
    {"resonant_core", "glass_moon"},
  }

  return {
    skillChoiceTiers = skillChoiceTiers,
    objectiveDefs = objectiveDefs,
    objectiveOrder = objectiveOrder,
    skillTreeNodes = skillTreeNodes,
    skillTreeLinks = skillTreeLinks,
  }
end

return ProgressionContent
