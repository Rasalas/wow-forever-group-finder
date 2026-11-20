local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Hauptfenster, aufgebaut wie Blizzards „Looking For Group“-Fenster
-------------------------------------------------------------------------
WIN_W, WIN_H = 458, 535 -- Maße von Blizzards Gruppensuche
ok, win = pcall(CreateFrame, "Frame", "AutoGroupFinderFrame", UIParent, "PortraitFrameTemplate")
if not ok then win = CreateFrame("Frame", "AutoGroupFinderFrame", UIParent, "BasicFrameTemplateWithInset") end
win:SetSize(WIN_W, WIN_H)
win:SetFrameStrata("MEDIUM")
win:SetToplevel(true)
win:EnableMouse(true)
win:Hide()
-- Eigene Platzierung statt Blizzards Fensterverwaltung (ShowUIPanel): deren Aufruf aus Add-on-Code
-- färbt sie ein, danach laufen Zauberbuch und Aktionsleisten „unsicher“ (Cooldown-Fehler im Kampf).
HOME_X, HOME_Y = 16, -116 -- Platz von Blizzards linken Fenstern
PANEL_GAP = HOME_X -- Abstand zu Blizzards Fenstern daneben, wie zum Bildschirmrand
tinsert(UISpecialFrames, "AutoGroupFinderFrame") -- Esc schließt

function ApplyWindowMode()
  win:ClearAllPoints()
  if state.winPos then
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", state.winPos.x, state.winPos.y)
  else
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", HOME_X, HOME_Y)
  end
end
ApplyWindowMode()

-- Wie ein Blizzard-Fenster neben den anderen: offene linke/mittlere Fenster schieben unseres nach rechts
function FitBesideBlizzard()
  if state.winPos or not GetUIPanel then return end
  local x = HOME_X
  for _, area in ipairs({ "left", "center" }) do
    local f = GetUIPanel(area)
    if f and f ~= win and f:IsShown() and f:GetRight() then x = math.max(x, f:GetRight() - (UIParent:GetLeft() or 0) + PANEL_GAP) end
  end
  win:ClearAllPoints()
  win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, HOME_Y)
end

function OpenWindow()
  ApplyWindowMode()
  FitBesideBlizzard()
  win:Show()
  win:Raise()
end
function CloseWindow() win:Hide() end

-- Sichere Hooks: laufen nach Blizzards Code und bewegen nur unser Fenster, Blizzards Ablauf bleibt sauber.
-- Die Karte schließt es, wie Blizzards eigene Fenster.
local function AfterPanel(frame)
  if not win:IsShown() then return end
  if frame and frame == _G.WorldMapFrame then win:Hide() return end
  FitBesideBlizzard()
end
if hooksecurefunc then
  if ShowUIPanel then hooksecurefunc("ShowUIPanel", AfterPanel) end
  if HideUIPanel then hooksecurefunc("HideUIPanel", function() AfterPanel() end) end
end

-- Ziehen verschiebt (Titelleiste und freie Stellen), Doppelklick auf die Titelleiste setzt zurück.
-- Wie die Karte: nach dem Schließen wieder am Standardplatz.
win:SetMovable(true)
win:SetClampedToScreen(true)
win:RegisterForDrag("LeftButton")
function StartMoveWindow()
  if not db or winMoving then return end
  winMoving = true
  win:StartMoving()
end
SNAP = 40 -- so nah (Pixel) am Standardplatz rastet es beim Loslassen wieder ein
function StopMoveWindow()
  if not winMoving then return end
  winMoving = false
  win:StopMovingOrSizing()
  win:SetUserPlaced(false) -- Position steht in state, nicht in WoWs Layout-Speicher
  local x, y = win:GetLeft(), win:GetTop()
  local homeY = (UIParent:GetTop() or 0) + HOME_Y
  if x and math.abs(x - HOME_X) < SNAP and math.abs(y - homeY) < SNAP then
    state.winPos = nil
  elseif x then
    state.winPos = { x = x, y = y }
  end
  ApplyWindowMode()
  FitBesideBlizzard()
end
function ResetWindow()
  state.winPos = nil
  ApplyWindowMode()
  FitBesideBlizzard()
end
win:SetScript("OnDragStart", StartMoveWindow)
win:SetScript("OnDragStop", StopMoveWindow)
-- Geschlossen = Verschiebung vergessen
win:HookScript("OnHide", function()
  if winMoving then -- Sicherung: ausgeblendet mitten im Ziehen, dann Ziehen beenden
    winMoving = false
    win:StopMovingOrSizing()
    return
  end
  state.winPos = nil
end)

