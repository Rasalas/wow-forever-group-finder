unpack = unpack or table.unpack; math.atan2 = math.atan2 or math.atan; tinsert = table.insert
strsplit = function(sep, s) local t = {} for part in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = part end return (unpack or table.unpack)(t) end
GetRealZoneText = function() return ZONE or "Ironforge" end
date = os.date; GetInstanceInfo = function() return INSTANCE or "Scarlet Library" end; UnitClass = function() return "Mage", "MAGE" end; IsInInstance = function() return INSTANCE ~= nil, INSTANCE and "party" or "none" end; UnitLevel = UnitLevel or function() return 34 end
time = os.time
local now = 100
local NUM = { GetHeight = 76, GetStringHeight = 14, GetFrameLevel = 1, GetWidth = 140, GetHeight = 140, GetStringWidth = 50, GetEffectiveScale = 1, GetVerticalScrollRange = 0, GetVerticalScroll = 0 }
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
COMBAT = false
function InCombatLockdown() return COMBAT end
function IsShiftKeyDown() return false end
function GetCursorPosition() return 0, 0 end
function PlaySound() print("SOUND") end
function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower = string.lower; wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
SlashCmdList = {}; SOUNDKIT = { READY_CHECK = 1 }; RAID_CLASS_COLORS = {}
function GameTooltip_Hide() end
C_Texture = { GetAtlasInfo = function(a) return {} end }
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
C_ChatInfo = { SendAddonMessage = function() end, RegisterAddonMessagePrefix = function() end }
local dialog = setmetatable({}, { __index = function(_, k)
  if k == "IsShown" then return function() return true end end
  if k == "GetBottom" then return function() return 400 end end
  return function() end end })
StaticPopup_FindVisible = function(which) return which == "PARTY_INVITE" and dialog or nil end
local box = AutoGroupFinderInviteInfo
print("== Einladender mit Add-on (Nachricht kommt zuerst)")
fire("CHAT_MSG_ADDON", "AutoGrpFinder", "INV\tScarlet Library\tTANK\t3\t5\t2\t0,1;1,1;2,3\t10", "WHISPER", "Leader")
fire("PARTY_INVITE_REQUEST", "Leader")
print("shown:", rawget(box, "_shown"), "|", rawget(box.title, "_text"), "|", rawget(box.line, "_text"))
box:Hide()
print("== Einladender ohne Add-on, aber in der Gruppensuche")
res(9, "Grouper", { tank = true }, 5, { numMembers = 3, activityIDs = { 11 } })
fire("PARTY_INVITE_REQUEST", "Grouper")
print("shown:", rawget(box, "_shown"), "|", rawget(box.title, "_text"), "|", rawget(box.line, "_text"))
box:Hide()
print("== Unbekannter Einladender")
fire("PARTY_INVITE_REQUEST", "Stranger")
print("shown:", rawget(box, "_shown"))
print("== /gf testinvite")
StaticPopup_Show = function(which, arg) print("popup:", which, StaticPopupDialogs[which].timeout .. "s", arg) return dialog end
SlashCmdList.AUTOGROUPFINDER("testinvite")
print("box:", rawget(box, "_shown"), "|", rawget(box.title, "_text"), "|", rawget(box.line, "_text"))
StaticPopupDialogs.AUTOGROUPFINDER_FAKE_INVITE.OnAccept()
SlashCmdList.AUTOGROUPFINDER("help")
print("== /gf testinvite (Rollenauswahl)")
local timers = {}
C_Timer.After = function(d, fn) timers[#timers + 1] = fn end
SlashCmdList.AUTOGROUPFINDER("testinvite")
local demo = AutoGroupFinderDemoInvite
print("demo shown:", rawget(demo, "_shown"), "box:", rawget(box, "_shown"), "|", rawget(box.title, "_text"))
local sl = rawget(box, "slots").slots
local desc = {}
for i = 1, 5 do desc[i] = rawget(sl[i], "_shown") and (rawget(sl[i], "_desat") and "blass" or "farbig") or "-" end
print("slots:", table.concat(desc, " "))
local w = rawget(box, "slots")
print("line:", tostring(rawget(box.line, "_text")))
local roles = rawget(demo, "roles")
print("roles:", #roles)
local cb = rawget(roles[1], "checkButton")
cb:SetChecked(true); rawget(cb, "_scripts").OnClick(cb)
print("tank checked, others:", rawget(rawget(roles[3], "checkButton"), "_checked"))
for _, fn in ipairs(timers) do fn() end
print("after 10s hidden:", not rawget(demo, "_shown"))
print("== testinvite simple")
SlashCmdList.AUTOGROUPFINDER("testinvite simple")
print("== Gedächtnis: Gruppe nicht mehr in der letzten Suche")
box:Hide()
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED") -- Grouper wird gesehen und gemerkt
results[9] = nil
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
fire("PARTY_INVITE_REQUEST", "Grouper")
print("shown:", rawget(box, "_shown"), "|", rawget(box.title, "_text"))
print("== testinvite listing")
SlashCmdList.AUTOGROUPFINDER("testinvite listing")
local w2 = rawget(box, "slots")
local desc = {}
for i = 1, 5 do desc[i] = rawget(w2.empties[i], "_shown") and "leer" or (rawget(w2.slots[i], "_shown") and "rolle" or "-") end
print("slots:", table.concat(desc, " "))
print("== echte Einladung ohne Add-on, Tank angeboten")
box:Hide()
res(20, "Lister Hans", { tank = true }, 5, { numMembers = 3, activityIDs = { 10 } })
C_LFGList.GetSearchResultMemberCounts = function(id) if id == 20 then return { TANK = 0, HEALER = 1, DAMAGER = 2 } end end
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
fire("PARTY_INVITE_REQUEST", "Lister Hans", true, false, false)
local w3 = rawget(box, "slots")
local d3 = {}
for i = 1, 5 do d3[i] = rawget(w3.empties[i], "_shown") and "leer" or (rawget(w3.slots[i], "_shown") and ((rawget(w3.slots[i], "_desat") and "blass") or "farbig") or "-") end
print("slots:", table.concat(d3, " "), "ring:", rawget(w3.rings[1], "_shown"))
