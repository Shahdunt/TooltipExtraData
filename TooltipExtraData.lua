local addonName, TED = ...

TooltipExtraDataDB = TooltipExtraDataDB or {}

-- =========================
-- Defaults
-- =========================
local defaults = {
  enabled = true,
  colorGray = "808080",

  modules = {
    stack  = true,  -- current/max stack, or owned/max in AH/Auctionator
    itemid = true,  -- ItemID on item tooltips
    spellid = true, -- SpellID on spell tooltips
    iconid = true,  -- IconID (texture FileID) below ItemID/SpellID
  },
}

local function CopyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then
        dst[k] = {}
      end
      CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function Gray(text)
  local hex = (TooltipExtraDataDB and TooltipExtraDataDB.colorGray) or "808080"
  return "|cff" .. hex .. tostring(text) .. "|r"
end

local function Enabled()
  return TooltipExtraDataDB and TooltipExtraDataDB.enabled
end

local function ModuleOn(key)
  return Enabled() and TooltipExtraDataDB.modules and TooltipExtraDataDB.modules[key]
end

-- =========================
-- Tooltip state helpers
-- =========================
local function ensureTooltipState(tooltip)
  if not tooltip then return nil end
  tooltip.TED_State = tooltip.TED_State or {}
  return tooltip.TED_State
end

local function wasAdded(tooltip, key, value)
  local state = ensureTooltipState(tooltip)
  if not state then return false end
  return state[key] == value
end

local function markAdded(tooltip, key, value)
  local state = ensureTooltipState(tooltip)
  if not state then return end
  state[key] = value
end

local function clearTooltipState(tooltip)
  if tooltip then
    tooltip.TED_State = nil
  end
end

-- =========================
-- Tooltip helpers
-- =========================
local function getTooltipName(tooltip)
  return tooltip and tooltip.GetName and tooltip:GetName() or nil
end

local function addDoubleLine(tooltip, leftText, rightText)
  if not tooltip or not tooltip.AddDoubleLine then return end
  tooltip:AddDoubleLine(
    leftText,
    rightText,
    nil, nil, nil,
    WHITE_FONT_COLOR.r,
    WHITE_FONT_COLOR.g,
    WHITE_FONT_COLOR.b
  )
  tooltip:Show()
end

local function SafeHookScript(frame, scriptName, fn)
  if frame and frame.HasScript and frame:HasScript(scriptName) then
    frame:HookScript(scriptName, fn)
  end
end

local function GetItemIDFromLink(link)
  if not link then return nil end
  return tonumber(link:match("item:(%d+)"))
end

local function GetItemIDFromItemKey(...)
  local a1, a2 = ...
  if type(a1) == "table" then
    return tonumber(a1.itemID or a1.itemId or a1.id)
  end
  if type(a1) == "number" then
    return tonumber(a1)
  end
  if type(a2) == "number" then
    return tonumber(a2)
  end
  return nil
end

local function NormalizeCount(count)
  if count == nil then
    return nil
  end

  local ok, n = pcall(function()
    return tonumber(count)
  end)

  if ok and n ~= nil then
    return n
  end

  return nil
end

local function ExtractCountFromTooltipData(data)
  if type(data) ~= "table" then return nil end

  local count = data.stackCount
    or data.quantity
    or data.count
    or data.itemCount
    or data.stackSize
    or data.charges

  return NormalizeCount(count)
end

local function ExtractItemIDFromAny(data)
  if type(data) ~= "table" then return nil end

  return tonumber(
    data.itemID
    or data.itemId
    or data.id
    or (type(data.itemKey) == "table" and (data.itemKey.itemID or data.itemKey.itemId))
    or (type(data.itemKeyInfo) == "table" and (data.itemKeyInfo.itemID or data.itemKeyInfo.itemId))
    or (type(data.auctionInfo) == "table" and (data.auctionInfo.itemID or data.auctionInfo.itemId))
  )
end

local function ExtractCountFromAny(data)
  if type(data) ~= "table" then return nil end

  return NormalizeCount(
    data.quantity
    or data.stackCount
    or data.count
    or data.itemCount
    or data.stackSize
  )
end

