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
-- Wartezeit-Schätzung: Modell, Speichern, Selbstkorrektur, Teilen über den Kanal
local MAPS = { [10] = 189, [11] = 90, [12] = 36, [13] = 47 }
local origInfo = C_LFGList.GetActivityInfoTable
C_LFGList.GetActivityInfoTable = function(id) local a = origInfo(id) if a then a.mapID = MAPS[id] end return a end
local sentMsgs = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() end,
  SendAddonMessage = function(p, m, kind, target) sentMsgs[#sentMsgs + 1] = { m, kind, target } return 0 end }
GetChannelName = function(name) return name == "AutoGroupFinderStats" and 5 or 0 end
tContains = tContains or function(t, v) for _, x in ipairs(t) do if x == v then return true end end end
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN")
local db, E = AutoGroupFinderDB, ns.env
local Est = E.Estimate
local function check(label, got, want)
  got, want = tostring(got), tostring(want)
  print(label, got, got == want and "ok" or ("FEHLER, erwartet " .. want))
  if got ~= want then error(label .. ": " .. got .. " statt " .. want) end
end
local function setResults(list)
  for k in pairs(results) do results[k] = nil end
  for i, e in ipairs(list) do res(i, e[1], e[2], 5, { generalPlaystyle = 2, activityIDs = { 11 } }) end
  fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
end
db.playstyle, db.view, db.autoInvite = 2, "activities", false
for k in pairs(db.activities) do db.activities[k] = nil end
db.activities[11] = true
db.activities[10], db.activities[12], db.activities[13] = false, false, false
local dds = {}
for i = 1, 5 do dds[i] = { "Dd" .. i, { dps = true } } end

check("Ohne Daten keine Zeile:", #Est.Lines(), 0)
E.StartQueue()
check("Offene Rollen beim Start:", E.state.startNeed, "1.1.2")
setResults(dds)
check("Anfangs ehrlich ohne Zahl:", Est.Lines()[1], E.T.EST_UNKNOWN)
advance(200)
local withNew = { { "Tank1", { tank = true } }, { "Heal1", { healer = true } } }
for _, d in ipairs(dds) do withNew[#withNew + 1] = d end
setResults(withNew)
-- je 1 Tank/Heiler angekommen in 200 s, Annahmequote ohne Daten 50 %: Mitte 260 s, Spanne 126–394 s
check("Modell nach 200 s:", Est.Lines()[1], "Noch: 2–7 Min. · Engpass: Tank")
check("Grundlage:", Est.Lines()[2], "|cff9d9d9d" .. E.T.EST_SRC_LIVE .. "|r")
check("Erste Schätzung gemerkt:", E.state.estShown and math.floor(E.state.estShown.mid), 260)

Est.RecordFill(600, "TANK")
check("Gespeichert:", #db.fills, 1)
local f = db.fills[1]
check("Datensatz:", ("%d %d %s %d %s"):format(f.m, f.s, f.b, f.z, f.q), "90 600 T 5 1.1.2")
check("Fehler gelernt (tatsächlich/geschätzt):", ("%.2f"):format(db.calib[1]), "1.54")
check("Nachricht:", Est.Encode(f):gsub("h=%d+$", "h=H"), "v=1;k=fill;m=90;s=600;b=T;z=5;q=1.1.2;h=H")
check("Ohne Teilen nichts gesendet:", #sentMsgs, 0)
db.shareStats = true
Est.RecordFill(480, "HEALER")
check("Mit Teilen über Kanal 5:", sentMsgs[1] and (sentMsgs[1][2] .. " " .. sentMsgs[1][3]), "CHANNEL 5")

print("== Empfangen")
local base = #db.fills
local h = tonumber(os.date("!%H"))
local function msg(s, extra) return ("v=1;k=fill;m=90;s=%d;b=T;z=5;q=1.1.2;h=%d%s"):format(s, h, extra or "") end
E.OnAddonMessage("AutoGrpFinder", msg(300), "CHANNEL", "Other")
check("Gültige Meldung:", #db.fills, base + 1)
E.OnAddonMessage("AutoGrpFinder", msg(300), "CHANNEL", "Other")
check("Gleicher Absender kurz danach ignoriert:", #db.fills, base + 1)
E.OnAddonMessage("AutoGrpFinder", msg(300, ";neu=1"), "CHANNEL", "Other2")
check("Unbekanntes Feld wird übergangen:", #db.fills, base + 2)
E.OnAddonMessage("AutoGrpFinder", (msg(300):gsub("^v=1", "v=2")), "CHANNEL", "Other3")
check("Neuere Hauptversion ignoriert:", #db.fills, base + 2)
E.OnAddonMessage("AutoGrpFinder", "v=1;k=fill;m=90;s=abc", "CHANNEL", "Other4")
check("Kaputte Meldung ignoriert:", #db.fills, base + 2)
E.OnAddonMessage("AutoGrpFinder", msg(300), "CHANNEL", "Me")
check("Eigene Meldung ignoriert:", #db.fills, base + 2)
check("Gespeichert ohne Namen:", db.fills[#db.fills].o, "net")

print("== Echte Wartezeiten vor Modell")
E.OnAddonMessage("AutoGrpFinder", msg(900), "CHANNEL", "Other5")
E.StopQueue()
-- 5 Gruppen mit 1.1.2 in Gnomeregan: 600, 480, 300, 300, 900 -> Viertel 300, Dreiviertel 600
check("Vor dem Start aus Erfahrung:", Est.Lines()[1], "Geschätzt: 5–10 Min. · Engpass: Tank")
check("Grundlage Erfahrung:", Est.Lines()[2], "|cff9d9d9d" .. E.T.EST_SRC_HIST:format(5) .. "|r")
