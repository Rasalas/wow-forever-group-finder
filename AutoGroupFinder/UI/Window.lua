local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Hauptfenster, aufgebaut wie Blizzards „Looking For Group“-Fenster
-------------------------------------------------------------------------
WIN_W, WIN_H = 458, 535 -- Maße von Blizzards Gruppensuche
ok, win = pcall(CreateFrame, "Frame", "AutoGroupFinderFrame", UIParent, "PortraitFrameTemplate")
if not ok then win = CreateFrame("Frame", "AutoGroupFinderFrame", UIParent, "BasicFrameTemplateWithInset") end
win:SetSize(WIN_W, WIN_H)
win:SetPoint("CENTER")
win:SetFrameStrata("HIGH")
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetClampedToScreen(true)
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
win:Hide()
tinsert(UISpecialFrames, "AutoGroupFinderFrame") -- Esc schließt
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
    GameTooltip:SetText(title)
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