local function GetOwnedItemCount(itemId)
  if not itemId or not GetItemCount then
    return 0
  end

  local ok, count = pcall(GetItemCount, itemId)
  if not ok or count == nil then
    return 0
  end

  local normalized = NormalizeCount(count)
  if normalized == nil then
    return 0
  end

  return normalized
end

-- =========================
-- API wrappers
-- =========================
local GetItemMaxStackSizeByID = (C_Item and C_Item.GetItemMaxStackSizeByID) and C_Item.GetItemMaxStackSizeByID
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) and C_Item.GetItemIconByID or GetItemIconByID
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture or GetSpellTexture

-- =========================
-- Modules
-- =========================
TED.Modules = {}

-- ---- Stack module
function TED.Modules.Stack(tooltip, itemId, currentCount)
  if not ModuleOn("stack") then return end
  if not GetItemMaxStackSizeByID then return end
  if not tooltip or not itemId or currentCount == nil then return end

  local itemIdNum = tonumber(itemId)
  local currentNum = NormalizeCount(currentCount)
  if not itemIdNum or currentNum == nil then return end

  local maxStack = GetItemMaxStackSizeByID(itemIdNum)
  if not maxStack then return end

  local maxNum = NormalizeCount(maxStack)
  if maxNum == nil or maxNum <= 1 then return end

  local name = getTooltipName(tooltip)
  if not name then return end

  local right1 = _G[name .. "TextRight1"]
  if not right1 then return end

  local displayText = tostring(currentNum) .. "/" .. tostring(maxNum)
  if wasAdded(tooltip, "stack", displayText) then return end

  right1:SetText(Gray(displayText))
  right1:Show()
  tooltip:Show()

  markAdded(tooltip, "stack", displayText)
end

-- ---- ItemID module
function TED.Modules.ItemID(tooltip, itemId)
  if not ModuleOn("itemid") then return end
  if not tooltip or not itemId then return end

  itemId = tonumber(itemId)
  if not itemId then return end

  if wasAdded(tooltip, "itemid", itemId) then return end
  addDoubleLine(tooltip, "ItemID", tostring(itemId))
  markAdded(tooltip, "itemid", itemId)
end

-- ---- SpellID module
function TED.Modules.SpellID(tooltip, spellId)
  if not ModuleOn("spellid") then return end
  if not tooltip or not spellId then return end

  spellId = tonumber(spellId)
  if not spellId then return end

  if wasAdded(tooltip, "spellid", spellId) then return end
  addDoubleLine(tooltip, "SpellID", tostring(spellId))
  markAdded(tooltip, "spellid", spellId)
end

-- ---- IconID module
function TED.Modules.IconID(tooltip, iconId)
  if not ModuleOn("iconid") then return end
  if not tooltip or not iconId then return end

  iconId = tonumber(iconId)
  if not iconId then return end

  if wasAdded(tooltip, "iconid", iconId) then return end
  addDoubleLine(tooltip, "IconID", tostring(iconId))
  markAdded(tooltip, "iconid", iconId)
end

-- =========================
-- Common item/spell appliers
-- =========================
local function ApplyItemModules(tooltip, itemId, count)
  if not Enabled() then return end
  if not tooltip or not itemId then return end

  itemId = tonumber(itemId)
  if not itemId then return end

  if count ~= nil then
    count = NormalizeCount(count)
    if count ~= nil then
      TED.Modules.Stack(tooltip, itemId, count)
    end
  end

  TED.Modules.ItemID(tooltip, itemId)

  local iconId = GetItemIconByID and GetItemIconByID(itemId)
  if iconId then
    TED.Modules.IconID(tooltip, iconId)
  end
end

local function ApplySpellModules(tooltip, spellId)
  if not Enabled() then return end
  if not tooltip or not spellId then return end

  spellId = tonumber(spellId)
  if not spellId then return end

  TED.Modules.SpellID(tooltip, spellId)

  local iconId = GetSpellTexture and GetSpellTexture(spellId)
  if iconId then
    TED.Modules.IconID(tooltip, iconId)
  end
end

