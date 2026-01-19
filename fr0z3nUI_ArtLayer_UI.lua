---@diagnostic disable: undefined-global, duplicate-set-field, need-check-nil

local ADDON, ns = ...
ns = ns or {}

local Print = ns.Print or function(msg)
  print(tostring(msg))
end

local function Clamp(v, minV, maxV)
  v = tonumber(v)
  if not v then return minV end
  if v < minV then return minV end
  if v > maxV then return maxV end
  return v
end

local function SortedKeys(t)
  local out = {}
  for k in pairs(t or {}) do
    out[#out + 1] = k
  end
  table.sort(out, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
  return out
end

local function SetShown(frame, shown)
  if not frame then return end
  if shown then
    frame:Show()
  else
    frame:Hide()
  end
end

local function GetDropDownText(dd)
  if UIDropDownMenu_GetText then
    return UIDropDownMenu_GetText(dd)
  end
  if dd and dd.Text and dd.Text.GetText then
    return dd.Text:GetText()
  end
  return nil
end

local function CreateLabel(parent, text, w)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetText(text)
  if w then fs:SetWidth(w) fs:SetJustifyH("LEFT") end
  return fs
end

local function CreateEditBox(parent, width)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(width or 140, 22)
  eb:SetTextInsets(8, 8, 0, 0)
  return eb
end

local function CreateButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetText(text)
  b:SetSize(w or 80, h or 22)
  return b
end

local function CreateCheck(parent, text)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb.text:SetText(text)
  return cb
end

local function CreateSlider(parent, label, minV, maxV, step)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step or 0.01)
  s:SetObeyStepOnDrag(true)
  s.Text:SetText(label)
  s.Low:SetText(tostring(minV))
  s.High:SetText(tostring(maxV))
  return s
end

local function CreateDropDown(parent, width)
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dd, width or 140)
  return dd
end

local UI

local function GetDB()
  return ns.EnsureDB and ns.EnsureDB() or nil
end

local function ApplySelected()
  local key = UI and UI.selectedKey
  if key and ns.ApplyWidget then
    ns.ApplyWidget(key)
  elseif ns.ApplyAllWidgets then
    ns.ApplyAllWidgets()
  end
end

local function GetSelectedWidget()
  local db = GetDB()
  if not (db and db.widgets and UI and UI.selectedKey) then return nil end
  return db.widgets[UI.selectedKey]
end

local function RefreshControls()
  if not UI then return end
  local w = GetSelectedWidget()

  local hasWidget = (type(w) == "table")
  SetShown(UI.noWidget, not hasWidget)
  SetShown(UI.controls, hasWidget)

  if not hasWidget then
    return
  end

  w.enabled = (w.enabled ~= false)
  if w.clickthrough == nil then w.clickthrough = true end
  if w.scale == nil then w.scale = 1 end
  if w.alpha == nil then w.alpha = 1 end

  UI.enabled:SetChecked(w.enabled)
  UI.clickthrough:SetChecked(w.clickthrough and true or false)

  UI.typeValue:SetText(tostring(w.type or "texture"))

  UI.alpha:SetValue(Clamp(w.alpha, 0, 1))
  UI.alpha.Value:SetText(string.format("%.2f", Clamp(w.alpha, 0, 1)))

  UI.scale:SetValue(Clamp(w.scale, 0.05, 10))
  UI.scale.Value:SetText(string.format("%.2f", Clamp(w.scale, 0.05, 10)))

  UI.w:SetText(tostring(w.w or ""))
  UI.h:SetText(tostring(w.h or ""))

  UI.point:SetText(tostring(w.point or "CENTER"))
  UI.x:SetText(tostring(w.x or 0))
  UI.y:SetText(tostring(w.y or 0))

  UIDropDownMenu_SetText(UI.strataDD, tostring(w.strata or "(default)"))

  local isTexture = (w.type ~= "model")
  SetShown(UI.textureRow, isTexture)
  SetShown(UI.layerRow, isTexture)

  if isTexture then
    UI.texture:SetText(tostring(w.texture or ""))

    UIDropDownMenu_SetText(UI.layerDD, tostring(w.layer or "ARTWORK"))
    UI.sub:SetText(tostring(w.sub or 0))

    UIDropDownMenu_SetText(UI.blendDD, tostring(w.blend or "BLEND"))
  end
