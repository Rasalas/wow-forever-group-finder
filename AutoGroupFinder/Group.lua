local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Gruppe und offene Plätze
-------------------------------------------------------------------------
function Target()
  local _, _, maxPlayers = SearchActivities()
  local size = SizeBucket(maxPlayers)
  return size, db.need[size] or DEFAULT_NEED[size], math.max(maxPlayers or 0, 5)
end

function MemberKeys()
  local t = {}
  for _, m in ipairs(api.members()) do t[Key(m.name)] = m.unit end
  return t
end

-- Gibt die Belegung inklusive dir zurück und welche deiner Rollen du übernimmst:
-- die seltenste, die noch fehlt (Tank vor Heiler vor Schaden).
function Filled()
  local f = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  for k, unit in pairs(MemberKeys()) do
    local r = joined[k] or expired[k] or api.unitRole(unit)
    if r ~= "TANK" and r ~= "HEALER" then r = "DAMAGER" end -- ohne Rolle zählt als Schaden
    f[r] = f[r] + 1
  end
  local _, need = Target()
  local me
  for _, r in ipairs(ROLES) do
    if char.myRoles[r] and (need[r] or 0) - f[r] > 0 then me = r break end
  end
  if not me then
    for _, r in ipairs(ROLES) do if char.myRoles[r] then me = r break end end
  end
  me = me or "DAMAGER"
  f[me] = f[me] + 1
  return f, me
end

-- rem = noch zu besetzen, open = davon noch ohne laufende Einladung
function Slots()
  local _, need = Target()
  local f = Filled()
  local rem, open = {}, {}
  for _, r in ipairs(ROLES) do
    rem[r] = math.max(0, (need[r] or 0) - f[r])
    open[r] = rem[r]
  end
  for _, p in pairs(pending) do if p.role then open[p.role] = math.max(0, open[p.role] - 1) end end
  return rem, open
end

function Composition()
  local _, need = Target()
  local f = Filled()
  local comp = {}
  for _, r in ipairs(ROLES) do comp[r] = { math.min(f[r], need[r] or 0), need[r] or 0 } end
  return comp
end

function AnyLeft(t)
  for _, r in ipairs(ROLES) do if t[r] > 0 then return true end end
  return false
end

function PendingCount()
  local n = 0
  for _ in pairs(pending) do n = n + 1 end
  return n
end

-- Eine Gruppe fasst 5; mehr erst nach dem Umwandeln in einen Schlachtzug.
function RoomLeft()
  local _, _, cap = Target()
  if not api.isRaid() then cap = math.min(cap, 5) end
  return cap - math.max(1, api.groupSize()) - PendingCount()
end

function NeedsRaid()
  local size = Target()
  return size > 5 and not api.isRaid() and api.groupSize() >= 5 and AnyLeft((Slots()))
end

function CanInvite() return api.canInvite() end

function RoleFor(c, open)
  for _, r in ipairs(ROLES) do
    if c.roles[r] and open[r] > 0 then return r end
  end
end

-- Seltene Rollen zuerst: reichlich vorhandene Rollen warten, bis die knappen beigetreten sind.
SCARCE_RATIO = 3  -- ab so vielen Kandidaten je offenem Platz gilt eine Rolle als reichlich vorhanden
SCARCE_WAIT = 180 -- so lange hält eine knappe Rolle ohne jeden Kandidaten die anderen höchstens auf

function Supply()
  local s = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  for _, c in ipairs(candidates) do
    for _, r in ipairs(ROLES) do if c.roles[r] then s[r] = s[r] + 1 end end
  end
  return s
end

