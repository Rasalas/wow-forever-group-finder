local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Seite 1: Gruppe suchen – Rollen oben, darunter Kategorien oder Aktivitäten (wie Blizzards „List Self“)
-------------------------------------------------------------------------
rolesBg = finder:CreateTexture(nil, "BORDER", nil, -3)
rolesBg:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -25)
rolesBg:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", -2, -127)
Atlas(rolesBg, "groupfinder-roles-background")
Inset(finder, -118)

function AtlasSized(tex, name)
  if HasAtlas(name) then tex:SetAtlas(name, true) return true end
end

-- Blizzards klassische Kästchen (größer als UICheckButtonTemplate)
function BlizzCheck(parent, size)
  local cb = CreateFrame("CheckButton", nil, parent)
  cb:SetSize(size, size)
  cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  return cb
end

-- Vier Plätze (3 Rollen + Fahne) gleichmäßig über die Breite, gleicher Rand links und rechts
SLOT = 110
function SlotCenter(i) return WIN_W / 2 + (i - 2.5) * SLOT end

-- Wie Blizzards Rollen-Knöpfe: Drüberfahren lässt das Häkchen leuchten, Drücken drückt es mit
-- und rückt das Icon einen Pixel (wie bei den Seitenreitern).
function RoleButtonFeel(b)
  b:HookScript("OnEnter", function(self) if self.check:IsEnabled() then self.check:LockHighlight() end end)
  b:HookScript("OnLeave", function(self) self.check:UnlockHighlight() end)
  b:SetScript("OnMouseDown", function(self)
    self.check:SetButtonState("PUSHED")
    self.icon:AdjustPointsOffset(1, -1)
  end)
  b:SetScript("OnMouseUp", function(self)
    self.check:SetButtonState("NORMAL")
    self.icon:AdjustPointsOffset(-1, 1)
  end)
end
function CheckSound(on)
  PlaySound(on and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
end

-- Eigene Rolle: farbige Rund-Icons mit Leuchten, Auswahl über das Häkchen
myRoleBtns = {}
for i, role in ipairs(ROLES) do
  local b = CreateFrame("Button", nil, finder)
  b:SetSize(64, 64)
  b:SetPoint("CENTER", win, "TOPLEFT", SlotCenter(i), -76)
  b.glow = b:CreateTexture(nil, "BACKGROUND")
  b.glow:SetPoint("CENTER")
  if not AtlasSized(b.glow, ROLE_BIG[role] .. "-Background") then b.glow:SetSize(80, 80) end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("CENTER")
  if not AtlasSized(b.icon, ROLE_BIG[role]) then
    b.icon:SetSize(64, 64)
    SetRoleTexture(b.icon, role, true)
  end
  b.check = BlizzCheck(b, 24)
  b.check:SetPoint("BOTTOMLEFT", -5, -5)
  local function pick()
    db.myRoles[role] = not db.myRoles[role] or nil
    if not next(db.myRoles) then db.myRoles[role] = true end -- mindestens eine Rolle
    CheckSound(db.myRoles[role])
    Rebuild()
  end
  b:SetScript("OnClick", pick)
  b.check:SetScript("OnClick", pick)
  Tooltip(b, T.YOUR_ROLE:format(ROLE_NAME[role]))
  RoleButtonFeel(b)
  b.role = role
  myRoleBtns[i] = b
end

-- Trennlinie und Fahne „Neulingsfreundlich“ wie bei Blizzard
divider = finder:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(0.55, 0.45, 0.3, 0.6)
divider:SetSize(1, 78)
divider:SetPoint("CENTER", win, "TOPLEFT", SlotCenter(3.5), -76)
npf = CreateFrame("Button", nil, finder)
npf:SetSize(84, 84)
npf:SetPoint("CENTER", win, "TOPLEFT", SlotCenter(4), -76)
npf.icon = npf:CreateTexture(nil, "ARTWORK")
npf.icon:SetPoint("CENTER")
if not AtlasSized(npf.icon, "UI-LFG-RoleIcon-Leader") then
  npf.icon:SetSize(64, 64)
  npf.icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
end
newcomer = npf:CreateTexture(nil, "OVERLAY")
newcomer:SetSize(20, 20)
newcomer:SetPoint("TOPRIGHT", -8, -7)
Atlas(newcomer, "newplayerchat-chaticon-newcomer")
npf.check = BlizzCheck(npf, 24)
npf.check:SetPoint("BOTTOMLEFT", 6, 5)
npf.check:SetScript("OnClick", function(self)
  db.newPlayerFriendly = self:GetChecked() and true or false
  CheckSound(db.newPlayerFriendly)
end)
npf:SetScript("OnClick", function(self) self.check:Click() end)
Tooltip(npf, LFG_LIST_NEW_PLAYER_FRIENDLY_TOOLTIP or T.NEWCOMER_TIP)
RoleButtonFeel(npf)

-- Kategorien als Karten, wie Blizzards Startseite
CATEGORY_ART = {
  [2] = "groupfinder-button-dungeons",
  [114] = "groupfinder-button-raids-warlords",
  [116] = "groupfinder-button-questing",
  [118] = "groupfinder-button-battlegrounds",
  [120] = "groupfinder-button-custom-pve",
}
catView = CreateFrame("Frame", nil, finder)
catView:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -124)
catView:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 40)
cards = {}
coverInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("groupfinder-button-cover")
CARD_W, CARD_H = coverInfo and coverInfo.width or 400, coverInfo and coverInfo.height or 64

