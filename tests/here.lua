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
-- Schnellstart am Dungeon und Klick aufs Rollensymbol zum Anvisieren
local MAPS = { [10] = 189, [11] = 90, [12] = 36, [13] = 47 }
local NAMES = { [189] = "Scarlet Monastery", [90] = "Gnomeregan", [36] = "The Deadmines", [47] = "Razorfen Kraul" }
local origInfo = C_LFGList.GetActivityInfoTable
C_LFGList.GetActivityInfoTable = function(id) local a = origInfo(id) if a then a.mapID = MAPS[id] end return a end
local SUB, INSIDE = "Gnomeregan", false
GetRealZoneText = function(mapID) if mapID then return NAMES[mapID] or "" end return INSIDE and "Gnomeregan" or "Dun Morogh" end
GetSubZoneText = function() return SUB end
IsInInstance = function() return INSIDE end
InCombatLockdown = function() return COMBAT end
tContains = tContains or function(t, v) for _, x in ipairs(t) do if x == v then return true end end end
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
local db, E = AutoGroupFinderDB, ns.env
rawset(E.targetBtn, "SetAttribute", function(self, k, v) if k == "macrotext" then rawset(self, "_macro", v) end end)
local function check(label, got, want)
  got, want = tostring(got), tostring(want)
  print(label, got, got == want and "ok" or ("FEHLER, erwartet " .. want))
  if got ~= want then error(label .. ": " .. got .. " statt " .. want) end
end
local function picked() local _, ids = E.SearchActivities() local t = {} for i, id in ipairs(ids) do t[i] = id end table.sort(t) return table.concat(t, ",") end

check("Vor Gnomeregan erkannt:", E.state.here and E.state.here.name, "Gnomeregan")
check("Aktivitäten dazu:", E.state.here and table.concat(E.state.here.ids, ","), "11")
db.view = "categories"; AutoGroupFinderFrame:Show(); E.UpdateUI()
check("Karte sichtbar:", E.hereCard:IsShown(), true)
AutoGroupFinderCharDB.activities[10], AutoGroupFinderCharDB.activities[12] = true, true
db.playstyle = 0
rawget(E.hereCard, "_scripts").OnClick(E.hereCard)
check("Ohne Spielstil keine Suche:", E.state.queued, false)
check("Nur Gnomeregan gewählt:", picked(), "11")
check("Auswahl offen:", db.view, "activities")
db.playstyle = 2
rawget(E.hereCard, "_scripts").OnClick(E.hereCard)
check("Mit Spielstil: Suche läuft:", E.state.queued, true)
E.StopQueue()
SUB = "Kharanos"; fire("ZONE_CHANGED")
check("Woanders keine Karte:", E.state.here, nil)
INSIDE = true; SUB = ""; fire("ZONE_CHANGED_NEW_AREA")
check("Drinnen erkannt:", E.state.here and E.state.here.name, "Gnomeregan")
db.view = "activities"; AutoGroupFinderFrame:Show(); E.UpdateUI()
check("Leiste über der Dungeon-Liste:", E.hereBar:IsShown(), true)
SlashCmdList.AUTOGROUPFINDER("test here")
db.hereSuggest = false; db.view = "categories"; AutoGroupFinderFrame:Show(); E.UpdateUI()
check("Leiste weg bei Option aus:", (function() db.view = "activities"; E.UpdateUI() return E.hereBar:IsShown() end)(), false)
check("Option aus, Karte weg:", E.hereCard:IsShown(), false)

print("== Anvisieren")
local row = E.ListRow(1)
row.cand = { name = "Tanky-Realm", key = "Tanky-Realm" }
row.avatar.IsVisible = function() return true end
row.avatar.GetCenter = function() return 100, 200 end
row.avatar.GetWidth = function() return 40 end
row.avatar.GetHeight = function() return 40 end
UIParent.GetEffectiveScale = function() return 1 end
row.avatar.GetEffectiveScale = function() return 1 end
E.ShowTargetButton(row)
check("Makro gesetzt:", rawget(E.targetBtn, "_macro"), "/target Tanky-Realm")
COMBAT = true
row.cand = { name = "Other", key = "Other" }
E.ShowTargetButton(row)
check("Im Kampf unverändert:", rawget(E.targetBtn, "_macro"), "/target Tanky-Realm")

print("== Stufe 10: nichts passt")
E.CloseWindow()
local was = UnitLevel
UnitLevel = function() return 10 end
for k in pairs(AutoGroupFinderCharDB.activities) do AutoGroupFinderCharDB.activities[k] = nil end
db.allLevels, db.view = false, "activities"
E.state.treeVersion = (E.state.treeVersion or 0) + 1
AutoGroupFinderFrame:Show(); E.UpdateUI()
check("Leerzustand nennt den nächsten Dungeon:", rawget(E.emptyText, "_text"), E.T.EMPTY_NEXT:format(17, "Deadmines"))
AutoGroupFinderCharDB.activities[10] = true
E.state.treeVersion = E.state.treeVersion + 1; E.UpdateUI()
check("Eigene Auswahl bleibt sichtbar:", rawget(E.emptyText, "_text"), "")
UnitLevel = was
