local ProgressionSystem = {}
ProgressionSystem.__index = ProgressionSystem

local DEFAULT_SKILL_POINT_INTERVAL = 500

local DEFAULT_SKILL_TREE = {
  -- Intentionally no active effect until a future UI spends points.
  click_specialist_1 = {
    branch = "click",
    cost = 1,
    requires = nil,
    modifiers = {
      planet_click_impulse_boost = {mul = 1.08},
    },
  },
  satellite_specialist_1 = {
    branch = "satellite",
    cost = 1,
    requires = nil,
    modifiers = {
      speed_satellite = {mul = 1.06},
      speed_moon_satellite = {mul = 1.06},
    },
  },
  moon_specialist_1 = {
    branch = "moon",
    cost = 1,
    requires = nil,
    modifiers = {
      speed_moon = {mul = 1.07},
    },
  },
}

local DEFAULT_PERKS = {
  -- Placeholder examples for future progression design.
  -- Keep disabled so current gameplay is preserved until explicitly enabled.
  moon_cluster_1 = {
    enabled = false,
    threshold = 3,
    modifiers = {
      speed_moon = {mul = 1.05},
    },
  },
  moon_cluster_2 = {
    enabled = false,
    threshold = 5,
    modifiers = {
      speed_moon_satellite = {mul = 1.08},
    },
  },
}

local function cloneTable(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, entry in pairs(value) do
    copy[key] = cloneTable(entry)
  end
  return copy
end

local function mergeModifiers(target, source)
  for stat, entry in pairs(source or {}) do
    local existing = target[stat]
    if not existing then
      target[stat] = {add = entry.add or 0, mul = entry.mul or 1}
    else
      existing.add = (existing.add or 0) + (entry.add or 0)
      existing.mul = (existing.mul or 1) * (entry.mul or 1)
    end
  end
end

local function ensureProgressionState(state, skillPointInterval)
  local progression = state.progression
  if type(progression) ~= "table" then
    progression = {}
    state.progression = progression
  end

  progression.skillPoints = tonumber(progression.skillPoints) or 0
  progression.spentSkillPoints = tonumber(progression.spentSkillPoints) or 0
  progression.totalOrbitsEarned = tonumber(progression.totalOrbitsEarned) or 0
  progression.nextSkillPointOrbit = tonumber(progression.nextSkillPointOrbit) or skillPointInterval
  progression.unlockedSkills = progression.unlockedSkills or {}
  progression.unlockedPerks = progression.unlockedPerks or {}
  return progression
end

function ProgressionSystem.new(opts)
  opts = opts or {}

  local self = {
    state = assert(opts.state, "ProgressionSystem requires state"),
    modifiers = assert(opts.modifiers, "ProgressionSystem requires modifiers"),
    skillPointInterval = opts.skillPointInterval or DEFAULT_SKILL_POINT_INTERVAL,
    skillTree = cloneTable(opts.skillTree or DEFAULT_SKILL_TREE),
    perks = cloneTable(opts.perks or DEFAULT_PERKS),
  }

  setmetatable(self, ProgressionSystem)
  ensureProgressionState(self.state, self.skillPointInterval)
  self:syncModifiers()
  return self
end

function ProgressionSystem:getState()
  return ensureProgressionState(self.state, self.skillPointInterval)
end

function ProgressionSystem:grantSkillPoints(amount)
  local count = math.max(0, math.floor(tonumber(amount) or 0))
  if count == 0 then
    return
  end
  local progression = self:getState()
  progression.skillPoints = progression.skillPoints + count
end

function ProgressionSystem:onOrbitsEarned(count)
  local gained = math.max(0, math.floor(tonumber(count) or 0))
  if gained == 0 then
    return
  end

  local progression = self:getState()
  progression.totalOrbitsEarned = progression.totalOrbitsEarned + gained

  if self.skillPointInterval <= 0 then
    return
  end

  while progression.totalOrbitsEarned >= progression.nextSkillPointOrbit do
    progression.skillPoints = progression.skillPoints + 1
    progression.nextSkillPointOrbit = progression.nextSkillPointOrbit + self.skillPointInterval
  end
end

function ProgressionSystem:canUnlockSkill(skillId)
  local definition = self.skillTree[skillId]
  if not definition then
    return false
  end

  local progression = self:getState()
  if progression.unlockedSkills[skillId] then
    return false
  end

  local requires = definition.requires
  if requires and not progression.unlockedSkills[requires] then
    return false
  end

  local cost = math.max(0, math.floor(tonumber(definition.cost) or 0))
  return progression.skillPoints >= cost
end

function ProgressionSystem:unlockSkill(skillId)
  if not self:canUnlockSkill(skillId) then
    return false
  end

  local definition = self.skillTree[skillId]
  local progression = self:getState()
  local cost = math.max(0, math.floor(tonumber(definition.cost) or 0))
  progression.skillPoints = progression.skillPoints - cost
  progression.spentSkillPoints = progression.spentSkillPoints + cost
  progression.unlockedSkills[skillId] = true
  self:syncModifiers()
  return true
end

function ProgressionSystem:evaluatePerks()
  local progression = self:getState()
  local moonCount = #(self.state.moons or {})
  local changed = false

  for perkId, definition in pairs(self.perks) do
    if definition.enabled and not progression.unlockedPerks[perkId] then
      if moonCount >= (definition.threshold or math.huge) then
        progression.unlockedPerks[perkId] = true
        changed = true
      end
    end
  end

  if changed then
    self:syncModifiers()
  end
end

function ProgressionSystem:syncModifiers()
  local progression = self:getState()

  local skillModifiers = {}
  for skillId, unlocked in pairs(progression.unlockedSkills) do
    if unlocked then
      local definition = self.skillTree[skillId]
      if definition then
        mergeModifiers(skillModifiers, definition.modifiers)
      end
    end
  end

  local perkModifiers = {}
  for perkId, unlocked in pairs(progression.unlockedPerks) do
    if unlocked then
      local definition = self.perks[perkId]
      if definition then
        mergeModifiers(perkModifiers, definition.modifiers)
      end
    end
  end

  self.modifiers:replaceSource("progression.skills", skillModifiers)
  self.modifiers:replaceSource("progression.perks", perkModifiers)
end

function ProgressionSystem:update()
  self:evaluatePerks()
end

return ProgressionSystem
