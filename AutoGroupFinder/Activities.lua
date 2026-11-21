local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Kategorien und Aktivitäten
-------------------------------------------------------------------------
function CategoryName(c)
  local ci = L.GetLfgCategoryInfo and L.GetLfgCategoryInfo(c)
  return (type(ci) == "table" and ci.name) or ci or tostring(c)
end

function Categories()
  local out = {}
  for _, c in ipairs(L.GetAvailableCategories and L.GetAvailableCategories() or {}) do
    out[#out + 1] = { id = c, name = CategoryName(c) }
  end
  return out
end

-- Journal-Instanz zu einer Karte. Forevers neue Dungeons stehen in einer eigenen Stufe des Journals und
-- fehlen in GetInstanceForGameMap; dann per Name suchen. Blizzards Journal nie umschalten, solange es offen ist.
local journalIDs = {}
local function SameName(a, b)
  return type(a) == "string" and type(b) == "string" and a ~= "" and b ~= ""
    and (a == b or a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil)
end
function JournalInstance(mapID, name)
  local key = mapID or name
  if key == nil then return nil end
  if journalIDs[key] ~= nil then return journalIDs[key] or nil end
  local ej = C_EncounterJournal
  if mapID and ej and ej.GetInstanceForGameMap then
    local ok, jid = pcall(ej.GetInstanceForGameMap, mapID)
    if ok and jid and jid ~= 0 then journalIDs[key] = jid return jid end
  end
  if not (name and EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return nil end
  local journal = _G.EncounterJournal
  if journal and journal:IsShown() then return nil end -- später nochmal
  local okP, prev = pcall(EJ_GetCurrentTier or error)
  local okN, tiers = pcall(EJ_GetNumTiers)
  local found
  for t = (okN and tiers or 0), 1, -1 do -- Forevers Stufe ist die neueste
    pcall(EJ_SelectTier, t)
    for _, raid in ipairs({ false, true }) do
      for i = 1, 100 do
        local ok, id, iname = pcall(EJ_GetInstanceByIndex, i, raid)
        if not (ok and id) then break end
        if SameName(iname, name) then found = id break end
      end
      if found then break end
    end
    if found then break end
  end
  if okP and prev then pcall(EJ_SelectTier, prev) end
  journalIDs[key] = found or false
  return found
end

-- Steht man an oder in einem Dungeon? Draußen zählt das Gebiet (wie auf der Minimap), drinnen die Instanz.
-- Instanzname -> { name, cat, ids }; einmal aufgebaut, neu bei geänderter Aktivitätenliste (InvalidateHere)
local hereIndex
function InvalidateHere() hereIndex = nil end
local function BuildHereIndex()
  local index, any = {}, false
  for _, c in ipairs(Categories()) do
    for _, id in ipairs(L.GetAvailableActivities(c.id) or {}) do
      any = true
      local a = L.GetActivityInfoTable(id)
      local name = a and (a.mapID or 0) > 0 and (a.maxNumPlayers or 0) >= 5 and GetRealZoneText(a.mapID)
      if name and name ~= "" then
        local e = index[name]
        if not e then e = { name = name, cat = c.id, ids = {} }; index[name] = e end
        if e.cat == c.id then e.ids[#e.ids + 1] = id end
      end
    end
  end
  return any and index or nil -- leer = Aktivitäten noch nicht geladen, später nochmal
end

function HereDungeon()
  local here = IsInInstance() and GetRealZoneText() or GetSubZoneText()
  if not here or here == "" then return nil end
  hereIndex = hereIndex or BuildHereIndex()
  return hereIndex and hereIndex[here]
end

-- Ein Klick: genau diesen Dungeon wählen und suchen. Fehlt etwas (z. B. Spielstil), zeigt StartQueue den Grund.
function QuickStart(here)
  db.category, db.view = here.cat, "activities"
  -- false = abgewählt; nil hieße „gewählt, wenn die Stufe passt“
  for _, id in ipairs(L.GetAvailableActivities(here.cat) or {}) do char.activities[id] = false end
  for _, id in ipairs(here.ids) do char.activities[id] = true end
  Rebuild()
  StartQueue()
end

function CurrentCategory()
  local cats = Categories()
  for _, c in ipairs(cats) do if c.id == db.category then return c.id end end
  for _, c in ipairs(cats) do if c.id == 2 then return 2 end end -- Dungeons
  return cats[1] and cats[1].id
end

-- Questlog nach Zonen: Überschrift -> Questtitel. Eine Quest lässt sich nicht in den Eintrag schreiben
-- (GetActivityIDForQuestID wirft Fehler, Kommentare sind geschützt), die Zone schon.
local questZones
function InvalidateQuests() questZones = nil end
local function Norm(s) return (s or ""):lower():gsub("^the ", "") end
local function QuestLine(i)
  if C_QuestLog and C_QuestLog.GetInfo then
    local q = C_QuestLog.GetInfo(i)
    if q then return q.title, q.isHeader end
  elseif GetQuestLogTitle then
    local title, _, _, isHeader = GetQuestLogTitle(i)
    return title, isHeader
  end
end
function QuestZones()
  if questZones then return questZones end
  questZones = {}
  local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
    or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
  local zone
  for i = 1, n do
    local title, isHeader = QuestLine(i)
    if type(title) == "string" then
      if isHeader then
        zone = Norm(title)
        questZones[zone] = questZones[zone] or {}
      elseif zone then
        table.insert(questZones[zone], title)
      end
    end
  end
  return questZones
end
function QuestsFor(e)
  local z = QuestZones()
  local list = z[Norm(e.full)] or z[Norm(e.name)]
  return list and #list > 0 and list or nil
end

function ActivityEntry(id, lvl)
  local a = L.GetActivityInfoTable(id)
  if not a then return nil end
  local lo, hi = a.minLevelSuggestion or 0, a.maxLevelSuggestion or 0
  return {
    id = id,
    name = (a.shortName and a.shortName ~= "") and a.shortName or a.fullName or "?",
    full = a.fullName,
    lo = lo, hi = hi, order = a.orderIndex or 0, max = a.maxNumPlayers or 0,
    fits = not ((lo > 0 and lo > lvl) or (hi > 0 and hi < lvl)),
  }
end

function SortActivities(list)
  table.sort(list, function(x, y)
    if x.order ~= y.order then return x.order > y.order end
    if x.hi ~= y.hi then return x.hi > y.hi end
    if x.lo ~= y.lo then return x.lo > y.lo end
    return x.name < y.name
  end)
end

-- Wie Blizzards Liste: lose Aktivitäten zuerst, dann Gruppen. Ausgeblendetes zählt nicht.
function ActivityTree(catOverride)
  local cat = catOverride or CurrentCategory()
  local cached = state.trees[cat or 0]
  if cached and cached.version == state.treeVersion then return cached.tree end
  local tree = { cat = cat, loose = {}, groups = {}, all = {} }
  if not cat then return tree end
  -- Kategorien mit nur einer Aktivität (Custom): die gilt immer, eine Liste braucht es nicht
  local ci = L.GetLfgCategoryInfo and L.GetLfgCategoryInfo(cat)
  tree.auto = type(ci) == "table" and ci.autoChooseActivity == true
  local lvl = UnitLevel("player")
  local zones = cat == QUEST_CATEGORY
  local function visible(e)
    if zones then e.quests = QuestsFor(e) end
    return e.fits or e.quests or db.allLevels or char.activities[e.id]
  end
  for _, id in ipairs(L.GetAvailableActivities(cat, 0) or {}) do
    local e = ActivityEntry(id, lvl)
    if e then e.auto = tree.auto end
    if e and visible(e) then tree.loose[#tree.loose + 1] = e end
  end
  SortActivities(tree.loose)
  local groupIDs = L.GetAvailableActivityGroups and L.GetAvailableActivityGroups(cat) or {}
  for _, gid in ipairs(groupIDs) do
    local g = { id = gid, items = {}, anyFits = false }
    g.name, g.order = L.GetActivityGroupInfo(gid)
    for _, id in ipairs(L.GetAvailableActivities(cat, gid) or {}) do
      local e = ActivityEntry(id, lvl)
      if e and visible(e) then
        g.items[#g.items + 1] = e
        g.anyFits = g.anyFits or e.fits
      end
    end
    if #g.items > 0 then
      SortActivities(g.items)
      tree.groups[#tree.groups + 1] = g
    end
  end
  table.sort(tree.groups, function(x, y)
    if (x.order or 0) ~= (y.order or 0) then return (x.order or 0) < (y.order or 0) end
    return (x.name or "") < (y.name or "")
  end)
  for _, e in ipairs(tree.loose) do tree.all[#tree.all + 1] = e end
  for _, g in ipairs(tree.groups) do
    for _, e in ipairs(g.items) do tree.all[#tree.all + 1] = e end
  end
  -- Zonen mit eigenen Quests sind vorgewählt; ohne Quests wie sonst nach Stufe
  local anyQuest = false
  for _, e in ipairs(tree.all) do anyQuest = anyQuest or e.quests ~= nil end
  if anyQuest then for _, e in ipairs(tree.all) do e.default = e.quests ~= nil end end
  state.trees[cat or 0] = { version = state.treeVersion, tree = tree }
  return tree
end

-- Für den Leerzustand: die nächste Aktivität über der eigenen Stufe
function NextActivity(cat)
  local lvl, best = UnitLevel("player"), nil
  local function scan(gid)
    for _, id in ipairs(L.GetAvailableActivities(cat, gid) or {}) do
      local e = ActivityEntry(id, lvl)
      if e and e.lo > lvl and (not best or e.lo < best.lo) then best = e end
    end
  end
  scan(0)
  for _, gid in ipairs(L.GetAvailableActivityGroups and L.GetAvailableActivityGroups(cat) or {}) do scan(gid) end
  return best
end

-- Beim ersten Kontakt mit einer Aktivität: angehakt, wenn sie zur Stufe passt.
function IsPicked(e)
  if e.auto then return true end
  local v = char.activities[e.id]
  if v == nil then if e.default ~= nil then return e.default end return e.fits end
  return v
end

function SearchActivities()
  local tree = ActivityTree()
  local ids, maxPlayers = {}, 0
  for _, e in ipairs(tree.all) do
    if IsPicked(e) then
      ids[#ids + 1] = e.id
      maxPlayers = math.max(maxPlayers, e.max)
    end
  end
  return tree.cat, ids, maxPlayers
end

function SizeBucket(maxPlayers)
  if not maxPlayers or maxPlayers <= 5 then return 5 end
  for _, s in ipairs(SIZES) do if maxPlayers <= s then return s end end
  return 40
end

-- Kurz: erster Eintrag plus Anzahl weiterer; lang: alle Namen
function ActivityName(info, full)
  local ids = info.activityIDs or {}
  if full then
    local names = {}
    for _, id in ipairs(ids) do
      local a = L.GetActivityInfoTable(id)
      if a then names[#names + 1] = a.fullName ~= "" and a.fullName or a.shortName end
    end
    return table.concat(names, ", ")
  end
  local a = ids[1] and L.GetActivityInfoTable(ids[1])
  local name = a and ((a.shortName ~= "" and a.shortName) or a.fullName) or ""
  if #ids > 1 then name = name .. " +" .. (#ids - 1) end
  return name
end

-------------------------------------------------------------------------
