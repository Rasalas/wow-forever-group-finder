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
    if db.myRoles[r] and (need[r] or 0) - f[r] > 0 then me = r break end
  end
  if not me then
    for _, r in ipairs(ROLES) do if db.myRoles[r] then me = r break end end
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
  for _, p in pairs(pending) do open[p.role] = math.max(0, open[p.role] - 1) end
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

-------------------------------------------------------------------------
-- Kandidaten aus den Suchergebnissen
-------------------------------------------------------------------------
ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

-- Sprachfilter für die Suche (WowLocale-Struktur) oder nil für alle Sprachen
function LanguageFilter()
  local mine = GetLocale()
  if mine == "enGB" then mine = "enUS" end
  local pick = {}
  if db.languageMode == "mine" then
    pick[mine] = true
  elseif db.languageMode == "mineEnglish" then
    pick[mine], pick.enUS = true, true
  elseif db.languageMode == "custom" then
    pick = db.languages
  end
  if not next(pick) then return nil end
  local filter = {}
  for _, loc in ipairs(LANGUAGES) do filter[loc] = pick[loc] and true or false end
  return filter
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

function Rebuild()
  wipe(candidates)
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
    if info and not info.isDelisted and not info.hasSelf then
      local solo = info.numMembers == 1
      local p = solo and api.leader(id)
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
          comp = comp, playstyle = info.generalPlaystyle, listing = true, seenAt = now }
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
      if k and r and not db.blocked[k] and not IsIgnoredName(info.leaderName)
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
          }
          c.role = RoleFor(c, open)
          if c.role then
            seen[k] = seen[k] or now
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
    if db.oldestFirst then return a.listedAt < b.listedAt end
    return a.listedAt > b.listedAt
  end)
  if UpdateUI then UpdateUI() end
end

function ToggleBlocked(name)
  local k = Key(name)
  db.blocked[k] = not db.blocked[k] or nil
  Print((db.blocked[k] and T.CHAT_BLOCKED or T.CHAT_UNBLOCKED):format(Short(name)))
  Rebuild()
end

-------------------------------------------------------------------------
