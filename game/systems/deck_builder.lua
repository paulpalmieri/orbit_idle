local DeckBuilderSystem = {}
DeckBuilderSystem.__index = DeckBuilderSystem

local function clampCurrency(value)
  local amount = math.floor(tonumber(value) or 0)
  if amount < 0 then
    return 0
  end
  return amount
end

local function buildDisplayOrder(config)
  local seen = {}
  local order = {}

  local function append(cardId)
    if seen[cardId] then
      return
    end
    seen[cardId] = true
    order[#order + 1] = cardId
  end

  for i = 1, #(config.STARTER_CARD_ORDER or {}) do
    append(config.STARTER_CARD_ORDER[i])
  end
  for i = 1, #(config.SHOP_CARD_ORDER or {}) do
    append(config.SHOP_CARD_ORDER[i])
  end

  local extras = {}
  for cardId in pairs(config.CARD_DEFS or {}) do
    if not seen[cardId] then
      extras[#extras + 1] = cardId
    end
  end
  table.sort(extras)
  for i = 1, #extras do
    append(extras[i])
  end

  return order
end

local function copyList(list)
  local out = {}
  for i = 1, #list do
    out[#out + 1] = list[i]
  end
  return out
end

function DeckBuilderSystem.new(opts)
  opts = opts or {}

  local minDeckSize = math.max(1, math.floor(tonumber(opts.minDeckSize) or 10))
  local maxDeckSize = math.max(minDeckSize, math.floor(tonumber(opts.maxDeckSize) or 20))

  local self = {
    state = assert(opts.state, "DeckBuilderSystem requires state"),
    config = assert(opts.config, "DeckBuilderSystem requires config"),
    startingCurrency = clampCurrency(opts.startingCurrency or 100),
    minDeckSize = minDeckSize,
    maxDeckSize = maxDeckSize,
  }

  self.displayOrder = buildDisplayOrder(self.config)
  setmetatable(self, DeckBuilderSystem)
  self:ensureState()
  return self
end

function DeckBuilderSystem:getMinDeckSize()
  return self.minDeckSize
end

function DeckBuilderSystem:getMaxDeckSize()
  return self.maxDeckSize
end

function DeckBuilderSystem:getDeckSize()
  self:ensureState()
  return #self.state.deckList
end

function DeckBuilderSystem:normalizeDeckBounds()
  local deck = self.state.deckList
  local inventory = self.state.inventory

  while #deck > self.maxDeckSize do
    local cardId = deck[#deck]
    deck[#deck] = nil
    if cardId and self.config.CARD_DEFS[cardId] then
      inventory[cardId] = (inventory[cardId] or 0) + 1
    end
  end

  while #deck < self.minDeckSize do
    local movedFromInventory = false
    for i = 1, #self.displayOrder do
      local cardId = self.displayOrder[i]
      local available = inventory[cardId] or 0
      if available > 0 then
        inventory[cardId] = available - 1
        deck[#deck + 1] = cardId
        movedFromInventory = true
        break
      end
    end

    if not movedFromInventory then
      local fallbackId = nil
      local startingDeck = self.config.STARTING_DECK or {}
      if #startingDeck > 0 then
        fallbackId = startingDeck[((#deck) % #startingDeck) + 1]
      elseif #self.displayOrder > 0 then
        fallbackId = self.displayOrder[1]
      end

      if not fallbackId then
        break
      end
      deck[#deck + 1] = fallbackId
    end
  end
end

function DeckBuilderSystem:ensureState()
  if type(self.state.inventory) ~= "table" then
    self.state.inventory = {}
  end

  if type(self.state.deckList) ~= "table" then
    self.state.deckList = copyList(self.config.STARTING_DECK or {})
  end

  local normalizedDeck = {}
  for i = 1, #self.state.deckList do
    local cardId = self.state.deckList[i]
    if self.config.CARD_DEFS[cardId] then
      normalizedDeck[#normalizedDeck + 1] = cardId
    end
  end
  self.state.deckList = normalizedDeck

  local normalizedInventory = {}
  for cardId, count in pairs(self.state.inventory) do
    if self.config.CARD_DEFS[cardId] then
      local normalized = clampCurrency(count)
      if normalized > 0 then
        normalizedInventory[cardId] = normalized
      end
    end
  end
  self.state.inventory = normalizedInventory

  self:normalizeDeckBounds()

  if self.state.currency == nil then
    self.state.currency = self.startingCurrency
  end
  self.state.currency = clampCurrency(self.state.currency)
end

function DeckBuilderSystem:getDeckListCopy()
  self:ensureState()
  return copyList(self.state.deckList)
end

function DeckBuilderSystem:getCurrency()
  self:ensureState()
  return self.state.currency
end

function DeckBuilderSystem:addCurrency(amount)
  self:ensureState()
  local gain = clampCurrency(amount)
  self.state.currency = self.state.currency + gain
end

function DeckBuilderSystem:getDeckCounts()
  self:ensureState()
  local counts = {}
  for i = 1, #self.state.deckList do
    local cardId = self.state.deckList[i]
    counts[cardId] = (counts[cardId] or 0) + 1
  end
  return counts
end

function DeckBuilderSystem:getInventoryCounts()
  self:ensureState()
  local counts = {}
  for cardId, count in pairs(self.state.inventory) do
    local normalized = clampCurrency(count)
    if normalized > 0 then
      counts[cardId] = normalized
    end
  end
  return counts
end

function DeckBuilderSystem:listDeckEntries()
  local counts = self:getDeckCounts()
  local list = {}
  for i = 1, #self.displayOrder do
    local cardId = self.displayOrder[i]
    local count = counts[cardId] or 0
    if count > 0 then
      list[#list + 1] = {id = cardId, count = count}
    end
  end
  return list
end

function DeckBuilderSystem:listInventoryEntries()
  local counts = self:getInventoryCounts()
  local list = {}
  for i = 1, #self.displayOrder do
    local cardId = self.displayOrder[i]
    local count = counts[cardId] or 0
    if count > 0 then
      list[#list + 1] = {id = cardId, count = count}
    end
  end
  return list
end

function DeckBuilderSystem:canRemoveFromDeck(_)
  self:ensureState()
  return #self.state.deckList > self.minDeckSize
end

function DeckBuilderSystem:canAddToDeck(cardId)
  self:ensureState()
  if #self.state.deckList >= self.maxDeckSize then
    return false
  end
  return (self.state.inventory[cardId] or 0) > 0
end

function DeckBuilderSystem:removeFromDeck(cardId)
  self:ensureState()
  if not self:canRemoveFromDeck(cardId) then
    return false
  end

  local deck = self.state.deckList
  for i = 1, #deck do
    if deck[i] == cardId then
      table.remove(deck, i)
      self.state.inventory[cardId] = (self.state.inventory[cardId] or 0) + 1
      return true
    end
  end
  return false
end

function DeckBuilderSystem:addToDeck(cardId)
  self:ensureState()
  if not self:canAddToDeck(cardId) then
    return false
  end

  local available = self.state.inventory[cardId] or 0
  self.state.inventory[cardId] = available - 1
  self.state.deckList[#self.state.deckList + 1] = cardId
  return true
end

function DeckBuilderSystem:buyShopCard(cardId)
  self:ensureState()
  local cardDef = self.config.CARD_DEFS[cardId]
  if not cardDef then
    return false
  end

  local price = clampCurrency(cardDef.shopPrice)
  if price <= 0 then
    return false
  end
  if self.state.currency < price then
    return false
  end

  self.state.currency = self.state.currency - price
  self.state.inventory[cardId] = (self.state.inventory[cardId] or 0) + 1
  return true
end

return DeckBuilderSystem
