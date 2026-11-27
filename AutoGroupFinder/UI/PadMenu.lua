local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Eigenes Menü für Forevers Controller-Oberfläche.
-- Dort tritt jedes Menü aus Blizzard_Menu der Controller-Steuerung (FrameControlsManager) bei. Öffnet ein
-- Add-on so ein Menü, befleckt es diese Steuerung (Taint): Beim Schließen blockiert Blizzard dann
-- SetPreferredGamepadInteractTarget und zeigt „AutoGroupFinder wurde geblockt“. Mit Controller zeichnet
-- AutoGroupFinder seine Menüs darum selbst; mit Maus bleiben es Blizzards. Die Menü-Generatoren bleiben
-- dieselben: Sie füllen hier eine Beschreibung mit denselben Aufrufen (CreateButton, CreateCheckbox,
-- CreateRadio, CreateTitle, CreateDivider), die dieses Menü dann zeichnet. Untermenüs öffnen an Ort und
-- Stelle, mit „Zurück“ als erster Zeile – mit dem Steuerkreuz einfacher als Menüs nebeneinander.
-------------------------------------------------------------------------
PadMenu = {}

-- Maße wie Blizzards Menüs (MenuStyle1Mixin: Ränder 8/8/8/15, Zeilen 20 hoch)
local ROW, INSET, TOP, BOTTOM, MIN_W, MAX_ROWS = 20, 8, 8, 12, 150, 30

-- Beschreibung wie Blizzards ElementDescription, soweit AutoGroupFinder sie nutzt; alles andere tut nichts
local Desc = {}
local function noop() end
-- Unbekannte Methoden (groß geschrieben, z. B. SetScrollMode) tun nichts; Felder bleiben nil
local meta = { __index = function(_, k) return Desc[k] or (type(k) == "string" and k:match("^%u") and noop) or nil end }
local function New(kind, text, isSelected, setSelected, data)
  return setmetatable({ kind = kind, text = text, isSelected = isSelected, setSelected = setSelected,
    data = data, children = {}, enabled = true }, meta)
