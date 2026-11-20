unpack = unpack or table.unpack; math.atan2 = math.atan2 or math.atan; tinsert = table.insert
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
    if k == "Hide" then return function() rawset(t, "_shown", false) end end
    if k == "SetShown" then return function(_, v) if v then t:Show() else t:Hide() end end end
    if k == "SetScript" or k == "HookScript" then return function(_, n, f) local s = rawget(t, "_scripts") or {}; rawset(t, "_scripts", s); s[n] = f end end
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
-- Dateien in der Reihenfolge der .toc laden, wie WoW es tut
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN")
local f = AutoGroupFinderFrame
f:Hide()
print("== window open, page", AutoGroupFinderDB.page); f:Show(); ticker()
print("status:", rawget(AutoGroupFinderStartButton, "_text"))
print("== real queue")
AutoGroupFinderDB.playstyle = 2; AutoGroupFinderDB.view = "activities"; AutoGroupFinderDB.samePlaystyle = true
ns.env.StartQueue()
res(1, "OldTank", { tank = true }, 600)
res(2, "NewTank", { tank = true, dps = true }, 5)
res(3, "Heal", { healer = true }, 30)
res(4, "Dps1", { dps = true }, 40)
res(5, "Dps2", { dps = true }, 50)
res(6, "WrongDungeon", { healer = true }, 2, { activityIDs = { 12 } })
res(7, "LowStyle", { healer = true }, 2, { generalPlaystyle = 4 })
AutoGroupFinderDB.playstyle = 2
for _, r in pairs(results) do r.generalPlaystyle = r.generalPlaystyle or 2 end
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
for _, n in ipairs({ "NewTank", "Heal", "Dps1", "Dps2" }) do sys("You have invited " .. n .. " to join your group.") end
sys("NewTank declines your group invitation.")
sys("You have invited OldTank to join your group.")
party = { "OldTank", "Heal", "Dps1", "Dps2" }
fire("GROUP_ROSTER_UPDATE")
print("invites:", table.concat(invites, ","))
print("== found page")
AutoGroupFinderDB.playstyle = 0
f:Show(); ticker()
SlashCmdList.AUTOGROUPFINDER("help")
LOCALE = "enUS"
print("== row interactions")
local inserted, told, menu
ChatFrameUtil = { InsertLink = function(t) inserted = t return true end, SendTell = function(n) told = n end }
MenuUtil = { CreateContextMenu = function(owner, gen)
  local items = {}
  local root = setmetatable({}, { __index = function(_, k) return function(_, text, fn) items[#items + 1] = { text, fn } return {} end end })
  gen(owner, root); menu = items end }
-- put a candidate on the found page
party = {}; fire("GROUP_ROSTER_UPDATE")
AutoGroupFinderDB.page = 2
SlashCmdList.AUTOGROUPFINDER("reset")
res(30, "Fresh", { tank = true, healer = true }, 3, { comment = "chill run" })
f:Show(); ticker()
local row
for _, fr in ipairs(frames) do local s = rawget(fr, "_scripts"); if s and s.OnClick and rawget(fr, "cand") then row = fr break end end
print("row found:", row ~= nil, row and rawget(row, "cand").name)
now = now + 1; ticker()
IsShiftKeyDown = function() return true end
row.sub.IsMouseOver = function() return false end
rawget(row, "_scripts").OnClick(row, "LeftButton"); print("shift name ->", inserted)
row.sub.IsMouseOver = function() return true end
rawget(row, "_scripts").OnClick(row, "LeftButton"); print("shift dungeon ->", inserted)
IsShiftKeyDown = function() return false end
rawget(row, "_scripts").OnClick(row, "RightButton")
for _, it in ipairs(menu) do io.write("[", tostring(it[1]), "] ") end print()
for _, it in ipairs(menu) do if it[1] == "Anflüstern" then it[2]() end end
print("whisper ->", told)

print("== click guard")
local btn
for _, fr in ipairs(frames) do if rawget(fr, "_text") == "Einladen" and rawget(fr, "_scripts") and rawget(fr, "_scripts").OnClick then btn = fr end end
local function parentRow() return row end
btn.GetParent = function() return row end
local n0 = #invites
now = now + 1; fire("LFG_LIST_SEARCH_RESULTS_RECEIVED"); ticker()  -- Aktualisierung ohne Änderung
rawget(btn, "_scripts").OnClick(btn); print("same player after refresh -> invited:", #invites > n0)
SlashCmdList.AUTOGROUPFINDER("reset")
results[30] = nil
res(31, "Other", { tank = true }, 1)
now = now + 1; fire("LFG_LIST_SEARCH_RESULTS_RECEIVED"); ticker()  -- anderer Spieler rutscht in die Zeile
local n1 = #invites
print("dbg row cand:", rawget(row, "cand") and rawget(row, "cand").name, "key:", rawget(row, "key"), "changedAt:", rawget(row, "changedAt"), "now:", now)
rawget(btn, "_scripts").OnClick(btn); print("other player just moved in -> invited:", #invites > n1)
now = now + 0.6
rawget(btn, "_scripts").OnClick(btn); print("0.6s later -> invited:", #invites > n1, invites[#invites])
