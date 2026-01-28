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

local function HasModernMenu()
  local mu = _G and rawget(_G, "MenuUtil")
  return type(mu) == "table" and type(mu.CreateContextMenu) == "function"
end

local function OpenModernMenu(anchor, build)
  local mu = _G and rawget(_G, "MenuUtil")
  if not (type(mu) == "table" and type(mu.CreateContextMenu) == "function") then return false end
  mu.CreateContextMenu(anchor, function(_, root)
    if type(build) == "function" then
      build(root)
    end
  end)
  return true
end

local function GetDropDownClickTarget(dd)
  return (dd and dd.Button) or dd
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

  -- OptionsSliderTemplate provides Text/Low/High but not a numeric value label.
  -- Keep a dedicated Value FontString so we can show the current slider value.
  if not s.Value then
    local fs = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPRIGHT", s, "TOPRIGHT", 0, 16)
    fs:SetJustifyH("RIGHT")
    fs:SetText("")
    s.Value = fs
  end
  return s
end

local function GetSliderMinMax(s, defaultMin, defaultMax)
  if s and s.GetMinMaxValues then
    local minV, maxV = s:GetMinMaxValues()
    minV, maxV = tonumber(minV), tonumber(maxV)
    if minV and maxV then
      return minV, maxV
    end
  end
  return defaultMin, defaultMax
end

local function SetSliderValueLabel(s, v, fmt)
  if not (s and s.Value and s.Value.SetText) then return end
  local f = fmt or "%.2f"
  s.Value:SetText(string.format(f, tonumber(v) or 0))
end

local function CreateDropDown(parent, width)
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dd, width or 140)
  return dd
end

local function CreateMultiLineBox(parent, width, height)
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetSize(width or 220, height or 70)

  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetAutoFocus(false)
  eb:SetMultiLine(true)
  eb:SetFontObject("ChatFontNormal")
  eb:SetWidth((width or 220) - 18)
  eb:SetText("")
  eb:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  sf:SetScrollChild(eb)
  sf.EditBox = eb
  return sf
end

