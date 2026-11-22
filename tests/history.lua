unpack = unpack or table.unpack; math.atan2 = math.atan2 or math.atan; tinsert = table.insert
strmatch = string.match; strfind = string.find; strsub = string.sub; strlen = string.len; strrep = string.rep; securecallfunction = securecallfunction or function(f, ...) return f(...) end
GetSubZoneText = GetSubZoneText or function() return "" end; IsInInstance = IsInInstance or function() return false, "none" end
hooksecurefunc = function(t, k, f) if type(t) == "string" then t, k, f = _G, t, k end local o = t[k]; rawset(t, k, function(...) local r = { o(...) }; f(...); return unpack(r) end) end
strsplit = function(sep, s) local t = {} for part in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = part end return (unpack or table.unpack)(t) end
GetRealZoneText = function() return ZONE or "Ironforge" end
date = os.date; GetInstanceInfo = function() return INSTANCE or "Scarlet Library" end; UnitClass = function() return "Mage", "MAGE" end; IsInInstance = function() return INSTANCE ~= nil, INSTANCE and "party" or "none" end; UnitLevel = UnitLevel or function() return 34 end
time = os.time
local now = 100
local NUM = { GetStringHeight = 14, GetFrameLevel = 1, GetWidth = 140, GetHeight = 140, GetStringWidth = 50, GetEffectiveScale = 1, GetVerticalScrollRange = 0, GetVerticalScroll = 0 }
local function dummy()
  return setmetatable({}, { __index = function(t, k)
    if ({ checkButton = 1, Icon = 1, ScrollBar = 1, CloseButton = 1, SetCustomOnMouseUpHandler = 1, cycle = 1, SetChecked = (rawget(t, "_isTab") and 1 or nil) })[k] then return nil end
    if NUM[k] then return function() return NUM[k] end end
    if k == "IsShown" then return function() return rawget(t, "_shown") end end
    -- Wie Blizzards DropdownButton: Menü sofort aufbauen, wenn der Knopf gezeigt ist
    if k == "SetupMenu" then return function(self, gen) rawset(self, "_menu", gen); if rawget(self, "_shown") then gen(self, dummy()) end end end
    if k == "GenerateMenu" then return function(self) local g = rawget(self, "_menu"); if g then g(self, dummy()) end end end
    if k == "Show" then return function() rawset(t, "_shown", true); local s = rawget(t, "_scripts"); if s and s.OnShow then s.OnShow(t) end end end
    if k == "Hide" then return function() local was = rawget(t, "_shown"); rawset(t, "_shown", false); local s = rawget(t, "_scripts"); if was and s and s.OnHide then s.OnHide(t) end end end
    if k == "SetShown" then return function(_, v) if v then t:Show() else t:Hide() end end end
    if k == "SetScript" then return function(_, n, f) local s = rawget(t, "_scripts") or {}; rawset(t, "_scripts", s); s[n] = f end end
    -- Wie im Spiel: HookScript hängt sich an, statt zu ersetzen
    if k == "HookScript" then return function(_, n, f) local s = rawget(t, "_scripts") or {}; rawset(t, "_scripts", s); local o = s[n]; s[n] = o and function(...) o(...); f(...) end or f end end
    if k == "GetScript" then return function(_, n) local s = rawget(t, "_scripts"); return s and s[n] end end
    if k == "SetText" then return function(_, v) rawset(t, "_text", v) end end
    if k == "SetWidth" then return function(_, v) rawset(t, "_w", v) end end
    if k == "SetChecked" then return function(_, v) rawset(t, "_checked", v) end end
    if k == "SetDesaturated" then return function(_, v) rawset(t, "_desat", v) end end
    if k == "GetChecked" then return function() return rawget(t, "_checked") end end
    if k == "GetCenter" then return function() return 0, 0 end end
    if k == "GetPropagateKeyboardInput" then return function() return true end end
    if k == "EnableKeyboard" then return function(_, v) rawset(t, "_kb", v) end end
    if k:match("^Create") then return function() return dummy() end end
    return function() return nil end
  end })
