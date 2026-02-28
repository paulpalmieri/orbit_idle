local ModifierSystem = {}
ModifierSystem.__index = ModifierSystem

local function normalizeEntry(entry)
  if type(entry) ~= "table" then
    return {add = 0, mul = 1}
  end
  local add = tonumber(entry.add) or 0
  local mul = tonumber(entry.mul) or 1
  return {add = add, mul = mul}
end

function ModifierSystem.new()
  local self = {
    bySource = {},
    cache = {},
  }
  return setmetatable(self, ModifierSystem)
end

function ModifierSystem:clearSource(sourceId)
  if sourceId == nil then
    return
  end
  self.bySource[sourceId] = nil
  self.cache = {}
end

function ModifierSystem:replaceSource(sourceId, modifiers)
  if sourceId == nil then
    return
  end
  local normalized = {}
  for stat, entry in pairs(modifiers or {}) do
    normalized[stat] = normalizeEntry(entry)
  end
  self.bySource[sourceId] = normalized
  self.cache = {}
end

function ModifierSystem:get(stat)
  local cached = self.cache[stat]
  if cached then
    return cached
  end

  local aggregate = {add = 0, mul = 1}
  for _, sourceEntries in pairs(self.bySource) do
    local entry = sourceEntries[stat]
    if entry then
      aggregate.add = aggregate.add + entry.add
      aggregate.mul = aggregate.mul * entry.mul
    end
  end

  self.cache[stat] = aggregate
  return aggregate
end

function ModifierSystem:getAdd(stat)
  return self:get(stat).add
end

function ModifierSystem:getMul(stat)
  return self:get(stat).mul
end

function ModifierSystem:apply(stat, baseValue)
  local entry = self:get(stat)
  return (baseValue + entry.add) * entry.mul
end

return ModifierSystem
