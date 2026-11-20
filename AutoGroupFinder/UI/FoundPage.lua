local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Seite 2: Gefundene Spieler, gruppiert nach Rolle
-------------------------------------------------------------------------
Inset(found, -72)

-- Leiste wie in Blizzards Browse-Ansicht: Kategorie, Aktivitäten, Aktualisieren.
-- Dieselbe Auswahl wie auf der ersten Seite.
catDd = Dropdown(found, 150, function()
    local opts = {}
    for _, c in ipairs(Categories()) do
      if #ActivityTree(c.id).all > 0 then opts[#opts + 1] = { c.id, c.name } end
    end
    return opts
  end, nil,
  function() return CurrentCategory() end,
  function(v) db.category, db.view = v, "activities"; Rebuild() end,
  "TOPLEFT", win, "TOPLEFT", 62, -38)

function ActivitySummary()
  local t, picked = ActivityTree(), {}
  for _, e in ipairs(t.all) do if IsPicked(e) then picked[#picked + 1] = e end end
  if #picked == 0 then return T.NOTHING_PICKED end
  if #picked == #t.all and #picked > 1 then return T.ALL_ACTIVITIES:format(#picked) end
  if #picked == 1 then return picked[1].name end
  return picked[1].name .. " +" .. (#picked - 1)
end

okAct, actDd = pcall(CreateFrame, "DropdownButton", nil, found, "WowStyle1DropdownTemplate")
if okAct and actDd and actDd.SetupMenu then
  actDd:SetWidth(170)
  SetupMenuLater(actDd, function(_, root)
    local t = ActivityTree()
    local multi = #t.groups > 1 or (#t.groups > 0 and #t.loose > 0)
    local function add(e)
      root:CreateCheckbox(e.name, function() return IsPicked(e) end, function()
        db.activities[e.id] = not IsPicked(e)
        Rebuild()
      end)
    end
    for _, e in ipairs(t.loose) do add(e) end
    for _, g in ipairs(t.groups) do
      if multi then root:CreateTitle(g.name or "?") end
      for _, e in ipairs(g.items) do add(e) end
    end
  end)
else
  actDd = CreateFrame("Frame", nil, found)
  actDd:SetSize(170, 24)
  actDd.Text = Label(actDd, "", "GameFontHighlightSmall", "LEFT", actDd, "LEFT", 4, 0)
end
actDd:SetPoint("LEFT", catDd, "RIGHT", 8, 0)

refresh = CreateFrame("Button", nil, found)
refresh:SetSize(32, 32)
refresh:SetPoint("LEFT", actDd, "RIGHT", 9, 0)
refresh:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
refresh:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
refresh:SetDisabledTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
refresh:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
refresh.Icon = refresh:CreateTexture(nil, "ARTWORK", nil, 5)
refresh.Icon:SetSize(16, 16)
refresh.Icon:SetPoint("CENTER", -1, 0)
refresh.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
refresh:SetScript("OnClick", function() DoSearch(true) end)
Tooltip(refresh, T.REFRESH)

list = Scroller(found, win, 12, -80, -12, 62)
hooksecurefunc(list, "SetVerticalScroll", function() HideTargetButton() end)
listEmpty = Label(found, "", "GameFontDisable", "TOP", win, "TOP", 0, -120)
listEmpty:SetWidth(WIN_W - 60)
-- Während der Suche Blizzards Lade-Kreisel mit „Suche …“ darüber, wie in der echten Gruppensuche
local okSpin
okSpin, spinner = pcall(CreateFrame, "Frame", nil, found, "LoadingSpinnerTemplate")
if okSpin and spinner and spinner.Anim then
  spinner:SetPoint("TOP", win, "TOP", 0, -190)
  spinner.label = Label(spinner, SEARCHING or T.SEARCHING, "GameFontNormalLarge", "BOTTOM", spinner, "TOP", 0, 4)
  spinner:Hide()
else
  spinner = nil
end
HEAD_H, PLAYER_H = 28, 58
listRows = {}

-- Nähe zum Dungeon als Symbol in der Namenszeile: 2 = am/im Dungeon, 1 = Zone des Eingangs
function NearIcon(level)
  if level == 2 then
    if HasAtlas("Dungeon") then return "|A:Dungeon:14:14|a" end
    if FileExists("Interface\\Minimap\\Dungeon") then return "|TInterface\\Minimap\\Dungeon:14:14|t" end
    return "|cffffd100" .. T.TAG_NEAR .. "|r"
  elseif level == 1 then
    if HasAtlas("Waypoint-MapPin-Untracked") then return "|A:Waypoint-MapPin-Untracked:14:14|a" end
    return "|cffd9c08c" .. T.TAG_NEAR_ZONE .. "|r"
  end
end

-- Klick aufs Rollensymbol nimmt den Spieler ins Ziel, wie bei Raid-Frames: ein geschützter Knopf mit /target.
-- Er hängt an UIParent statt am Fenster, sonst dürfte das Fenster im Kampf nicht mehr auf- und zugehen.
-- Geschützte Knöpfe lassen sich nur außerhalb des Kampfes verschieben; im Kampf bleibt er versteckt.
targetBtn = CreateFrame("Button", "AutoGroupFinderTargetButton", UIParent, "SecureActionButtonTemplate")
targetBtn:SetFrameStrata("HIGH")
targetBtn:RegisterForClicks("LeftButtonUp")
targetBtn:SetAttribute("type", "macro")
targetBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
if targetBtn.SetPassThroughButtons then pcall(targetBtn.SetPassThroughButtons, targetBtn, "RightButton") end
targetBtn:Hide()

function HideTargetButton()
  if not InCombatLockdown() then targetBtn:Hide() end
end

function ShowTargetButton(row)
  local c = row.cand
  if InCombatLockdown() or not c or not row.avatar:IsVisible() then return end
  local x, y = row.avatar:GetCenter()
  if not x then return end
  local s = row.avatar:GetEffectiveScale() / UIParent:GetEffectiveScale()
  targetBtn:ClearAllPoints()
  targetBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * s, y * s)
  targetBtn:SetSize(row.avatar:GetWidth() * s, row.avatar:GetHeight() * s)
  targetBtn:SetAttribute("macrotext", "/target " .. c.name)
  targetBtn.row, targetBtn.key = row, c.key
  targetBtn:Show()
end

targetBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(T.TARGET_TIP:format(Short(self.row and self.row.cand and self.row.cand.name or "")), 1, 1, 1, 1, true)
  GameTooltip:Show()
end)
targetBtn:SetScript("OnLeave", function(self)
  GameTooltip:Hide()
  if not (self.row and self.row:IsMouseOver()) then HideTargetButton() end
end)
-- Kurz vor dem Kampf ist Verstecken noch erlaubt; Scrollen und Schließen lassen ihn ebenfalls verschwinden.
targetEv = CreateFrame("Frame")
targetEv:RegisterEvent("PLAYER_REGEN_DISABLED")
targetEv:SetScript("OnEvent", function() targetBtn:Hide() end)
win:HookScript("OnHide", HideTargetButton)
found:HookScript("OnHide", HideTargetButton)

