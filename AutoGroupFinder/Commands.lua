local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Zeigt, was der Client an Group-Finder-Schnittstellen hat.
function Diag()
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    UpdateAddOnMemoryUsage()
    Print(("Memory: %.0f KB"):format(GetAddOnMemoryUsage(ADDON)))
  end
  Print(("Lua errors: %d"):format(#errors))
  Print(("areaName: %d/%d %s"):format(state.areaSeen or 0, state.areaTotal or 0, table.concat(db and db.areaSample or {}, ", ")))
  for _, e in ipairs(errors) do print("  " .. e) end
  if IsInInstance() then
    local mapID = select(8, GetInstanceInfo())
    Print(("Last boss: %s / learned %s (map %s, %d bosses)"):format(tostring(LastBossID()),
      tostring(FinalBossName(mapID)), tostring(mapID), #(ENCOUNTERS[mapID] or {})))
  end
  Print("Client: " .. tostring(select(4, GetBuildInfo())) .. " / " .. tostring((GetBuildInfo())))
  local api = C_LFGList
  Print("C_LFGList: " .. tostring(api ~= nil))
  if not api then return end
  for _, f in ipairs({ "Search", "GetSearchResults", "GetSearchResultInfo", "GetSearchResultLeaderInfo",
      "GetActivityInfoTable", "GetAvailableCategories", "GetAvailableActivities",
      "GetAvailableActivityGroups", "GetActivityGroupInfo", "GetLfgCategoryInfo" }) do
    Print("  " .. f .. ": " .. tostring(api[f] ~= nil))
  end
  if api.GetAvailableCategories then
    for _, c in ipairs(api.GetAvailableCategories() or {}) do
      local ci = api.GetLfgCategoryInfo and api.GetLfgCategoryInfo(c)
      local acts = api.GetAvailableActivities and api.GetAvailableActivities(c) or {}
      Print(("  %s: %s (%d)"):format(tostring(c), tostring(type(ci) == "table" and ci.name or ci), #acts))
    end
  end
end

-- /gf test api: schreibt Kategorien, Aktivitäten und Schnittstellen in die SavedVariables (nach /reload lesbar)
local function Flat(t)
  local out = {}
  if type(t) ~= "table" then return tostring(t) end
  for k, v in pairs(t) do if type(v) ~= "table" and type(v) ~= "function" then out[tostring(k)] = Readable(v) and v or "?" end end
  return out
end
function ApiDump()
  local api, d = C_LFGList or {}, { client = tostring(select(4, GetBuildInfo())), level = UnitLevel("player"), lfg = {}, cats = {} }
  for k in pairs(api) do d.lfg[#d.lfg + 1] = k end
  table.sort(d.lfg)
  for _, c in ipairs(api.GetAvailableCategories and api.GetAvailableCategories() or {}) do
    local cat = { id = c, info = Flat(api.GetLfgCategoryInfo and api.GetLfgCategoryInfo(c)), groups = {}, acts = {} }
    for _, gid in ipairs(api.GetAvailableActivityGroups and api.GetAvailableActivityGroups(c) or {}) do
      cat.groups[#cat.groups + 1] = { id = gid, name = (api.GetActivityGroupInfo(gid)), acts = api.GetAvailableActivities(c, gid) }
    end
    for _, id in ipairs(api.GetAvailableActivities(c) or {}) do
      local a = Flat(api.GetActivityInfoTable(id))
      a.id = id
      cat.acts[#cat.acts + 1] = a
    end
    d.cats[#d.cats + 1] = cat
  end
  if api.HasActiveEntryInfo and api.HasActiveEntryInfo() and api.GetActiveEntryInfo then d.entry = Flat(api.GetActiveEntryInfo()) end
  d.quests = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, math.min(C_QuestLog.GetNumQuestLogEntries() or 0, 40) do
      local q = Flat(C_QuestLog.GetInfo(i))
      if type(q) == "table" and (q.questID or 0) > 0 and api.GetActivityIDForQuestID then
        local ok, act = pcall(api.GetActivityIDForQuestID, q.questID)
        q.activityID = ok and act or "err"
      end
      d.quests[#d.quests + 1] = q
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, math.min(GetNumQuestLogEntries() or 0, 40) do d.quests[#d.quests + 1] = { GetQuestLogTitle(i) } end
  end
  -- Felder der letzten Suchergebnisse (z. B. ob Quest-Gruppen eine questID tragen)
  d.results = {}
  local okR, _, ids = pcall(function() return api.GetSearchResults() end)
  for i, id in ipairs(okR and ids or {}) do
    if i > 15 then break end
    local info = api.GetSearchResultInfo(id)
    local r = Flat(info)
    if type(info) == "table" and info.activityIDs then r.acts = table.concat(info.activityIDs, ",") end
    d.results[#d.results + 1] = r
  end
  d.listingFrames = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and k:match("^LFG") and type(v) == "table" and v.GetObjectType then
      d.listingFrames[#d.listingFrames + 1] = k .. "=" .. tostring(v:GetObjectType())
    end
  end
  table.sort(d.listingFrames)
  -- Was ist in Forever wirklich an? Spielregeln, Systeme, vorhandene C_-Namensräume
  d.rules, d.systems, d.ns = {}, {}, {}
  if Enum and Enum.GameRule and C_GameRules and C_GameRules.IsGameRuleActive then
    for name, v in pairs(Enum.GameRule) do
      local ok, on = pcall(C_GameRules.IsGameRuleActive, v)
      if ok and on then
        local okF, f = pcall(C_GameRules.GetGameRuleAsFloat, v)
        d.rules[#d.rules + 1] = name .. ((okF and f and f ~= 0 and f ~= 1) and ("=" .. tostring(f)) or "")
      end
    end
    table.sort(d.rules)
  end
  local function try(label, fn, ...)
    local r = { pcall(fn or error, ...) }
    local out = {}
    for i = 2, #r do out[#out + 1] = type(r[i]) == "table" and ("#" .. #r[i]) or tostring(r[i]) end
    d.systems[label] = (r[1] and "" or "ERR ") .. table.concat(out, ",")
  end
  local G = _G
  try("preset", C_GameRules and C_GameRules.GetForeverExperiencePreset)
  try("recentAllies", G.C_RecentAllies and C_RecentAllies.IsSystemEnabled)
  try("socialQueue", G.C_SocialQueue and C_SocialQueue.IsSystemEnabled)
  try("damageMeter", G.C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable)
  try("lootHistory", G.C_LootHistory and C_LootHistory.GetAllEncounterInfos)
  try("questSession", G.C_QuestSession and C_QuestSession.CanStart)
  try("newcomer", G.C_PlayerMentorship and C_PlayerMentorship.IsActivePlayerConsideredNewcomer)
  try("mentorLevel", G.C_PlayerMentorship and C_PlayerMentorship.GetMentorLevelRequirement)
  try("premadeStyle", api.GetPremadeGroupFinderStyle)
  try("applications", api.GetApplications)
  try("leavers", api.GetGroupLeaverCountsByRole)
  try("calendar", G.C_Calendar and C_Calendar.GetNumDayEvents, 0, 1)
  try("clubFinder", G.C_ClubFinder and C_ClubFinder.IsEnabled)
  try("ping", G.C_Ping and C_Ping.GetDefaultPingOptions)
  try("encounterTimeline", G.C_EncounterTimeline and C_EncounterTimeline.IsFeatureEnabled)
  try("raidLocks", G.GetNumSavedInstances)
  for k, v in pairs(G) do
    if type(k) == "string" and k:match("^C_") and type(v) == "table" then
      local n = 0
      for _, f in pairs(v) do if type(f) == "function" then n = n + 1 end end
      d.ns[#d.ns + 1] = k .. ":" .. n
    end
  end
  table.sort(d.ns)
  db.apiDump = d
  Print("API-Daten gespeichert, jetzt /reload.")
end

_G.SLASH_AUTOGROUPFINDER1 = SLASH
_G.SLASH_AUTOGROUPFINDER2 = "/groupfinder"
SlashCmdList.AUTOGROUPFINDER = function(msg)
  local raw = strtrim(msg or "")
  msg = strlower(raw)
  if msg == "diag" then Diag() return end
  if msg == "test api" then ApiDump() return end
  AutoGroupFinder_Slash(msg, raw)
end

function _G.AutoGroupFinder_Slash(msg, raw)
  if msg == "" then
    AutoGroupFinder_Toggle()
  elseif msg:match("^whisper") then
    local text = strtrim((raw or msg):sub(8))
    db.whisperText = text ~= "" and text or nil
    Print(T.CHAT_WHISPER_SET:format(db.whisperText or T.WHISPER_DEFAULT))
  elseif msg == "config" or msg == "settings" then
    OpenSettings() -- nennt nur den Weg
  elseif msg == "test" then
    Print((T.TEST_LIST:gsub("%%s", SLASH)))
  elseif msg == "test search" or msg == "test search shots" then
    RunTest(msg == "test search shots")
  elseif msg:match("^test invite") then
    InviteInfo.Demo(msg:match("^test invite%s+(%a+)"))
  elseif msg == "test minimap" then
    TestMinimap()
  elseif msg == "test here" then
    state.here = HereDungeon()
    if state.here then
      Print(T.TEST_HERE_FOUND:format(state.here.name, #state.here.ids))
    else
      Print(T.TEST_HERE_NONE:format(GetSubZoneText() or "", GetRealZoneText() or ""))
    end
    Rebuild()
  elseif msg == "start" then
    StartQueue()
  elseif msg == "stop" then
    StopQueue(T.CHAT_STOPPED)
  elseif msg == "minimap reset" then
    db.minimap.free, db.minimap.angle = nil, DEFAULTS.minimap.angle
    db.minimap.hide = false
    PlaceMinimap()
    UpdateMinimap()
  elseif msg == "minimap" then
    db.minimap.hide = not db.minimap.hide
    UpdateMinimap()
    Print(T.CHAT_MINIMAP:format(db.minimap.hide and T.OFF or T.ON))
  elseif msg == "sound" then
    db.sound = not db.sound
    Print(T.CHAT_SOUND:format(db.sound and T.ON or T.OFF))
  elseif msg:match("^interval %d+$") then
    db.interval = math.max(3, tonumber(msg:match("%d+")))
    Print(T.CHAT_INTERVAL:format(db.interval))
  elseif msg == "reset" then
    wipe(seen) wipe(db.skipUntil) wipe(pending) wipe(expired)
    Print(T.CHAT_RESET)
    Rebuild()
  elseif msg == "dump" then
    local _, ids = L.GetSearchResults()
    local id = ids and ids[1]
    if not id then Print(T.CHAT_NO_RESULTS) return end
    for k, v in pairs(L.GetSearchResultInfo(id) or {}) do print("  ", k, tostring(v)) end
    for k, v in pairs(L.GetSearchResultLeaderInfo(id) or {}) do
      if type(v) == "table" then
        for k2, v2 in pairs(v) do print("  ", k .. "." .. k2, tostring(v2)) end
      else
        print("  ", k, tostring(v))
      end
    end
  else
    Print(T.HELP:gsub("%%s", SLASH))
  end
end