function Card(i)
  local card = cards[i]
  if card then return card end
  card = CreateFrame("Button", nil, catView)
  card:SetSize(CARD_W, CARD_H)
  if i == 1 then
    card:SetPoint("TOP", catView, "TOP", 0, -8)
  else
    card:SetPoint("TOP", cards[i - 1], "BOTTOM", 0, -4)
  end
  card.art = card:CreateTexture(nil, "BACKGROUND")
  card.art:SetPoint("TOPLEFT", 5, -8)
  card.art:SetPoint("BOTTOMRIGHT", -5, 5)
  card.cover = card:CreateTexture(nil, "ARTWORK")
  card.cover:SetPoint("CENTER")
  AtlasSized(card.cover, "groupfinder-button-cover")
  if card.SetPushedAtlas and HasAtlas("groupfinder-button-cover-down") then card:SetPushedAtlas("groupfinder-button-cover-down") end
  if card.SetHighlightAtlas and HasAtlas("groupfinder-button-cover-hover") then card:SetHighlightAtlas("groupfinder-button-cover-hover") end
  card.label = Label(card, "", "GameFontNormalLarge", "LEFT", card, "LEFT", 20, 0)
  card:SetScript("OnClick", function(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    db.category, db.view = self.categoryID, "activities"
    Rebuild()
  end)
  cards[i] = card
  return card
end

function UpdateCards()
  local n = 0
  for _, c in ipairs(Categories()) do
    if #ActivityTree(c.id).all > 0 then
      n = n + 1
      local card = Card(n)
      card.categoryID = c.id
      card.label:SetText(c.name)
      if not Atlas(card.art, CATEGORY_ART[c.id] or "groupfinder-button-questing") then
        card.art:SetColorTexture(0.15, 0.2, 0.3, 0.9)
      end
      card:Show()
    end
  end
  for i = n + 1, #cards do cards[i]:Hide() end
end

-- Aktivitätsansicht
actView = CreateFrame("Frame", nil, finder)
actView:SetPoint("TOPLEFT", win, "TOPLEFT", 7, -125)
actView:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -7, 40)

