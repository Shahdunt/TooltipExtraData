local addonName, TED = ...

TooltipExtraDataDB = TooltipExtraDataDB or {}

-- =========================
-- Defaults (simple + extensible)
-- =========================
local defaults = {
  enabled = true,
  colorGray = "808080",

  modules = {
    stack  = true,  -- shows current/max on right side of title (bags/loot only)
    itemid = true,  -- shows ItemID on item tooltips
    spellid = true, -- shows SpellID on spell tooltips
    iconid = true,  -- shows IconID (texture FileID) below ItemID/SpellID
  },
}

local function CopyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
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
-- Tooltip helpers
-- =========================
local function getTooltipName(tooltip)
  return tooltip and tooltip.GetName and tooltip:GetName() or nil
end

local function alreadyHasLine(tooltip, needle)
  local name = getTooltipName(tooltip)
  if not name then return false end

  for i = tooltip:NumLines(), 1, -1 do
    local left = _G[name .. "TextLeft" .. i]
    if left then
      local t = left:GetText()
      if t and t:find(needle, 1, true) then
        return true
      end
    end
  end
  return false
end

local function addDoubleLine(tooltip, leftText, rightText)
  if not tooltip or not tooltip.AddDoubleLine then return end
  tooltip:AddDoubleLine(leftText, rightText, nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)
  tooltip:Show()
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

-- ---- Stack module: right side of title, gray, "current/max"
function TED.Modules.Stack(tooltip, itemId, currentCount)
  if not ModuleOn("stack") then return end
  if not GetItemMaxStackSizeByID then return end
  if not tooltip or not itemId or not currentCount then return end

  local itemIdNum = tonumber(itemId)
  local currentNum = tonumber(currentCount)
  if not itemIdNum or not currentNum then return end

  local maxStack = GetItemMaxStackSizeByID(itemIdNum)
  if not maxStack or maxStack <= 1 then return end -- omit non-stackables

  local name = getTooltipName(tooltip)
  if not name then return end

  local right1 = _G[name .. "TextRight1"]
  if not right1 then return end

  local stackText = Gray(currentNum .. "/" .. maxStack)
  if right1:GetText() == stackText then return end

  right1:SetText(stackText)
  right1:Show()
  tooltip:Show()
end

-- ---- ItemID module: adds "ItemID" line
function TED.Modules.ItemID(tooltip, itemId)
  if not ModuleOn("itemid") then return end
  if not tooltip or not itemId then return end

  itemId = tonumber(itemId)
  if not itemId then return end

  if alreadyHasLine(tooltip, "ItemID") then return end
  addDoubleLine(tooltip, "ItemID", tostring(itemId))
end

-- ---- SpellID module: adds "SpellID" line
function TED.Modules.SpellID(tooltip, spellId)
  if not ModuleOn("spellid") then return end
  if not tooltip or not spellId then return end

  spellId = tonumber(spellId)
  if not spellId then return end

  if alreadyHasLine(tooltip, "SpellID") then return end
  addDoubleLine(tooltip, "SpellID", tostring(spellId))
end

-- ---- IconID module: shows normal AddDoubleLine under ItemID/SpellID (default colors)
function TED.Modules.IconID(tooltip, iconId)
  if not ModuleOn("iconid") then return end
  if not tooltip or not iconId then return end

  iconId = tonumber(iconId)
  if not iconId then return end

  if alreadyHasLine(tooltip, "IconID") then return end
  addDoubleLine(tooltip, "IconID", tostring(iconId))
end

-- =========================
-- Data extraction / hooks
-- =========================

-- Items: from tooltip itself (works for most item tooltips, chat links too)
local function handleItemFromTooltip(tooltip)
  if not Enabled() then return end
  if not tooltip or not tooltip.GetItem then return end

  local _, link = tooltip:GetItem()
  if not link then return end

  local itemId = tonumber(link:match("item:(%d+)"))
  if not itemId then return end

  -- Order matters: ItemID first, then IconID below it
  TED.Modules.ItemID(tooltip, itemId)

  local iconId = GetItemIconByID and GetItemIconByID(itemId)
  if iconId then
    TED.Modules.IconID(tooltip, iconId)
  end
end

-- Spells: from tooltip itself
local function handleSpellFromTooltip(tooltip)
  if not Enabled() then return end
  if not tooltip or not tooltip.GetSpell then return end

  local _, spellId = tooltip:GetSpell()
  if not spellId then return end

  -- Order matters: SpellID first, then IconID below it
  TED.Modules.SpellID(tooltip, spellId)

  local iconId = GetSpellTexture and GetSpellTexture(spellId)
  if iconId then
    TED.Modules.IconID(tooltip, iconId)
  end
end

