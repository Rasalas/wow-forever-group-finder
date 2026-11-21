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
-- Gruppenübersicht: wer ist wo, Wegpunkt, Stufe, Bewertungen
local MAPS = { [10] = 189, [11] = 90 }
local origInfo = C_LFGList.GetActivityInfoTable
C_LFGList.GetActivityInfoTable = function(id) local a = origInfo(id) if a then a.mapID = MAPS[id] end return a end
GetRealZoneText = function(mapID) if mapID == 90 then return "Gnomeregan" end if mapID == 189 then return "Scarlet Monastery" end return "Dun Morogh" end
local where = { player = 1426, party1 = 900, party2 = 1455 }
local names = { [1426] = "Dun Morogh", [900] = "Gnomeregan", [1455] = "Ironforge" }
local waypoint
C_Map = { GetBestMapForUnit = function(u) return where[u] end, GetMapInfo = function(id) return { name = names[id] } end,
  SetUserWaypoint = function(p) waypoint = p end }
UiMapPoint = { CreateFromVector2D = function(ui, pos) return ui .. "@" .. pos.x .. "," .. pos.y end }
C_EncounterJournal = { GetInstanceForGameMap = function(m) return m == 90 and 231 end,
  GetDungeonEntrancesForMap = function(ui) if ui == 1426 then return { { journalInstanceID = 231, name = "Gnomeregan", position = { x = 0.3, y = 0.4 } } } end return {} end }
UnitClass = function() return "Mage", "MAGE" end
local lvl = { player = 34, party1 = 28, party2 = 33 }
UnitLevel = function(u) return lvl[u] or 30 end
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN")
local db, E = AutoGroupFinderDB, ns.env
local function check(label, got, want)
  got, want = tostring(got), tostring(want)
  print(label, got, got == want and "ok" or ("FEHLER, erwartet " .. want))
  if got ~= want then error(label .. ": " .. got .. " statt " .. want) end
end
AutoGroupFinderCharDB.groupActivityID = 11
party = { "Gnomy", "Dwarfy" }
fire("GROUP_ROSTER_UPDATE")
db.page = 4
AutoGroupFinderFrame:Show(); E.UpdateUI()
check("Gruppenseite offen:", db.page, 4)
E.GroupPage.Update()
-- Zeilen über ihre Texte prüfen
local function rowText(i) local r = E.GroupPage.rows[i] return rawget(r.place, "_text"), rawget(r.level, "_text") end
local p1, l1 = rowText(1)
local p2, l2 = rowText(2)
local p3 = rowText(3)
check("Ich: Zone des Eingangs:", p1, "Dun Morogh")
check("Gnomy: am Dungeon:", p2:find(E.T.GROUP_HERE, 1, true) ~= nil, true)
check("Dwarfy: anderswo:", p3, "Ironforge")
check("Unter der Stufe gelb:", l2:find("ffd100", 1, true) ~= nil, true)
check("Zählung:", rawget(E.GroupPage.status, "_text"), E.T.GROUP_AT_DUNGEON:format(1, 3))
E.SetEntranceWaypoint(11)
check("Wegpunkt am Eingang gesetzt:", waypoint, "1426@0.3,0.4")

