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

-- Steht man an oder in einem Dungeon? Draußen zählt das Gebiet (wie auf der Minimap), drinnen die Instanz.
function HereDungeon()
  local here = IsInInstance() and GetRealZoneText() or GetSubZoneText()
  if not here or here == "" then return nil end
  local found
  for _, c in ipairs(Categories()) do
    for _, id in ipairs(L.GetAvailableActivities(c.id) or {}) do
      local a = L.GetActivityInfoTable(id)
      if a and (a.mapID or 0) > 0 and (a.maxNumPlayers or 0) >= 5 and GetRealZoneText(a.mapID) == here then
        found = found or { name = here, cat = c.id, ids = {} }
        if found.cat == c.id then found.ids[#found.ids + 1] = id end
      end
    end
  end
  return found
end

-- Ein Klick: genau diesen Dungeon wählen und suchen. Fehlt etwas (z. B. Spielstil), zeigt StartQueue den Grund.
function QuickStart(here)
  db.category, db.view = here.cat, "activities"
  for _, id in ipairs(L.GetAvailableActivities(here.cat) or {}) do db.activities[id] = nil end
  for _, id in ipairs(here.ids) do db.activities[id] = true end
  Rebuild()
  StartQueue()
end

function CurrentCategory()
  local cats = Categories()
  for _, c in ipairs(cats) do if c.id == db.category then return c.id end end
  for _, c in ipairs(cats) do if c.id == 2 then return 2 end end -- Dungeons
  return cats[1] and cats[1].id
end

function ActivityEntry(id, lvl)
  local a = L.GetActivityInfoTable(id)
  if not a then return nil end
  local lo, hi = a.minLevelSuggestion or 0, a.maxLevelSuggestion or 0
  return {
    id = id,
    name = (a.shortName and a.shortName ~= "") and a.shortName or a.fullName or "?",
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
  local lvl = UnitLevel("player")
  local function visible(e) return e.fits or db.allLevels or db.activities[e.id] end
  for _, id in ipairs(L.GetAvailableActivities(cat, 0) or {}) do
    local e = ActivityEntry(id, lvl)
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
  state.trees[cat or 0] = { version = state.treeVersion, tree = tree }
  return tree
end

-- Beim ersten Kontakt mit einer Aktivität: angehakt, wenn sie zur Stufe passt.
function IsPicked(e)
  local v = db.activities[e.id]
  if v == nil then return e.fits end
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
