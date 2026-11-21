local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Ereignisse
-------------------------------------------------------------------------

function OnResults()
  state.searching = nil
  Estimate.OnResults()
  Rebuild()
  AutoInvite()
  Estimate.AfterResults()
end

-- Meldung in der Bildschirmmitte und Taskleiste blinken lassen (falls WoW im Hintergrund ist)
function Notify(text)
  if not db.notify then return end
  local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING
  if RaidWarningUtil and RaidWarningUtil.AddMessage then
    pcall(RaidWarningUtil.AddMessage, text, color)
  elseif RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color)
  end
  if FlashClientIcon then pcall(FlashClientIcon) end
end

-- Rollen setzen erlaubt Blizzard nur nach Klick oder Taste; vorgemerkt und beim nächsten Klick gesetzt.
roleQueue = {}
-- Blizzard erlaubt pro Klick oder Taste nur EINE geschützte Aktion (Rolle setzen, Flüstern, Raid umwandeln,
-- Suchen, Eintragen); jede weitere im selben Klick wird blockiert (ADDON_ACTION_BLOCKED). Darum diese
-- Warteschlange: jeder Klick erledigt höchstens eine vorgemerkte Aktion.
local function NextRestricted()
  if state.unlist then
    state.unlist = nil
    if not state.queued and api.listed() then return function() api.unlist() end end
  end
  if IsInGroup() and UnitIsGroupLeader("player") then
    local members = MemberKeys()
    for k, role in pairs(roleQueue) do
      local unit = members[k]
      if unit then
        roleQueue[k] = nil
        if api.unitRole(unit) ~= role then return function() api.setRole(unit, role) end end
      end
    end
    -- eigene Rolle nur einmal pro Änderung setzen, nicht bei jedem Klick
    local _, me = Filled()
    if api.unitRole("player") ~= me and state.selfRole ~= me then
      state.selfRole = me
      return function() api.setRole("player", me) end
    end
  end
  local now = GetTime()
  while #whisperQueue > 0 do
    local w = table.remove(whisperQueue, 1)
    if now - w.t < 20 then return function() api.whisper(w.name, w.text) end end
  end
end

-- true = dieser Klick ist verbraucht
HardwareTick = function()
  if not db or InCombatLockdown() then return false end
  local action = NextRestricted()
  if action then action() return true end
  -- Jemand ist gleich wieder gegangen: Eintragen ist der eine erlaubte Schritt dieses Klicks
  local r = state.resume
  if r and r.auto and not state.queued then
    state.resume = nil -- nur ein Versuch, sonst meldet jeder Klick denselben Fehler
    StartQueue(r)
    return true
  end
  return false
end

