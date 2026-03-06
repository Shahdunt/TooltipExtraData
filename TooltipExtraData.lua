local addonName, TED = ...

TooltipExtraDataDB = TooltipExtraDataDB or {}

-- =========================
-- Defaults
-- =========================
local defaults = {
  enabled = true,
  colorGray = "808080",

  modules = {
    stack  = true,  -- current/max stack
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
  local currentNum = tonumber(currentCount)
  if not itemIdNum or not currentNum then return end

  local maxStack = GetItemMaxStackSizeByID(itemIdNum)
  if not maxStack or maxStack <= 1 then return end

  local name = getTooltipName(tooltip)
  if not name then return end

  local right1 = _G[name .. "TextRight1"]
  if not right1 then return end

  local stackKey = tostring(currentNum) .. "/" .. tostring(maxStack)
  if wasAdded(tooltip, "stack", stackKey) then return end

  right1:SetText(Gray(stackKey))
  right1:Show()
  tooltip:Show()

  markAdded(tooltip, "stack", stackKey)
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
-- Data extraction / hooks
-- =========================

local function handleItemFromTooltip(tooltip)
  if not Enabled() then return end
  if not tooltip or not tooltip.GetItem then return end

  local _, link = tooltip:GetItem()
  if not link then return end

  local itemId = tonumber(link:match("item:(%d+)"))
  if not itemId then return end

  TED.Modules.ItemID(tooltip, itemId)

  local iconId = GetItemIconByID and GetItemIconByID(itemId)
  if iconId then
    TED.Modules.IconID(tooltip, iconId)
  end
end

local function handleSpellFromTooltip(tooltip)
  if not Enabled() then return end
  if not tooltip or not tooltip.GetSpell then return end

  local _, spellId = tooltip:GetSpell()
  if not spellId then return end

  TED.Modules.SpellID(tooltip, spellId)

  local iconId = GetSpellTexture and GetSpellTexture(spellId)
  if iconId then
    TED.Modules.IconID(tooltip, iconId)
  end
end

local function onSetHyperlink(tooltip, link)
  if not Enabled() then return end
  if not link then return end

  local kind, id = link:match("^(%a+):(%d+)")
  id = tonumber(id)
  if not id then return end

  if kind == "item" then
    TED.Modules.ItemID(tooltip, id)

    local iconId = GetItemIconByID and GetItemIconByID(id)
    if iconId then
      TED.Modules.IconID(tooltip, iconId)
    end

  elseif kind == "spell" then
    TED.Modules.SpellID(tooltip, id)

    local iconId = GetSpellTexture and GetSpellTexture(id)
    if iconId then
      TED.Modules.IconID(tooltip, iconId)
    end
  end
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
    if current == nil then return end

    TED.Modules.Stack(tooltip, itemId, current)
    TED.Modules.ItemID(tooltip, itemId)

    local iconId = GetItemIconByID and GetItemIconByID(itemId)
    if iconId then
      TED.Modules.IconID(tooltip, iconId)
    end
  end)
end

-- Loot
local function hookLoot()
  if GetLootSlotLink and GetLootSlotInfo then
    hooksecurefunc(GameTooltip, "SetLootItem", function(tooltip, slot)
      if not Enabled() then return end

      local link = GetLootSlotLink(slot)
      if not link then return end

      local itemId = tonumber(link:match("item:(%d+)"))
      local qty = select(3, GetLootSlotInfo(slot))

      if itemId and qty ~= nil then
        TED.Modules.Stack(tooltip, itemId, qty)
        TED.Modules.ItemID(tooltip, itemId)

        local iconId = GetItemIconByID and GetItemIconByID(itemId)
        if iconId then
          TED.Modules.IconID(tooltip, iconId)
        end
      end
    end)
  end

  if GetLootRollItemLink and GetLootRollItemInfo then
    hooksecurefunc(GameTooltip, "SetLootRollItem", function(tooltip, rollID)
      if not Enabled() then return end

      local link = GetLootRollItemLink(rollID)
      if not link then return end

      local itemId = tonumber(link:match("item:(%d+)"))
      local qty = select(3, GetLootRollItemInfo(rollID))

      if itemId and qty ~= nil then
        TED.Modules.Stack(tooltip, itemId, qty)
        TED.Modules.ItemID(tooltip, itemId)

        local iconId = GetItemIconByID and GetItemIconByID(itemId)
        if iconId then
          TED.Modules.IconID(tooltip, iconId)
        end
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
    if count == nil then return end

    TED.Modules.Stack(tooltip, itemId, count)
    TED.Modules.ItemID(tooltip, itemId)

    local iconId = GetItemIconByID and GetItemIconByID(itemId)
    if iconId then
      TED.Modules.IconID(tooltip, iconId)
    end
  end)
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
        handleItemFromTooltip(tooltip)
      end)

      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        if not Enabled() then return end
        handleSpellFromTooltip(tooltip)
      end)
    else
      SafeHookScript(GameTooltip, "OnTooltipSetItem", handleItemFromTooltip)
      SafeHookScript(GameTooltip, "OnTooltipSetSpell", handleSpellFromTooltip)

      SafeHookScript(ItemRefTooltip, "OnTooltipSetItem", handleItemFromTooltip)
      SafeHookScript(ItemRefTooltip, "OnTooltipSetSpell", handleSpellFromTooltip)
    end

    hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)

    hookBags()
    hookLoot()
    hookActions()

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
    "Show Stack (current/max)",
    "Shows stack count on the right side of the item name.",
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