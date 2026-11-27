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

-- Hardware-Ereignisse wie im Client: eingeschränkte Funktionen nur während eines echten Klicks oder
-- Tastendrucks. Ohne einen feuert ADDON_ACTION_FORBIDDEN (der Dialog „… wurde geblockt“) und nichts passiert.
-- Controller (Forevers Gamepad-Modus): Klicks in die Welt kommen ohne Hardware-Ereignis an.
local HW, GAMEPAD, PAD_CONNECTED = false, false, false
local calls, forbidden, chat = {}, {}, {}
-- Was IsUsingGamepad genau meldet, ist undokumentiert; Blizzard selbst entscheidet nur über den Oberflächenstil.
function IsUsingGamepad() return GAMEPAD or PAD_CONNECTED end
C_InputInterfaceStyle = { GetCurrentStyle = function() return GAMEPAD and 1 or 0 end }
local function restricted(tbl, key, name)
  local orig = tbl[key] or function() return true end
  tbl[key] = function(...)
    if not HW then
      forbidden[#forbidden + 1] = name
      fire("ADDON_ACTION_FORBIDDEN", "AutoGroupFinder", name .. "()")
      return
    end
    calls[#calls + 1] = name
    return orig(...)
  end
end
C_PartyInfo.ConvertToRaid = function() end
C_PartyInfo.DoReadyCheck = function() end
C_ChatInfo = { SendChatMessage = function() end }
UnitSetRole = function() return true end
DoReadyCheck = function() end
restricted(C_LFGList, "Search", "C_LFGList.Search")
restricted(C_LFGList, "CreateListing", "C_LFGList.CreateListing")
restricted(C_LFGList, "UpdateListing", "C_LFGList.UpdateListing")
restricted(C_PartyInfo, "ConvertToRaid", "C_PartyInfo.ConvertToRaid")
restricted(C_PartyInfo, "DoReadyCheck", "C_PartyInfo.DoReadyCheck")
restricted(C_ChatInfo, "SendChatMessage", "C_ChatInfo.SendChatMessage")
restricted(_G, "UnitSetRole", "UnitSetRole")
restricted(_G, "DoReadyCheck", "DoReadyCheck")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = (m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end }

local function hardware(f, ...) HW = true f(...) HW = false end
local function worldClick(hw) HW = hw; rawget(WorldFrame, "_scripts").OnMouseDown(WorldFrame, "LeftButton"); HW = false end
local function count(list, name) local n = 0 for _, v in ipairs(list) do if v == name then n = n + 1 end end return n end
local function check(label, got, want)
  print(("%-62s %s"):format(label, tostring(got)))
  if got ~= want then error(label .. ": " .. tostring(got) .. " statt " .. tostring(want)) end
end

local ns = {}
-- Dateien in der Reihenfolge der .toc laden, wie WoW es tut
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN")
local env = ns.env
AutoGroupFinderDB.playstyle = 2; AutoGroupFinderDB.view = "activities"; AutoGroupFinderDB.keySearch = true
hardware(env.StartQueue)
check("Start per Klick trägt ein", count(calls, "C_LFGList.CreateListing"), 1)

print("== Maus: Klick in die Welt sucht (echter Klick)")
advance(60); worldClick(true)
check("Suche nach Weltklick", count(calls, "C_LFGList.Search"), 1)
check("nichts geblockt", #forbidden, 0)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

print("== Maus, Controller angeschlossen, aber nicht benutzt: Weltklick sucht weiter")
PAD_CONNECTED = true
advance(60); worldClick(true)
check("Suche nach Weltklick", count(calls, "C_LFGList.Search"), 2)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
PAD_CONNECTED = false

print("== Controller: Klick in die Welt kommt ohne Hardware-Ereignis")
GAMEPAD = true
advance(60); worldClick(false)
check("kein geblockter Aufruf", #forbidden, 0)
check("keine weitere Suche", count(calls, "C_LFGList.Search"), 2)

print("== Controller: Taste „Nächste Aktion“ sucht")
hardware(AutoGroupFinder_Next)
check("Suche per Taste", count(calls, "C_LFGList.Search"), 3)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

print("== Controller: Vorgemerktes erledigt die Taste zuerst")
advance(60)
env.whisperQueue[#env.whisperQueue + 1] = { name = "Heal", text = "hi", t = GetTime() }
hardware(AutoGroupFinder_Next)
check("Flüstern per Taste gesendet", count(calls, "C_ChatInfo.SendChatMessage"), 1)
check("dieser Tastendruck sucht nicht zusätzlich", count(calls, "C_LFGList.Search"), 3)
hardware(AutoGroupFinder_Next)
check("nächster Tastendruck sucht", count(calls, "C_LFGList.Search"), 4)
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("nichts geblockt", #forbidden, 0)

print("== Maus, aber Weltklick ohne Hardware-Ereignis (unbekannte Ursache): höchstens einmal")
GAMEPAD = false
advance(60); worldClick(false)
check("einmal geblockt", #forbidden, 1)
advance(60); worldClick(false)
advance(60); worldClick(false)
check("danach keine Versuche mehr", #forbidden, 1)
local hints = 0
for _, m in ipairs(chat) do if m:find(env.T.CHAT_WORLDCLICK_OFF, 1, true) then hints = hints + 1 end end
check("ein Hinweis im Chat", hints, 1)
local logged = false
for _, e in ipairs(env.errors) do if e:find("ADDON_ACTION_FORBIDDEN", 1, true) and e:find("C_LFGList.Search", 1, true) then logged = true end end
check("in /gf diag vermerkt", logged, true)
hardware(AutoGroupFinder_Next)
check("Taste sucht weiterhin", count(calls, "C_LFGList.Search"), 5)

print("== Controller: Austragen ohne Klick wartet, der Knopf oben bietet es an")
GAMEPAD = true
env.StopQueue("Gestoppt")
check("noch eingetragen", LISTED, true)
ticker()
local nudge = AutoGroupFinderNudge
check("Knopf sichtbar", rawget(nudge, "_shown"), true)
check("Knopftext", rawget(nudge.text, "_text"), env.T.NUDGE_PENDING)
hardware(rawget(nudge, "_scripts").OnClick, nudge)
check("Knopf trägt aus", LISTED, false)
ticker()
check("Knopf wieder weg", rawget(nudge, "_shown"), false)
check("nichts weiter geblockt", #forbidden, 1)
print("gamepad ok")
