local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Seite 4: Deine Gruppe. Vor dem Dungeon: wer ist wo, Wegpunkt zum Eingang, Stufe.
-- Im Dungeon: wie lange schon drin und Bewertung der Mitspieler für künftige Gruppen.
-------------------------------------------------------------------------
GroupPage = {}

-- Eingang eines Dungeons auf der Karte: Zone (uiMapID) und Position, sofern die Karte ihn kennt
function DungeonEntrance(activityID)
  local a = activityID and L.GetActivityInfoTable(activityID)
  if not (a and a.mapID and C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then return end
  local jid = JournalInstance(a.mapID)
  local inst = GetRealZoneText(a.mapID)
  local maps = {}
  for _, ui in ipairs(DUNGEON_ZONES[a.mapID] or {}) do maps[#maps + 1] = ui end
  local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if here then maps[#maps + 1] = here end
  for _, ui in ipairs(maps) do
    local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, ui)
    for _, e in ipairs(ok and list or {}) do
      if (jid and e.journalInstanceID == jid) or e.name == inst then return ui, e.position end
    end
  end
end

function SetEntranceWaypoint(activityID)
  local a = activityID and L.GetActivityInfoTable(activityID)
  local name = a and a.fullName or "?"
  local ui, pos = DungeonEntrance(activityID)
  if not (ui and pos and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then
    Print(T.CHAT_NO_ENTRANCE:format(name))
    return
  end
  pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromVector2D(ui, pos))
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
  Print(T.CHAT_WAYPOINT:format(name))
end

-- Welcher Dungeon gehört zur Gruppe? Der zuletzt gesuchte, sonst die gewählte Aktivität
-- Für welche der gewählten Dungeons passen die Mitglieder (laut Eintrag beim Einladen)?
-- Liefert { {id, name, n}, ... } absteigend und die Zahl der Mitglieder mit bekanntem Eintrag.
function GroupFit()
  local counts, known = {}, 0
  for k in pairs(MemberKeys()) do
    -- gemerkt beim Einladen, sonst der Eintrag aus den Suchen der letzten 30 Minuten
    local ids = char.memberFor and char.memberFor[k]
    if not ids and state.listings[k] and (state.listings[k].numMembers or 1) == 1 then ids = state.listings[k].activityIDs end
    if ids then
      known = known + 1
      for _, id in ipairs(ids) do counts[id] = (counts[id] or 0) + 1 end
    end
  end
  local list = {}
  for _, e in ipairs(ActivityTree().all) do
    if counts[e.id] then list[#list + 1] = { id = e.id, name = e.name, n = counts[e.id] } end
  end
  table.sort(list, function(a, b) return a.n > b.n end)
  return list, known
end

function GroupActivity()
  local fit = GroupFit()
  if fit[1] then return fit[1].id end
  if char.groupActivityID then return char.groupActivityID end
  local _, ids = SearchActivities()
  return ids[1]
end

-- Wo ist ein Mitglied? 2 = im/am Dungeon, 1 = Zone des Eingangs, 0 = woanders, nil = offline
local function Place(unit, near)
  local conn = UnitIsConnected and UnitIsConnected(unit)
  if Readable(conn) and conn == false then return nil, nil, true end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit(unit)
  if not Readable(map) then map = nil end
  local info = map and C_Map.GetMapInfo(map)
  local zone = info and Readable(info.name) and info.name or nil
  if unit == "player" then zone = IsInInstance() and GetRealZoneText() or zone end
  return zone, zone and near[zone] or 0
end

do
  local page = pages[4]
  Inset(page, -60)
  local title = Label(page, "", "GameFontNormalLarge", "TOPLEFT", win, "TOPLEFT", 24, -72)
  local sub = Label(page, "", "GameFontHighlightSmall", "TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  local status = Label(page, "", "GameFontNormal", "TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
  local wp = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  wp:SetSize(170, 22)
  wp:SetPoint("TOPRIGHT", win, "TOPRIGHT", -22, -110)
  wp:SetText(T.GROUP_WAYPOINT)
  wp:SetScript("OnClick", function() SetEntranceWaypoint(GroupActivity()) end)

  local rows = {}
  GroupPage.rows, GroupPage.status = rows, status
  local ROW_H = 30
  local function Row(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -150 - (i - 1) * (ROW_H + 2))
    row:SetPoint("RIGHT", win, "RIGHT", -20, 0)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if not Atlas(row.bg, "common-button-list-mid2") then row.bg:SetColorTexture(0, 0, 0, 0.35) end
    row.role = row:CreateTexture(nil, "ARTWORK")
    row.role:SetSize(22, 22)
    row.role:SetPoint("LEFT", 8, 0)
    row.name = Label(row, "", "GameFontHighlight", "LEFT", row.role, "RIGHT", 8, 0)
    row.level = Label(row, "", "GameFontHighlightSmall", "LEFT", row.name, "RIGHT", 6, 0)
    row.rate = {}
    for k, v in ipairs({ -1, 1 }) do
      local b = CreateFrame("Button", nil, row)
      b:SetSize(20, 20)
      b:SetPoint("RIGHT", row, "RIGHT", -8 - (k - 1) * 24, 0)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetAllPoints()
      b.icon:SetTexture(RATE_ICON[v])
      b:SetScript("OnClick", function() if row.member then Rate(row.member, v) end end)
      Tooltip(b, v == 1 and T.RATE_GOOD or T.RATE_BAD, v == 1 and T.RATE_GOOD_TIP or T.RATE_BAD_TIP)
      b.v = v
      row.rate[v] = b
    end
    row.place = Label(row, "", "GameFontDisableSmall", "RIGHT", row.rate[1], "LEFT", -12, 0)
    rows[i] = row
    return row
  end

  GroupPage.Update = function()
    local id = GroupActivity()
    local a = id and L.GetActivityInfoTable(id)
    local near = id and NearNames(id) or {}
    local inside = IsInInstance()
    title:SetText(inside and GetRealZoneText() or (a and a.fullName) or T.TAB_GROUP)
    local parts = {}
    local fill = char.lastFill
    if fill and time() - fill.t < 4 * 3600 then parts[#parts + 1] = T.GROUP_FILLED:format(math.max(1, math.floor(fill.s / 60 + 0.5))) end
    local run = inside and char.instanceSince and math.floor((time() - char.instanceSince) / 60)
    if run and run >= 1 then parts[#parts + 1] = T.GROUP_RUN:format(run) end
    local done, total = History.Progress(inside and History.Run(state.historyEntry), state.historyEntry)
    if total then parts[#parts + 1] = SKULL .. " " .. done .. "/" .. total end
    local fit, known = GroupFit()
    if #fit > 1 or (fit[1] and fit[1].n < known) then
      local f = {}
      for _, e in ipairs(fit) do f[#f + 1] = T.GROUP_FIT:format(e.name, e.n, known) end
      parts[#parts + 1] = table.concat(f, " · ")
    end
    sub:SetText(table.concat(parts, " · "))

    local units = { "player" }
    for _, m in ipairs(api.members()) do units[#units + 1] = m.unit end
    local there = 0
    for i, unit in ipairs(units) do
      local row = Row(i)
      -- Einheiten-Werte können in Instanzen geheim sein; dann bleibt die Zeile schlicht
      local name = unit == "player" and MyName() or GetUnitName(unit, true)
      if not Readable(name) or type(name) ~= "string" then name = "?" end
      local _, class = UnitClass and UnitClass(unit)
      if not Readable(class) then class = nil end
      local color = class and RAID_CLASS_COLORS[class]
      local role = unit == "player" and select(2, Filled()) or MemberRole(Key(name), unit)
      if not Readable(role) or (role ~= "TANK" and role ~= "HEALER") then role = "DAMAGER" end
      SetRoleTexture(row.role, role, false)
      -- „3×“: schon so oft zusammen (diese Gruppe zählt mit)
      row.name:SetText((color and color:WrapTextInColorCode(Short(name)) or Short(name))
        .. (unit ~= "player" and ("  " .. TogetherTag(name)) or ""))
      local lvl = UnitLevel(unit)
      if not Readable(lvl) then lvl = nil end
      local low = a and a.minLevelSuggestion and lvl and lvl > 0 and lvl < a.minLevelSuggestion
      row.level:SetText(lvl and lvl > 0 and ((low and "|cffffd100" or "") .. lvl .. (low and "|r" or "")) or "")
      local zone, level, offline = Place(unit, near)
      if level == 2 then there = there + 1 end
      -- ohne Karte (z. B. Mitspieler in Instanzen) bleibt der Ort leer statt „Offline“
      row.place:SetText(offline and "|cffff6060" .. (PLAYER_OFFLINE or "Offline") .. "|r"
        or level == 2 and "|cff40ff40" .. T.GROUP_HERE .. "|r" or zone or "")
      row.member = unit ~= "player" and name or nil
      local r = row.member and Rating(name)
      for v, b in pairs(row.rate) do
        b:SetShown(row.member ~= nil)
        b:SetAlpha(r == v and 1 or 0.35)
      end
      row:Show()
    end
    for i = #units + 1, #rows do rows[i]:Hide() end
    status:SetText(T.GROUP_AT_DUNGEON:format(there, #units))
    status:SetShown(not inside)
    wp:SetShown(not inside and id ~= nil)
  end
end

-------------------------------------------------------------------------