end
local function Add(parent, d) parent.children[#parent.children + 1] = d return d end
function Desc:CreateButton(text, fn, data) return Add(self, New("button", text, nil, fn, data)) end
function Desc:CreateCheckbox(text, isSel, setSel, data) return Add(self, New("checkbox", text, isSel, setSel, data)) end
function Desc:CreateRadio(text, isSel, setSel, data) return Add(self, New("radio", text, isSel, setSel, data)) end
function Desc:CreateTitle(text) return Add(self, New("title", text)) end
function Desc:CreateDivider() return Add(self, New("divider")) end
function Desc:SetTooltip(fn) self.tooltip = fn end
function Desc:SetEnabled(v) self.enabled = v and true or false end

local frame -- wird beim ersten Öffnen gebaut
local owner, stack, followed -- wer es geöffnet hat, die offenen Ebenen, bei der Controller-Steuerung angemeldet?

local function Manager()
  return UsingGamepad() and GamepadMode and GamepadMode.FrameControlsManager or nil
end

-- Atlas in seiner eigenen Größe, sonst die Ersatzgrafik in 16×16
local function Sized(tex, atlas, fallback)
  if HasAtlas(atlas) then tex:SetAtlas(atlas, true) else tex:SetTexture(fallback) tex:SetSize(16, 16) end
end

local function Selected(d)
  if not d.isSelected then return false end
  local ok, v = pcall(d.isSelected, d.data)
  return ok and v and true or false
end

local function Build()
  frame = CreateFrame("Frame", "AutoGroupFinderPadMenu", UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  -- Hintergrund wie Blizzards Menüs in Forever (MenuStyle1Mixin:Generate)
  local back = frame:CreateTexture(nil, "BACKGROUND")
  if Atlas(back, "common-dropdown-bg") then
    back:SetPoint("TOPLEFT", -10, 3)
    back:SetPoint("BOTTOMRIGHT", 10, -3)
    back:SetAlpha(0.925)
  else
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.85)
  end
  frame.rows = {}
  frame:Hide()
  tinsert(UISpecialFrames, "AutoGroupFinderPadMenu") -- Esc schließt
  -- B schließt, wie bei Blizzards Menüs
  frame.SmartNavigationCloseHandler = function() frame:Hide() return true end
  -- Die Controller-Steuerung wechselt nur zwischen Fenstern, die sie kennt: wie Blizzards eigene
  -- Popups (ReadyCheck, Gildeneinladung) anmelden und beim Schließen wieder abmelden.
  frame:HookScript("OnShow", function(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    local m = Manager()
    if m and m.HandlePopupShown and not InCombatLockdown() and not followed then
      followed = true
      pcall(m.HandlePopupShown, m, self)
    end
  end)
  frame:HookScript("OnHide", function(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    owner, stack = nil, nil
    if followed then
      followed = nil
      local m = GamepadMode and GamepadMode.FrameControlsManager
      if m and m.HandlePopupHide then pcall(m.HandlePopupHide, m, self) end
    end
  end)
  -- Klick daneben schließt; der Knopf, der es geöffnet hat, schaltet selbst um
  frame:SetScript("OnEvent", function(self, _, button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    if self:IsMouseOver() or (owner and owner.IsMouseOver and owner:IsMouseOver()) then return end
    self:Hide()
  end)
end

local function Row(i)
  local r = frame.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, frame)
  r:SetHeight(ROW)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  r.box = r:CreateTexture(nil, "ARTWORK")
  r.tick = r:CreateTexture(nil, "OVERLAY")
  r.arrow = r:CreateTexture(nil, "ARTWORK")
  r.arrow:SetSize(16, 16)
  r.arrow:SetPoint("RIGHT", 0, 0)
  r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  r.line = r:CreateTexture(nil, "ARTWORK")
  r.line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
  r.line:SetPoint("LEFT")
  r.line:SetPoint("RIGHT")
  r.line:SetHeight(13)
  r.label = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.label:SetJustifyH("LEFT")
  r:SetScript("OnClick", function(self) PadMenu.Pick(self.desc) end)
  r:SetScript("OnEnter", function(self)
    local d = self.desc
    if d and d.tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(d.tooltip, GameTooltip, d)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.rows[i] = r
  return r
end

local BACK = {} -- Zeile „Zurück“ im Untermenü

local function Layout()
  local level = stack[#stack]
  local list = {}
  if #stack > 1 then list[1] = BACK end
  for _, d in ipairs(level.children) do list[#list + 1] = d end
  local cols = math.max(1, math.ceil(#list / MAX_ROWS))
  local perCol = math.ceil(#list / cols)
  local widest, start, startOn = MIN_W, nil, false
  for i, d in ipairs(list) do
    local r = Row(i)
    r.desc = d
    local kind = d == BACK and "back" or d.kind
    local sub = kind == "button" and #d.children > 0
    local choice = kind == "checkbox" or kind == "radio"
    local on = choice and Selected(d)
    -- Kästchen und Häkchen wie MenuVariants.CreateCheckbox/CreateRadio
    r.box:ClearAllPoints()
    r.tick:ClearAllPoints()
    if kind == "checkbox" then
      Sized(r.box, "common-dropdown-ticksquare", "Interface\\Buttons\\UI-CheckBox-Up")
      Sized(r.tick, "common-dropdown-icon-checkmark-yellow", "Interface\\Buttons\\UI-CheckBox-Check")
      r.box:SetPoint("LEFT")
      r.tick:SetPoint("CENTER", r.box, "CENTER", 2, 1)
    elseif kind == "radio" then
      Sized(r.box, "common-dropdown-tickradial", "Interface\\Buttons\\UI-RadioButton")
      Sized(r.tick, "common-dropdown-icon-radialtick-yellow", "Interface\\Buttons\\UI-RadioButton")
      r.box:SetPoint("LEFT", -3, 0)
      r.tick:SetPoint("TOPLEFT", r.box, "TOPLEFT")
    end
    r.box:SetShown(choice)
    r.tick:SetShown(on)
    r.label:SetFontObject(kind == "title" and "GameFontNormalSmall" or "GameFontHighlightSmall")
    r.label:SetJustifyH("LEFT") -- SetFontObject setzt die Ausrichtung der Vorlage
    r.label:ClearAllPoints()
    if choice then
      r.label:SetPoint("LEFT", r.box, "RIGHT", kind == "checkbox" and 7 or 1, kind == "checkbox" and 1 or 0)
    else
      r.label:SetPoint("LEFT", r, "LEFT", 0, 0)
    end
    r.label:SetPoint("RIGHT", r, "RIGHT", sub and -16 or 0, 0)
    r.label:SetText(d == BACK and ("< " .. (_G.BACK or "Back")) or d.text or "")
    r.arrow:SetShown(sub)
    r.line:SetShown(kind == "divider")
    r.label:SetShown(kind ~= "divider")
    local clickable = kind ~= "title" and kind ~= "divider" and d.enabled ~= false
    r:SetEnabled(clickable)
    if r.label.SetTextColor and kind ~= "title" then
      if d.enabled == false then r.label:SetTextColor(0.5, 0.5, 0.5) else r.label:SetTextColor(1, 1, 1) end
    end
    if clickable and (not start or (on and not startOn)) then start, startOn = r, on end
    r:Show()
    local w = (r.label:GetStringWidth() or 0) + (choice and (r.box:GetWidth() or 16) + 8 or 0) + (sub and 20 or 4)
    if w > widest then widest = w end
  end
  for i = #list + 1, #frame.rows do frame.rows[i]:Hide() end
  -- lange Listen (Aufteilung im Schlachtzug) in Spalten statt über den Bildschirm hinaus
  for i = 1, #list do
    local r = frame.rows[i]
    r:SetWidth(widest)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET + math.floor((i - 1) / perCol) * (widest + INSET * 2),
      -TOP - ((i - 1) % perCol) * ROW)
  end
  frame:SetSize(cols * widest + (cols - 1) * INSET * 2 + INSET * 2, perCol * ROW + TOP + BOTTOM)
  -- Der Controller-Cursor beginnt auf der gewählten Zeile, wie in Blizzards Auswahlfeldern
  if start and SmartNavigation and SmartNavigation.SetTargetButtonForFrame and not InCombatLockdown() then
    pcall(SmartNavigation.SetTargetButtonForFrame, SmartNavigation, frame, start)
  end
end

-- Zeile gewählt: Untermenü öffnen, Häkchen umschalten (Menü bleibt offen), sonst ausführen und schließen
function PadMenu.Pick(d)
  if not d then return end
  if d == BACK then
    table.remove(stack)
    Layout()
    return
  end
  if d.kind == "button" and #d.children > 0 then
    stack[#stack + 1] = d
    Layout()
    return
  end
  local opener = owner
  if d.kind == "checkbox" then
    PlaySound(Selected(d) and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856))
    if d.setSelected then d.setSelected(d.data) end
    if frame:IsShown() then Layout() end
  else
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    frame:Hide()
    if d.setSelected then d.setSelected(d.data) end
  end
  -- Auswahlfelder zeigen ihre Auswahl im Knopf: neu erzeugen, wie Blizzard es nach dem Schließen tut
  if opener and opener.GenerateMenu then pcall(opener.GenerateMenu, opener) end
end

-- Menü des Generators `gen(owner, root)` unter `owner` öffnen; ist es dort schon offen, schließen.
function PadMenu.Open(anchor, gen)
  if not frame then Build() end
  if frame:IsShown() then
    local same = owner == anchor
    frame:Hide()
    if same then return end
  end
  local root = New("root")
  local ok, err = pcall(gen, anchor, root)
  if not ok then geterrorhandler()(err) return end
  if #root.children == 0 then return end
  owner, stack = anchor, { root }
  Layout()
  frame:ClearAllPoints()
  if anchor and anchor ~= UIParent then
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  else
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
  end
  frame:Show()
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
end

function PadMenu.Close() if frame then frame:Hide() end end

-- Rechtsklick-Menü: mit Maus Blizzards, mit Controller das eigene
function ContextMenu(owner, gen)
  if UsingGamepad() then PadMenu.Open(owner, gen) return true end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
  MenuUtil.CreateContextMenu(owner, gen)
  return true
end

-- Auswahlfeld (DropdownButton): Blizzards eingebauter Klick ruft self:OpenMenu(). Mit Controller öffnet
-- stattdessen das eigene Menü; mit Maus bleibt es Blizzards.
function PadMenu.Hook(button, gen)
  local blizzardOpen = DropdownButtonMixin and DropdownButtonMixin.OpenMenu
  button.OpenMenu = function(self, ...)
    if UsingGamepad() then
      if self.IsEnabled and self:IsEnabled() == false then return end
      PadMenu.Open(self, gen)
    elseif blizzardOpen then
      return blizzardOpen(self, ...)
    end
  end
  button:HookScript("OnHide", function(self) if frame and owner == self then frame:Hide() end end)
end
