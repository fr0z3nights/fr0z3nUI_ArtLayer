---@diagnostic disable: undefined-global

local ADDON, ns = ...
ns = ns or {}

local PREFIX = "|cff00ccff[ArtLayer]|r "
local function Print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
  else
    print(PREFIX .. tostring(msg))
  end
end

local function EnsureDB()
  fr0z3nUI_ArtLayerDB = fr0z3nUI_ArtLayerDB or {}
  fr0z3nUI_ArtLayerDB.overrides = fr0z3nUI_ArtLayerDB.overrides or {}
  fr0z3nUI_ArtLayerDB.widgets = fr0z3nUI_ArtLayerDB.widgets or {}
  fr0z3nUI_ArtLayerDB.seen = fr0z3nUI_ArtLayerDB.seen or {}
  return fr0z3nUI_ArtLayerDB
end

local function SafeCall(obj, method, ...)
  if not obj then return false end
  local fn = obj[method]
  if type(fn) ~= "function" then return false end
  local ok = pcall(fn, obj, ...)
  return ok
end

local function GetFramePath(frame, maxDepth)
  maxDepth = maxDepth or 8
  if not frame then return "<nil>" end
  local out = {}
  local cur = frame
  for _ = 1, maxDepth do
    if not cur then break end
    local n = cur.GetName and cur:GetName()
    out[#out + 1] = n or ("<" .. tostring(cur) .. ">")
    cur = cur.GetParent and cur:GetParent() or nil
  end
  return table.concat(out, " <- ")
end

local function DescribeFrame(frame)
  if not frame then
    Print("No frame")
    return
  end

  local name = frame.GetName and frame:GetName() or nil
  local strata = frame.GetFrameStrata and frame:GetFrameStrata() or "?"
  local level = frame.GetFrameLevel and frame:GetFrameLevel() or "?"
  local shown = frame.IsShown and frame:IsShown() and "shown" or "hidden"

  Print(string.format("Frame: %s (%s) strata=%s level=%s", name or tostring(frame), shown, tostring(strata), tostring(level)))
  Print("Path: " .. GetFramePath(frame))

  if frame.GetRegions then
    local regions = { frame:GetRegions() }
    local count = 0
    for i = 1, #regions do
      local r = regions[i]
      if r and r.GetObjectType then
        local typ = r:GetObjectType()
        local rname = r.GetName and r:GetName() or ""
        if r.GetDrawLayer then
          local layer, sub = r:GetDrawLayer()
          Print(string.format("  Region %d: %s %s layer=%s sub=%s", i, typ, rname, tostring(layer), tostring(sub)))
        else
          Print(string.format("  Region %d: %s %s", i, typ, rname))
        end
        count = count + 1
        if count >= 12 then
          Print("  ...")
          break
        end
      end
    end
  end
end

local function ApplyOverrides()
  local db = EnsureDB()
  for frameName, ov in pairs(db.overrides) do
    local f = _G and _G[frameName] or nil
    if f then
      if ov.strata then
        SafeCall(f, "SetFrameStrata", ov.strata)
      end
      if ov.level then
        SafeCall(f, "SetFrameLevel", ov.level)
      end
    end
  end
end

local function GetFocusFrame()
  if GetMouseFocus then
    local f = GetMouseFocus()
    if f then return f end
  end
  return nil
end

local function SetOverrideOnFocus(kind, value)
  local f = GetFocusFrame()
  if not f then
    Print("No mouse focus frame")
    return
  end
  local name = f.GetName and f:GetName()
  if not name then
    Print("Focused frame has no name; cannot persist override")
    return
  end

  local db = EnsureDB()
  db.overrides[name] = db.overrides[name] or {}
  db.overrides[name][kind] = value
  ApplyOverrides()
  DescribeFrame(f)
end

local function ClearOverrideOnFocus()
  local f = GetFocusFrame()
  if not f then
    Print("No mouse focus frame")
    return
  end
  local name = f.GetName and f:GetName()
  if not name then
    Print("Focused frame has no name")
    return
  end

  local db = EnsureDB()
  if db.overrides[name] then
    db.overrides[name] = nil
    Print("Cleared override for " .. name)
  else
    Print("No override for " .. name)
  end
end

-- -----------------------------------------------------------------------------
-- Widgets: textures/models with simple conditions
-- -----------------------------------------------------------------------------

local WIDGET_ROOT
local widgetFrames = {}

local function Clamp(v, minV, maxV)
  v = tonumber(v)
  if not v then return minV end
  if minV and v < minV then return minV end
  if maxV and v > maxV then return maxV end
  return v
end

local function SplitCSV(s)
  s = tostring(s or "")
  local out = {}
  for part in s:gmatch("[^,]+") do
    part = part:gsub("^%s+", ""):gsub("%s+$", "")
    if part ~= "" then out[#out + 1] = part end
  end
  return out
end

local function NormalizeTexturePath(tex)
  tex = tostring(tex or "")
  tex = tex:gsub("/", "\\")
  tex = tex:gsub("\\+", "\\")
  -- Prefer extension-less paths for consistency.
  tex = tex:gsub("%.tga$", ""):gsub("%.blp$", "")
  -- Canonicalize common casing variants.
  tex = tex:gsub("^Interface\\Addons\\", "Interface\\AddOns\\")
  if tex == "" then return "" end
  if tex:find("^Interface\\") then
    return tex
  end
  -- Accept bare filenames or Media\foo.tga or media\foo.tga
  tex = tex:gsub("^[Mm]edia\\", "")
  return "Interface\\AddOns\\fr0z3nUI_ArtLayer\\media\\" .. tex
end

local function GetPlayerKey()
  if not UnitName then return nil end
  local name, realm = UnitName("player")
  if not name or name == "" then return nil end
  realm = realm and realm ~= "" and realm or (GetRealmName and GetRealmName() or "")
  return name .. "-" .. tostring(realm)
end

local function RecordSeen()
  local db = EnsureDB()
  local key = GetPlayerKey()
  if not key then return end
  db.seen[key] = time and time() or 0
end

local function PlayerFaction()
  if UnitFactionGroup then
    local f = UnitFactionGroup("player")
    return f
  end
  return nil
end

local function ConditionPlayer(c)
  local key = GetPlayerKey()
  if not key then return false end
  local nameOnly = key:match("^([^-]+)") or key

  local list = c and c.list
  if type(list) == "string" then
    list = SplitCSV(list)
  end
  if type(list) ~= "table" then return false end

  local ignoreRealm = (c and c.ignoreRealm) and true or false

  for _, who in ipairs(list) do
    who = tostring(who or "")
    who = who:gsub("^%s+", ""):gsub("%s+$", "")
    if who ~= "" then
      if ignoreRealm then
        local wantName = who:match("^([^-]+)") or who
        if wantName:lower() == nameOnly:lower() then
          return true
        end
      else
        if who:find("-", 1, true) then
          if who:lower() == key:lower() then
            return true
          end
        else
          if who:lower() == nameOnly:lower() then
            return true
          end
        end
      end
    end
  end
  return false
end

local function HasMail()
  if HasNewMail then
    return HasNewMail() and true or false
  end
  return false
end

local function IsInCombat()
  if InCombatLockdown then
    return InCombatLockdown() and true or false
  end
  return false
end

local function ModelSetRotation(modelFrame, rotation)
  if not modelFrame then return end
  rotation = tonumber(rotation) or 0
  if modelFrame.SetFacing then
    modelFrame:SetFacing(rotation)
    return
  end
  if modelFrame.SetRotation then
    modelFrame:SetRotation(rotation)
  end
end

local function ModelApplyZoom(modelFrame, zoom)
  if not modelFrame then return end
  zoom = tonumber(zoom)
  if not zoom then return end
  if modelFrame.SetCamDistanceScale then
    modelFrame:SetCamDistanceScale(zoom)
    return
  end
  if modelFrame.SetPortraitZoom then
    modelFrame:SetPortraitZoom(zoom)
    return
  end
  if modelFrame.SetModelScale then
    modelFrame:SetModelScale(zoom)
  end
end

local function ModelApplyAnimation(modelFrame, anim)
  if not modelFrame then return end
  anim = tonumber(anim)
  if anim == nil then return end
  if modelFrame.SetAnimation then
    modelFrame:SetAnimation(anim)
  end
end

local function ApplyModelSpec(modelFrame, spec)
  if not (modelFrame and spec) then return end
  if modelFrame.ClearModel then modelFrame:ClearModel() end

  local kind = tostring(spec.kind or "player"):lower()
  local id = spec.id

  if kind == "player" then
    if modelFrame.SetUnit then
      modelFrame:SetUnit("player")
    end
  elseif kind == "npc" or kind == "creature" then
    local npcID = tonumber(id)
    if npcID and modelFrame.SetCreature then
      modelFrame:SetCreature(npcID)
    end
  elseif kind == "display" then
    local displayID = tonumber(id)
    if displayID and modelFrame.SetDisplayInfo then
      modelFrame:SetDisplayInfo(displayID)
    end
  elseif kind == "file" then
    local fileID = tonumber(id)
    if fileID and modelFrame.SetModelByFileID then
      modelFrame:SetModelByFileID(fileID)
    end
  end

  if spec.rotation ~= nil then ModelSetRotation(modelFrame, spec.rotation) end
  if spec.zoom ~= nil then ModelApplyZoom(modelFrame, spec.zoom) end
  if spec.anim ~= nil then ModelApplyAnimation(modelFrame, spec.anim) end
end

local function EnsureRoot()
  if WIDGET_ROOT then return end
  WIDGET_ROOT = CreateFrame("Frame", "fr0z3nUI_ArtLayer_Root", UIParent)
  WIDGET_ROOT:SetAllPoints(UIParent)
  WIDGET_ROOT:Hide()
end

local function ApplyWidgetFrameProps(frame, widget)
  if not (frame and widget) then return end

  local scale = Clamp(widget.scale or 1, 0.05, 10)
  if frame.SetScale then
    frame:SetScale(scale)
  end

  local clickthrough = (widget.clickthrough ~= nil) and (widget.clickthrough and true or false) or true
  if frame.EnableMouse then
    frame:EnableMouse(not clickthrough)
  end

  local w = Clamp(widget.w or 128, 1, 4096)
  local h = Clamp(widget.h or 128, 1, 4096)
  frame:SetSize(w, h)

  frame:ClearAllPoints()
  local p = widget.point or "CENTER"
  local x = tonumber(widget.x) or 0
  local y = tonumber(widget.y) or 0
  frame:SetPoint(p, UIParent, p, x, y)

  if frame.SetFrameStrata and widget.strata then
    SafeCall(frame, "SetFrameStrata", widget.strata)
  end
  if frame.SetFrameLevel and widget.level then
    SafeCall(frame, "SetFrameLevel", tonumber(widget.level) or 1)
  end

  local a = Clamp(widget.alpha or 1, 0, 1)
  if widget.type == "texture" then
    if frame.tex then
      if frame.tex.SetAlpha then frame.tex:SetAlpha(a) end
      if frame.tex.SetBlendMode then
        SafeCall(frame.tex, "SetBlendMode", widget.blend or "BLEND")
      end
      if widget.layer and frame.tex.SetDrawLayer then
        SafeCall(frame.tex, "SetDrawLayer", widget.layer, tonumber(widget.sub) or 0)
      end
    end
  elseif widget.type == "model" then
    if frame.model and frame.model.SetAlpha then
      frame.model:SetAlpha(a)
    end
  end
end

local function CreateWidgetFrame(key, widget)
  EnsureRoot()
  local f
  if widget.type == "model" then
    f = CreateFrame("Frame", nil, WIDGET_ROOT)
    local m = CreateFrame("DressUpModel", nil, f)
    m:SetAllPoints(f)
    if m.EnableMouse then m:EnableMouse(false) end
    f.model = m
  else
    f = CreateFrame("Frame", nil, WIDGET_ROOT)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(f)
    f.tex = t
  end
  widgetFrames[key] = f
  return f
end

local function GetOrCreateWidgetFrame(key, widget)
  local f = widgetFrames[key]
  if not f then
    f = CreateWidgetFrame(key, widget)
  end
  return f
end

local function ConditionSeen(db, cond)
  local list = cond.list or {}
  local ignoreRealm = cond.ignoreRealm and true or false

  for _, who in ipairs(list) do
    who = tostring(who or "")
    if who ~= "" then
      if ignoreRealm then
        for key in pairs(db.seen) do
          local n = key:match("^([^-]+)") or key
          if n:lower() == who:lower() then
            return true
          end
        end
      else
        -- allow 'Name' or 'Name-Realm'
        for key in pairs(db.seen) do
          if key:lower() == who:lower() then
            return true
          end
        end
        for key in pairs(db.seen) do
          local n = key:match("^([^-]+)") or key
          if n:lower() == who:lower() then
            return true
          end
        end
      end
    end
  end
  return false
end

local function EvaluateWidget(db, widget)
  if not widget.enabled then return false end
  local conds = widget.conds
  if type(conds) ~= "table" then return true end

  for _, c in ipairs(conds) do
    if c.type == "faction" then
      local want = tostring(c.value or "")
      local have = PlayerFaction() or ""
      if want ~= "" and have ~= want then return false end
    elseif c.type == "seen" then
      if not ConditionSeen(db, c) then return false end
    elseif c.type == "mail" then
      if not HasMail() then return false end
    elseif c.type == "combat" then
      local want = tostring(c.value or "in")
      local inCombat = IsInCombat()
      if want == "in" and not inCombat then return false end
      if want == "out" and inCombat then return false end
    elseif c.type == "player" then
      if not ConditionPlayer(c) then return false end
    end
  end

  return true
end

local function ApplyWidget(key)
  local db = EnsureDB()
  local w = db.widgets[key]
  if type(w) ~= "table" then return end

  w.type = w.type or "texture"
  if w.enabled == nil then w.enabled = true end
  if w.scale == nil then w.scale = 1 end
  if w.clickthrough == nil then w.clickthrough = true end
  if w.type == "texture" and w.blend == nil then w.blend = "BLEND" end

  local frame = GetOrCreateWidgetFrame(key, w)
  ApplyWidgetFrameProps(frame, w)

  if w.type == "texture" then
    local texPath = NormalizeTexturePath(w.texture)
    if frame.tex and texPath and texPath ~= "" then
      frame.tex:SetTexture(texPath)
    end
  elseif w.type == "model" then
    if frame.model then
      ApplyModelSpec(frame.model, w.model or {})
    end
  end

  local show = EvaluateWidget(db, w)
  if show then
    frame:Show()
    if WIDGET_ROOT and not WIDGET_ROOT:IsShown() then WIDGET_ROOT:Show() end
  else
    frame:Hide()
  end
end

local function ApplyAllWidgets()
  local db = EnsureDB()
  local anyShown = false
  for key in pairs(db.widgets) do
    ApplyWidget(key)
    local f = widgetFrames[key]
    if f and f.IsShown and f:IsShown() then anyShown = true end
  end
  if WIDGET_ROOT then
    if anyShown then WIDGET_ROOT:Show() else WIDGET_ROOT:Hide() end
  end
end

local function AddWidgetTexture(key, tex)
  local db = EnsureDB()
  key = tostring(key or "")
  if key == "" then
    Print("Usage: /fal widgets add texture <key> <file.tga>")
    return
  end
  db.widgets[key] = db.widgets[key] or {}
  local w = db.widgets[key]
  w.type = "texture"
  w.enabled = true
  w.texture = tex
  w.w = w.w or 128
  w.h = w.h or 128
  w.point = w.point or "CENTER"
  w.x = w.x or 0
  w.y = w.y or 0
  w.alpha = w.alpha or 1
  w.scale = w.scale or 1
  if w.clickthrough == nil then w.clickthrough = true end
  w.layer = w.layer or "ARTWORK"
  w.sub = w.sub or 0
  w.blend = w.blend or "BLEND"
  w.conds = w.conds or {}
  ApplyWidget(key)
  Print("Added texture widget: " .. key)
end

local function AddWidgetModel(key, kind, id)
  local db = EnsureDB()
  key = tostring(key or "")
  if key == "" then
    Print("Usage: /fal widgets add model <key> <player|npc|display|file> [id]")
    return
  end
  db.widgets[key] = db.widgets[key] or {}
  local w = db.widgets[key]
  w.type = "model"
  w.enabled = true
  w.w = w.w or 160
  w.h = w.h or 160
  w.point = w.point or "CENTER"
  w.x = w.x or 0
  w.y = w.y or 0
  w.alpha = w.alpha or 1
  w.scale = w.scale or 1
  if w.clickthrough == nil then w.clickthrough = true end
  w.conds = w.conds or {}
  w.model = w.model or {}
  w.model.kind = tostring(kind or "player"):lower()
  w.model.id = (w.model.kind == "player") and nil or tonumber(id)
  w.model.zoom = w.model.zoom or 1.0
  w.model.rotation = w.model.rotation or 0
  ApplyWidget(key)
  Print("Added model widget: " .. key)
end

-- Expose bits for UI module
ns.Print = Print
ns.EnsureDB = EnsureDB
ns.NormalizeTexturePath = NormalizeTexturePath
ns.ApplyWidget = ApplyWidget
ns.ApplyAllWidgets = ApplyAllWidgets

local function SetWidgetSize(key, w, h)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.w = tonumber(w) or wd.w
  wd.h = tonumber(h) or wd.h
  ApplyWidget(key)
end

local function SetWidgetPos(key, point, x, y)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.point = tostring(point or "CENTER")
  wd.x = tonumber(x) or 0
  wd.y = tonumber(y) or 0
  ApplyWidget(key)
end

local function SetWidgetAlpha(key, a)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.alpha = Clamp(a, 0, 1)
  ApplyWidget(key)
end

local function SetWidgetStrata(key, strata)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.strata = tostring(strata or ""):upper()
  ApplyWidget(key)
end

local function SetWidgetLayer(key, layer, sub)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.layer = tostring(layer or "ARTWORK"):upper()
  wd.sub = tonumber(sub) or 0
  ApplyWidget(key)
end

local function ToggleWidget(key)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.enabled = not (wd.enabled == false)
  ApplyWidget(key)
  Print(string.format("Widget %s: %s", key, wd.enabled and "enabled" or "disabled"))
end

local function WidgetCondClear(key)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.conds = {}
  ApplyWidget(key)
  Print("Cleared conditions for " .. key)
end

local function WidgetCondAddFaction(key, faction)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.conds = wd.conds or {}
  table.insert(wd.conds, { type = "faction", value = tostring(faction or "") })
  ApplyWidget(key)
  Print("Added faction condition to " .. key)
end

local function WidgetCondAddSeen(key, csv, ignoreRealm)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.conds = wd.conds or {}
  table.insert(wd.conds, { type = "seen", list = SplitCSV(csv), ignoreRealm = ignoreRealm and true or false })
  ApplyWidget(key)
  Print("Added seen condition to " .. key)
end

local function WidgetCondAddMail(key)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.conds = wd.conds or {}
  table.insert(wd.conds, { type = "mail" })
  ApplyWidget(key)
  Print("Added mail condition to " .. key)
end

local function WidgetCondAddCombat(key, mode)
  local db = EnsureDB()
  local wd = db.widgets[key]
  if type(wd) ~= "table" then Print("Unknown widget: " .. tostring(key)) return end
  wd.conds = wd.conds or {}
  mode = tostring(mode or "in"):lower()
  if mode ~= "in" and mode ~= "out" then mode = "in" end
  table.insert(wd.conds, { type = "combat", value = mode })
  ApplyWidget(key)
  Print("Added combat condition to " .. key)
end

local function ListWidgets()
  local db = EnsureDB()
  Print("Widgets:")
  local n = 0
  for key, w in pairs(db.widgets) do
    n = n + 1
    local f = widgetFrames[key]
    local vis = (f and f.IsShown and f:IsShown()) and "shown" or "hidden"
    Print(string.format("- %s (%s) %s", key, tostring(w.type or "?"), vis))
  end
  if n == 0 then Print("(none)") end
end

local function SeenList()
  local db = EnsureDB()
  Print("Seen characters:")
  local n = 0
  for key, t in pairs(db.seen) do
    n = n + 1
    Print(string.format("- %s (%s)", key, tostring(t)))
  end
  if n == 0 then Print("(none)") end
end

local function SeenClear()
  local db = EnsureDB()
  db.seen = {}
  Print("Cleared seen list")
  ApplyAllWidgets()
end

SLASH_FR0Z3NUI_ARTLAYER1 = "/fal"
SLASH_FR0Z3NUI_ARTLAYER2 = "/artlayer"
SlashCmdList.FR0Z3NUI_ARTLAYER = function(msg)
  EnsureDB()
  msg = tostring(msg or "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd and cmd:lower()) or ""

  if cmd == "" then
    if ns and ns.OpenConfig then
      ns.OpenConfig()
    else
      Print("UI not loaded")
    end
    return
  end

  if cmd == "help" or cmd == "?" then
    Print("/fal inspect  - prints info about the frame under your cursor")
    Print("/fal strata <BACKGROUND|LOW|MEDIUM|HIGH|DIALOG|FULLSCREEN|FULLSCREEN_DIALOG|TOOLTIP>")
    Print("/fal level <number>")
    Print("/fal clear - clears saved override for focused frame")
    Print("/fal ui - opens the widget config window")
    Print("/fal widgets list")
    Print("/fal widgets add texture <key> <file.tga|media\\file.tga|Interface\\...>")
    Print("/fal widgets add model <key> <player|npc|display|file> [id]")
    Print("/fal widgets toggle <key>")
    Print("/fal widgets set <key> size <w> <h>")
    Print("/fal widgets set <key> pos <point> <x> <y>")
    Print("/fal widgets set <key> alpha <0-1>")
    Print("/fal widgets set <key> strata <strata>")
    Print("/fal widgets set <key> layer <ARTWORK|OVERLAY|BACKGROUND|BORDER> [sub]")
    Print("/fal widgets cond <key> clear")
    Print("/fal widgets cond <key> add faction <Alliance|Horde>")
    Print("/fal widgets cond <key> add seen <Name1,Name2,...> [norealm]")
    Print("/fal widgets cond <key> add mail")
    Print("/fal widgets cond <key> add combat <in|out>")
    Print("/fal seen list")
    Print("/fal seen clear")
    return
  end

  if cmd == "inspect" then
    DescribeFrame(GetFocusFrame())
    return
  end

  if cmd == "strata" then
    local v = tostring(rest or ""):upper()
    if v == "" then
      Print("Usage: /fal strata <strata>")
      return
    end
    SetOverrideOnFocus("strata", v)
    return
  end

  if cmd == "level" then
    local n = tonumber(rest)
    if not n then
      Print("Usage: /fal level <number>")
      return
    end
    SetOverrideOnFocus("level", math.floor(n))
    return
  end

  if cmd == "clear" or cmd == "reset" then
    ClearOverrideOnFocus()
    return
  end

  if cmd == "ui" or cmd == "config" then
    if ns and ns.OpenConfig then
      ns.OpenConfig()
    else
      Print("UI not loaded")
    end
    return
  end

  if cmd == "seen" then
    local sub, arg = tostring(rest or ""):match("^(%S+)%s*(.-)$")
    sub = (sub and sub:lower()) or ""
    if sub == "list" then
      SeenList()
      return
    elseif sub == "clear" then
      SeenClear()
      return
    end
    Print("Usage: /fal seen list|clear")
    return
  end

  if cmd == "widgets" or cmd == "widget" then
    local sub, rest2 = tostring(rest or ""):match("^(%S+)%s*(.-)$")
    sub = (sub and sub:lower()) or ""

    if sub == "list" then
      ListWidgets()
      return
    end

    if sub == "add" then
      local typ, rest3 = tostring(rest2 or ""):match("^(%S+)%s*(.-)$")
      typ = (typ and typ:lower()) or ""
      if typ == "texture" then
        local key, tex = tostring(rest3 or ""):match("^(%S+)%s*(.-)$")
        AddWidgetTexture(key, tex)
        return
      elseif typ == "model" then
        local key, kind, id = tostring(rest3 or ""):match("^(%S+)%s*(%S+)%s*(.-)$")
        AddWidgetModel(key, kind, id)
        return
      end
      Print("Usage: /fal widgets add texture <key> <file.tga> OR /fal widgets add model <key> <kind> [id]")
      return
    end

    if sub == "toggle" then
      ToggleWidget(tostring(rest2 or ""))
      return
    end

    if sub == "set" then
      local key, field, a, b = tostring(rest2 or ""):match("^(%S+)%s*(%S+)%s*(%S*)%s*(.-)$")
      field = tostring(field or ""):lower()
      if field == "size" then
        SetWidgetSize(key, a, b)
        return
      elseif field == "pos" then
        -- pos <point> <x> <y>
        local point, x, y = tostring(rest2 or ""):match("^%S+%s+pos%s+(%S+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s*$")
        if not point then
          Print("Usage: /fal widgets set <key> pos <point> <x> <y>")
          return
        end
        SetWidgetPos(key, point, tonumber(x) or 0, tonumber(y) or 0)
        return
      elseif field == "alpha" then
        SetWidgetAlpha(key, a)
        return
      elseif field == "strata" then
        SetWidgetStrata(key, a)
        return
      elseif field == "layer" then
        SetWidgetLayer(key, a, tonumber(b))
        return
      end
      Print("Usage: /fal widgets set <key> size|pos|alpha|strata|layer ...")
      return
    end

    if sub == "cond" then
      local key, rest3 = tostring(rest2 or ""):match("^(%S+)%s*(.-)$")
      local op, rest4 = tostring(rest3 or ""):match("^(%S+)%s*(.-)$")
      op = (op and op:lower()) or ""
      if op == "clear" then
        WidgetCondClear(key)
        return
      end
      if op == "add" then
        local ctype, rest5 = tostring(rest4 or ""):match("^(%S+)%s*(.-)$")
        ctype = (ctype and ctype:lower()) or ""
        if ctype == "faction" then
          WidgetCondAddFaction(key, rest5)
          return
        elseif ctype == "seen" then
          local list, flag = tostring(rest5 or ""):match("^(.-)%s*(%S*)$")
          WidgetCondAddSeen(key, list, flag and flag:lower() == "norealm")
          return
        elseif ctype == "mail" then
          WidgetCondAddMail(key)
          return
        elseif ctype == "combat" then
          WidgetCondAddCombat(key, rest5)
          return
        end
        Print("Usage: /fal widgets cond <key> add faction|seen|mail|combat ...")
        return
      end
      Print("Usage: /fal widgets cond <key> clear|add ...")
      return
    end

    Print("Unknown widgets command. Try /fal help")
    return
  end

  Print("Unknown command. Try /fal help")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UPDATE_PENDING_MAIL")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    EnsureDB()
    return
  end
  if event == "PLAYER_LOGIN" then
    EnsureDB()
    RecordSeen()
    ApplyOverrides()
    ApplyAllWidgets()
    Print("Loaded. Use /fal")
    return
  end

  -- Re-evaluate widgets on relevant events
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_PENDING_MAIL" then
    ApplyAllWidgets()
    return
  end
end)