-- Auswahlfeld im Stil von Blizzards Dropdowns; ohne Vorlage ein Knopf, der durchschaltet.
dropdowns = {}
function Dropdown(parent, width, options, placeholder, get, set, ...)
  local okDd, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  if okDd and dd and dd.SetupMenu then
    dd:SetWidth(width)
    dd:SetPoint(...)
    if placeholder and dd.SetDefaultText then dd:SetDefaultText(placeholder) end
    dd:SetupMenu(function(_, root)
      for _, o in ipairs(type(options) == "function" and options() or options) do
        root:CreateRadio(o[2], function(v) return get() == v end, function(v) set(v) end, o[1])
      end
    end)
  else
    dd = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    dd:SetSize(width, 24)
    dd:SetPoint(...)
    dd:SetScript("OnClick", function()
      local opts, idx = type(options) == "function" and options() or options, 0
      for i, o in ipairs(opts) do if o[1] == get() then idx = i end end
      if opts[1] then set(opts[idx % #opts + 1][1]) end
    end)
    dd.cycle = function()
      dd:SetText(placeholder or "")
      for _, o in ipairs(type(options) == "function" and options() or options) do
        if o[1] == get() then dd:SetText(o[2]) end
      end
    end
  end
  dropdowns[#dropdowns + 1] = dd
  return dd
end

PLAYSTYLE_OPTIONS = {
  { 1, GROUP_FINDER_GENERAL_PLAYSTYLE1 or "Learning" },
  { 2, GROUP_FINDER_GENERAL_PLAYSTYLE2 or "Relaxed" },
  { 3, GROUP_FINDER_GENERAL_PLAYSTYLE3 or "Competitive" },
  { 4, GROUP_FINDER_GENERAL_PLAYSTYLE4 or "Carry Offered" },
}
VOICE_OPTIONS = {
  { 0, VOICE_CHAT_MODE_NONE or "None" },
  { 1, VOICE_CHAT_MODE_LEGACY or "In-game" },
  { 2, VOICE_CHAT_MODE_DISCORD or "Discord" },
  { 3, VOICE_CHAT_MODE_CUSTOM or "Custom" },
}
PLAYSTYLE_NAME = {}
for _, o in ipairs(PLAYSTYLE_OPTIONS) do PLAYSTYLE_NAME[o[1]] = o[2] end
PLAYSTYLE_REQUIRED = GROUP_FINDER_PLAYSTYLE_REQUIRED or T.PLAYSTYLE_REQUIRED

Dropdown(actView, 210, PLAYSTYLE_OPTIONS,
  DISABLED_FONT_COLOR and DISABLED_FONT_COLOR:WrapTextInColorCode(PLAYSTYLE_REQUIRED) or PLAYSTYLE_REQUIRED,
  function() return db.playstyle end,
  function(v) db.playstyle = v; Rebuild() end,
  "TOPLEFT", actView, "TOPLEFT", 28, -10)

levelCheck = CreateFrame("CheckButton", nil, actView, "UICheckButtonTemplate")
levelCheck:SetSize(26, 26)
-- mittig zur Spielweise-Auswahl, rechtsbündig mit der Liste darunter
levelCheck:SetPoint("RIGHT", actView, "TOPRIGHT", -10, -22)
levelText = Label(actView, T.ALL_LEVELS, "GameFontNormalSmall", "RIGHT", levelCheck, "LEFT", -2, 0)
levelText:SetJustifyH("RIGHT")
levelCheck:SetHitRectInsets(-levelText:GetStringWidth() - 4, 0, 0, 0)
levelCheck:SetScript("OnClick", function(self)
  db.allLevels = self:GetChecked() and true or false
  Rebuild()
end)

barTop = actView:CreateTexture(nil, "ARTWORK")
barTop:SetPoint("LEFT", actView, "TOPLEFT", 0, -42)
barTop:SetPoint("RIGHT", actView, "TOPRIGHT", 0, -42)
if not AtlasSized(barTop, "groupfinder-ScrollLine") then barTop:SetColorTexture(0.5, 0.4, 0.25, 0.5) barTop:SetHeight(1) end
barBottom = actView:CreateTexture(nil, "ARTWORK")
barBottom:SetPoint("LEFT", actView, "BOTTOMLEFT", 0, 46)
barBottom:SetPoint("RIGHT", actView, "BOTTOMRIGHT", 0, 46)
if not AtlasSized(barBottom, "groupfinder-ScrollLine") then barBottom:SetColorTexture(0.5, 0.4, 0.25, 0.5) barBottom:SetHeight(1) end

voiceDd = Dropdown(actView, 220, VOICE_OPTIONS, nil,
  function() return db.voice end,
  function(v) db.voice = v end,
  "BOTTOMRIGHT", actView, "BOTTOMRIGHT", -20, 12)
Label(actView, VOICE_CHAT or T.VOICE_CHAT, "GameFontNormalSmall", "RIGHT", voiceDd, "LEFT", -8, 0)

-- Aktivitäten als Baum wie bei Blizzard: Gruppe mit Plus/Minus, Einträge eine Stufe eingerückt
tree = Scroller(actView, actView, 22, -48, -12, 52)
treeRows = {}
ROW = 22

function SetPicked(entries, value)
  for _, e in ipairs(entries) do db.activities[e.id] = value end
  Rebuild()
end

BAR_W = 50 -- Breite der Balkenspalte

function TreeRow(i)
  local row = treeRows[i]
  if row then return row end
  row = CreateFrame("Button", nil, tree.child)
  row:SetHeight(ROW)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
  row:SetPoint("RIGHT", tree.child, "RIGHT")
  row.expand = CreateFrame("Button", nil, row)
  row.expand:SetSize(16, 16)
  row.expand:SetPoint("LEFT", 0, 0)
  row.expand:SetHitRectInsets(1, -4, -2, -2)
  row.expand:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
  row.check = BlizzCheck(row, 30)
  row.level = Label(row, "", "GameFontNormal", "RIGHT", row, "RIGHT", 0, 0)
  row.level:SetWidth(60)
  row.level:SetJustifyH("LEFT")
  -- fast unsichtbarer Balken in eigener Spalte links neben den Stufen (Länge = Beliebtheit)
  row.bar = row:CreateTexture(nil, "BACKGROUND")
  row.bar:SetPoint("TOPRIGHT", row.level, "TOPLEFT", -4, -3)
  row.bar:SetPoint("BOTTOMRIGHT", row.level, "BOTTOMLEFT", -4, 3)
  row.bar:SetColorTexture(1, 0.82, 0, 0.12)
  row.bar:Hide()
  row.name = Label(row, "", "GameFontNormal", "LEFT", row.check, "RIGHT", 0, 0)
  row.name:SetPoint("RIGHT", row.level, "LEFT", -(BAR_W + 10), 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row:SetScript("OnClick", function(self)
    if IsShiftKeyDown() then InsertChat(self.linkText) else self.check:Click() end
  end)
  row:SetScript("OnEnter", function(self)
    self.check:LockHighlight()
    if not (db.showDemand and self.activity) then return end
    local d = state.demand[self.activity]
    local popular = Popularity(self.activity)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.linkText)
    if popular == 0 and state.lastSearchAt == 0 then
      GameTooltip:AddLine(T.DEMAND_NO_DATA, 0.6, 0.6, 0.6, true)
    else
      GameTooltip:AddLine(T.DEMAND_POPULAR:format(popular), 1, 1, 1)
      GameTooltip:AddLine(T.DEMAND_BASIS, 0.6, 0.6, 0.6, true)
      if d and (d.players > 0 or d.groups > 0) then
        GameTooltip:AddLine(T.DEMAND_NOW:format(d.players, d.TANK, d.HEALER, d.DAMAGER), 0.8, 0.8, 0.8, true)
        if d.groups > 0 then GameTooltip:AddLine(T.DEMAND_GROUPS:format(d.groups), 0.8, 0.8, 0.8) end
      else
        GameTooltip:AddLine(T.DEMAND_NONE, 0.6, 0.6, 0.6)
      end
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function(self)
    self.check:UnlockHighlight()
    GameTooltip:Hide()
  end)
  row.check:SetScript("OnClick", function(self)
    local r = self:GetParent()
    -- Teilweise angehakte Gruppe: Klick wählt alles ab, wie bei Blizzard
    SetPicked(r.entries, not r.anyPicked)
  end)
  row.expand:SetScript("OnClick", function(self)
    local r = self:GetParent()
    db.collapsed[r.groupID] = not r.isCollapsed
    Rebuild()
  end)
  treeRows[i] = row
  return row
end

function EntryFont(e, fs)
  local lvl = UnitLevel("player")
  if e.hi ~= 0 and e.hi < lvl then
    fs:SetFontObject(_G.LFGActivityEntryTrivial or "GameFontDisable")
    if not _G.LFGActivityEntryTrivial then fs:SetTextColor(0.6, 0.6, 0.6) end
  elseif e.lo ~= 0 and e.lo > lvl then
    fs:SetFontObject(_G.LFGActivityEntryDifficult or "GameFontNormal")
    if not _G.LFGActivityEntryDifficult then fs:SetTextColor(1, 0.25, 0.1) end
  else
    fs:SetFontObject(_G.LFGActivityEntry or "GameFontNormal")
    if not _G.LFGActivityEntry then fs:SetTextColor(1, 0.82, 0) end
  end
end

function UpdateTree()
  local t = ActivityTree()
  local n = 0
  -- Längster Balken = meiste Wartende unter den sichtbaren Aktivitäten
  local maxDemand = 0
  if db.showDemand then
    for _, e in ipairs(t.all) do maxDemand = math.max(maxDemand, Popularity(e.id)) end
  end
  local barSpace = BAR_W
  local function header(text, entries, groupID, collapsed)
    n = n + 1
    local row = TreeRow(n)
    row.activity = nil
    row.bar:Hide()
    local picked = 0
    for _, e in ipairs(entries) do if IsPicked(e) then picked = picked + 1 end end
    row.entries, row.groupID, row.isCollapsed, row.anyPicked = entries, groupID, collapsed, picked > 0
    row.expand:SetShown(groupID ~= nil)
    row.check:ClearAllPoints()
    if groupID then
      row.expand:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
      row.check:SetPoint("LEFT", row.expand, "RIGHT", 4, 0)
    else
      row.check:SetPoint("LEFT", row.expand, "LEFT", 4, 0)
    end
    row.check:SetChecked(picked > 0)
    row.check:SetCheckedTexture(picked > 0 and picked < #entries and "Interface\\Buttons\\UI-MultiCheck-Up"
      or "Interface\\Buttons\\UI-CheckBox-Check")
    row.name:SetFontObject(_G.LFGActivityHeader or "GameFontHighlight")
    if not _G.LFGActivityHeader then row.name:SetTextColor(1, 1, 1) end
    row.name:SetText(text)
    row.linkText = text
    row.level:SetText("")
    row:Show()
  end
  local function item(e)
    n = n + 1
    local row = TreeRow(n)
    row.entries, row.groupID, row.anyPicked = { e }, nil, IsPicked(e)
    row.activity = e.id
    local amount = db.showDemand and Popularity(e.id) or 0
    if maxDemand > 0 and amount >= 5 then -- kleine Zahlen sind Zufall
      row.bar:SetWidth(math.max(2, barSpace * amount / maxDemand))
      row.bar:Show()
    else
      row.bar:Hide()
    end
    row.expand:Hide()
    row.check:ClearAllPoints()
    row.check:SetPoint("LEFT", row.expand, "RIGHT", 4, 0)
    row.check:SetChecked(IsPicked(e))
    row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    EntryFont(e, row.name)
    EntryFont(e, row.level)
    row.name:SetText(e.name)
    row.linkText = e.name
    row.level:SetText(e.lo > 0 and ("(%d - %d)"):format(e.lo, e.hi) or "")
    row:Show()
  end
  if t.cat then
    -- Zeile „alles“ nur, wenn es mehr als eine Gruppe gibt; sonst übernimmt das die Gruppe selbst.
    local multi = #t.groups > 1 or (#t.groups > 0 and #t.loose > 0)
    if multi then header(CategoryName(t.cat), t.all) end
    for _, e in ipairs(t.loose) do item(e) end
    for _, g in ipairs(t.groups) do
      local collapsed = false
      if multi then
        collapsed = db.collapsed[g.id]
        if collapsed == nil then collapsed = not g.anyFits end
      end
      header(g.name or "?", g.items, multi and g.id or nil, collapsed)
      if not collapsed then
        for _, e in ipairs(g.items) do item(e) end
      end
    end
  end
  for i = n + 1, #treeRows do treeRows[i]:Hide() end
  tree:SetContentHeight(n * ROW)
end

function UpdateFinder()
  local showActs = db.view == "activities"
  catView:SetShown(not showActs)
  actView:SetShown(showActs)
  for _, b in ipairs(myRoleBtns) do b.check:SetChecked(db.myRoles[b.role] and true or false) end
  npf.check:SetChecked(db.newPlayerFriendly)
  if showActs then
    levelCheck:SetChecked(db.allLevels)
    for _, dd in ipairs(dropdowns) do if dd.cycle then dd.cycle() end end
    UpdateTree()
  else
    UpdateCards()
  end
end

-- Optionen hinter dem Zahnrad in der Titelleiste
OPTIONS = {
  { "autoInvite", T.OPT_AUTOINVITE, T.OPT_AUTOINVITE_TIP, function() AutoInvite() end },
  { "keySearch", T.OPT_CLICKSEARCH, T.OPT_CLICKSEARCH_TIP:format(DEFAULTS.interval) },
  { "oldestFirst", T.OPT_OLDEST, T.OPT_OLDEST_TIP, function() Rebuild() end },
  { "samePlaystyle", T.OPT_SAME_PLAYSTYLE, T.OPT_SAME_PLAYSTYLE_TIP, function() Rebuild() end },
  { "levelCheck", T.OPT_LEVEL, T.OPT_LEVEL_TIP, function() Rebuild() end },
  { "preferFriends", T.OPT_FRIENDS, T.OPT_FRIENDS_TIP, function() Rebuild() end },
  { "inviteWhisper", T.OPT_WHISPER, T.OPT_WHISPER_TIP:format(SLASH) },
  { "notify", T.OPT_NOTIFY, T.OPT_NOTIFY_TIP },
  { "showDemand", T.OPT_DEMAND, T.OPT_DEMAND_TIP, function() Rebuild() end },
  { "sound", T.OPT_SOUND, T.OPT_SOUND_TIP },
}
function ToggleOption(o)
  db[o[1]] = not db[o[1]]
  if o[4] then o[4]() end
end
-- Flüstertext in Blizzards Eingabefenster ändern; leer = Standardtext
function DialogEditBox(d) return d.GetEditBox and d:GetEditBox() or d.editBox end
function SaveWhisper(text)
  text = strtrim(text or "")
  db.whisperText = text ~= "" and text or nil
  Print(T.CHAT_WHISPER_SET:format(db.whisperText or T.WHISPER_DEFAULT))
end
_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
StaticPopupDialogs.AUTOGROUPFINDER_WHISPER = {
  text = T.WHISPER_EDIT_PROMPT,
  button1 = ACCEPT or OKAY,
  button2 = CANCEL,
  button3 = DEFAULT or T.DEFAULT,
  hasEditBox = 1,
  editBoxWidth = 350,
  OnShow = function(d)
    local eb = DialogEditBox(d)
    eb:SetMaxLetters(200)
    eb:SetText(db.whisperText or T.WHISPER_DEFAULT)
    eb:HighlightText()
  end,
  OnAccept = function(d) SaveWhisper(DialogEditBox(d):GetText()) end,
  OnAlt = function() SaveWhisper("") end,
  EditBoxOnEnterPressed = function(eb)
    SaveWhisper(eb:GetText())
    eb:GetParent():Hide()
  end,
  EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
  hideOnEscape = 1,
  timeout = 0,
  whileDead = 1,
}
function EditWhisper() if StaticPopup_Show then StaticPopup_Show("AUTOGROUPFINDER_WHISPER") end end

function OpenSettings()
  if settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(settingsCategory:GetID())
  end
end

okGear, gear = pcall(CreateFrame, "DropdownButton", nil, win)
menuOk = okGear and gear and gear.SetupMenu
if not menuOk then gear = CreateFrame("Button", nil, win) end
gear:SetSize(16, 16)
gear:SetPoint("TOPRIGHT", win, "TOPRIGHT", -36, -4)
-- Über der Titelleiste, sonst verdeckt deren Rahmen das Zahnrad
closeLevel = win.CloseButton and win.CloseButton:GetFrameLevel()
gear:SetFrameLevel((closeLevel or (win:GetFrameLevel() or 1) + 600) + 1)
gear.Icon = gear:CreateTexture(nil, "ARTWORK")
gear.Icon:SetAllPoints()
if not Atlas(gear.Icon, "OptionsIcon-Brown") then gear.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton") end
gear.Icon:SetAlpha(0.8)
gear:SetScript("OnEnter", function(self)
  self.Icon:SetAlpha(1)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(T.OPTIONS)
  GameTooltip:Show()
end)
gear:SetScript("OnLeave", function(self)
  self.Icon:SetAlpha(0.8)
  GameTooltip:Hide()
end)

fallbackChecks = {}
if menuOk then
  gear:SetupMenu(function(_, root)
    for _, o in ipairs(OPTIONS) do
      local item = root:CreateCheckbox(o[2], function() return db[o[1]] end, function() ToggleOption(o) end)
      if o[3] and item and item.SetTooltip then
        item:SetTooltip(function(tooltip)
          GameTooltip_SetTitle(tooltip, o[2])
          GameTooltip_AddNormalLine(tooltip, o[3])
        end)
      end
    end
    if next(db.blocked) then
      local list = root:CreateButton(T.BLOCKED_LIST)
      for k in pairs(db.blocked) do
        list:CreateButton(T.UNBLOCK_ENTRY:format(Short(k)), function() ToggleBlocked(k) end)
      end
    end
    root:CreateDivider()
    root:CreateButton(T.EDIT_WHISPER, EditWhisper)
    if settingsCategory then root:CreateButton(T.SETTINGS, OpenSettings) end
  end)
else
  -- Ohne Menü-API: kleines Aufklappfenster mit Häkchen
  local pop = CreateFrame("Frame", nil, gear, BackdropTemplateMixin and "BackdropTemplate" or nil)
  pop:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 0, -4)
  pop:SetFrameStrata("DIALOG")
  if pop.SetBackdrop then
    pop:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    pop:SetBackdropColor(0, 0, 0, 0.92)
  end
  pop:Hide()
  local widest = 0
  for i, o in ipairs(OPTIONS) do
    local cb = CreateFrame("CheckButton", nil, pop, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 12, -12 - (i - 1) * 24)
    local fs = Label(cb, o[2], "GameFontHighlightSmall", "LEFT", cb, "RIGHT", 2, 0)
    widest = math.max(widest, fs:GetStringWidth())
    cb:SetScript("OnClick", function() ToggleOption(o) end)
    if o[3] then Tooltip(cb, o[2], o[3]) end
    cb.key = o[1]
    fallbackChecks[#fallbackChecks + 1] = cb
  end
  pop:SetSize(widest + 64, 24 + #OPTIONS * 24)
  gear:SetScript("OnClick", function() pop:SetShown(not pop:IsShown()) end)
end

-------------------------------------------------------------------------