end
frames = {}
function CreateFrame(_, name, _, tmpl) local f = dummy(); frames[#frames+1] = f; rawset(f, "_shown", true); if name then _G[name] = f end; return f end
UIParent, Minimap, WorldFrame, GameTooltip = dummy(), dummy(), dummy(), dummy()
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("CHAT", (m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end }
function GetTime() return now end
function GetLocale() return LOCALE or "deDE" end
function IsInRaid() return false end
function UnitIsUnit() return false end
function GetBuildInfo() return "1.60.1", "x", "y", 16001 end
function Ambiguate(n) return n end
function UnitName() return "Me" end
function UnitLevel() return 34 end
local party = {}
function GetUnitName(u) return party[tonumber(u:match("%d+"))] end
function GetNumGroupMembers() return #party > 0 and #party + 1 or 0 end
function IsInGroup() return #party > 0 end
function UnitIsGroupLeader() return true end
function UnitIsGroupAssistant() return false end
function UnitGroupRolesAssigned() return "NONE" end
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end
function GetCursorPosition() return 0, 0 end
function PlaySound() print("SOUND") end
function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower = string.lower; wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
SlashCmdList = {}; SOUNDKIT = { READY_CHECK = 1 }; RAID_CLASS_COLORS = {}
function GameTooltip_Hide() end
Vector2DMixin = {}
-- Wie im Spiel: Blizzards C-Funktionen suchen Mixins roh im Namensraum des Aufrufers.
C_Texture = { GetAtlasInfo = function(a) if not rawget(getfenv(2), "Vector2DMixin") then error("unable to find mixin or metatable (Vector2DMixin)") end return {} end }
ERR_INVITE_PLAYER_S = "You have invited %s to join your group."
ERR_DECLINE_GROUP_S = "%s declines your group invitation."
ERR_ALREADY_IN_GROUP_S = "%s is already in a group."
local ticker
local timers = {}
C_Timer = { NewTicker = function(_, f) ticker = f end, After = function(d, f) timers[#timers+1] = { t = now + d, f = f } end }
function Screenshot() print("SCREENSHOT @" .. now) end
function advance(sec) local stop = now + sec while true do table.sort(timers, function(a, b) return a.t < b.t end) local nxt = timers[1] local nextTick = math.floor(now) + 1 if nxt and nxt.t <= stop and nxt.t <= nextTick then table.remove(timers, 1) now = nxt.t nxt.f() elseif nextTick <= stop then now = nextTick ticker() else now = stop break end end end
local results, invites = {}, {}
C_LFGList = {
  Search = function(...) local a = { ... }; print("SEARCH cat=" .. a[1], "nargs=" .. select("#", ...), "acts=" .. table.concat(a[7], ",")) end,
  GetSearchResults = function() local ids = {} for id in pairs(results) do ids[#ids+1] = id end table.sort(ids) return #ids, ids end,
  GetSearchResultInfo = function(id) return results[id] end,
  GetSearchResultLeaderInfo = function(id) return results[id].p end,
  GetAvailableCategories = function() return { 1, 2 } end,
  GetLfgCategoryInfo = function(c) return { name = c == 2 and "Dungeons" or "Questing" } end,
  GetAvailableActivities = function(_, gid) if gid == 0 then return { 13 } end if gid == 100 then return { 10, 11, 12 } end return { 10, 11, 12, 13 } end,
  GetAvailableActivityGroups = function() return { 100 } end,
  HasActiveEntryInfo = function() return LISTED end,
  CreateListing = function(d) LISTED = true; print("LIST playstyle=" .. tostring(d.generalPlaystyle) .. " voice=" .. tostring(d.voiceMode) .. " npf=" .. tostring(d.newPlayerFriendly) .. " acts=" .. #d.activityIDs) return true end,
  UpdateListing = function() print("UPDATE LISTING") return true end,
  RemoveListing = function() LISTED = false; print("UNLIST") end,
  GetActivityGroupInfo = function() return "Scarlet Monastery", 1 end,
  GetActivityInfoTable = function(id)
    local r = { [10] = { "Scarlet Library", 33, 41 }, [11] = { "Gnomeregan", 29, 38 }, [12] = { "Deadmines", 17, 26 }, [13] = { "Razorfen Kraul", 29, 38 } }
    if not r[id] then return nil end
    return { fullName = r[id][1], shortName = "", minLevelSuggestion = r[id][2], maxLevelSuggestion = r[id][3], maxNumPlayers = 5, orderIndex = 0 }
  end,
}
C_PartyInfo = { InviteUnit = function(n) invites[#invites+1] = n; print("INVITE", n) end }
local function fire(e, ...) for _, f in ipairs(frames) do local s = rawget(f, "_scripts"); if s and s.OnEvent then s.OnEvent(f, e, ...) end end end
local function sys(m) fire("CHAT_MSG_SYSTEM", m) end

local function res(id, name, roles, age, extra)
  local r = { leaderName = name, numMembers = 1, age = age, activityIDs = { 10 }, isDelisted = false, hasSelf = false,
    p = { lfgRoles = roles, level = 34, classFilename = "MAGE" } }
  for k, v in pairs(extra or {}) do r[k] = v end
  results[id] = r
end
local ns = {}
-- Dateien in der Reihenfolge der .toc laden, wie WoW es tut
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN")
local db = AutoGroupFinderDB
db.playstyle, db.view = 2, "activities"
-- Nachfrage: 3 Spieler für Library (10), 1 für Gnomeregan (11), 1 Gruppe für Library
res(1, "T1", { tank = true }, 5); res(2, "H1", { healer = true }, 5); res(3, "D1", { dps = true }, 5)
res(4, "D2", { dps = true }, 5, { activityIDs = { 11 } })
res(5, "Grp", { tank = true }, 5, { numMembers = 3 })
AutoGroupFinderCharDB.activities[10] = false -- Library nicht angehakt: trotzdem gezählt, aber niemand eingeladen
local f = AutoGroupFinderFrame
f:Show()
AutoGroupFinder_Refresh()
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
print("searched all visible activities (inkl. nicht angehakter Library)")
-- Balken prüfen: Zeilen mit activity
local bars = {}
for _, fr in ipairs(frames) do
  local a = rawget(fr, "activity")
  if a and rawget(fr, "_shown") then
    local bar = rawget(fr, "bar")
    bars[#bars + 1] = a .. ":" .. tostring(bar and rawget(bar, "_shown") and rawget(bar, "_w") or "-")
  end
end
print("rows with demand:", table.concat(bars, " "))
print("candidates only from picked:", AutoGroupFinderCharDB.activities[10] == false)
print("== popularity: invited players still count")
results[1] = nil; results[2] = nil   -- T1/H1 sofort weg (eingeladen)
now = now + 60; fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local pop = {}
for _, fr in ipairs(frames) do
  local a = rawget(fr, "activity")
  if a and rawget(fr, "_shown") then local bar = rawget(fr, "bar"); pop[#pop + 1] = a .. ":" .. tostring(bar and rawget(bar, "_shown") and rawget(bar, "_w") or "-") end
end
print("bars after T1/H1 left:", table.concat(pop, " "), "(Library bleibt am längsten)")
print("== history outside instance")
IsInGroup = function() return true end
party = { "Quester" }
ZONE = "Duskwood"
fire("GROUP_ROSTER_UPDATE")
print("entry:", AutoGroupFinderCharDB.history[1].name, #AutoGroupFinderCharDB.history[1].members)
party = { "Quester", "T1" }
fire("GROUP_ROSTER_UPDATE")
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD")
INSTANCE = "Scarlet Library"; fire("PLAYER_ENTERING_WORLD")
print("entry:", AutoGroupFinderCharDB.history[1].name, "members:", #AutoGroupFinderCharDB.history[1].members, "entries:", #AutoGroupFinderCharDB.history)
print("== reload continues")
local loaded = ns
fire("PLAYER_LOGIN")
print("entries after login:", #AutoGroupFinderCharDB.history)
print("== group disbands, new group")
IsInGroup = function() return #party > 0 end
party = {}; fire("GROUP_ROSTER_UPDATE")
INSTANCE = nil; ZONE = "Westfall"
party = { "Other" }; fire("GROUP_ROSTER_UPDATE")
print("entries:", #AutoGroupFinderCharDB.history, "newest:", AutoGroupFinderCharDB.history[1].name, AutoGroupFinderCharDB.history[1].members[1].name)
db.page = 3; f:Show(); ticker()
print("== pro Charakter")
print("history in CharDB:", AutoGroupFinderCharDB.history ~= nil, "nicht mehr im Account:", AutoGroupFinderDB.history == nil, "roles:", AutoGroupFinderCharDB.myRoles.DAMAGER)

print("== Ablauf: Dauer, Abgang, Dungeon")
local function check(label, got, want)
  print(label, got, got == want and "ok" or ("FEHLER, erwartet " .. tostring(want)))
  if got ~= want then error(label .. ": " .. tostring(got) .. " statt " .. tostring(want)) end
end
local clock = 1000000
time = function() return clock end
local E = ns.env
party = {}; fire("GROUP_ROSTER_UPDATE")
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
party = { "Tank", "Heal", "Dd" }; fire("GROUP_ROSTER_UPDATE")
local h = AutoGroupFinderCharDB.history[1]
clock = clock + 120; INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
check("1) Abschnitt angelegt:", h.runs and h.runs[1].name, "Gnomeregan")
check("2) Betreten bekannt:", h.runs[1].enter, clock)
clock = clock + 60; fire("PLAYER_REGEN_DISABLED")
clock = clock + 30; fire("PLAYER_REGEN_ENABLED")
check("3) erster Kampf:", h.runs[1].first, 1000000 + 180)
clock = clock + 300; party = { "Tank", "Heal" }; fire("GROUP_ROSTER_UPDATE")
check("4) Dd gegangen:", h.members[3].left, clock)
clock = clock + 600; fire("ENCOUNTER_END", 2898, "Grubbis", 1, 5, 0)
clock = clock + 60; fire("ENCOUNTER_END", 2898, "Grubbis", 1, 5, 1)
check("5) Boss und Wipe:", h.runs[1].kills .. "/" .. h.runs[1].wipes, "1/1")
clock = clock + 900; fire("PLAYER_REGEN_DISABLED"); fire("PLAYER_REGEN_ENABLED")
check("6) letzter Kampf:", h.runs[1].last, clock)
clock = clock + 120; INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
check("7) verlassen:", h.runs[1].exit, clock)
clock = clock + 60; party = {}; fire("GROUP_ROSTER_UPDATE")
check("8) Gruppe zu Ende:", h.ended, clock)
db.page = 3; f:Show(); E.History.Update()
local function txt(fr, key) local l = rawget(fr, key) return l and rawget(l, "_text") end
local function plain(t) return t and (t:gsub("|T.-|t", "S"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local card, ddList
for _, fr in ipairs(frames) do
  if rawget(fr, "entry") == h and rawget(fr, "head") then card = fr end
  local m = rawget(fr, "member")
  if m and m.name == "Dd" and fr:IsShown() then ddList = txt(fr, "note") end
end
check("9) Kurzfassung mit Dauer, Bossen und Wipe:", plain(E.History.Stats(h)), "38 Min · Bosse: 1 · 1× Wipe")
check("11) Dauer vor dem Datum:", txt(card, "date"):match("^%d+ Min") ~= nil, true)
check("10c) Liste zeigt Namen mit Abgang:", ddList and ddList:match("ging nach %d+ Min"), "ging nach 9 Min")
rawget(card, "_scripts").OnClick(card, "LeftButton")
check("10a) Detailseite offen:", E.History.detail, h)
local dd
for _, fr in ipairs(frames) do
  local m = rawget(fr, "member")
  if m and m.name == "Dd" and fr:IsShown() and rawget(fr, "kind") == "member" then dd = txt(fr, "text") end
end
check("10) Abgang nach 8,5 Min:", dd and dd:match("ging nach %d+ Min"), "ging nach 9 Min")
E.History.Back()
check("10b) zurück zur Liste:", E.History.detail, nil)
print("== Nach dem letzten Boss geht niemand früh")
party = { "A", "B" }; fire("GROUP_ROSTER_UPDATE")
local h2 = AutoGroupFinderCharDB.history[1]
GetInstanceInfo = function() return INSTANCE or "Scarlet Library", "party", 1, "", 5, 0, false, 90 end
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
clock = clock + 1200; fire("ENCOUNTER_END", 2940, "Thermaplugg", 1, 5, 1)
check("12) Lauf geschafft:", h2.done, clock)
fire("ENCOUNTER_END", 2768, "Grubbis", 1, 5, 1); fire("ENCOUNTER_END", 2768, "Grubbis", 1, 5, 1)
local n, of = E.History.Progress(h2.runs[1])
check("12b) Fortschritt aus den Spieldaten:", n .. "/" .. of, "2/11")
clock = clock + 60; party = { "A" }; fire("GROUP_ROSTER_UPDATE")
clock = clock + 1200; party = {}; fire("GROUP_ROSTER_UPDATE")
E.History.detail = h2; E.History.Update()
local early2
for _, fr in ipairs(frames) do
  local m = rawget(fr, "member")
  if m and m.name == "B" and fr:IsShown() and rawget(fr, "kind") == "member" then early2 = (txt(fr, "text") or ""):find("ging nach") ~= nil end
end
E.History.Back()
check("13) B ging nach dem Boss: kein Vermerk:", early2, false)
print("== Endboss lernen ohne Journal")
db.finalBoss = {}
party = { "A", "B" }; fire("GROUP_ROSTER_UPDATE")
INSTANCE = "Dalaran"; fire("PLAYER_ENTERING_WORLD", false, false)
clock = clock + 600; fire("ENCOUNTER_END", 3001, "Archmage", 1, 5, 1)
clock = clock + 600; fire("ENCOUNTER_END", 3002, "Kel", 1, 5, 0)
clock = clock + 120; fire("ENCOUNTER_END", 3002, "Kel", 1, 5, 1)
clock = clock + 300; INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
check("14) gelernt:", db.finalBoss[90] and db.finalBoss[90].Kel, 1)
check("15) als Endboss:", E.FinalBossName(90), "Kel")
party = {}; fire("GROUP_ROSTER_UPDATE")
party = { "C" }; fire("GROUP_ROSTER_UPDATE")
local h3 = AutoGroupFinderCharDB.history[1]
INSTANCE = "Dalaran"; fire("PLAYER_ENTERING_WORLD", false, false)
clock = clock + 900; fire("ENCOUNTER_END", 3002, "Kel", 1, 5, 1)
check("16) nächster Lauf erkennt das Ende:", h3.done, clock)
check("17) Lauf gilt als fertig:", E.RunDone(), true)
print("== Abbruch nach Wipe lernt nichts")
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
party = {}; fire("GROUP_ROSTER_UPDATE")
party = { "D" }; fire("GROUP_ROSTER_UPDATE")
INSTANCE = "Dalaran"; fire("PLAYER_ENTERING_WORLD", false, false)
fire("ENCOUNTER_END", 3001, "Archmage", 1, 5, 1); fire("ENCOUNTER_END", 3002, "Kel", 1, 5, 0)
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
check("18) Archmage nicht gelernt:", db.finalBoss[90].Archmage, nil)
print("== Kein leerer Eintrag")
party = {}; fire("GROUP_ROSTER_UPDATE")
local before = #AutoGroupFinderCharDB.history
local wasInGroup = IsInGroup
IsInGroup = function() return true end -- Gruppe da, aber noch niemand sonst
fire("GROUP_ROSTER_UPDATE")
check("19) ohne Mitspieler kein Eintrag:", #AutoGroupFinderCharDB.history, before)
IsInGroup = wasInGroup
local kinds = {}
for _, fr in ipairs(frames) do
  local k, t = rawget(fr, "kind"), rawget(fr, "title")
  if k and t and rawget(fr, "_shown") and rawget(t, "_shown") ~= false then kinds[#kinds + 1] = tostring(rawget(k, "_shown")) end
end
check("20) Dungeon-Einträge mit Symbol:", kinds[1], "true")
print("== Suche im Verlauf")
LOCALIZED_CLASS_NAMES_MALE = { SHAMAN = "Schamane", PRIEST = "Priester" }
local ent = { name = "City of Dalaran", members = { { name = "Rasa Las-Realm", class = "SHAMAN", role = "HEALER" }, { name = "Bob", class = "PRIEST" } } }
check("21) dala:", E.History.Matches(ent, "dala"), true)
check("22) sham (Klasse):", E.History.Matches(ent, "sham"), true)
check("23) pries:", E.History.Matches(ent, "pries"), true)
check("24) schama (übersetzt):", E.History.Matches(ent, "schama"), true)
check("25) zwei Wörter:", E.History.Matches(ent, "dala BOB"), true)
check("26) passt nicht:", E.History.Matches(ent, "dala warrior"), false)
check("27) Heiler als Rolle:", E.History.Matches(ent, "heil"), true)
time = os.time
local nowReal = os.time()
check("28) heute:", E.History.When(nowReal):match("^Heute %d%d:%d%d$") ~= nil, true)
check("29) gestern:", E.History.When(nowReal - 86400):match("^Gestern") ~= nil, true)
check("30) älter: Tag zuerst:", E.History.When(nowReal - 5 * 86400):match("^%d%d%.%d%d%. ") ~= nil, true)
E.History.search:SetText("zzz")
print("== Kurze Gruppe (Layer-Wechsel) fällt weg")
time = function() return clock end
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
party = {}; fire("GROUP_ROSTER_UPDATE")
local n0 = #AutoGroupFinderCharDB.history
party = { "Layerbot" }; fire("GROUP_ROSTER_UPDATE")
check("31) erst angelegt:", #AutoGroupFinderCharDB.history, n0 + 1)
clock = clock + 60; party = {}; fire("GROUP_ROSTER_UPDATE")
check("32) nach 1 Min wieder weg:", #AutoGroupFinderCharDB.history, n0)
party = { "Quester" }; fire("GROUP_ROSTER_UPDATE")
clock = clock + 900; party = {}; fire("GROUP_ROSTER_UPDATE")
check("33) längere Gruppe bleibt:", #AutoGroupFinderCharDB.history, n0 + 1)
time = os.time
print("== Schadensmesser (Kampf-Abschnitte) und Beute")
time = function() return clock end
local sessions = {}
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true end,
  GetAvailableCombatSessions = function()
    local l = {}
    for id in pairs(sessions) do l[#l + 1] = { sessionID = id, name = "Kampf " .. id } end
    table.sort(l, function(a, b) return a.sessionID < b.sessionID end)
    return l
  end,
  GetCombatSessionFromID = function(id, kind) return { combatSources = (sessions[id] or {})[kind] or {} } end,
}
local function fight(id, dmg, heal, deaths) sessions[id] = { [0] = dmg or {}, [2] = heal or {}, [9] = deaths or {} } end
local function src(n, c, a) return { name = n, classFilename = c, totalAmount = a } end
local function flush() local t = timers; for k = #t, 1, -1 do local x = table.remove(t, k); x.f() end end
C_LootHistory = { GetSortedInfoForDrop = function(enc, key)
  return { itemHyperlink = "[Gnomish Gear]", winner = { playerName = "Tank", playerClass = "WARRIOR" } } end }
fight(1, { src("Tank", "WARRIOR", 1000) }) -- vor dem Dungeon
party = {}; fire("GROUP_ROSTER_UPDATE"); INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
party = { "Tank", "Heal" }; fire("GROUP_ROSTER_UPDATE")
local hm = AutoGroupFinderCharDB.history[1]
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
fight(2, { src("Tank", "WARRIOR", 5000), src("Heal", "PRIEST", 300) }, { src("Heal", "PRIEST", 8000) })
fire("PLAYER_REGEN_ENABLED"); flush()
sessions = {}; fire("DAMAGE_METER_RESET") -- Spieler setzt den Messer zurück, Nummern beginnen neu
fight(1, { src("Tank", "WARRIOR", 2000) }, {}, { src("Heal", "PRIEST", 1) })
fire("PLAYER_REGEN_ENABLED"); flush()
fire("ENCOUNTER_END", 2940, "Thermaplugg", 1, 5, 1)
fire("LOOT_HISTORY_UPDATE_DROP", 2940, 1)
clock = clock + 60; INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
local m = hm.runs[1].meter
check("34) nur Kämpfe im Dungeon, über Zurücksetzen hinweg:", m.Tank.d, 5000 + 2000)
check("35) Heilung:", m.Heal.h, 8000)
check("36) Tod:", m.Heal.x, 1)
check("37) Beute beim Boss:", hm.runs[1].loot["2940:1"].who, "Tank")
local nf = 0; for _ in pairs(hm.runs[1].fights) do nf = nf + 1 end
check("38) Kämpfe einzeln, auch nach dem Zurücksetzen:", nf, 2)

print("== Zwei Läufe, Fremde im Messer, Würfe, Ablesen erst draußen")
clock = clock + 7 * 3600 -- sonst setzt der Verlauf die letzte Gruppe fort
sessions = {}
fight(5, { src("Tank", "WARRIOR", 1000), src("Stranger", "ROGUE", 500) }) -- draußen
party = {}; fire("GROUP_ROSTER_UPDATE"); INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
party = { "Tank", "Heal" }; fire("GROUP_ROSTER_UPDATE")
local h4 = AutoGroupFinderCharDB.history[1]
fire("PLAYER_LEAVING_WORLD") -- draußen: letzter Abschnitt vor dem Dungeon
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
check("39) Anfang nach dem letzten Kampf draußen:", h4.runs[1].meterFrom, 6)
fight(6, { src("Tank", "WARRIOR", 3000), src("Stranger", "ROGUE", 400) })
issecretvalue = function(v) return v == "Tank" or v == "Stranger" end -- noch geheim
fire("PLAYER_REGEN_ENABLED"); flush()
issecretvalue = nil
clock = clock + 600
fire("ENCOUNTER_END", 2940, "Thermaplugg", 1, 5, 1)
C_LootHistory.GetSortedInfoForDrop = function() return { itemHyperlink = "[Gear]",
  winner = { playerName = "Heal", playerClass = "PRIEST", state = 0, roll = 87 },
  rollInfos = { { playerName = "Heal", playerClass = "PRIEST", state = 0, roll = 87 },
    { playerName = "Tank", playerClass = "WARRIOR", state = 3, roll = 50 }, { playerName = "Zed", playerClass = "MAGE", state = 4 } } } end
fire("LOOT_HISTORY_UPDATE_DROP", 2940, 7)
local drop = h4.runs[1].loot["2940:7"]
check("40) Wurf des Gewinners:", drop.s .. ":" .. drop.r, "0:87")
check("41) Würfe ohne „kein Wurf“:", #drop.rolls, 2)
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false) -- raus nach Wipe …
check("41b) erster Lauf nach dem Geheimen nachgelesen:", h4.runs[1].meter.Tank.d, 3000)
fire("PLAYER_LEAVING_WORLD")
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false) -- … und wieder rein
fire("ENCOUNTER_END", 2768, "Grubbis", 1, 5, 1)
fight(7, { src("Tank", "WARRIOR", 2000) })
issecretvalue = function(v) return v == "Tank" end
clock = clock + 600; party = {}; fire("GROUP_ROSTER_UPDATE") -- Gruppe löst sich im Dungeon auf
issecretvalue = nil
check("42) im Dungeon noch offen:", h4.runs[2].meterPending, true)
fight(8, { src("Tank", "WARRIOR", 9999) }) -- danach allein weitergekämpft: zählt nicht
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
check("43) draußen abgelesen:", h4.runs[2].meter.Tank and h4.runs[2].meter.Tank.d, 2000)
check("44) danach fertig:", h4.runs[2].meterPending, nil)
local kills, total = E.History.EntryProgress(h4)
check("45) Bosse über beide Läufe:", kills .. "/" .. total, "2/11")
E.History.detail = h4; E.History.Update()
local stranger, tankRow, rollText = false, false, nil
for _, fr in ipairs(frames) do
  if fr:IsShown() and rawget(fr, "kind") then
    local t = txt(fr, "text") or ""
    if t:find("Stranger") then stranger = true end
    if rawget(fr, "kind") == "member" and t:find("Tank") and (txt(fr, "c3") or "") ~= "" then tankRow = true end
    if rawget(fr, "link") == "[Gear]" then rollText = plain(txt(fr, "c1")) end
  end
end
check("46) Fremde nicht im Schadensmesser:", stranger, false)
check("47) Schaden oben bei der Gruppe:", tankRow, true)
check("48) Gewinner mit Wurf:", rollText, "Heal  Bedarf 87")
E.History.Back()

print("== Tod: Geisterlauf bleibt derselbe Lauf; Kämpfe einzeln")
time = function() return clock end
clock = clock + 7 * 3600
sessions = {}
party = {}; fire("GROUP_ROSTER_UPDATE"); INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
fight(20, { src("Tank", "WARRIOR", 100) })
party = { "Tank", "Heal" }; fire("GROUP_ROSTER_UPDATE")
local h5 = AutoGroupFinderCharDB.history[1]
fire("PLAYER_LEAVING_WORLD"); INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
clock = clock + 60; fight(21, { src("Tank", "WARRIOR", 3000), src("Heal", "PRIEST", 500) }); fire("PLAYER_REGEN_ENABLED"); flush()
clock = clock + 60; fight(22, { src("Tank", "WARRIOR", 4000) }, {}, { src("Heal", "PRIEST", 1) }); fire("PLAYER_REGEN_ENABLED"); flush()
clock = clock + 60; fight(23, { src("Tank", "WARRIOR", 9000), src("Heal", "PRIEST", 1000) })
fire("ENCOUNTER_END", 2768, "Grubbis", 1, 5, 1); fire("PLAYER_REGEN_ENABLED"); flush()
UnitIsDeadOrGhost = function() return true end -- gestorben, freigelassen
clock = clock + 30; INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
UnitIsDeadOrGhost = function() return false end
clock = clock + 120; fire("PLAYER_LEAVING_WORLD"); INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
check("49) derselbe Lauf nach dem Geisterlauf:", #h5.runs, 1)
check("50) Ausflug als Tod vermerkt:", h5.runs[1].gaps and h5.runs[1].gaps[1].dead, true)
clock = clock + 60; fight(24, { src("Tank", "WARRIOR", 1000) }); fire("PLAYER_REGEN_ENABLED"); flush()
local nf5 = 0; for _ in pairs(h5.runs[1].fights) do nf5 = nf5 + 1 end
check("51) Kämpfe einzeln:", nf5, 4)
local b5 = h5.runs[1].bosses[1]
check("52) Boss mit seinem Kampf:", b5.sid and h5.runs[1].fights[b5.sid].m.Tank.d, 9000)
E.History.detail = h5; E.History.Update()
local rowsSeen = {}
for _, fr in ipairs(frames) do
  local k = rawget(fr, "kind")
  if fr:IsShown() and (k == "fight" or k == "event") then
    rowsSeen[#rowsSeen + 1] = { o = rawget(fr, "order"), t = plain(txt(fr, "text")), c1 = txt(fr, "c1") }
  end
end
table.sort(rowsSeen, function(a, b) return a.o < b.o end)
local seq = {}
for _, r in ipairs(rowsSeen) do seq[#seq + 1] = r.t or "" end
check("53) Ablauf:", table.concat(seq, " | "), "Betreten | Trash (2)  † Heal | S Grubbis | † Gestorben | Wieder betreten | Trash (1)")
local function memberOrder()
  local l = {}
  for _, fr in ipairs(frames) do
    if fr:IsShown() and rawget(fr, "kind") == "member" then l[#l + 1] = { o = rawget(fr, "order"), t = plain(txt(fr, "text")):match("^(%a+)") } end
  end
  table.sort(l, function(a, b) return a.o < b.o end)
  local out = {}
  for _, x in ipairs(l) do out[#out + 1] = x.t end
  return table.concat(out, ",")
end
check("57) standardmäßig nach Schaden:", memberOrder(), "Tank,Heal,Me")
E.History.sort = "x"; E.History.Update()
check("58) nach Toden sortiert:", memberOrder(), "Heal,Me,Tank")
E.History.sort = "join"; E.History.Update()
check("59) wie beigetreten:", memberOrder(), "Me,Tank,Heal")
E.History.sort = nil
E.History.Back()

print("== Alte, beim Tod getrennte Läufe zusammenführen")
local old = { runs = {
  { name = "Gnomeregan", map = 90, enter = 1000, exit = 2000, kills = 1, wipes = 1,
    bosses = { { id = 2768, n = "Grubbis", ok = true, t = 1500 }, { id = 2769, n = "Viscous", t = 1990 } },
    meter = { Tank = { d = 100, c = "WARRIOR" }, Me = { d = 50 } }, loot = { ["2768:1"] = { enc = 2768 } } },
  { name = "Gnomeregan", map = 90, enter = 2130, exit = 2900, kills = 2, wipes = 0,
    bosses = { { id = 2769, n = "Viscous", ok = true, t = 2400 }, { id = 2940, n = "Thermaplugg", ok = true, t = 2800 } },
    meter = { Me = { d = 20 } } },
  { name = "Gnomeregan", map = 90, enter = 3000, exit = 3500, kills = 0, wipes = 0, bosses = {} }, -- nach dem Endboss: neuer Lauf
} }
E.History.MergeSplitRuns(old)
check("54) zwei Teile zu einem Lauf:", #old.runs, 2)
check("55) Ausflug als Tod (nach Wipe):", old.runs[1].gaps[1].dead, true)
check("56) Bosse und Schaden zusammen:", #old.runs[1].bosses .. ":" .. old.runs[1].meter.Me.d .. ":" .. old.runs[1].exit, "4:70:2900")
old.members = { { name = "Tank", role = "TANK" } }; old.t = 900
table.insert(AutoGroupFinderCharDB.history, 1, old)
E.History.detail = old; E.History.Update()
local seq2 = {}
for _, fr in ipairs(frames) do
  local k = rawget(fr, "kind")
  if fr:IsShown() and k == "event" then seq2[#seq2 + 1] = { o = rawget(fr, "order"), t = plain(txt(fr, "text")) } end
end
table.sort(seq2, function(a, b) return a.o < b.o end)
local s2 = {}
for _, x in ipairs(seq2) do s2[#s2 + 1] = x.t end
check("60) nach dem Wipe kein doppelter Tod:", table.concat(s2, " | "):match("Wipe: Viscous | Wieder betreten") ~= nil, true)
E.History.Back()
old.runs[1].loot["0:5"] = { enc = 0, t = 1200, link = "[Trash Item]", who = "Tank" }
E.History.detail = old; E.History.Update()
local all = {}
for _, fr in ipairs(frames) do
  local k = rawget(fr, "kind")
  if fr:IsShown() and (k == "event" or k == "loot" or k == "fight") then all[#all + 1] = { o = rawget(fr, "order"), t = plain(txt(fr, "text")) } end
end
table.sort(all, function(a, b) return a.o < b.o end)
local s3 = {}
for _, x in ipairs(all) do s3[#s3 + 1] = x.t end
check("61) Trash-Beute an ihrer Stelle:", table.concat(s3, " | "):match("^Betreten | Trash%-Beute | %[Trash Item%] | S Grubbis") ~= nil, true)
E.History.Back()

print("== Allein im Dungeon: Erfahrung, Gold, Beute, Haltbarkeit, Quests")
time = function() return clock end
clock = clock + 7 * 3600
sessions = {}
local xp, money, bags, dura, complete = 100, 5000, { [1] = { itemID = 11, stackCount = 1, quality = 2, hyperlink = "[Sword]" } }, 100, {}
UnitXP = function() return xp end
UnitXPMax = function() return 1000 end
GetMoney = function() return money end
GetInventoryItemDurability = function(slot) if slot == 1 then return dura, 100 end end
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerItemInfo = function(bag, slot) return bags[slot] end }
C_QuestLog = C_QuestLog or {}
C_QuestLog.GetNumQuestLogEntries = function() return 1 end
C_QuestLog.GetInfo = function() return { questID = 77, title = "Gnomer Quest" } end
C_QuestLog.IsComplete = function(id) return complete[id] or false end
party = {}; fire("GROUP_ROSTER_UPDATE"); INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
local before = #AutoGroupFinderCharDB.history
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false)
local solo = AutoGroupFinderCharDB.history[1]
check("62) allein im Dungeon: eigener Eintrag:", #AutoGroupFinderCharDB.history == before + 1 and solo.solo, true)
xp = 900; fire("PLAYER_XP_UPDATE")
xp = 200; UnitLevel = function() return 35 end; fire("PLAYER_XP_UPDATE") -- Stufenaufstieg
money = 7500; fire("PLAYER_MONEY")
bags[2] = { itemID = 12, stackCount = 3, quality = 1, hyperlink = "[Gnome Bits]" }
bags[3] = { itemID = 13, stackCount = 1, quality = 0, hyperlink = "[Grey Junk]" }
fire("BAG_UPDATE_DELAYED")
complete[77] = true
fight(30, { src("Me", "MAGE", 500) })
fire("ENCOUNTER_END", 2768, "Grubbis", 1, 1, 1)
dura = 80
clock = clock + 900; INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
UnitLevel = function() return 34 end
local sr = solo.runs[1]
check("63) Erfahrung über den Aufstieg:", sr.xp, 800 + 300)
check("64) Stufe:", sr.lvlFrom .. "→" .. sr.lvlTo, "34→35")
check("65) Gold:", sr.money, 2500)
check("66) eigene Beute ohne Graues:", sr.mine[12] and sr.mine[12].n or 0, 3)
check("67) Graues nicht:", sr.mine[13], nil)
check("68) Haltbarkeit:", sr.durStart .. "→" .. sr.durEnd, "100→80")
check("69) Quest erledigt:", sr.quests and sr.quests[77], "Gnomer Quest")
check("70) Eintrag bleibt nach dem Verlassen:", AutoGroupFinderCharDB.history[1], solo)
E.History.detail = solo; E.History.Update()
local icons = 0
for _, fr in ipairs(frames) do if fr:IsShown() and rawget(fr, "kind") == "icons" then icons = icons + 1 end end
check("70b) Für dich mit Beute-Symbolen:", icons, 1)
E.History.Back()
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false); clock = clock + 30
INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
print("== Instanzen pro Stunde")
local n = E.History.InstanceCount()
check("71) wieder rein gilt als dieselbe Instanz:", n >= 1, true)
local n0 = n
clock = clock + 3600 * 2
INSTANCE = "Gnomeregan"; fire("PLAYER_ENTERING_WORLD", false, false); INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
INSTANCE = "Scarlet Library"; fire("PLAYER_ENTERING_WORLD", false, false); INSTANCE = nil; fire("PLAYER_ENTERING_WORLD", false, false)
check("72) zwei neue in der letzten Stunde:", (E.History.InstanceCount()), 2)
fire("UI_ERROR_MESSAGE", 1, TRANSFER_ABORT_TOO_MANY_INSTANCES or "You have entered too many instances recently.")
TRANSFER_ABORT_TOO_MANY_INSTANCES = TRANSFER_ABORT_TOO_MANY_INSTANCES or "You have entered too many instances recently."
fire("UI_ERROR_MESSAGE", 1, TRANSFER_ABORT_TOO_MANY_INSTANCES)
check("73) Grenze gelernt:", AutoGroupFinderDB.instanceLimit, 2)
print("== Zusammen gespielt, Statistik, Todesbericht")
check("74) Tank schon mehrfach dabei:", E.History.Together("Tank") >= 3, true)
check("75) Fremder nie:", E.History.Together("Nobody"), 0)
local runsDone = E.History.DungeonStats(90)
check("76) Gnomeregan-Läufe mit Endboss gezählt:", runsDone >= 1, true)
local f6 = { t = 1, m = { Tank = { d = 10, x = 1, r = 4242, c = "WARRIOR" } } }
local h6 = { t = clock, name = "Gnomeregan", members = { { name = "Tank" } }, runs = { { name = "Gnomeregan", map = 90, enter = clock - 60,
  bosses = { { id = 2768, n = "Grubbis", ok = true, t = clock - 30, sid = 1 } }, fights = { [1] = f6 }, kills = 1, wipes = 0 } } }
table.insert(AutoGroupFinderCharDB.history, 1, h6)
E.History.detail = h6; E.History.Update()
local recaps
for _, fr in ipairs(frames) do if fr:IsShown() and rawget(fr, "kind") == "fight" then recaps = rawget(fr, "recaps") end end
check("77) Todesbericht am Kampf:", recaps and recaps[1], 4242)
E.History.Back()
time = os.time