local function ApplyAHOwnedStack(tooltip, itemId)
  if not Enabled() then return end
  if not ModuleOn("stack") then return end
  if not tooltip or not itemId then return end

  itemId = tonumber(itemId)
  if not itemId then return end

  local ownedCount = GetOwnedItemCount(itemId)
  ApplyItemModules(tooltip, itemId, ownedCount)
end

-- =========================
-- Generic frame/data scanning
-- =========================
local function FindCountInFrameChain(frame, maxDepth)
  local depth = 0
  local current = frame
  maxDepth = maxDepth or 8

  while current and depth < maxDepth do
    local directCount = NormalizeCount(
      current.quantity
      or current.stackCount
      or current.count
      or current.itemCount
    )
    if directCount ~= nil then
      return directCount
    end

    if current.GetElementData then
      local ok, data = pcall(current.GetElementData, current)
      if ok and type(data) == "table" then
        local count = NormalizeCount(
          data.quantity
          or data.stackCount
          or data.count
          or data.itemCount
        )
        if count ~= nil then
          return count
        end

        if type(data.itemKeyInfo) == "table" then
          count = NormalizeCount(
            data.itemKeyInfo.quantity
            or data.itemKeyInfo.stackCount
            or data.itemKeyInfo.count
            or data.itemKeyInfo.itemCount
          )
          if count ~= nil then
            return count
          end
        end

        if type(data.auctionInfo) == "table" then
          count = NormalizeCount(
            data.auctionInfo.quantity
            or data.auctionInfo.stackCount
            or data.auctionInfo.count
            or data.auctionInfo.itemCount
          )
          if count ~= nil then
            return count
          end
        end
      end
    end

    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end

  return nil
end

local function IsAuctionatorFrame(frame)
  local depth = 0
  local current = frame

  while current and depth < 12 do
    local name = current.GetName and current:GetName()
    if type(name) == "string" and name:find("Auctionator", 1, true) then
      return true
    end

    if current.AuctionatorSellingFrame
      or current.AuctionatorShoppingFrame
      or current.AuctionatorCancellingFrame
      or current.AuctionatorTabMixin
      or current.Search
      or current.ResultsListing
      or current.BuyDisplay
    then
      return true
    end

    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end

  return false
end

local function ReadAuctionatorDataObject(data, wantedItemID, depth)
  if type(data) ~= "table" then return nil end
  depth = depth or 0
  if depth > 5 then return nil end

  local foundItemID = ExtractItemIDFromAny(data)
  local foundCount = ExtractCountFromAny(data)

  if foundCount ~= nil then
    if wantedItemID == nil or foundItemID == nil or foundItemID == wantedItemID then
      return foundCount
    end
  end

  local keys = {
    "data",
    "itemKey",
    "itemKeyInfo",
    "auctionInfo",
    "selectedData",
    "selectedRowData",
    "selectedResult",
    "selectedListing",
    "selectedItem",
    "selectedEntry",
    "rowData",
    "result",
    "listing",
    "searchResult",
    "currentRowData",
    "elementData",
    "searchData",
    "purchaseData",
    "buyData",
    "resultsData",
  }

  for _, key in ipairs(keys) do
    local sub = data[key]
    if type(sub) == "table" then
      local count = ReadAuctionatorDataObject(sub, wantedItemID, depth + 1)
      if count ~= nil then
        return count
      end
    end
  end

  return nil
end

local function ReadAuctionatorObject(obj, wantedItemID)
  if type(obj) ~= "table" then return nil end

  local count = ReadAuctionatorDataObject(obj, wantedItemID, 0)
  if count ~= nil then
    return count
  end

  local methods = {
    "GetElementData",
    "GetData",
    "GetSelectedData",
    "GetSelectedResult",
    "GetSelectedRowData",
    "GetResult",
    "GetListingData",
  }

  for _, methodName in ipairs(methods) do
    local method = obj[methodName]
    if type(method) == "function" then
      local ok, result = pcall(method, obj)
      if ok and type(result) == "table" then
        count = ReadAuctionatorDataObject(result, wantedItemID, 0)
        if count ~= nil then
          return count
        end
      end
    end
  end

  return nil
end

-- =========================
-- Owner/context-based stack detection
-- =========================
local function GetOwnerItemID(tooltip)
  if not tooltip or not tooltip.GetItem then return nil end
  local _, link = tooltip:GetItem()
  return GetItemIDFromLink(link)