end

local function SelectWidget(key)
  UI.selectedKey = key
  UIDropDownMenu_SetText(UI.widgetDD, key or "(none)")
  RefreshControls()
end

local function RefreshWidgetList()
  if not UI then return end
  local db = GetDB()
  local keys = SortedKeys(db and db.widgets or {})
  UI.widgetKeys = keys

  UIDropDownMenu_Initialize(UI.widgetDD, function(_, level)
    local info = UIDropDownMenu_CreateInfo()

    info.text = "(select widget)"
    info.func = function() SelectWidget(nil) end
    UIDropDownMenu_AddButton(info, level)

    for _, key in ipairs(keys) do
      info = UIDropDownMenu_CreateInfo()
      info.text = key
      info.func = function() SelectWidget(key) end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  if UI.selectedKey and db and db.widgets and not db.widgets[UI.selectedKey] then
    UI.selectedKey = nil
  end

  if not UI.selectedKey and keys[1] then
    UI.selectedKey = keys[1]
  end

  SelectWidget(UI.selectedKey)
end

local function CreateWidgetDialog()
  StaticPopupDialogs["FAL_CREATE_WIDGET"] = {
    text = "Create widget key (texture widget).",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(self)
      local key = self.editBox:GetText() or ""
      key = key:gsub("^%s+", ""):gsub("%s+$", "")
      if key == "" then
        Print("Invalid key")
        return
      end
      local db = GetDB()
      db.widgets[key] = db.widgets[key] or {}
      local w = db.widgets[key]
      w.type = w.type or "texture"
      w.enabled = true
      if w.clickthrough == nil then w.clickthrough = true end
      w.scale = w.scale or 1
      w.alpha = w.alpha or 1
      w.w = w.w or 128
      w.h = w.h or 128
      w.point = w.point or "CENTER"
      w.x = w.x or 0
      w.y = w.y or 0
      w.layer = w.layer or "ARTWORK"
      w.sub = w.sub or 0
      w.blend = w.blend or "BLEND"
      w.conds = w.conds or {}

      if ns.ApplyWidget then ns.ApplyWidget(key) end
      RefreshWidgetList()
      SelectWidget(key)
    end,
    EditBoxOnEnterPressed = function(self)
      local parent = self:GetParent()
      parent.button1:Click()
    end,
    OnShow = function(self)
      self.editBox:SetText("")
      self.editBox:SetFocus()
    end,
  }
end

local function DeleteWidgetDialog(key)
  StaticPopupDialogs["FAL_DELETE_WIDGET"] = {
    text = "Delete widget '" .. tostring(key) .. "'?",
    button1 = "Delete",
    button2 = "Cancel",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function()
      local db = GetDB()
      if db and db.widgets then
        db.widgets[key] = nil
      end
      if ns.ApplyAllWidgets then ns.ApplyAllWidgets() end
      RefreshWidgetList()
    end,
  }
  StaticPopup_Show("FAL_DELETE_WIDGET")
end

local function CreateUI()
  if UI then return UI end
  CreateWidgetDialog()

  local f = CreateFrame("Frame", "fr0z3nUI_ArtLayer_Config", UIParent, "BackdropTemplate")
  f:SetSize(520, 420)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0, 0, 0, 0.85)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("ArtLayer Widgets")

  local close = CreateButton(f, "Close", 80, 22)
  close:SetPoint("TOPRIGHT", -12, -10)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Widget row
  local widgetLabel = CreateLabel(f, "Widget:")
  widgetLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)

  local widgetDD = CreateDropDown(f, 210)
  widgetDD:SetPoint("LEFT", widgetLabel, "RIGHT", -10, -2)

  local addBtn = CreateButton(f, "New", 60, 22)
  addBtn:SetPoint("LEFT", widgetDD, "RIGHT", -6, 2)

  local delBtn = CreateButton(f, "Delete", 60, 22)
  delBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)

  local refreshBtn = CreateButton(f, "Refresh", 70, 22)
  refreshBtn:SetPoint("LEFT", delBtn, "RIGHT", 6, 0)

  local noWidget = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  noWidget:SetPoint("TOPLEFT", widgetLabel, "BOTTOMLEFT", 0, -12)
  noWidget:SetText("No widget selected")

  local controls = CreateFrame("Frame", nil, f)
  controls:SetPoint("TOPLEFT", noWidget, "BOTTOMLEFT", 0, -6)
  controls:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

  -- Left column basics
  local enabled = CreateCheck(controls, "Enabled")
  enabled:SetPoint("TOPLEFT", 0, 0)

  local clickthrough = CreateCheck(controls, "Clickthrough")
  clickthrough:SetPoint("LEFT", enabled, "RIGHT", 120, 0)

  local typeLabel = CreateLabel(controls, "Type:")
  typeLabel:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -12)
  local typeValue = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  typeValue:SetPoint("LEFT", typeLabel, "RIGHT", 6, 0)
  typeValue:SetText("-")

  local alpha = CreateSlider(controls, "Alpha", 0, 1, 0.01)
  alpha:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -28)
  alpha:SetWidth(240)

  local scale = CreateSlider(controls, "Scale", 0.1, 3, 0.05)
  scale:SetPoint("TOPLEFT", alpha, "BOTTOMLEFT", 0, -34)
  scale:SetWidth(240)

  -- Size
  local sizeLabel = CreateLabel(controls, "Size (w/h):")
  sizeLabel:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -18)
  local wEB = CreateEditBox(controls, 60)
  wEB:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
  local hEB = CreateEditBox(controls, 60)
  hEB:SetPoint("LEFT", wEB, "RIGHT", 8, 0)

  -- Position
  local posLabel = CreateLabel(controls, "Pos (point/x/y):")
  posLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -18)
  local pointEB = CreateEditBox(controls, 90)
  pointEB:SetPoint("LEFT", posLabel, "RIGHT", 8, 0)
  local xEB = CreateEditBox(controls, 60)
  xEB:SetPoint("LEFT", pointEB, "RIGHT", 8, 0)
  local yEB = CreateEditBox(controls, 60)
  yEB:SetPoint("LEFT", xEB, "RIGHT", 8, 0)

  -- Right column: strata/layer/blend/texture
  local right = CreateFrame("Frame", nil, controls)
  right:SetPoint("TOPLEFT", 270, 0)
  right:SetPoint("TOPRIGHT", -6, 0)

  local strataLabel = CreateLabel(right, "Strata:")
  strataLabel:SetPoint("TOPLEFT", 0, 0)
  local strataDD = CreateDropDown(right, 160)
  strataDD:SetPoint("LEFT", strataLabel, "RIGHT", -10, -2)

  local textureRow = CreateFrame("Frame", nil, right)
  textureRow:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -22)
  textureRow:SetSize(220, 60)

  local textureLabel = CreateLabel(textureRow, "Texture:")
  textureLabel:SetPoint("TOPLEFT", 0, 0)
  local texEB = CreateEditBox(textureRow, 220)
  texEB:SetPoint("TOPLEFT", textureLabel, "BOTTOMLEFT", 0, -4)

  local layerRow = CreateFrame("Frame", nil, right)
  layerRow:SetPoint("TOPLEFT", textureRow, "BOTTOMLEFT", 0, -16)
  layerRow:SetSize(220, 120)

  local layerLabel = CreateLabel(layerRow, "Layer/Sub:")
  layerLabel:SetPoint("TOPLEFT", 0, 0)
  local layerDD = CreateDropDown(layerRow, 150)
  layerDD:SetPoint("TOPLEFT", layerLabel, "BOTTOMLEFT", -16, -2)
  local subEB = CreateEditBox(layerRow, 60)
  subEB:SetPoint("LEFT", layerDD, "RIGHT", -8, 2)

  local blendLabel = CreateLabel(layerRow, "Blend:")
  blendLabel:SetPoint("TOPLEFT", layerDD, "BOTTOMLEFT", 16, -16)
  local blendDD = CreateDropDown(layerRow, 150)
  blendDD:SetPoint("TOPLEFT", blendLabel, "BOTTOMLEFT", -16, -2)

  local hint = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", layerRow, "BOTTOMLEFT", 0, -10)
  hint:SetText("Tip: blend + layer fixes some alpha issues")

  -- Wire behavior
  local function SaveAndApply()
    local widget = GetSelectedWidget()
    if type(widget) ~= "table" then return end

    widget.enabled = enabled:GetChecked() and true or false
    widget.clickthrough = clickthrough:GetChecked() and true or false

    widget.alpha = Clamp(alpha:GetValue(), 0, 1)
    widget.scale = Clamp(scale:GetValue(), 0.05, 10)

    widget.w = tonumber(wEB:GetText()) or widget.w
    widget.h = tonumber(hEB:GetText()) or widget.h

    widget.point = (pointEB:GetText() ~= "" and pointEB:GetText()) or widget.point or "CENTER"
    widget.x = tonumber(xEB:GetText()) or 0
    widget.y = tonumber(yEB:GetText()) or 0

    local strataText = GetDropDownText(strataDD)
    if strataText and strataText ~= "(default)" then
      widget.strata = strataText
    else
      widget.strata = nil
    end

    if widget.type ~= "model" then
      widget.texture = texEB:GetText() or widget.texture
      widget.layer = GetDropDownText(layerDD) or widget.layer
      widget.sub = tonumber(subEB:GetText()) or widget.sub
      widget.blend = GetDropDownText(blendDD) or widget.blend
    end

    ApplySelected()
  end

  enabled:SetScript("OnClick", function() SaveAndApply() end)
  clickthrough:SetScript("OnClick", function() SaveAndApply() end)

  alpha:SetScript("OnValueChanged", function(_, v)
    alpha.Value:SetText(string.format("%.2f", v))
    SaveAndApply()
  end)

  scale:SetScript("OnValueChanged", function(_, v)
    scale.Value:SetText(string.format("%.2f", v))
    SaveAndApply()
  end)

  local function EBApply(eb)
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      SaveAndApply()
    end)
    eb:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      RefreshControls()
    end)
  end

  EBApply(wEB)
  EBApply(hEB)
  EBApply(pointEB)
  EBApply(xEB)
  EBApply(yEB)
  EBApply(texEB)
  EBApply(subEB)

  UIDropDownMenu_Initialize(strataDD, function(_, level)
    local items = { "(default)", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
    for _, s in ipairs(items) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = s
      info.func = function()
        UIDropDownMenu_SetText(strataDD, s)
        SaveAndApply()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  UIDropDownMenu_Initialize(layerDD, function(_, level)
    local items = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }
    for _, s in ipairs(items) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = s
      info.func = function()
        UIDropDownMenu_SetText(layerDD, s)
        SaveAndApply()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  UIDropDownMenu_Initialize(blendDD, function(_, level)
    local items = { "BLEND", "ADD", "MOD", "ALPHAKEY" }
    for _, s in ipairs(items) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = s
      info.func = function()
        UIDropDownMenu_SetText(blendDD, s)
        SaveAndApply()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  addBtn:SetScript("OnClick", function()
    StaticPopup_Show("FAL_CREATE_WIDGET")
  end)

  delBtn:SetScript("OnClick", function()
    if UI.selectedKey then
      DeleteWidgetDialog(UI.selectedKey)
    end
  end)

  refreshBtn:SetScript("OnClick", function()
    RefreshWidgetList()
  end)

  UI = {
    frame = f,
    widgetDD = widgetDD,
    strataDD = strataDD,
    layerDD = layerDD,
    blendDD = blendDD,
    selectedKey = nil,
    widgetKeys = {},

    noWidget = noWidget,
    controls = controls,

    enabled = enabled,
    clickthrough = clickthrough,
    typeValue = typeValue,

    alpha = alpha,
    scale = scale,

    w = wEB,
    h = hEB,
    point = pointEB,
    x = xEB,
    y = yEB,

    textureRow = textureRow,
    layerRow = layerRow,
    texture = texEB,
    sub = subEB,
  }

  RefreshWidgetList()
  return UI
end

function ns.OpenConfig()
  local ui = CreateUI()
  if ui.frame:IsShown() then
    ui.frame:Hide()
  else
    ui.frame:Show()
    RefreshWidgetList()
  end
end