print("== Bewertungen")
E.Rate("Gnomy", 1)
check("Gerne wieder gespeichert:", db.ratings.Gnomy and db.ratings.Gnomy.v, 1)
E.Rate("Gnomy", 1)
check("Nochmal klicken entfernt:", db.ratings.Gnomy, nil)
party = {}; fire("GROUP_ROSTER_UPDATE")
db.playstyle, db.view = 2, "activities"
db.ratings.Gut = { v = 1, t = 0 }
db.ratings.Schlecht = { v = -1, t = 0 }
res(1, "Neu", { dps = true }, 1, { generalPlaystyle = 2 })
res(2, "Gut", { dps = true }, 50, { generalPlaystyle = 2 })
res(3, "Schlecht", { dps = true }, 2, { generalPlaystyle = 2 })
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local order = {}
for _, c in ipairs(E.candidates) do order[#order + 1] = c.name end
check("Gemochte zuerst, „nicht wieder“ fehlt:", table.concat(order, ","), "Gut,Neu")

print("== Gruppen, die dich brauchen (nur Tank/Heiler)")
local told, typed = {}, {}
ChatFrame_SendTell = function(n) told[#told + 1] = n end
ChatEdit_InsertLink = function(t) typed[#typed + 1] = t return true end
C_LFGList.GetSearchResultMemberCounts = function(id) return results[id].counts end
for k in pairs(results) do results[k] = nil end
res(5, "Anfuehrer", { dps = true }, 30, { numMembers = 3, counts = { TANK = 1, HEALER = 0, DAMAGER = 2 } })
res(6, "Voll", { dps = true }, 30, { numMembers = 4, counts = { TANK = 1, HEALER = 1, DAMAGER = 2 } })
local myRoles = AutoGroupFinderCharDB.myRoles
AutoGroupFinderCharDB.myRoles = { DAMAGER = true }
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("Als Schaden keine Gruppenvorschläge:", #E.groupOffers, 0)
AutoGroupFinderCharDB.myRoles = { HEALER = true, DAMAGER = true }
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("Als Heiler: Gruppe ohne Heiler:", #E.groupOffers == 1 and E.groupOffers[1].name, "Anfuehrer")
check("Rolle Heiler:", E.groupOffers[1].role, "HEALER")
E.AskGroup(E.groupOffers[1])
check("Flüstern an den Anführer geöffnet:", told[1], "Anfuehrer")
check("Text vorausgefüllt, nicht gesendet:", typed[1] ~= nil and typed[1]:find("Scarlet Library", 1, true) ~= nil, true)
E.AskGroup(E.groupOffers[1])
check("Zweite Anfrage gesperrt:", #told, 1)
party = { "Jemand" }; fire("GROUP_ROSTER_UPDATE"); fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("In einer Gruppe keine Vorschläge:", #E.groupOffers, 0)
party = {}; fire("GROUP_ROSTER_UPDATE")
AutoGroupFinderCharDB.myRoles = myRoles

print("== Selbst eingeladen, Rolle unbekannt")
E.pending["Alpha Skullcrusher"] = { t = 0, confirmed = true, manual = true }
local lines = table.concat(E.StatusLines(), " | ")
check("Tooltip ohne Fehler, nur Name:", lines:find("Alpha Skullcrusher", 1, true) ~= nil and not lines:find("Alpha Skullcrusher (", 1, true), true)
E.pending["Alpha Skullcrusher"] = nil

print("== Klassen mischen (ich bin Magier)")
for k in pairs(results) do results[k] = nil end
db.ratings = {}
AutoGroupFinderCharDB.myRoles = { DAMAGER = true }
local function dd(id, name, class, age) res(id, name, { dps = true }, age, { generalPlaystyle = 2 }) results[id].p.classFilename = class end
dd(11, "Magier1", "MAGE", 1)
dd(12, "Hexer1", "WARLOCK", 2)
dd(13, "Jaeger1", "HUNTER", 50)
dd(14, "Druide1", "DRUID", 60)
local function order()
  fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
  local o = {}
  for _, c in ipairs(E.candidates) do o[#o + 1] = c.name end
  return table.concat(o, ",")
end
db.mixClasses = false
check("Aus: Neueste zuerst:", order(), "Magier1,Hexer1,Jaeger1,Druide1")
db.mixClasses = true
check("An: fremde Klasse und Rüstung vor Stoff:", order(), "Jaeger1,Druide1,Hexer1,Magier1")
E.pending["Jaeger1"] = { role = "DAMAGER", t = 0, confirmed = true, c = { class = "HUNTER" } }
check("Jäger eingeladen: Druide vor Stoffträgern:", order(), "Druide1,Hexer1,Magier1")
E.pending["Jaeger1"] = nil

print("== Für welchen Dungeon passt wer?")
for k in pairs(results) do results[k] = nil end
db.activities[10], db.activities[11] = true, true
res(21, "Bibli", { dps = true }, 1, { generalPlaystyle = 2, activityIDs = { 10 } })
res(22, "Beide", { dps = true }, 2, { generalPlaystyle = 2, activityIDs = { 10, 11 } })
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local byName = {}
for _, c in ipairs(E.candidates) do byName[c.name] = c end
check("Liste zeigt nur eigene passende Dungeons:", byName.Beide and byName.Beide.forNames, "Scarlet Library, Gnomeregan")
AutoGroupFinderCharDB.memberFor = { Bibli = { 10 }, Beide = { 10, 11 } }
party = { "Bibli", "Beide" }; fire("GROUP_ROSTER_UPDATE")
local fit, known = E.GroupFit()
check("Bibliothek passt für alle:", fit[1].name .. " " .. fit[1].n .. "/" .. known, "Scarlet Library 2/2")
check("Wegpunkt-Dungeon ist der häufigste:", E.GroupActivity(), 10)
party = {}; fire("GROUP_ROSTER_UPDATE")
check("Ohne Gruppe vergessen:", AutoGroupFinderCharDB.memberFor, nil)
print("== Rückfall: Eintrag aus der Suche")
E.state.listings.Fremd = { numMembers = 1, activityIDs = { 11 }, seenAt = 0 }
party = { "Fremd" }; fire("GROUP_ROSTER_UPDATE")
local fit2 = E.GroupFit()
check("Ohne Einladung durchs Add-on: aus dem Eintrag:", fit2[1] and fit2[1].name, "Gnomeregan")
party = {}; fire("GROUP_ROSTER_UPDATE")
