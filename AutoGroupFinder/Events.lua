local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Ereignisse
-------------------------------------------------------------------------

function OnResults()
  state.searching = nil
  Rebuild()
  AutoInvite()
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
HardwareTick = function()
  if not db or InCombatLockdown() then return end
  if IsInGroup() and UnitIsGroupLeader("player") then
    for k, unit in pairs(MemberKeys()) do
      local role = roleQueue[k]
      if role and api.unitRole(unit) ~= role then api.setRole(unit, role) end
      roleQueue[k] = nil
    end
    -- eigene Rolle nur einmal pro Änderung setzen, nicht bei jedem Klick
    local _, me = Filled()
    if api.unitRole("player") ~= me and state.selfRole ~= me then
      api.setRole("player", me)
      state.selfRole = me
    end
  end
  local now = GetTime()
  for _, w in ipairs(whisperQueue) do
    if now - w.t < 20 then api.whisper(w.name, w.text) end
  end
  wipe(whisperQueue)
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

function History.Merge(entry)
  local have = {}
  for _, m in ipairs(entry.members) do have[Key(m.name)] = m end
  for _, m in ipairs(History.Snapshot()) do
    local old = have[Key(m.name)]
    if old then
      old.role = old.role or m.role
      old.level = m.level or old.level
    else
      entry.members[#entry.members + 1] = m
    end
  end
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
    state.historyEntry = nil
    return
  end
  local e = state.historyEntry or ContinuesLast()
  if not e then
    e = { t = time(), name = GetRealZoneText and GetRealZoneText() or "?", members = {} }
    table.insert(char.history, 1, e)
    while #char.history > 100 do table.remove(char.history) end
  end
  state.historyEntry = e
  local inInstance, kind = IsInInstance()
  if inInstance and (kind == "party" or kind == "raid") then
    local name = GetInstanceInfo()
    if not e.instance then
      e.name, e.instance = name, true
    elseif name and not e.name:find(name, 1, true) then
      e.name = e.name .. ", " .. name
    end
  end
  e.last = time()
  History.Merge(e)
end

function OnRoster()
  if not IsInGroup() then state.selfRole = nil end
  local members = MemberKeys()
  for name in pairs(members) do
    local k = FindPending(name)
    if k then
      joined[k] = pending[k].role
      pending[k] = nil
      roleQueue[k] = joined[k]
      Print(T.CHAT_JOINED:format(Short(k), ROLE_NAME[joined[k]]))
      Notify(T.CHAT_JOINED:format(Short(k), ROLE_NAME[joined[k]]))
    elseif expired[name] and not joined[name] then
      joined[name] = expired[name]
      roleQueue[name] = joined[name]
      Print(T.CHAT_LATE:format(Short(name), ROLE_NAME[joined[name]]))
    end
  end
  for k in pairs(joined) do if not members[k] then joined[k] = nil end end
  Rebuild()
  if not IsInGroup() then state.completed = false end
  -- Fertige Gruppe wieder unvollständig: Neustart braucht einen Klick, also nur Bescheid geben.
  if not state.queued and state.completed and IsInGroup() and CanInvite() then
    local rem = Slots()
    if AnyLeft(rem) and not state.backfillNoted then
      state.backfillNoted = true
      Print(T.CHAT_BACKFILL:format(NeedText(rem)))
      Notify(T.NOTIFY_BACKFILL:format(NeedText(rem)))
    elseif not AnyLeft(rem) then
      state.backfillNoted = false
    end
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
  if state.searching and now - state.searching > 10 then state.searching = nil end
  if UpdateUI then UpdateUI() end
end

ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "CHAT_MSG_ADDON",
    "PARTY_INVITE_REQUEST",
    "PLAYER_ENTERING_WORLD",
    "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_SEARCH_FAILED",
    "LFG_LIST_AVAILABILITY_UPDATE", "GROUP_ROSTER_UPDATE", "CHAT_MSG_SYSTEM" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    _G.AutoGroupFinderDB = _G.AutoGroupFinderDB or {}
    db = AutoGroupFinderDB
    db.errors = errors -- nur die Fehler dieser Sitzung
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
    db.myRoles, db.myRole = nil, nil
    local nowEpoch = time()
    for k, t in pairs(db.skipUntil) do if t <= nowEpoch then db.skipUntil[k] = nil end end
    for a, seenBy in pairs(db.popular) do
      for k, t in pairs(seenBy) do if t < nowEpoch - 1800 then seenBy[k] = nil end end
      if next(seenBy) == nil then db.popular[a] = nil end
    end
    pcall(RegisterSettings)
    return
  end
  if not db then return end
  if event == "PLAYER_LOGIN" then
    if L.RequestAvailableActivities then pcall(L.RequestAvailableActivities) end
    PlaceMinimap()
    UpdateMinimap()
    WorldFrame:HookScript("OnMouseDown", function()
      HardwareTick()
      if db.keySearch then DoSearch(false) end
    end)
    C_Timer.NewTicker(1, Tick)
    History.Track() -- nach /reload in der laufenden Gruppe weitermachen
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM_PREFIX) end
    Print(T.LOADED:format(SLASH))
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
    OnAddonMessage(arg1, arg2, arg3, arg4)
  elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
    -- kommt oft in Schüben: einmal neu aufbauen statt bei jedem Eintrag
    if not state.rebuildQueued then
      state.rebuildQueued = true
      C_Timer.After(0.2, function() state.rebuildQueued = false Rebuild() end)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    AutoInvite() -- im Kampf liegengebliebene Einladungen nachholen
  elseif event == "PLAYER_ENTERING_WORLD" then
    History.Track()
    local inInstance, kind = IsInInstance()
    if state.queued and inInstance and (kind == "party" or kind == "raid") then
      StopQueue(T.CHAT_IN_INSTANCE)
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    History.Track()
    OnRoster()
  elseif event == "CHAT_MSG_SYSTEM" then
    OnSystem(arg1)
  else
    Rebuild()
  end
end)

-------------------------------------------------------------------------