-- Rechtsklick auf einen Spieler: Aktionen wie bei Blizzard
function ShowPlayerMenu(owner, c)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then Whisper(c.name) return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(Short(c.name))
    root:CreateButton(T.WHISPER, function() Whisper(c.name) end)
    for _, r in ipairs(ROLES) do
      if c.roles[r] then
        root:CreateButton(T.CTX_INVITE_AS:format(ROLE_NAME[r]), function()
          if CanInvite() then Invite(c, r, true) Rebuild() else Print(T.CHAT_LEADER_ONLY) end
        end)
      end
    end
    if C_FriendList and C_FriendList.AddFriend then
      root:CreateButton(T.ADD_FRIEND, function() C_FriendList.AddFriend(c.name) end)
    end
    root:CreateButton(T.CTX_SKIP, function()
      db.skipUntil[c.key] = time() + 3600
      Rebuild()
    end)
    root:CreateButton(T.CTX_BLOCK, function() ToggleBlocked(c.name) end)
  end)
end

-- Ist gerade ein anderer Spieler in diese Zeile gerutscht? Dann kurz keine Klicks annehmen.
function JustChanged(row) return GetTime() - (row.changedAt or 0) < 0.5 end
function SetRowKey(row, key)
  if row.key ~= key or not row:IsShown() then
    row.key, row.changedAt = key, GetTime()
  end
end