-- held = Rollen, die gerade nicht eingeladen werden; waiting = knappe Rollen, auf die sie warten
function HeldRoles()
  local held, waiting = {}, {}
  if not db.scarceFirst or not state.queued then return held, waiting end
  local rem, supply, now = Slots(), SupplyNow(), GetTime()
  for _, r in ipairs(ROLES) do
    if rem[r] > 0 and supply[r] < SCARCE_RATIO * rem[r] then
      local last = math.max(state.lastSupply[r] or 0, state.queuedAt)
      if now - last < SCARCE_WAIT then waiting[#waiting + 1] = r end
    end
  end
  if #waiting > 0 then
    for _, r in ipairs(ROLES) do
      if rem[r] > 0 and supply[r] >= SCARCE_RATIO * rem[r] then held[r] = true end
    end
  end
  return held, waiting
end

-------------------------------------------------------------------------
-- Kandidaten aus den Suchergebnissen
-------------------------------------------------------------------------
ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

-- Sprachfilter für die Suche (WowLocale-Struktur) oder nil für alle Sprachen
-- Bevorzugte Sprache: abwechselnd nur diese Spielsprache und alle suchen. Wer bei der gefilterten Suche
-- auftaucht, hat diese Spielsprache (state.langOf) und kommt innerhalb seiner Rolle zuerst dran.
-- Wer die Sprache spricht, aber einen anderen Client hat, ist nicht erkennbar und wird normal eingeladen.
function LanguageFilter()
  local pref = db.preferLang
  state.lastSearchLang = nil
  if not pref or pref == "none" then return nil end
  state.langToggle = not state.langToggle
  if not state.langToggle then return nil end
  state.lastSearchLang = pref
  local filter = {}
  for _, loc in ipairs(LANGUAGES) do filter[loc] = loc == pref end
  filter[pref] = true
  return filter
end

-- Angebot je Rolle; nach einer gefilterten Suche zählt das Angebot der letzten ungefilterten
function SupplyNow()
  return state.lastSearchLang and state.supplyAll or Supply()
end

function IsIgnoredName(name)
  if not (C_FriendList and C_FriendList.IsIgnored) then return false end
  local ok, ignored = pcall(C_FriendList.IsIgnored, name)
  return ok and ignored
end

function NewDemand() return { players = 0, groups = 0, TANK = 0, HEALER = 0, DAMAGER = 0 } end

-- Wer gerade wartet, täuscht: Beliebte Dungeons leeren sich schnell. Deshalb zählen wir,
-- wie viele verschiedene Spieler und Gruppen sich in den letzten 30 Minuten eingetragen haben.
POPULAR_WINDOW = 1800
function Popularity(activityID)
  local seenBy = db.popular[activityID]
  if not seenBy then return 0 end
  local n, cutoff = 0, time() - POPULAR_WINDOW
  for k, t in pairs(seenBy) do
    if t < cutoff then seenBy[k] = nil else n = n + 1 end
  end
  return n
end

-- Zonen der Dungeon-Eingänge (uiMapID) je Instanz (mapID der Aktivität); Namen kommen lokalisiert aus C_Map.
DUNGEON_ZONES = {
  [389] = { 1454 }, [36] = { 1436 }, [43] = { 1413 }, [33] = { 1421 }, [48] = { 1440 }, -- RFC, DM, WC, SFK, BFD
  [34] = { 1453 }, [90] = { 1426 }, [47] = { 1413 }, [189] = { 1420 }, [129] = { 1413 }, -- Verlies, Gnome, RFK, SM, RFD
  [70] = { 1418 }, [209] = { 1446 }, [349] = { 1443 }, [109] = { 1435 }, [429] = { 1444 }, -- Uld, ZF, Mara, ST, DM
  [230] = { 1428, 1427 }, [229] = { 1428, 1427 }, [329] = { 1423 }, [289] = { 1422 }, -- BRD, BRS, Strat, Scholo
  [409] = { 1428, 1427 }, [469] = { 1428, 1427 }, [249] = { 1445 }, [309] = { 1434 }, -- MC, BWL, Ony, ZG
  [509] = { 1451 }, [531] = { 1451 }, [533] = { 1423 }, -- AQ20, AQ40, Naxx
}
local nearCache = {}
-- Gebietsnamen je Nähe: 2 = Gebiet heißt wie der Dungeon (direkt am Eingang oder drin), 1 = Zone des Eingangs.
-- areaName ist das Gebiet wie auf der Minimap, vor Gnomeregan also „Gnomeregan“, in Kharanos „Kharanos“.
function NearNames(activityID)
  if nearCache[activityID] then return nearCache[activityID] end
  local names = {}
  local a = L.GetActivityInfoTable(activityID)
  if a and a.mapID then
    local inst = GetRealZoneText(a.mapID)
    for _, ui in ipairs(DUNGEON_ZONES[a.mapID] or {}) do
      local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(ui)
      if info and info.name then names[info.name] = 1 end
    end
    if inst and inst ~= "" then names[inst] = 2 end
  end
  nearCache[activityID] = names
  return names
end

-- Jede Minute: was älter ist als gebraucht, fliegt raus, damit lange Sitzungen nicht wachsen
function PruneState()
  local nowEpoch, now = time(), GetTime()
  for a, seenBy in pairs(db.popular) do
    for k, t in pairs(seenBy) do if t < nowEpoch - POPULAR_WINDOW then seenBy[k] = nil end end
    if next(seenBy) == nil then db.popular[a] = nil end
  end
  for k, l in pairs(state.listings) do if now - l.seenAt > 1800 then state.listings[k] = nil end end
  for k, t in pairs(seen) do if now - t > 7200 then seen[k] = nil; state.langOf[k] = nil end end
  for k, d in pairs(InviteInfo.byAddon) do if now - d.t > 600 then InviteInfo.byAddon[k] = nil end end
  for k, t in pairs(db.skipUntil) do if t <= nowEpoch then db.skipUntil[k] = nil end end
  for k, t in pairs(db.asked) do if t + ASK_COOLDOWN <= nowEpoch then db.asked[k] = nil end end
  Estimate.Prune()
end

-- Gruppen, denen genau deine seltene Rolle fehlt (nur Tank/Heiler, nur wenn du allein bist)
groupOffers = {}
ASK_COOLDOWN = 900 -- denselben Anführer frühestens nach 15 Minuten wieder anfragen

function Rebuild()
  wipe(candidates)
  wipe(groupOffers)
  if not db then return end
  state.treeVersion = state.treeVersion + 1 -- Auswahl oder Daten können sich geändert haben
  local now = GetTime()
  local _, open = Slots()
  local wanted = {}
  for _, e in ipairs(ActivityTree().all) do
    if IsPicked(e) then wanted[e.id] = e end
  end
  local members = MemberKeys()
  local me = UnitName("player")
  local demand = wipe(state.demand)
  for _, id in ipairs(api.results()) do
    local info = api.info(id)
    -- geheime Werte (z. B. in Instanzen) dürfen wir nicht auswerten: Eintrag überspringen
    if not AllReadable(info, "isDelisted", "hasSelf", "numMembers", "leaderName", "activityIDs", "age",
        "generalPlaystyle", "numCharFriends", "numBNetFriends", "numGuildMates", "comment") then info = nil end
    if info and not info.isDelisted and not info.hasSelf then
      local solo = info.numMembers == 1
      local p = solo and api.leader(id)
      if p and not AllReadable(p, "lfgRoles", "level", "classFilename", "areaName") then p = nil end
      if p then
        state.areaTotal = (state.areaTotal or 0) + 1
        if p.areaName and p.areaName ~= "" then
          state.areaSeen = (state.areaSeen or 0) + 1
          db.areaSample = db.areaSample or {}
          if #db.areaSample < 40 and not tContains(db.areaSample, p.areaName) then tinsert(db.areaSample, p.areaName) end
        end
      end
      local r = p and p.lfgRoles
      -- Einträge merken, um spätere Einladungen dieser Anführer einordnen zu können
      if info.leaderName then
        local first = info.activityIDs and info.activityIDs[1]
        local a = first and L.GetActivityInfoTable(first)
        local counts = L.GetSearchResultMemberCounts and L.GetSearchResultMemberCounts(id)
        local max = (a and a.maxNumPlayers and a.maxNumPlayers > 0) and a.maxNumPlayers or 5
        -- Dungeons haben bei Blizzard eine feste Verteilung (1/1/3); daraus folgt, was fehlt
        local expected = a and (a.useDungeonRoleExpectations or max == 5) and DEFAULT_NEED[5]
        local comp, used = {}, 0
        for _, r in ipairs(ROLES) do
          local n = counts and counts[r] or 0
          local need = expected and math.max(n, expected[r]) or n
          comp[r] = { n, need }
          used = used + need
        end
        comp.EMPTY = math.max(0, max - used)
        state.listings[Key(info.leaderName)] = { activity = ActivityName(info, true), activityID = first,
          comp = comp, playstyle = info.generalPlaystyle, listing = true, seenAt = now,
          resultID = id, numMembers = info.numMembers }
        local lk = Key(info.leaderName)
        local role
        for _, r in ipairs({ "TANK", "HEALER" }) do
          if char.myRoles[r] and comp[r][1] < comp[r][2] then role = r break end
        end
        local match
        for _, a in ipairs(info.activityIDs or {}) do if wanted[a] then match = a break end end
        if role and match and not solo and not IsInGroup() and lk ~= me and not db.blocked[lk]
            and (db.ratings[lk] or {}).v ~= -1 and not IsIgnoredName(info.leaderName) then
          local lp = api.leader(id)
          if lp and not AllReadable(lp, "areaName", "classFilename") then lp = nil end
          local area = lp and lp.areaName ~= "" and lp.areaName or nil
          local o = { id = id, name = info.leaderName, key = lk, role = role, comp = comp,
            activity = ActivityName(info), activityText = ActivityName(info, true), activityID = match,
            numMembers = info.numMembers, max = max, class = lp and lp.classFilename, area = area,
            friend = (info.numCharFriends or 0) + (info.numBNetFriends or 0) > 0,
            guild = (info.numGuildMates or 0) > 0, liked = (db.ratings[lk] or {}).v == 1,
            near = area and NearNames(match)[area], comment = info.comment,
            listedAt = info.age and (now - info.age) or now }
          groupOffers[#groupOffers + 1] = o
        end
      end
      -- Nachfrage je Aktivität: Solo-Spieler nach Rolle, dazu suchende Gruppen
      local who = info.leaderName and Key(info.leaderName) or ("#" .. id)
      for _, a in ipairs(info.activityIDs or {}) do
        local d = demand[a] or NewDemand()
        demand[a] = d
        db.popular[a] = db.popular[a] or {}
        db.popular[a][who] = time()
        if solo then
          d.players = d.players + 1
          if r then
            if r.tank then d.TANK = d.TANK + 1 end
            if r.healer then d.HEALER = d.HEALER + 1 end
            if r.dps then d.DAMAGER = d.DAMAGER + 1 end
          end
        else
          d.groups = d.groups + 1
        end
      end
      -- Kandidaten nur aus Solo-Einträgen: wer mit anderen gelistet ist, steckt schon in einer Gruppe.
      local k = solo and info.leaderName and Key(info.leaderName)
      if k and r and not db.blocked[k] and (db.ratings[k] or {}).v ~= -1 and not IsIgnoredName(info.leaderName)
          and (not db.samePlaystyle or db.playstyle == 0 or info.generalPlaystyle == db.playstyle)
          and k ~= me and not members[k] and not pending[k] and (db.skipUntil[k] or 0) <= time() then
        local matches = {}
        for _, a in ipairs(info.activityIDs or {}) do
          if wanted[a] then matches[#matches + 1] = wanted[a] end
        end
        -- Zu niedrige Stufe für alle gewünschten Aktivitäten? Höhere Stufen sind willkommen.
        local levelOk = not db.levelCheck or not p.level or p.level == 0
        if not levelOk then
          for _, e in ipairs(matches) do
            if e.lo == 0 or p.level >= e.lo - db.levelTolerance then levelOk = true break end
          end
        end
        if #matches > 0 and levelOk then
          local c = {
            id = id, name = info.leaderName, key = k,
            roles = { TANK = r.tank, HEALER = r.healer, DAMAGER = r.dps },
            class = p.classFilename, level = p.level, activity = ActivityName(info),
            activityText = ActivityName(info, true), comment = info.comment,
            matchedActivity = matches[1] and matches[1].id,
            playstyle = info.generalPlaystyle,
            friend = (info.numCharFriends or 0) + (info.numBNetFriends or 0) > 0,
            guild = (info.numGuildMates or 0) > 0,
            area = p.areaName ~= "" and p.areaName or nil,
          }
          if state.lastSearchLang then state.langOf[k] = state.lastSearchLang end
          c.liked = (db.ratings[k] or {}).v == 1
          c.lang = state.langOf[k]
          for _, e in ipairs(matches) do
            local n = c.area and NearNames(e.id)[c.area]
            if n and n > (c.near or 0) then c.near = n end
          end
          c.role = RoleFor(c, open)
          if c.role then
            if not seen[k] then seen[k] = now; Estimate.Arrived(c) end
            c.listedAt = info.age and (now - info.age) or seen[k]
            candidates[#candidates + 1] = c
          end
        end
      end
    end
  end
  -- Tanks, dann Heiler, dann Schaden; innerhalb einer Rolle standardmäßig die Neuesten zuerst.
  table.sort(candidates, function(a, b)
    if a.role ~= b.role then return ROLE_ORDER[a.role] < ROLE_ORDER[b.role] end
    if db.preferFriends then
      local af, bf = a.friend or a.guild, b.friend or b.guild
      if af ~= bf then return af end
    end
    if a.liked ~= b.liked then return a.liked end
    local pref = db.preferLang ~= "none" and db.preferLang
    if pref and (a.lang == pref) ~= (b.lang == pref) then return a.lang == pref end
    if db.preferNear and (a.near or 0) ~= (b.near or 0) then return (a.near or 0) > (b.near or 0) end
    if db.oldestFirst then return a.listedAt < b.listedAt end
    return a.listedAt > b.listedAt
  end)
  table.sort(groupOffers, function(a, b)
    local af, bf = a.friend or a.guild, b.friend or b.guild
    if af ~= bf then return af end
    if a.liked ~= b.liked then return a.liked end
    if (a.near or 0) ~= (b.near or 0) then return (a.near or 0) > (b.near or 0) end
    return a.listedAt > b.listedAt
  end)
  for r, n in pairs(Supply()) do if n > 0 then state.lastSupply[r] = GetTime() end end
  if not state.lastSearchLang then state.supplyAll = Supply() end
  if UpdateUI then UpdateUI() end
end

-- Mitglieder einer eingetragenen Gruppe, solange Blizzard den Eintrag noch kennt
function ListingMembers(l)
  if not (l and l.resultID and L.GetSearchResultPlayerInfo) then return nil end
  local list = {}
  for i = 1, l.numMembers or 0 do
    local ok, p = pcall(L.GetSearchResultPlayerInfo, l.resultID, i)
    if ok and AllReadable(p, "name", "classFilename", "level", "assignedRole") and p.name then
      local role = p.assignedRole
      if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = nil end
      list[#list + 1] = { name = p.name, class = p.classFilename, level = p.level, role = role }
    end
  end
  return #list > 0 and list or nil
end

-- Eigene Gruppe für die Einladungsnachricht: "Name~KLASSE~T/H/D~Stufe;..."
local ROLE_LETTER, LETTER_ROLE = { TANK = "T", HEALER = "H", DAMAGER = "D" }, { T = "TANK", H = "HEALER", D = "DAMAGER" }
function EncodeMembers()
  local _, me = Filled()
  local _, myClass = UnitClass("player")
  local list = { { name = UnitName("player"), class = myClass, role = me, level = UnitLevel("player") } }
  for _, m in ipairs(History.Snapshot()) do list[#list + 1] = m end
  local out = {}
  for _, m in ipairs(list) do
    out[#out + 1] = ("%s~%s~%s~%d"):format((m.name or "?"):gsub("[~;\t]", ""), m.class or "", ROLE_LETTER[m.role] or "", m.level or 0)
  end
  return table.concat(out, ";")
end
function DecodeMembers(s)
  if not s or s == "" then return nil end
  local list = {}
  for name, class, r, level in s:gmatch("([^~;]+)~([^~;]*)~([^~;]*)~(%d+)") do
    list[#list + 1] = { name = name, class = class ~= "" and class or nil, role = LETTER_ROLE[r], level = tonumber(level) }
  end
  return #list > 0 and list or nil
end

function ToggleBlocked(name)
  local k = Key(name)
  db.blocked[k] = not db.blocked[k] or nil
  Print((db.blocked[k] and T.CHAT_BLOCKED or T.CHAT_UNBLOCKED):format(Short(name)))
  Rebuild()
end

-------------------------------------------------------------------------