end

local function GetMerchantStackFromOwner(tooltip)
  local owner = tooltip and tooltip:GetOwner()
  if not owner then return nil end

  local name = owner.GetName and owner:GetName()
  local id = owner.GetID and owner:GetID()

  if id and name and name:match("^MerchantItem%d+$") and GetMerchantItemInfo then
    local _, _, _, quantity = GetMerchantItemInfo(id)
    return NormalizeCount(quantity)
  end

  if owner.index and GetMerchantItemInfo then
    local _, _, _, quantity = GetMerchantItemInfo(owner.index)
    return NormalizeCount(quantity)
  end

  return nil
end

local function IsAHLikeOwner(tooltip)
  local owner = tooltip and tooltip:GetOwner()
  if not owner then return false end

  local current = owner
  local depth = 0

  while current and depth < 12 do
    local name = current.GetName and current:GetName()
    if type(name) == "string" then
      if name:find("Auctionator", 1, true)
        or name:find("AuctionHouse", 1, true)
        or name:find("BrowseResults", 1, true)
        or name:find("Commodities", 1, true)
        or name:find("ItemBuyFrame", 1, true)
      then
        return true
      end
    end

    if IsAuctionatorFrame(current) then
      return true
    end

    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end

  return false
end

local function GetAuctionStackFromOwner(tooltip)
  local owner = tooltip and tooltip:GetOwner()
  if not owner then return nil end

  local itemId = GetOwnerItemID(tooltip)
  if not itemId then return nil end

  local count = FindCountInFrameChain(owner, 8)
  if count ~= nil then
    return GetOwnedItemCount(itemId)
  end

  return GetOwnedItemCount(itemId)
end

local function GetAuctionatorShoppingStack(tooltip)
  local owner = tooltip and tooltip:GetOwner()
  if not owner then return nil end

  local wantedItemID = GetOwnerItemID(tooltip)
  if not wantedItemID then return nil end

  local current = owner
  local depth = 0

  while current and depth < 12 do
    if IsAuctionatorFrame(current) then
      local count = ReadAuctionatorObject(current, wantedItemID)
      if count ~= nil then
        return GetOwnedItemCount(wantedItemID)
      end
    end

    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end

  local globalsToCheck = {
    "AuctionatorShoppingFrame",
    "AuctionatorShoppingTabFrame",
    "AuctionatorShoppingResultsListing",
    "AuctionatorShoppingResults",
    "AuctionatorResultsListing",
    "AuctionatorBuyCommodityFrame",
    "AuctionatorBuyItemFrame",
    "AuctionHouseFrame",
  }

  for _, globalName in ipairs(globalsToCheck) do
    local obj = rawget(_G, globalName)
    if type(obj) == "table" then
      local count = ReadAuctionatorObject(obj, wantedItemID)
      if count ~= nil then
        return GetOwnedItemCount(wantedItemID)
      end
    end
  end

  return GetOwnedItemCount(wantedItemID)
end

local function GetAuctionatorStackFromOwner(tooltip)
  local owner = tooltip and tooltip:GetOwner()
  if not owner then return nil end

  local itemId = GetOwnerItemID(tooltip)
  if not itemId then return nil end

  if not IsAuctionatorFrame(owner) then
    return GetAuctionatorShoppingStack(tooltip)
  end

  local count = FindCountInFrameChain(owner, 12)
  if count ~= nil then
    return GetOwnedItemCount(itemId)
  end

  count = ReadAuctionatorObject(owner, itemId)
  if count ~= nil then
    return GetOwnedItemCount(itemId)
  end

  return GetAuctionatorShoppingStack(tooltip)
end