-- Hyperlinks (ItemRefTooltip + GameTooltip SetHyperlink)
local function onSetHyperlink(tooltip, link)
  if not Enabled() then return end
  if not link then return end

  local kind, id = link:match("^(%a+):(%d+)")
  id = tonumber(id)
  if not id then return end

  if kind == "item" then
    TED.Modules.ItemID(tooltip, id)
    local iconId = GetItemIconByID and GetItemIconByID(id)
    if iconId then TED.Modules.IconID(tooltip, iconId) end
  elseif kind == "spell" then
    TED.Modules.SpellID(tooltip, id)
    local iconId = GetSpellTexture and GetSpellTexture(id)
    if iconId then TED.Modules.IconID(tooltip, iconId) end
  end
end

-- Bags: real stack count
local function hookBags()
  if not (C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemID) then return end

  hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
    if not Enabled() then return end

    local itemId = C_Container.GetContainerItemID(bag, slot)
    if not itemId then return end

    local info = C_Container.GetContainerItemInfo(bag, slot)
    local current = info and (info.stackCount or info.quantity)
    if not current then return end

    TED.Modules.Stack(tooltip, itemId, current)
    TED.Modules.ItemID(tooltip, itemId)

    local iconId = GetItemIconByID and GetItemIconByID(itemId)
    if iconId then TED.Modules.IconID(tooltip, iconId) end
  end)
end

-- Loot: quantities
local function hookLoot()
  if GetLootSlotLink and GetLootSlotInfo then
    hooksecurefunc(GameTooltip, "SetLootItem", function(tooltip, slot)
      if not Enabled() then return end

      local link = GetLootSlotLink(slot)
      if not link then return end

      local itemId = tonumber(link:match("item:(%d+)"))
      local qty = select(3, GetLootSlotInfo(slot))
      if itemId and qty then
        TED.Modules.Stack(tooltip, itemId, qty)
        TED.Modules.ItemID(tooltip, itemId)

        local iconId = GetItemIconByID and GetItemIconByID(itemId)
        if iconId then TED.Modules.IconID(tooltip, iconId) end
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
      if itemId and qty then
        TED.Modules.Stack(tooltip, itemId, qty)
        TED.Modules.ItemID(tooltip, itemId)

        local iconId = GetItemIconByID and GetItemIconByID(itemId)
        if iconId then TED.Modules.IconID(tooltip, iconId) end
      end
    end)
  end
end

-- Action bars: show stack for usable items placed on action buttons
local function hookActions()
  if not GetActionInfo then return end

  hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
    if not Enabled() then return end
    if not slot then return end

    local actionType, id = GetActionInfo(slot)
    if actionType ~= "item" or not id then return end

    local itemId = tonumber(id)
    if not itemId then return end

    -- Count shown on the action button (usually total in bags)
    local count = (GetActionCount and GetActionCount(slot)) or (GetItemCount and GetItemCount(itemId)) or nil
    if not count or count <= 0 then return end

    TED.Modules.Stack(tooltip, itemId, count)
    TED.Modules.ItemID(tooltip, itemId)

    local iconId = GetItemIconByID and GetItemIconByID(itemId)
    if iconId then TED.Modules.IconID(tooltip, iconId) end
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
    if type(TooltipExtraDataDB) ~= "table" then TooltipExtraDataDB = {} end
    CopyDefaults(TooltipExtraDataDB, defaults)
  end

  if event == "PLAYER_LOGIN" then
    -- Prefer Retail approach: TooltipDataProcessor
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
      -- Fallback: only hook scripts if they exist
      local function SafeHookScript(frame, scriptName, fn)
        if frame and frame.HasScript and frame:HasScript(scriptName) then
          frame:HookScript(scriptName, fn)
        end
      end

      SafeHookScript(GameTooltip, "OnTooltipSetItem", handleItemFromTooltip)
      SafeHookScript(GameTooltip, "OnTooltipSetSpell", handleSpellFromTooltip)

      SafeHookScript(ItemRefTooltip, "OnTooltipSetItem", handleItemFromTooltip)
      SafeHookScript(ItemRefTooltip, "OnTooltipSetSpell", handleSpellFromTooltip)
    end

    hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)

    -- Stack-aware sources
    hookBags()
    hookLoot()
	hookActions()
  end
end)

-- =========================
-- Slash command (tiny)
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
-- Options panel (Settings/AddOns) + checkboxes
-- =========================
local panel = CreateFrame("Frame")
panel.name = "TooltipExtraData"

local function CreateCheck(parent, label, tooltipText, getter, setter)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb.Text:SetText(label)
  if tooltipText then cb.tooltip = tooltipText end

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
  -- Ensure DB is initialized even if panel is opened very early
  if type(TooltipExtraDataDB) ~= "table" then TooltipExtraDataDB = {} end
  CopyDefaults(TooltipExtraDataDB, defaults)

  if self._init then
    for _, c in ipairs(self._checks or {}) do
      if c and c.Refresh then c:Refresh() end
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
    "Shows stack count on the right side of the item name (bags/loot only).",
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
  hint:SetText("Tip: Use /ted for quick toggles. /reload if you want to instantly refresh some tooltips.")
end)

if InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
end