function ListRow(i)
  local row = listRows[i]
  if row then return row end
  row = CreateFrame("Button", nil, list.child)
  row:SetPoint("RIGHT", list.child, "RIGHT")
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- Blizzards Listen-Grafiken: Eintrag, Aufleuchten beim Drüberfahren, Überschriften-Leiste
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetPoint("TOPLEFT", 3, -2)
  row.bg:SetPoint("BOTTOMRIGHT", -3, 0)
  if not Atlas(row.bg, "common-button-list-mid2") then row.bg:SetColorTexture(0, 0, 0, 0.4) end
  row.hl = row:CreateTexture(nil, "HIGHLIGHT")
  row.hl:SetPoint("TOPLEFT", 3, -3)
  row.hl:SetPoint("BOTTOMRIGHT", -3, -1)
  if Atlas(row.hl, "common-button-list-mid2-hover") then row.hl:SetBlendMode("ADD") else row.hl:SetColorTexture(1, 1, 1, 0.06) end
  row.headBg = row:CreateTexture(nil, "BACKGROUND")
  row.headBg:SetAllPoints()
  if not Atlas(row.headBg, "common-button-list-collapseExpand") then row.headBg:SetColorTexture(0.3, 0.2, 0.1, 0.6) end
  row.head = Label(row, "", "GameFontNormal", "LEFT", row, "LEFT", 14, 0)
  row.avatar = row:CreateTexture(nil, "ARTWORK")
  row.avatar:SetSize(40, 40)
  row.avatar:SetPoint("LEFT", 12, -1)
  -- Rechte Spalte vor dem Knopf: Wartezeit oben, Spielweise darunter
  local META_RIGHT = -98
  row.age = Label(row, "", "GameFontHighlightSmall", "BOTTOMRIGHT", row, "RIGHT", META_RIGHT, 1)
  row.clock = row:CreateTexture(nil, "ARTWORK")
  row.clock:SetSize(13, 12)
  row.clock:SetPoint("RIGHT", row.age, "LEFT", -2, 0)
  if not Atlas(row.clock, "groupfinder-waitdot") then row.clock:Hide() end
  row.style = Label(row, "", "GameFontDisableSmall", "TOPRIGHT", row, "RIGHT", META_RIGHT, -3)
  -- Mitte: Name als Titel (mit Markierungen), darunter der Dungeon
  row.name = Label(row, "", "GameFontNormal", "BOTTOMLEFT", row, "LEFT", 62, 1)
  row.name:SetPoint("BOTTOMRIGHT", row, "RIGHT", META_RIGHT - 70, 1)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.sub = Label(row, "", "GameFontHighlightSmall", "TOPLEFT", row, "LEFT", 62, -3)
  row.sub:SetPoint("TOPRIGHT", row, "RIGHT", META_RIGHT - 70, -3)
  row.sub:SetJustifyH("LEFT")
  row.sub:SetWordWrap(false)
  -- Stufe unten links am Avatar, wie bei Blizzards Einheitenrahmen
  row.level = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  row.level:SetPoint("BOTTOMLEFT", row.avatar, "BOTTOMLEFT", -3, -2)
  -- Weitere Rollen als kleine Abzeichen unten rechts am Avatar
  row.extra = {}
  for j = 1, 2 do
    local t = row:CreateTexture(nil, "OVERLAY")
    t:SetSize(16, 16)
    t:SetPoint("BOTTOMRIGHT", row.avatar, "BOTTOMRIGHT", 4 - (j - 1) * 13, -3)
    row.extra[j] = t
  end
  -- Laufende Einladung: Blizzards Cooldown-Ring, rund wie das Rollensymbol
  local okCd, cd = pcall(CreateFrame, "Cooldown", nil, row, "CooldownFrameTemplate")
  if okCd and cd then
    cd:SetAllPoints(row.avatar)
    if cd.SetSwipeTexture then cd:SetSwipeTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.65) end
    if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    if cd.SetReverse then cd:SetReverse(true) end
    cd:Hide()
    row.cd = cd
  end
  row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.btn:SetSize(74, 22)
  row.btn:SetPoint("RIGHT", -14, -1)
  row.btn:SetText(T.INVITE)
  row.btn:SetScript("OnClick", function(self)
    if JustChanged(self:GetParent()) then return end
    local c = self:GetParent().cand
    local _, open = Slots()
    local role = c and RoleFor(c, open)
    if role and CanInvite() then Invite(c, role, true) Rebuild() end
  end)
  row:SetScript("OnClick", function(self, button)
    local c = self.cand
    if not c or JustChanged(self) then return end
    if IsShiftKeyDown() then
      InsertChat(self.sub:IsMouseOver() and c.activityText or Short(c.name))
    elseif button == "RightButton" then
      ShowPlayerMenu(self, c)
    end
  end)
  row:SetScript("OnEnter", function(self)
    local c = self.cand
    if not c then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local color = c.class and RAID_CLASS_COLORS[c.class]
    GameTooltip:SetText(Short(c.name), color and color.r or 1, color and color.g or 1, color and color.b or 1)
    if c.level and c.level > 0 then GameTooltip:AddLine(T.LEVEL:format(c.level), 1, 1, 1) end
    local roles = {}
    for _, r in ipairs(ROLES) do if c.roles[r] then roles[#roles + 1] = ROLE_NAME[r] end end
    GameTooltip:AddLine(table.concat(roles, ", "), 1, 1, 1)
    GameTooltip:AddLine(c.activityText, 1, 0.82, 0, true)
    if c.liked then GameTooltip:AddLine(RateTag(1) .. " " .. T.RATE_GOOD, 0.25, 1, 0.25) end
    if c.near then
      GameTooltip:AddLine(NearIcon(c.near) .. " " .. (c.near == 2 and T.TAG_NEAR_TIP or T.TAG_NEAR_ZONE_TIP):format(c.area), 1, 0.82, 0, true)
    elseif c.area then
      GameTooltip:AddLine((ZONE or "Zone") .. ": " .. c.area, 0.8, 0.8, 0.8)
    end
    if c.playstyle and c.playstyle > 0 and PLAYSTYLE_NAME[c.playstyle] then
      GameTooltip:AddLine(PLAYSTYLE_NAME[c.playstyle], 0.13, 1, 0.13)
    end
    if type(c.comment) == "string" and c.comment ~= "" then
      GameTooltip:AddLine("\"" .. c.comment .. "\"", 0.9, 0.9, 0.9, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T.ROW_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if not targetBtn:IsMouseOver() then HideTargetButton() end
  end)
  row:HookScript("OnEnter", ShowTargetButton)
  listRows[i] = row
  return row
end

function Age(c)
  local s = math.max(0, math.floor(GetTime() - c.listedAt))
  return s < 60 and T.AGE_S:format(s) or T.AGE_M:format(math.floor(s / 60))
end

INVITE_SECONDS = 60 -- so lange gilt Blizzards Einladung

-- Überschrift einer Gruppe in der Liste
local function HeadRow(n, y, key, text)
  local row = ListRow(n)
  row:SetHeight(HEAD_H)
  row:SetPoint("TOPLEFT", 0, -y)
  SetRowKey(row, key)
  row.cand = nil
  row.bg:Hide()
  row.hl:Hide()
  row.headBg:Show()
  row.head:SetText(text)
  row.head:Show()
  row.avatar:Hide() row.name:Hide() row.level:Hide() row.sub:Hide() row.btn:Hide()
  row.age:Hide() row.clock:Hide() row.style:Hide()
  if row.cd then row.cd:Hide() end
  for _, t in ipairs(row.extra) do t:Hide() end
  row:Show()
  return y + HEAD_H
end

-- Spielerkarte; invitedAt = Zeitpunkt einer laufenden Einladung (Countdown statt Einladen-Knopf)
local function PlayerRow(n, y, c, role, invitedAt)
  local row = ListRow(n)
  row:SetHeight(PLAYER_H)
  row:SetPoint("TOPLEFT", 0, -y)
  SetRowKey(row, c.key)
  row.cand = c
  row.bg:Show()
  row.hl:Show()
  row.headBg:Hide()
  row.head:Hide()
  SetRoleTexture(row.avatar, role, true)
  row.avatar:Show()
  local color = c.class and RAID_CLASS_COLORS[c.class]
  local title = Short(c.name)
  title = color and color:WrapTextInColorCode(title) or title
  local tags = {}
  if c.liked then tags[#tags + 1] = RateTag(1) end
  if c.friend then tags[#tags + 1] = "|cff82c5ff" .. T.TAG_FRIEND .. "|r" end
  if c.guild then tags[#tags + 1] = "|cff40ff40" .. T.TAG_GUILD .. "|r" end
  if c.near then tags[#tags + 1] = NearIcon(c.near) end
  if c.lang and c.lang == db.preferLang then tags[#tags + 1] = "|cffc0c0c0" .. c.lang:sub(3, 4) .. "|r" end
  if #tags > 0 then title = title .. "  " .. table.concat(tags, " ") end
  row.name:SetText(title)
  row.name:Show()
  row.level:SetText((c.level and c.level > 0) and c.level or "")
  row.level:Show()
  row.sub:SetText(c.activity)
  row.sub:Show()
  row.age:SetText(Age(c))
  row.age:Show()
  row.clock:SetShown(HasAtlas("groupfinder-waitdot"))
  row.style:SetText((c.playstyle and c.playstyle > 0 and PLAYSTYLE_NAME[c.playstyle]) or "")
  row.style:Show()
  -- weitere Rollen, die der Spieler auch angegeben hat
  local j = 0
  for _, r in ipairs(ROLES) do
    if c.roles[r] and r ~= role and j < 2 then
      j = j + 1
      SetRoleTexture(row.extra[j], r, false)
      row.extra[j]:Show()
    end
  end
  for k = j + 1, 2 do row.extra[k]:Hide() end
  if row.cd then
    if invitedAt then
      if row.cd.invitedAt ~= invitedAt then row.cd:SetCooldown(invitedAt, INVITE_SECONDS) end
      row.cd.invitedAt = invitedAt
      row.cd:Show()
    else
      row.cd.invitedAt = nil
      row.cd:Hide()
    end
  end
  row.btn:SetText(invitedAt and T.INVITED or T.INVITE)
  row.btn:SetEnabled(not invitedAt)
  row.btn:Show()
  row:Show()
  return y + PLAYER_H
end

function UpdateFound()
  local summary = ActivitySummary()
  if actDd.OverrideText then actDd:OverrideText(summary) elseif actDd.Text then actDd.Text:SetText(summary) end
  for _, dd in ipairs(dropdowns) do if dd.cycle then dd.cycle() end end
  refresh:SetEnabled(not state.searching)
  local n, y = 0, 0
  -- Laufende Einladungen zuerst, mit Countdown
  local invited = {}
  for _, p in pairs(pending) do if p.c and p.role then invited[#invited + 1] = p end end
  table.sort(invited, function(a, b) return a.t < b.t end)
  if #invited > 0 then
    n = n + 1
    y = HeadRow(n, y, "head:invited", T.INVITED_HEAD:format(#invited))
    for _, p in ipairs(invited) do
      n = n + 1
      y = PlayerRow(n, y, p.c, p.role, p.t)
    end
  end
  local counts, lastRole = {}, nil
  for _, c in ipairs(candidates) do counts[c.role] = (counts[c.role] or 0) + 1 end
  for _, c in ipairs(candidates) do
    if c.role ~= lastRole then
      lastRole = c.role
      n = n + 1
      y = HeadRow(n, y, "head:" .. c.role, ("%s (%d)"):format(ROLE_PLURAL[c.role], counts[c.role]))
    end
    n = n + 1
    y = PlayerRow(n, y, c, c.role)
  end
  for i = n + 1, #listRows do listRows[i]:Hide() end
  list:SetContentHeight(y)
  local tr = targetBtn.row
  if targetBtn:IsShown() and not (tr and tr:IsVisible() and tr.cand and tr.cand.key == targetBtn.key) then HideTargetButton() end
  local _, pickedIDs = SearchActivities()
  local nothing = #candidates == 0 and #invited == 0
  if #pickedIDs == 0 then
    listEmpty:SetText(T.PICK_ACTIVITY)
  elseif nothing then
    local text = state.searching and T.SEARCHING or (T.FOUND_EMPTY .. "\n" .. T.FOUND_EMPTY_HINT)
    listEmpty:SetText((state.searching and spinner) and "" or text)
  else
    listEmpty:SetText("")
  end
  if spinner then spinner:SetShown(state.searching and nothing and #pickedIDs > 0) end
end

-------------------------------------------------------------------------