local function ApplyContextStackFromOwner(tooltip)
  if not Enabled() then return end
  if not ModuleOn("stack") then return end
  if not tooltip then return end

  local itemId = GetOwnerItemID(tooltip)
  if not itemId then return end

  local merchantCount = GetMerchantStackFromOwner(tooltip)
  if merchantCount ~= nil then
    ApplyItemModules(tooltip, itemId, merchantCount)
    return
  end

  if IsAHLikeOwner(tooltip) then
    ApplyAHOwnedStack(tooltip, itemId)
    return
  end

  local auctionatorCount = GetAuctionatorStackFromOwner(tooltip)
  if auctionatorCount ~= nil then
    ApplyItemModules(tooltip, itemId, auctionatorCount)
    return
  end

  local auctionCount = GetAuctionStackFromOwner(tooltip)
  if auctionCount ~= nil then
    ApplyItemModules(tooltip, itemId, auctionCount)
    return
  end
end

-- =========================
-- Data extraction / hooks
-- =========================
local function handleItemFromTooltip(tooltip, data)
  if not Enabled() then return end
  if not tooltip or not tooltip.GetItem then return end

  local _, link = tooltip:GetItem()
  if not link then return end

  local itemId = GetItemIDFromLink(link)
  if not itemId then return end

  if IsAHLikeOwner(tooltip) then
    ApplyAHOwnedStack(tooltip, itemId)
    return
  end

  local count = ExtractCountFromTooltipData(data)
  ApplyItemModules(tooltip, itemId, count)

  if count == nil then
    ApplyContextStackFromOwner(tooltip)
  end
end

local function handleSpellFromTooltip(tooltip)
  if not Enabled() then return end
  if not tooltip or not tooltip.GetSpell then return end

  local _, spellId = tooltip:GetSpell()
  if not spellId then return end

  ApplySpellModules(tooltip, spellId)
end

local function onSetHyperlink(tooltip, link)
  if not Enabled() then return end
  if not link then return end

  local kind, id = link:match("^(%a+):(%d+)")
  id = tonumber(id)
  if not id then return end

  if kind == "item" then
    if IsAHLikeOwner(tooltip) then
      ApplyAHOwnedStack(tooltip, id)
    else
      ApplyItemModules(tooltip, id, nil)
    end
  elseif kind == "spell" then
    ApplySpellModules(tooltip, id)
  end
end

local function onSetItemKey(tooltip, ...)
  if not Enabled() then return end

  local itemId = GetItemIDFromItemKey(...)
  if not itemId then return end

  ApplyAHOwnedStack(tooltip, itemId)
  ApplyContextStackFromOwner(tooltip)
end

-- Bags
local function hookBags()
  if not (C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemID) then return end

  hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
    if not Enabled() then return end

    local itemId = C_Container.GetContainerItemID(bag, slot)
    if not itemId then return end

    local info = C_Container.GetContainerItemInfo(bag, slot)
    local current = info and (info.stackCount or info.quantity)
    ApplyItemModules(tooltip, itemId, current)
  end)
end

-- Loot
local function hookLoot()
  if GetLootSlotLink and GetLootSlotInfo then
    hooksecurefunc(GameTooltip, "SetLootItem", function(tooltip, slot)
      if not Enabled() then return end

      local link = GetLootSlotLink(slot)
      if not link then return end

      local itemId = GetItemIDFromLink(link)
      local qty = select(3, GetLootSlotInfo(slot))

      if itemId then
        ApplyItemModules(tooltip, itemId, qty)
      end
    end)
  end

  if GetLootRollItemLink and GetLootRollItemInfo then
    hooksecurefunc(GameTooltip, "SetLootRollItem", function(tooltip, rollID)
      if not Enabled() then return end

      local link = GetLootRollItemLink(rollID)
      if not link then return end

      local itemId = GetItemIDFromLink(link)
      local qty = select(3, GetLootRollItemInfo(rollID))

      if itemId then
        ApplyItemModules(tooltip, itemId, qty)
      end
    end)
  end
end

-- Action bars
local function hookActions()
  if not GetActionInfo then return end

  hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
    if not Enabled() then return end
    if not slot then return end

    local actionType, id = GetActionInfo(slot)
    if actionType ~= "item" or not id then return end

    local itemId = tonumber(id)
    if not itemId then return end

    local count = GetActionCount and GetActionCount(slot)
    if count == nil and GetItemCount then
      count = GetItemCount(itemId)
    end

    ApplyItemModules(tooltip, itemId, count)
  end)
end

