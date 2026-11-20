local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Hauptfenster, aufgebaut wie Blizzards „Looking For Group“-Fenster
-------------------------------------------------------------------------
WIN_W, WIN_H = 458, 535 -- Maße von Blizzards Gruppensuche
ok, win = pcall(CreateFrame, "Frame", "AutoGroupFinderFrame", UIParent, "PortraitFrameTemplate")
if not ok then win = CreateFrame("Frame", "AutoGroupFinderFrame", UIParent, "BasicFrameTemplateWithInset") end
win:SetSize(WIN_W, WIN_H)
win:SetPoint("CENTER") -- nur ohne Blizzards Fensterverwaltung
win:SetFrameStrata("MEDIUM")
win:SetToplevel(true)
win:EnableMouse(true)
win:Hide()
-- Ein Fenster wie Blizzards Gruppensuche: links platziert, weicht anderen Fenstern aus, die Karte schließt es, Esc auch.
win:SetAttribute("UIPanelLayout-defined", true)
win:SetAttribute("UIPanelLayout-enabled", true)
win:SetAttribute("UIPanelLayout-area", "left")
win:SetAttribute("UIPanelLayout-pushable", 1)
win:SetAttribute("UIPanelLayout-whileDead", 1)

tinsert(UISpecialFrames, "AutoGroupFinderFrame") -- Esc schließt auch das frei verschobene Fenster

-- Frei verschoben (db.winPos) gehört das Fenster nicht mehr zu Blizzards Verwaltung: ohne Bereich
-- zeigen ShowUIPanel/HideUIPanel es einfach an bzw. blenden es aus.
function ApplyWindowMode()
  if db and db.winPos then
    win:SetAttribute("UIPanelLayout-area", nil)
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.winPos.x, db.winPos.y)
  else
    win:SetAttribute("UIPanelLayout-area", "left")
  end
end

-- Im Kampf tut ShowUIPanel nichts, dann einfach an der letzten Stelle zeigen
function OpenWindow()
  ApplyWindowMode()
  if ShowUIPanel and not InCombatLockdown() then ShowUIPanel(win) else win:Show() end
end
function CloseWindow()
  if HideUIPanel and not InCombatLockdown() then HideUIPanel(win) else win:Hide() end
end

-- Shift + Ziehen verschiebt, Doppelklick auf die Titelleiste setzt zurück
win:SetMovable(true)
win:SetClampedToScreen(true)
win:RegisterForDrag("LeftButton")
function StartMoveWindow()
  if not IsShiftKeyDown() or not db then return end
  if not db.winPos then
    -- aus Blizzards Verwaltung lösen, ohne dass das Fenster springt
    local l, t = win:GetLeft(), win:GetTop()
    if not l then return end
    if GetUIPanel and GetUIPanel("left") == win then db.winHome = { x = l, y = t } end
    CloseWindow()
    db.winPos = { x = l, y = t }
    OpenWindow()
  end
  win.moving = true
  win:StartMoving()
end
-- Standardplatz merken, solange Blizzard das Fenster links platziert
SNAP = 40 -- so nah (Pixel) am Standardplatz rastet es beim Loslassen wieder ein
win:HookScript("OnShow", function()
  C_Timer.After(0, function()
    if db and not db.winPos and GetUIPanel and GetUIPanel("left") == win and win:GetLeft() then
      db.winHome = { x = win:GetLeft(), y = win:GetTop() }
    end
  end)
end)

function StopMoveWindow()
  if not win.moving then return end
  win.moving = false
  win:StopMovingOrSizing()
  win:SetUserPlaced(false) -- Position steht in db, nicht in WoWs Layout-Speicher
  local x, y, home = win:GetLeft(), win:GetTop(), db.winHome
  if home and math.abs(x - home.x) < SNAP and math.abs(y - home.y) < SNAP then
    ResetWindow() -- zurück in Blizzards Verwaltung
    return
  end
  db.winPos = { x = x, y = y }
  ApplyWindowMode()
end
function ResetWindow()
  if not db or not db.winPos then return end
  db.winPos = nil
  win:Hide()
  win:ClearAllPoints()
  win:SetPoint("CENTER")
  OpenWindow()
end
win:SetScript("OnDragStart", StartMoveWindow)
win:SetScript("OnDragStop", StopMoveWindow)

-- Griff über der Titelleiste (zwischen Porträt und Zahnrad), mit Hinweis nur bei Shift oder frei verschobenem Fenster
titleHandle = CreateFrame("Button", nil, win)
titleHandle:SetPoint("TOPLEFT", win, "TOPLEFT", 60, 0)
titleHandle:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", -60, -22)
titleHandle:SetFrameLevel(win:GetFrameLevel() + 520)
titleHandle:RegisterForDrag("LeftButton")
titleHandle:SetScript("OnDragStart", StartMoveWindow)
titleHandle:SetScript("OnDragStop", StopMoveWindow)
titleHandle:SetScript("OnDoubleClick", ResetWindow)
titleHandle:SetScript("OnEnter", function(self)
  if not (IsShiftKeyDown() or (db and db.winPos)) then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText(T.TITLE)
  GameTooltip:AddLine(T.WIN_MOVE_TIP, 1, 1, 1, true)
  if db and db.winPos then GameTooltip:AddLine(T.WIN_RESET_TIP, 1, 1, 1, true) end
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

pages = { CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win) }
for _, p in ipairs(pages) do p:SetAllPoints() end
finder, found = pages[1], pages[2]

-------------------------------------------------------------------------