local function Trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ParseCharList(text)
  text = tostring(text or "")
  text = text:gsub("\r", "")
  text = text:gsub("\n", ",")
  local out = {}
  for part in text:gmatch("[^,]+") do
    part = Trim(part)
    if part ~= "" then
      out[#out + 1] = part
    end
  end
  return out
end

local function JoinLines(list)
  if type(list) ~= "table" then return "" end
  local out = {}
  for _, v in ipairs(list) do
    local s = Trim(v)
    if s ~= "" then out[#out + 1] = s end
  end
  return table.concat(out, "\n")
end

local function RemoveCondsOfType(conds, typ)
  if type(conds) ~= "table" then return end
  for i = #conds, 1, -1 do
    local c = conds[i]
    if type(c) == "table" and c.type == typ then
      table.remove(conds, i)
    end
  end
end

local function FindCond(conds, typ)
  if type(conds) ~= "table" then return nil end
  for _, c in ipairs(conds) do
    if type(c) == "table" and c.type == typ then
      return c
    end
  end
  return nil
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
  if UI.unlockDrag then
    UI.unlockDrag:SetChecked((UI._dragKey ~= nil and UI._dragKey == UI.selectedKey) and true or false)
  end

  UI.typeValue:SetText(tostring(w.type or "texture"))

  do
    local minV, maxV = GetSliderMinMax(UI.alpha, 0, 1)
    local v = Clamp(w.alpha, minV, maxV)
    UI.alpha:SetValue(v)
    SetSliderValueLabel(UI.alpha, v)
  end

  do
    local minV, maxV = GetSliderMinMax(UI.scale, 0.05, 10)
    local v = Clamp(w.scale, minV, maxV)
    UI.scale:SetValue(v)
    SetSliderValueLabel(UI.scale, v)
  end

  UI.w:SetText(tostring(w.w or ""))
  UI.h:SetText(tostring(w.h or ""))

  UI.point:SetText(tostring(w.point or "CENTER"))
  UI.x:SetText(tostring(w.x or 0))
  UI.y:SetText(tostring(w.y or 0))

  do
    local conds = w.conds
    local fc = FindCond(conds, "faction")
    local want = fc and tostring(fc.value or "") or ""
    if want ~= "Alliance" and want ~= "Horde" then
      want = "Both"
    end
    UIDropDownMenu_SetText(UI.factionDD, want)

    local pc = FindCond(conds, "player")
    local list = nil
    if pc and type(pc.list) == "table" then
      list = pc.list
    elseif pc and type(pc.list) == "string" then
      list = ParseCharList(pc.list)
    end
    if UI.chars and UI.chars.EditBox and UI.chars.EditBox.SetText then
      UI.chars.EditBox:SetText(JoinLines(list))
      UI.chars.EditBox:HighlightText(0, 0)
    end
    if UI.chars and UI.chars.SetVerticalScroll then
      UI.chars:SetVerticalScroll(0)
    end
  end

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
  if UI and UI._dragKey and UI._dragKey ~= key and UI._disableDragMode then
    UI._disableDragMode()
  end
  UI.selectedKey = key
  UIDropDownMenu_SetText(UI.widgetDD, key or "(none)")
  RefreshControls()
end

local function RefreshWidgetList()
  if not UI then return end
  local db = GetDB()
  local keys = SortedKeys(db and db.widgets or {})
  UI.widgetKeys = keys

  if HasModernMenu() then
    local target = GetDropDownClickTarget(UI.widgetDD)
    if target and target.SetScript then
      target:SetScript("OnClick", function(btn)
        OpenModernMenu(btn, function(root)
          if root and root.CreateTitle then
            root:CreateTitle("Widget")
          end

          if root and root.CreateButton then
            root:CreateButton("(select widget)", function() SelectWidget(nil) end)
            for _, key in ipairs(keys) do
              root:CreateButton(key, function() SelectWidget(key) end)
            end
          end
        end)
      end)
    end
  else
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
  end

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
      local eb = self.editBox or self.EditBox
      if not (eb and eb.GetText) then
        Print("Popup edit box unavailable")
        return
      end
      local key = eb:GetText() or ""
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
      local b1 = parent and (parent.button1 or parent.Button1)
      if b1 and b1.Click then
        b1:Click()
      end
    end,
    OnShow = function(self)
      local eb = self.editBox or self.EditBox
      if eb and eb.SetText then eb:SetText("") end
      if eb and eb.SetFocus then eb:SetFocus() end
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

  local f = CreateFrame("Frame", "fr0z3nUI_ArtLayer_Config", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(700, 560)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnHide", function()
    if UI and UI._disableDragMode then
      UI._disableDragMode()
    end
  end)
  f:Hide()

  local title = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:ClearAllPoints()
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("|cff00ccff[FAL]|r ArtLayer")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)

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

  local unlockDrag = CreateCheck(controls, "Unlock (drag)")
  unlockDrag:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -8)

  local unlockHint = controls:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  unlockHint:SetPoint("LEFT", unlockDrag.text, "RIGHT", 8, 0)
  unlockHint:SetText("Drag the widget to reposition")

  local typeLabel = CreateLabel(controls, "Type:")
  typeLabel:SetPoint("TOPLEFT", unlockDrag, "BOTTOMLEFT", 0, -10)
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

  -- Drag / unlock helpers (UI-only; does not persist as a setting)
  local function DisableDragMode()
    if not UI or not UI._dragKey then return end
    local key = UI._dragKey
    local widgetFrame = (ns.GetWidgetFrame and ns.GetWidgetFrame(key)) or nil
    if widgetFrame then
      widgetFrame._falForceShow = nil
      if widgetFrame._falDragOverlay and widgetFrame._falDragOverlay.Hide then
        widgetFrame._falDragOverlay:Hide()
      end
      if widgetFrame.SetScript then
        widgetFrame:SetScript("OnDragStart", nil)
        widgetFrame:SetScript("OnDragStop", nil)
      end
      if widgetFrame.SetMovable then
        widgetFrame:SetMovable(false)
      end
    end
    UI._dragKey = nil
    if ns.ApplyWidget then ns.ApplyWidget(key) end
  end

  local function EnableDragMode(key)
    if not key then return end
    DisableDragMode()

    UI._dragKey = key
    if ns.ApplyWidget then ns.ApplyWidget(key) end

    local widgetFrame = (ns.GetWidgetFrame and ns.GetWidgetFrame(key)) or nil
    if not widgetFrame then
      UI._dragKey = nil
      return
    end

    widgetFrame._falForceShow = true
    if ns.ApplyWidget then ns.ApplyWidget(key) end

    if widgetFrame.SetMovable then widgetFrame:SetMovable(true) end
    if widgetFrame.SetClampedToScreen then widgetFrame:SetClampedToScreen(true) end
    if widgetFrame.EnableMouse then widgetFrame:EnableMouse(true) end
    if widgetFrame.RegisterForDrag then
      pcall(widgetFrame.RegisterForDrag, widgetFrame, "LeftButton")
    end

    if not widgetFrame._falDragOverlay and widgetFrame.CreateTexture then
      local ov = widgetFrame:CreateTexture(nil, "OVERLAY")
      ov:SetAllPoints(widgetFrame)
      if ov.SetColorTexture then
        ov:SetColorTexture(0, 1, 1, 0.12)
      end
      widgetFrame._falDragOverlay = ov
    end
    if widgetFrame._falDragOverlay and widgetFrame._falDragOverlay.Show then
      widgetFrame._falDragOverlay:Show()
    end

    widgetFrame:SetScript("OnDragStart", function(self)
      if self.StartMoving then self:StartMoving() end
    end)

    widgetFrame:SetScript("OnDragStop", function(self)
      if self.StopMovingOrSizing then self:StopMovingOrSizing() end

      local db = GetDB()
      local w = db and db.widgets and db.widgets[key]
      if type(w) == "table" then
        local cx, cy
        if self.GetCenter then
          cx, cy = self:GetCenter()
        end
        local px, py
        if UIParent and UIParent.GetCenter then
          px, py = UIParent:GetCenter()
        end
        if cx and cy and px and py then
          w.point = "CENTER"
          w.x = math.floor((cx - px) + 0.5)
          w.y = math.floor((cy - py) + 0.5)
        else
          local p, _, _, x, y
          if self.GetPoint then
            p, _, _, x, y = self:GetPoint(1)
          end
          w.point = tostring(p or "CENTER")
          w.x = math.floor((tonumber(x) or 0) + 0.5)
          w.y = math.floor((tonumber(y) or 0) + 0.5)
        end
        pointEB:SetText(tostring(w.point or "CENTER"))
        xEB:SetText(tostring(w.x or 0))
        yEB:SetText(tostring(w.y or 0))
      end

      if ns.ApplyWidget then ns.ApplyWidget(key) end
      local f2 = (ns.GetWidgetFrame and ns.GetWidgetFrame(key)) or nil
      if f2 then
        f2._falForceShow = true
        if f2._falDragOverlay and f2._falDragOverlay.Show then f2._falDragOverlay:Show() end
      end
    end)
  end

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
  textureRow:SetSize(320, 60)

  local textureLabel = CreateLabel(textureRow, "Texture:")
  textureLabel:SetPoint("TOPLEFT", 0, 0)
  local texEB = CreateEditBox(textureRow, 240)
  texEB:SetPoint("TOPLEFT", textureLabel, "BOTTOMLEFT", 0, -4)

  local texPickBtn = CreateButton(textureRow, "Pick", 60, 22)
  texPickBtn:SetPoint("LEFT", texEB, "RIGHT", 8, 0)

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

    do
      local minV, maxV = GetSliderMinMax(alpha, 0, 1)
      widget.alpha = Clamp(alpha:GetValue(), minV, maxV)
    end
    do
      local minV, maxV = GetSliderMinMax(scale, 0.05, 10)
      widget.scale = Clamp(scale:GetValue(), minV, maxV)
    end

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

    widget.conds = widget.conds or {}

    do
      local txt = GetDropDownText(UI.factionDD)
      local want = (txt == "Alliance" or txt == "Horde") and txt or ""
      RemoveCondsOfType(widget.conds, "faction")
      if want ~= "" then
        table.insert(widget.conds, { type = "faction", value = want })
      end
    end

    do
      local raw = (UI.chars and UI.chars.EditBox and UI.chars.EditBox.GetText) and UI.chars.EditBox:GetText() or ""
      local list = ParseCharList(raw)
      RemoveCondsOfType(widget.conds, "player")
      if list[1] then
        table.insert(widget.conds, { type = "player", list = list })
      end
    end

    ApplySelected()
  end

  enabled:SetScript("OnClick", function() SaveAndApply() end)
  clickthrough:SetScript("OnClick", function() SaveAndApply() end)

  unlockDrag:SetScript("OnClick", function()
    local key = UI and UI.selectedKey
    if unlockDrag:GetChecked() then
      EnableDragMode(key)
    else
      DisableDragMode()
    end
    unlockDrag:SetChecked((UI and UI._dragKey and key and UI._dragKey == key) and true or false)
  end)

  alpha:SetScript("OnValueChanged", function(_, v)
    SetSliderValueLabel(alpha, v)
    SaveAndApply()
  end)

  scale:SetScript("OnValueChanged", function(_, v)
    SetSliderValueLabel(scale, v)
    SaveAndApply()
  end)

  local function EBApply(eb)
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      SaveAndApply()
    end)
    eb:SetScript("OnEditFocusLost", function()
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

  -- Conditions
  local condLabel = CreateLabel(controls, "Conditions:")
  condLabel:SetPoint("TOPLEFT", posLabel, "BOTTOMLEFT", 0, -18)

  local factionLabel = CreateLabel(controls, "Faction:")
  factionLabel:SetPoint("TOPLEFT", condLabel, "BOTTOMLEFT", 0, -10)
  local factionDD = CreateDropDown(controls, 140)
  factionDD:SetPoint("LEFT", factionLabel, "RIGHT", -16, -2)
  UIDropDownMenu_SetText(factionDD, "Both")

  local charsLabel = CreateLabel(controls, "Characters (one per line):")
  charsLabel:SetPoint("TOPLEFT", factionLabel, "BOTTOMLEFT", 0, -14)
  local chars = CreateMultiLineBox(controls, 240, 70)
  chars:SetPoint("TOPLEFT", charsLabel, "BOTTOMLEFT", 0, -6)

  -- Keep the texture/layer controls visible even at odd UI scales by placing
  -- the whole "right" section below the conditions block.
  if right and right.ClearAllPoints and right.SetPoint then
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", chars, "BOTTOMLEFT", 0, -18)
    right:SetPoint("BOTTOMRIGHT", controls, "BOTTOMRIGHT", -6, 0)
  end

  if chars and chars.EditBox and chars.EditBox.SetScript then
    chars.EditBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      SaveAndApply()
    end)
    chars.EditBox:SetScript("OnEditFocusLost", function()
      SaveAndApply()
    end)
  end

  do
    local items = { "(default)", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
    if HasModernMenu() then
      local target = GetDropDownClickTarget(strataDD)
      if target and target.SetScript then
        target:SetScript("OnClick", function(btn)
          OpenModernMenu(btn, function(root)
            if root and root.CreateTitle then root:CreateTitle("Strata") end
            for _, s in ipairs(items) do
              if root and root.CreateRadio then
                root:CreateRadio(s, function() return GetDropDownText(strataDD) == s end, function()
                  UIDropDownMenu_SetText(strataDD, s)
                  SaveAndApply()
                end)
              elseif root and root.CreateButton then
                root:CreateButton(s, function()
                  UIDropDownMenu_SetText(strataDD, s)
                  SaveAndApply()
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(strataDD, function(_, level)
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
    end
  end

  -- Texture presets (simple picker)
  do
    local presets = {
      { "Solid (WHITE8X8)", "Interface\\Buttons\\WHITE8X8" },
      { "Soft Glow", "Interface\\Buttons\\UI-Quickslot2" },
      { "Dialog BG", "Interface\\DialogFrame\\UI-DialogBox-Background" },
      { "Tooltip BG", "Interface\\Tooltips\\UI-Tooltip-Background" },
      { "Circle (TargetingFrame)", "Interface\\TargetingFrame\\UI-StatusBar" },
      { "Raid Icon Star", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
      { "Raid Icon Circle", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
      { "Raid Icon Diamond", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
      { "Raid Icon Triangle", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    }

    local function SetTexturePath(path)
      if texEB and texEB.SetText then
        texEB:SetText(tostring(path or ""))
      end
      SaveAndApply()
    end

    texPickBtn:SetScript("OnClick", function(btn)
      if HasModernMenu() then
        OpenModernMenu(btn, function(root)
          if root and root.CreateTitle then
            root:CreateTitle("Texture Presets")
          end
          if root and root.CreateButton then
            root:CreateButton("(clear)", function() SetTexturePath("") end)
            for _, p in ipairs(presets) do
              root:CreateButton(p[1], function() SetTexturePath(p[2]) end)
            end
          end
        end)
        return
      end

      if EasyMenu then
        local menu = {
          { text = "Texture Presets", isTitle = true, notCheckable = true },
          { text = "(clear)", notCheckable = true, func = function() SetTexturePath("") end },
        }
        for _, p in ipairs(presets) do
          menu[#menu + 1] = { text = p[1], notCheckable = true, func = function() SetTexturePath(p[2]) end }
        end
        UI._texMenuFrame = UI._texMenuFrame or CreateFrame("Frame", "FAL_TextureMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, UI._texMenuFrame, btn, 0, 0, "MENU")
      end
    end)

    texPickBtn:SetScript("OnEnter", function()
      if GameTooltip then
        GameTooltip:SetOwner(texPickBtn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Texture", 1, 1, 1)
        GameTooltip:AddLine("Pick a built-in texture preset.")
        GameTooltip:AddLine("You can also type a path manually:")
        GameTooltip:AddLine("Interface\\Buttons\\WHITE8X8", 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end
    end)
    texPickBtn:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
  end

  do
    local items = { "Both", "Alliance", "Horde" }
    if HasModernMenu() then
      local target = GetDropDownClickTarget(factionDD)
      if target and target.SetScript then
        target:SetScript("OnClick", function(btn)
          OpenModernMenu(btn, function(root)
            if root and root.CreateTitle then root:CreateTitle("Faction") end
            for _, s in ipairs(items) do
              if root and root.CreateButton then
                root:CreateButton(s, function()
                  UIDropDownMenu_SetText(factionDD, s)
                  SaveAndApply()
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(factionDD, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, s in ipairs(items) do
          info = UIDropDownMenu_CreateInfo()
          info.text = s
          info.func = function()
            UIDropDownMenu_SetText(factionDD, s)
            SaveAndApply()
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
    end
  end

  do
    local items = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }
    if HasModernMenu() then
      local target = GetDropDownClickTarget(layerDD)
      if target and target.SetScript then
        target:SetScript("OnClick", function(btn)
          OpenModernMenu(btn, function(root)
            if root and root.CreateTitle then root:CreateTitle("Layer") end
            for _, s in ipairs(items) do
              if root and root.CreateRadio then
                root:CreateRadio(s, function() return GetDropDownText(layerDD) == s end, function()
                  UIDropDownMenu_SetText(layerDD, s)
                  SaveAndApply()
                end)
              elseif root and root.CreateButton then
                root:CreateButton(s, function()
                  UIDropDownMenu_SetText(layerDD, s)
                  SaveAndApply()
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(layerDD, function(_, level)
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
    end
  end

  do
    local items = { "BLEND", "ADD", "MOD", "ALPHAKEY" }
    if HasModernMenu() then
      local target = GetDropDownClickTarget(blendDD)
      if target and target.SetScript then
        target:SetScript("OnClick", function(btn)
          OpenModernMenu(btn, function(root)
            if root and root.CreateTitle then root:CreateTitle("Blend") end
            for _, s in ipairs(items) do
              if root and root.CreateRadio then
                root:CreateRadio(s, function() return GetDropDownText(blendDD) == s end, function()
                  UIDropDownMenu_SetText(blendDD, s)
                  SaveAndApply()
                end)
              elseif root and root.CreateButton then
                root:CreateButton(s, function()
                  UIDropDownMenu_SetText(blendDD, s)
                  SaveAndApply()
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(blendDD, function(_, level)
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
    end
  end

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
    unlockDrag = unlockDrag,
    typeValue = typeValue,

    alpha = alpha,
    scale = scale,

    w = wEB,
    h = hEB,
    point = pointEB,
    x = xEB,
    y = yEB,

    factionDD = factionDD,
    chars = chars,

    textureRow = textureRow,
    layerRow = layerRow,
    texture = texEB,
    texturePick = texPickBtn,
    sub = subEB,
  }

  UI._disableDragMode = DisableDragMode

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
