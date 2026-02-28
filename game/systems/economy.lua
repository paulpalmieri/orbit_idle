local EconomySystem = {}
EconomySystem.__index = EconomySystem

local DEFAULT_COSTS = {
  moon = 50,
  planet = 1000,
  megaPlanet = 5000,
  satellite = 5,
  moonSatellite = 10,
  speedWave = 25,
  speedClick = 15,
  blackHoleShader = 100,
}

local function roundCost(value)
  local rounded = math.floor((value or 0) + 0.5)
  if rounded < 0 then
    return 0
  end
  return rounded
end

function EconomySystem.new(opts)
  opts = opts or {}
  local self = {
    state = assert(opts.state, "EconomySystem requires state"),
    modifiers = assert(opts.modifiers, "EconomySystem requires modifiers"),
    costs = opts.costs or DEFAULT_COSTS,
  }
  return setmetatable(self, EconomySystem)
end

function EconomySystem:getCost(costId)
  local baseCost = self.costs[costId]
  if baseCost == nil then
    error("Unknown cost id: " .. tostring(costId))
  end

  local stat = "cost_" .. costId
  local computed = self.modifiers:apply(stat, baseCost)
  local rounded = roundCost(computed)
  if baseCost > 0 and rounded < 1 then
    return 1
  end
  return rounded
end

function EconomySystem:canAffordCost(costId)
  return self.state.orbits >= self:getCost(costId)
end

function EconomySystem:trySpendCost(costId)
  local amount = self:getCost(costId)
  if self.state.orbits < amount then
    return false, amount
  end
  self.state.orbits = self.state.orbits - amount
  return true, amount
end

return EconomySystem
