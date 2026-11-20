unpack = unpack or table.unpack; math.atan2 = math.atan2 or math.atan; tinsert = table.insert
hooksecurefunc = function(t, k, f) if type(t) == "string" then t, k, f = _G, t, k end local o = t[k]; rawset(t, k, function(...) local r = { o(...) }; f(...); return unpack(r) end) end
strsplit = function(sep, s) local t = {} for part in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = part end return (unpack or table.unpack)(t) end
GetRealZoneText = function() return ZONE or "Ironforge" end
date = os.date; GetInstanceInfo = function() return INSTANCE or "Scarlet Library" end; UnitClass = function() return "Mage", "MAGE" end; IsInInstance = function() return INSTANCE ~= nil, INSTANCE and "party" or "none" end; UnitLevel = UnitLevel or function() return 34 end
time = os.time
local now = 100
local NUM = { GetStringHeight = 14, GetFrameLevel = 1, GetWidth = 140, GetHeight = 140, GetStringWidth = 50, GetEffectiveScale = 1, GetVerticalScrollRange = 0, GetVerticalScroll = 0 }
local function dummy()
  return setmetatable({}, { __index = function(t, k)
    if ({ checkButton = 1, Icon = 1, ScrollBar = 1, CloseButton = 1, SetCustomOnMouseUpHandler = 1, SetupMenu = 1, cycle = 1, SetChecked = (rawget(t, "_isTab") and 1 or nil) })[k] then return nil end
    if NUM[k] then return function() return NUM[k] end end
    if k == "IsShown" then return function() return rawget(t, "_shown") end end
    if k == "Show" then return function() rawset(t, "_shown", true); local s = rawget(t, "_scripts"); if s and s.OnShow then s.OnShow(t) end end end
    if k == "Hide" then return function() rawset(t, "_shown", false) end end
    if k == "SetShown" then return function(_, v) if v then t:Show() else t:Hide() end end end
    if k == "SetScript" or k == "HookScript" then return function(_, n, f) local s = rawget(t, "_scripts") or {}; rawset(t, "_scripts", s); s[n] = f end end
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
db.activities[10] = false -- Library nicht angehakt: trotzdem gezählt, aber niemand eingeladen
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
print("candidates only from picked:", AutoGroupFinderDB.activities[10] == false)
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