-- Merchants / vendors
local function hookMerchants()
  if GetMerchantItemLink and GetMerchantItemInfo then
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, index)
      if not Enabled() then return end
      if not index then return end

      local link = GetMerchantItemLink(index)
      if not link then return end

      local itemId = GetItemIDFromLink(link)
      if not itemId then return end

      local _, _, _, quantity = GetMerchantItemInfo(index)
      ApplyItemModules(tooltip, itemId, quantity)
    end)
  end
end

-- Auction House
local function hookAuctionHouse()
  if GameTooltip and GameTooltip.SetAuctionItem and GetAuctionItemLink and GetAuctionItemInfo then
    hooksecurefunc(GameTooltip, "SetAuctionItem", function(tooltip, list, index)
      if not Enabled() then return end
      if not list or not index then return end

      local link = GetAuctionItemLink(list, index)
      if not link then return end

      local itemId = GetItemIDFromLink(link)
      if not itemId then return end

      ApplyAHOwnedStack(tooltip, itemId)
    end)
  end
end

-- Auctionator / SetItemKey paths
local function hookItemKeyTooltips()
  if GameTooltip and GameTooltip.SetItemKey then
    hooksecurefunc(GameTooltip, "SetItemKey", function(tooltip, ...)
      onSetItemKey(tooltip, ...)
    end)
  end

  if ItemRefTooltip and ItemRefTooltip.SetItemKey then
    hooksecurefunc(ItemRefTooltip, "SetItemKey", function(tooltip, ...)
      onSetItemKey(tooltip, ...)
    end)
  end
end

-- =========================
-- Init (Retail-safe)
-- =========================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    if type(TooltipExtraDataDB) ~= "table" then
      TooltipExtraDataDB = {}
    end
    CopyDefaults(TooltipExtraDataDB, defaults)
  end

  if event == "PLAYER_LOGIN" then
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not Enabled() then return end
        handleItemFromTooltip(tooltip, data)
      end)

      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        if not Enabled() then return end
        handleSpellFromTooltip(tooltip, data)
      end)
    else
      SafeHookScript(GameTooltip, "OnTooltipSetItem", function(self)
        handleItemFromTooltip(self, nil)
      end)
      SafeHookScript(GameTooltip, "OnTooltipSetSpell", handleSpellFromTooltip)

      SafeHookScript(ItemRefTooltip, "OnTooltipSetItem", function(self)
        handleItemFromTooltip(self, nil)
      end)
      SafeHookScript(ItemRefTooltip, "OnTooltipSetSpell", handleSpellFromTooltip)
    end

    hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)

    hookBags()
    hookLoot()
    hookActions()
    hookMerchants()
    hookAuctionHouse()
    hookItemKeyTooltips()

    SafeHookScript(GameTooltip, "OnTooltipSetItem", function(self)
      ApplyContextStackFromOwner(self)
    end)

    SafeHookScript(ItemRefTooltip, "OnTooltipSetItem", function(self)
      ApplyContextStackFromOwner(self)
    end)

    SafeHookScript(GameTooltip, "OnTooltipCleared", function(self)
      clearTooltipState(self)
    end)
    SafeHookScript(GameTooltip, "OnHide", function(self)
      clearTooltipState(self)
    end)

    SafeHookScript(ItemRefTooltip, "OnTooltipCleared", function(self)
      clearTooltipState(self)
    end)
    SafeHookScript(ItemRefTooltip, "OnHide", function(self)
      clearTooltipState(self)
    end)
  end
end)