-- Griff über der Titelleiste (zwischen Porträt und Zahnrad); Hinweis nur, wenn das Fenster verschoben ist
titleHandle = CreateFrame("Button", nil, win)
titleHandle:SetPoint("TOPLEFT", win, "TOPLEFT", 60, 0)
titleHandle:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", -60, -22)
titleHandle:SetFrameLevel(win:GetFrameLevel() + 520)
titleHandle:RegisterForDrag("LeftButton")
titleHandle:SetScript("OnDragStart", StartMoveWindow)
titleHandle:SetScript("OnDragStop", StopMoveWindow)
titleHandle:SetScript("OnDoubleClick", ResetWindow)
titleHandle:SetScript("OnEnter", function(self)
  if not state.winPos then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText(T.TITLE)
  GameTooltip:AddLine(T.WIN_RESET_TIP, 1, 1, 1, true)
  GameTooltip:Show()
end)
titleHandle:SetScript("OnLeave", GameTooltip_Hide)
if win.SetTitle then win:SetTitle(T.TITLE) end
-- Porträt wie in Blizzards Gruppensuche: das große Auge, animiert während der Suche
portraitEye = Eye.Create(win, true, win:GetFrameLevel() + 600) -- über Rahmen (500) und Titel (510)
if portraitEye then
  portraitEye:SetSize(64, 64)
  portraitEye:SetPoint("CENTER", win, "TOPLEFT", 25, -22)
  portraitEye:SetScript("OnClick", portraitEye.OnClick)
  local p = win.GetPortrait and win:GetPortrait()
  if p then p:SetAlpha(0) end
elseif win.SetPortraitToAsset then
  pcall(win.SetPortraitToAsset, win, ICON)
end

-- Blizzards Dropdowns bauen ihr Menü schon bei SetupMenu auf, vor ADDON_LOADED gibt es db aber noch nicht.
-- Nach dem Laden erzeugt Events.lua alle Menüs neu (RefreshMenus).
menus = {}
function SetupMenuLater(button, gen)
  button:SetupMenu(function(owner, root) if db then gen(owner, root) end end)
  menus[#menus + 1] = button
end
function RefreshMenus()
  for _, m in ipairs(menus) do if m.GenerateMenu then m:GenerateMenu() end end
end

function Label(parent, text, font, ...)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  fs:SetPoint(...)
  fs:SetText(text)
  return fs
end

function Tooltip(frame, title, body)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, nil, nil, nil, nil, true) -- lange Texte umbrechen wie bei Blizzard
    if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- Shift-Klick: in ein offenes Chat-Eingabefeld einfügen, sonst den Chat damit öffnen
function InsertChat(text)
  if not text or text == "" then return end
  local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
  if insert and insert(text) then return end
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open then open(text) end
end

function Whisper(name)
  local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
  if tell then tell(name) end
end

-- Hintergrund des eingelassenen Bereichs (Dungeon-Motiv mit Rahmen)
function Inset(parent, top)
  local bg = parent:CreateTexture(nil, "BORDER", nil, -2)
  bg:SetPoint("TOPLEFT", win, "TOPLEFT", 6, top - 3)
  bg:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -5, 6)
  Atlas(bg, "groupfinder-background")
  local border = parent:CreateTexture(nil, "BORDER", nil, 1)
  border:SetPoint("TOPLEFT", win, "TOPLEFT", 4, top - 1)
  border:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 3)
  Atlas(border, "common-insideframe")
end

-- Scrollbereich, dessen Balken nur erscheint, wenn es etwas zu scrollen gibt
function Scroller(parent, anchor, left, top, right, bottom)
  local okS, sf = pcall(CreateFrame, "ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  if not okS then
    sf = CreateFrame("ScrollFrame", nil, parent)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
      local max = self:GetVerticalScrollRange()
      self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
    end)
  end
  local function place(r)
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, top)
    sf:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", r, bottom)
  end
  place(right)
  function sf:SetTopInset(t) top = t; place(self.barShown and right - 22 or right) end
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(WIN_W - 40, 10)
  sf:SetScrollChild(child)
  sf.child = child
  sf:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then child:SetWidth(w) end end)
  -- Volle Breite wie bei Blizzard; Platz für den Balken nur, wenn wirklich gescrollt werden muss
  function sf:SetContentHeight(h)
    child:SetHeight(math.max(10, h))
    local needBar = h > (self:GetHeight() or 0) + 1
    if needBar ~= self.barShown then
      self.barShown = needBar
      place(needBar and right - 22 or right)
    end
    local w = self:GetWidth()
    if w and w > 0 then child:SetWidth(w) end
    if self.ScrollBar then self.ScrollBar:SetShown(needBar) end
    if not needBar then self:SetVerticalScroll(0) end
  end
  return sf
end

pages = { CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win) }
for _, p in ipairs(pages) do p:SetAllPoints() end
finder, found = pages[1], pages[2]

-------------------------------------------------------------------------