-- Verlauf: ein Eintrag je Gruppe, vom Entstehen bis zum Auflösen. Draußen heißt er nach der
-- Zone; betretene Dungeons und Raids ersetzen bzw. ergänzen den Namen.
function History.Snapshot()
  local list = {}
  for _, m in ipairs(api.members()) do
    local _, class = UnitClass(m.unit)
    local role = joined[Key(m.name)] or api.unitRole(m.unit)
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = nil end
    list[#list + 1] = { name = m.name, class = class, role = role, level = UnitLevel(m.unit) }
  end
  return list
end

-- joined/left je Mitglied: wer früh geht, steht später leise im Verlauf
function History.Merge(entry)
  local have, now, here = {}, time(), {}
  for _, m in ipairs(entry.members) do have[Key(m.name)] = m end
  for _, m in ipairs(History.Snapshot()) do
    local k = Key(m.name)
    here[k] = true
    local old = have[k]
    if old then
      old.role = old.role or m.role
      old.level = m.level or old.level
      old.left = nil -- wieder da
    else
      m.joined = now
      entry.members[#entry.members + 1] = m
    end
  end
  for k, m in pairs(have) do if not here[k] then m.left = m.left or now end end
end

-- Ein Abschnitt je Dungeon-Besuch: Betreten, erster und letzter Kampf, Bosse
-- Endboss lernen (Forevers Journal ist leer): der letzte besiegte Boss, wenn danach kein Wipe kam
-- und man den Dungeon innerhalb von 15 Minuten verlässt. Gezählt je Dungeon, die Mehrheit gilt.
function LearnFinal(r)
  local last
  for i = #r.bosses, 1, -1 do
    local b = r.bosses[i]
    if not b.ok then return end -- danach noch gewipt: abgebrochen, nicht fertig
    last = b break
  end
  if not (last and r.map and r.exit and r.exit - last.t <= 900) then return end
  local c = db.finalBoss[r.map] or {}
  db.finalBoss[r.map] = c
  c[last.n] = (c[last.n] or 0) + 1
end
function FinalBossName(mapID)
  local best, n = nil, 0
  for name, count in pairs(db.finalBoss[mapID] or {}) do
    if count > n then best, n = name, count end
  end
  return best
end
function History.Exit(r)
  if not r or r.exit then return end
  r.exit = time()
  LearnFinal(r)
  if History.MeterUpdate then History.MeterUpdate(r) end
  r.meterBase, r.meterLast, r.meterAcc = nil, nil, nil -- nur das Ergebnis aufheben
end

function History.Run(e)
  local r = e and e.runs and e.runs[#e.runs]
  return r and not r.exit and r or nil
end
function History.Boss(id, name, ok)
  local r = History.Run(state.historyEntry)
  if not r then return end
  if ok then r.kills = r.kills + 1 else r.wipes = r.wipes + 1 end
  r.bosses[#r.bosses + 1] = { id = Readable(id) and id or nil, n = Readable(name) and name or "?", t = time(), ok = ok or nil }
end
-- Besiegte Bosse von allen laut Spieldaten (Encounters.lua); nil, wenn der Dungeon unbekannt ist
function History.Progress(r)
  local list = r and r.map and ENCOUNTERS[r.map]
  if not list then return nil end
  local dead, n = {}, 0
  for _, b in ipairs(r.bosses) do if b.ok and b.id then dead[b.id] = true end end
  for _, id in ipairs(list) do if dead[id] then n = n + 1 end end
  return n, #list
end
function History.Fight(start)
  local r = History.Run(state.historyEntry)
  if not r then return end
  if start then r.first = r.first or time() else r.last = time() end
end

-- Nach /reload: den letzten Eintrag fortsetzen, wenn er frisch ist und jemand von damals dabei ist
function ContinuesLast()
  local last = char.history[1]
  if not last or time() - (last.last or last.t) > 6 * 3600 then return nil end
  local now = MemberKeys()
  for _, m in ipairs(last.members) do
    if now[Key(m.name)] then return last end
  end
end

function History.Track()
  if not IsInGroup() then
    local e = state.historyEntry
    if e then
      e.ended = time()
      History.Exit(History.Run(e))
      -- Kurze Gruppen ohne Dungeon (z. B. Layer-Wechsel per Einladung) nicht aufheben,
      -- außer das Add-on hat sie selbst gefüllt
      if e.ended - e.t < SHORT_GROUP and not e.instance and not e.wait then
        for i, x in ipairs(char.history) do if x == e then table.remove(char.history, i) break end end
      end
    end
    state.historyEntry = nil
    return
  end
  local e = state.historyEntry or ContinuesLast()
  if not e and #History.Snapshot() == 0 then return end -- noch niemand da (Einladung läuft)
  if not e then
    e = { t = time(), name = GetRealZoneText and GetRealZoneText() or "?", members = {} }
    table.insert(char.history, 1, e)
    while #char.history > 100 do table.remove(char.history) end
  end
  state.historyEntry = e
  local inInstance, kind = IsInInstance()
  if inInstance and (kind == "party" or kind == "raid") then
    local name = GetInstanceInfo()
    e.kind = kind
    if not e.instance then
      e.name, e.instance = name, true
    elseif name and not e.name:find(name, 1, true) then
      e.name = e.name .. ", " .. name
    end
    e.runs = e.runs or {}
    local r = History.Run(e)
    if r and r.name ~= name then History.Exit(r) r = nil end
    if not r then
      -- nach /reload drinnen ist das Betreten unbekannt (instanceSince fehlt dann)
      e.runs[#e.runs + 1] = { name = name, map = select(8, GetInstanceInfo()), enter = char.instanceSince,
        kills = 0, wipes = 0, bosses = {} }
      if History.MeterStart then History.MeterStart(e.runs[#e.runs]) end
    end
  else
    History.Exit(History.Run(e))
  end
  e.last = time()
  History.Merge(e)
end

SHORT_GROUP = 180 -- Sekunden; kürzere Gruppen ohne Dungeon kommen nicht in den Verlauf
RESUME_AUTO_WINDOW = 180 -- Sekunden nach dem Vollwerden, in denen ein Abgang automatisch weitersuchen lässt

-- Lauf vorbei? Letzter Boss laut Dungeon-Journal besiegt, sonst nach langer Zeit im Dungeon.
-- Dann gehen Leute absichtlich; Nachbesetzen nur noch leise anbieten.
RUN_DONE_AFTER = 1500
-- Endboss aus den Spieldaten (Encounters.lua, DungeonEncounter); Forevers Journal ist abgeschaltet
function LastBossID()
  local list = GetInstanceInfo and ENCOUNTERS[select(8, GetInstanceInfo())]
  return list and list[#list]
end
function RunDone()
  if state.runDone then return true end
  local inside = IsInInstance and IsInInstance()
  return (inside and char.instanceSince and time() - char.instanceSince > RUN_DONE_AFTER) and true or false
end

function OnRoster()
  if not IsInGroup() then state.selfRole, state.runDone, char.memberFor = nil, nil, nil else state.inGroupAt = GetTime() end
  if state.resume and IsInGroup() and not CanInvite() then state.resume = nil end
  local members = MemberKeys()
  for name in pairs(members) do
    local k = FindPending(name)
    if k and not pending[k].role then
      -- selbst eingeladen, Rolle unbekannt: nichts festlegen, Blizzards Rollenzuweisung zählt
      pending[k] = nil
      local r = api.unitRole(members[name])
      Print(T.CHAT_JOINED:format(Short(k), ROLE_NAME[r] or ROLE_NAME.DAMAGER))
    elseif k then
      joined[k] = pending[k].role
      state.lastJoinRole = joined[k]
      Estimate.Joined(joined[k])
      pending[k] = nil
      roleQueue[k] = joined[k]
      Print(T.CHAT_JOINED:format(Short(k), ROLE_NAME[joined[k]]))
      if db.sound then PlaySound(SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION or SOUNDKIT.IG_PLAYER_INVITE or 880, "SFX") end
      if (Target()) <= 5 then Notify(T.CHAT_JOINED:format(Short(k), ROLE_NAME[joined[k]])) end -- in Raids nur die volle Gruppe
    elseif expired[name] and not joined[name] then
      joined[name] = expired[name]
      state.lastJoinRole = joined[name]
      Estimate.Joined(joined[name])
      roleQueue[name] = joined[name]
      Print(T.CHAT_LATE:format(Short(name), ROLE_NAME[joined[name]]))
    end
  end
  for k in pairs(joined) do if not members[k] then joined[k] = nil end end
  Estimate.OnRoster()
  if state.queued or win:IsShown() then Rebuild() end -- sonst sieht es niemand; das Fenster baut beim Öffnen neu
  if not IsInGroup() then state.completed = false end
  -- Fertige Gruppe wieder unvollständig: Neustart braucht einen Klick, also nur Bescheid geben.
  if not state.queued and state.completed and IsInGroup() and CanInvite() then
    local rem = Slots()
    if AnyLeft(rem) and not state.backfillNoted then
      state.backfillNoted = true
      local link = " |cff71d5ff|Haddon:AutoGroupFinder:backfill|h[" .. T.BACKFILL_LINK .. "]|h|r"
      if RunDone() then
        Print(T.CHAT_BACKFILL:format(NeedText(rem)) .. link) -- nach dem Lauf: kein Knopf, keine Meldung
        return
      end
      -- Kurz nach dem Vollwerden und noch draußen: beim nächsten Klick automatisch weitersuchen
      local auto = char.lastFill and time() - char.lastFill.t < RESUME_AUTO_WINDOW and not (IsInInstance and IsInInstance())
      state.resume = { auto = auto, t = GetTime() }
      if auto then
        Print(T.CHAT_BACKFILL:format(NeedText(rem)) .. " " .. T.RESUME_NEXT)
      else
        Print(T.CHAT_BACKFILL:format(NeedText(rem)) .. link)
      end
      Notify(T.NOTIFY_BACKFILL:format(NeedText(rem)))
    elseif not AnyLeft(rem) then
      state.backfillNoted, state.resume = false, nil
    end
  end
  if state.queued and IsInGroup() and not CanInvite() then
    StopQueue(T.CHAT_LEADER_ONLY) -- Anführer abgegeben: einladen geht nicht mehr
    return
  end
  if state.queued then
    local _, _, cap = Target()
    if not AnyLeft((Slots())) or api.groupSize() >= cap then
      FinishQueue()
    else
      AutoInvite() -- auch wenn jemand gegangen ist: Platz wird neu besetzt
    end
  end
end

function Tick()
  if not db then return end
  local now = GetTime()
  local drop = {}
  for k, p in pairs(pending) do
    if not p.confirmed and now - p.t > 5 then
      drop[#drop + 1] = { k, 60, T.CHAT_NOT_SENT }
    elseif now - p.t > db.inviteTimeout then
      drop[#drop + 1] = { k, db.declineCooldown, T.CHAT_NO_ANSWER }
    end
  end
  for _, d in ipairs(drop) do DropPending(d[1], d[2], d[3]) end
  state.ticks = (state.ticks or 0) + 1
  if IsInGroup() then state.inGroupAt = now end
  if state.resume and (state.queued or now - state.resume.t > 600) then state.resume = nil end
  local full = state.ticks % 5 == 0 -- Alterangaben u. Ä. reichen alle 5 s; Änderungen zeichnen sofort über Rebuild
  if state.searching and now - state.searching > 10 then state.searching, full = nil, true end
  if state.ticks % 60 == 0 then PruneState() end
  UpdateNudge()
  if UpdateBroker then UpdateBroker() end
  if win:IsShown() then
    if full and UpdateUI then UpdateUI() elseif UpdateNeed then UpdateNeed() end
  end
end

ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CHAT_MSG_ADDON",
    "PARTY_INVITE_REQUEST", "QUEST_LOG_UPDATE", "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_END",
    "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_SEARCH_FAILED",
    "LFG_LIST_AVAILABILITY_UPDATE", "LFG_LIST_ACTIVE_ENTRY_UPDATE", "GROUP_ROSTER_UPDATE", "CHAT_MSG_SYSTEM" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    _G.AutoGroupFinderDB = _G.AutoGroupFinderDB or {}
    db = AutoGroupFinderDB
    db.errors = errors -- nur die Fehler dieser Sitzung
    if not db.shareV2 then db.shareStats, db.shareV2 = true, true end -- Teilen ist jetzt Standard
    db.languageMode, db.languages = nil, nil -- abgelöst durch preferLang
    db.winHome = nil -- Fenster platziert sich jetzt selbst
    for k, v in pairs(DEFAULTS) do
      if db[k] == nil then db[k] = type(v) == "table" and CopyTable(v) or v end
    end
    for k, v in pairs(DEFAULTS.minimap) do if db.minimap[k] == nil then db.minimap[k] = v end end
    for _, size in ipairs(SIZES) do
      db.need[size] = db.need[size] or CopyTable(DEFAULT_NEED[size])
    end
    if (db.voice or 0) < 0 then db.voice = 0 end
    -- Pro Charakter: eigene Rollen und Verlauf. Beim ersten Start die bisherigen Account-Werte übernehmen.
    _G.AutoGroupFinderCharDB = _G.AutoGroupFinderCharDB or {}
    char = _G.AutoGroupFinderCharDB
    if not char.myRoles then
      char.myRoles = db.myRoles or (db.myRole and { [db.myRole] = true }) or { DAMAGER = true }
    end
    if not char.history then
      char.history = db.history or {}
      db.history = nil -- gehört ab jetzt dem Charakter, der zuerst eingeloggt hat
    end
    for i = #char.history, 1, -1 do -- leere Einträge aus älteren Versionen
      if #(char.history[i].members or {}) == 0 then table.remove(char.history, i) end
    end
    db.myRoles, db.myRole = nil, nil
    -- Auswahl pro Charakter (activityID -> true/false, nil = nach Stufe); die alte Account-Auswahl passte nicht zu jedem
    char.activities = char.activities or {}
    db.activities = nil
    local nowEpoch = time()
    for k, t in pairs(db.skipUntil) do if t <= nowEpoch then db.skipUntil[k] = nil end end
    for a, seenBy in pairs(db.popular) do
      for k, t in pairs(seenBy) do if t < nowEpoch - 1800 then seenBy[k] = nil end end
      if next(seenBy) == nil then db.popular[a] = nil end
    end
    BuildMinimap() -- vor PLAYER_LOGIN, dann sammeln Add-ons wie MinimapButtonButton ihn ein
    pcall(RegisterSettings)
    RefreshMenus()
    return
  end
  if not db then return end
  if event == "PLAYER_LOGIN" then
    if L.RequestAvailableActivities then pcall(L.RequestAvailableActivities) end
    PlaceMinimap()
    UpdateMinimap()
    WorldFrame:HookScript("OnMouseDown", function()
      if db.keySearch then DoSearch(false) else HardwareTick() end -- je Klick nur eine geschützte Aktion
    end)
    C_Timer.NewTicker(1, Tick)
    History.Track() -- nach /reload in der laufenden Gruppe weitermachen
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM_PREFIX) end
    Print(T.LOADED:format(SLASH))
  elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
    -- Über Blizzards Auge ausgetragen oder einer anderen Gruppe beigetreten: nicht weiter „suchen“
    if state.queued and GetTime() - state.queuedAt > 5 and L.HasActiveEntryInfo and not L.HasActiveEntryInfo() then
      -- Gruppe hat sich gerade aufgelöst (einziger Mitspieler weg): Blizzard nimmt den Eintrag mit
      local dissolved = not IsInGroup() and GetTime() - (state.inGroupAt or 0) < 3
      local since = state.queuedAt
      StopQueue(dissolved and T.CHAT_DISSOLVED or T.CHAT_LISTING_GONE)
      if dissolved then state.resume = { auto = true, since = since, t = GetTime() } end
    end
  elseif event == "ENCOUNTER_END" then
    -- encounterID, name, difficulty, size, success; in Instanzen evtl. geheim
    local won = Readable(arg5) and (arg5 == 1 or arg5 == true)
    local final = (Readable(arg1) and arg1 == LastBossID())
      or (Readable(arg2) and arg2 == FinalBossName(select(8, GetInstanceInfo())))
    if won and final then
      state.runDone = true
      if state.historyEntry then state.historyEntry.done = time() end -- wer danach geht, ging nicht früh
    end
    if Readable(arg5) then History.Boss(arg1, arg2, arg5 == 1 or arg5 == true) end
  elseif event == "LFG_LIST_AVAILABILITY_UPDATE" then
    InvalidateHere()
    state.here = HereDungeon() -- Dungeon-Liste ist da, Standort neu prüfen
    Rebuild()
  elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
    if not test then OnResults() end
  elseif event == "LFG_LIST_SEARCH_FAILED" then
    state.searching = nil
  elseif event == "PARTY_INVITE_REQUEST" then
    state.lastInviter = arg1
    -- arg2-4: Rollen, die der Einladende anbietet (Tank, Heiler, Schaden)
    local offered = (arg2 or arg3 or arg4) and { TANK = arg2, HEALER = arg3, DAMAGER = arg4 } or nil
    InviteInfo.offered = offered
    InviteInfo.Show(arg1, 0, offered)
  elseif event == "CHAT_MSG_ADDON" then
    if Readable(arg2) and Readable(arg4) then OnAddonMessage(arg1, arg2, arg3, arg4) end
  elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
    -- kommt oft in Schüben: einmal neu aufbauen statt bei jedem Eintrag
    if not state.rebuildQueued then
      state.rebuildQueued = true
      C_Timer.After(0.2, function() state.rebuildQueued = false Rebuild() end)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    History.Fight(false)
    AutoInvite() -- im Kampf liegengebliebene Einladungen nachholen
  elseif event == "PLAYER_REGEN_DISABLED" then
    History.Fight(true)
  elseif event:match("^ZONE_CHANGED") then
    state.here = HereDungeon()
    if UpdateUI then UpdateUI() end
  elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    if OnApplication then OnApplication(arg1, arg2) end
  elseif event == "QUEST_LOG_UPDATE" then
    InvalidateQuests()
    state.treeVersion = state.treeVersion + 1
    if win:IsShown() and db.view == "activities" and CurrentCategory() == QUEST_CATEGORY then UpdateUI() end
  elseif event == "PLAYER_ENTERING_WORLD" then
    state.here = HereDungeon()
    if arg1 then -- Einloggen oder Charakterwechsel, nicht /reload: Fenster beginnt auf der Startseite
      db.view, db.category = "categories", nil
      db.page = IsInGroup() and 4 or 1
    end
    C_Timer.After(10, Estimate.UpdateChannel) -- Chat-Kanäle sind direkt nach dem Laden noch nicht bereit
    local inInstance, kind = IsInInstance()
    -- Nur beim echten Betreten starten; nach /reload oder Login drinnen ist der Beginn unbekannt
    if not inInstance then char.instanceSince = nil
    elseif not char.instanceSince and not (arg1 or arg2) then char.instanceSince = time() end
    History.Track()
    if state.queued and inInstance and (kind == "party" or kind == "raid") then
      StopQueue(T.CHAT_IN_INSTANCE)
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    History.Track()
    OnRoster()
  elseif event == "CHAT_MSG_SYSTEM" then
    if Readable(arg1) then OnSystem(arg1) end -- in Instanzen und im Kampf oft geheim
  else
    Rebuild()
  end
end)

-------------------------------------------------------------------------

-- Klick auf [Nachbesetzen] im Chat: ein echter Klick, also darf eingetragen und gesucht werden
if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if link == "addon:AutoGroupFinder:backfill" and not state.queued then StartQueue() end
  end, ns)
end