-- =========================
-- Slash command
-- =========================
SLASH_TOOLTIPEXTRADATA1 = "/ted"
SlashCmdList.TOOLTIPEXTRADATA = function(msg)
  msg = (msg or ""):lower()

  if msg == "on" then
    TooltipExtraDataDB.enabled = true
    print("TooltipExtraData: enabled")

  elseif msg == "off" then
    TooltipExtraDataDB.enabled = false
    print("TooltipExtraData: disabled")

  elseif msg == "stack" then
    TooltipExtraDataDB.modules.stack = not TooltipExtraDataDB.modules.stack
    print("TooltipExtraData: stack = " .. tostring(TooltipExtraDataDB.modules.stack))

  elseif msg == "itemid" then
    TooltipExtraDataDB.modules.itemid = not TooltipExtraDataDB.modules.itemid
    print("TooltipExtraData: itemid = " .. tostring(TooltipExtraDataDB.modules.itemid))

  elseif msg == "spellid" then
    TooltipExtraDataDB.modules.spellid = not TooltipExtraDataDB.modules.spellid
    print("TooltipExtraData: spellid = " .. tostring(TooltipExtraDataDB.modules.spellid))

  elseif msg == "iconid" then
    TooltipExtraDataDB.modules.iconid = not TooltipExtraDataDB.modules.iconid
    print("TooltipExtraData: iconid = " .. tostring(TooltipExtraDataDB.modules.iconid))

  else
    print("TooltipExtraData commands:")
    print("/ted on | off")
    print("/ted stack | itemid | spellid | iconid  (toggle)")
  end
end

-- =========================
-- Options panel
-- =========================
local panel = CreateFrame("Frame")
panel.name = "TooltipExtraData"

local function CreateCheck(parent, label, tooltipText, getter, setter)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb.Text:SetText(label)
  if tooltipText then
    cb.tooltip = tooltipText
  end

  function cb:Refresh()
    local ok, val = pcall(getter)
    if ok then
      self:SetChecked(val and true or false)
    else
      self:SetChecked(false)
    end
  end

  cb:SetScript("OnClick", function(self)
    setter(self:GetChecked() and true or false)
    self:Refresh()
  end)

  cb:Refresh()
  return cb
end

panel:SetScript("OnShow", function(self)
  if type(TooltipExtraDataDB) ~= "table" then
    TooltipExtraDataDB = {}
  end
  CopyDefaults(TooltipExtraDataDB, defaults)

  if self._init then
    for _, c in ipairs(self._checks or {}) do
      if c and c.Refresh then
        c:Refresh()
      end
    end
    return
  end

  self._init = true
  self._checks = {}

  local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("TooltipExtraData")

  local sub = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText("Toggle what data is shown in tooltips.")

  local enabledCB = CreateCheck(
    self,
    "Enabled",
    "Master enable/disable for the addon.",
    function() return TooltipExtraDataDB.enabled end,
    function(v) TooltipExtraDataDB.enabled = v end
  )
  enabledCB:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
  table.insert(self._checks, enabledCB)

  local stackCB = CreateCheck(
    self,
    "Show Stack",
    "Shows current/max normally, and owned/max in AH/Auctionator.",
    function() return TooltipExtraDataDB.modules.stack end,
    function(v) TooltipExtraDataDB.modules.stack = v end
  )
  stackCB:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -10)
  table.insert(self._checks, stackCB)

  local itemIdCB = CreateCheck(
    self,
    "Show ItemID",
    "Adds ItemID to item tooltips.",
    function() return TooltipExtraDataDB.modules.itemid end,
    function(v) TooltipExtraDataDB.modules.itemid = v end
  )
  itemIdCB:SetPoint("TOPLEFT", stackCB, "BOTTOMLEFT", 0, -10)
  table.insert(self._checks, itemIdCB)

  local spellIdCB = CreateCheck(
    self,
    "Show SpellID",
    "Adds SpellID to spell tooltips.",
    function() return TooltipExtraDataDB.modules.spellid end,
    function(v) TooltipExtraDataDB.modules.spellid = v end
  )
  spellIdCB:SetPoint("TOPLEFT", itemIdCB, "BOTTOMLEFT", 0, -10)
  table.insert(self._checks, spellIdCB)

  local iconIdCB = CreateCheck(
    self,
    "Show IconID",
    "Adds IconID (texture FileID) below ItemID/SpellID.",
    function() return TooltipExtraDataDB.modules.iconid end,
    function(v) TooltipExtraDataDB.modules.iconid = v end
  )
  iconIdCB:SetPoint("TOPLEFT", spellIdCB, "BOTTOMLEFT", 0, -10)
  table.insert(self._checks, iconIdCB)

  local hint = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", iconIdCB, "BOTTOMLEFT", 2, -14)
  hint:SetText("Tip: Use /ted for quick toggles. /reload refreshes existing tooltips.")
end)

if InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
end