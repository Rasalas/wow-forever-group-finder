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

-- Controller-Oberfläche (Forever): Jedes Menü aus Blizzard_Menu tritt dort der Controller-Steuerung
-- (FrameControlsManager) bei. Öffnet ein Add-on so ein Menü, befleckt es diese Steuerung; beim Schließen
-- blockiert Blizzard SetPreferredGamepadInteractTarget und zeigt „AutoGroupFinder wurde geblockt“.
-- Darum: kein Blizzard-Menü aus Add-on-Code, sondern ein eigenes – mit Controller und, der Einheit halber,
-- auch mit Maus (Forever wechselt die Oberfläche, sobald man das andere Gerät benutzt).
local GAMEPAD = false
C_InputInterfaceStyle = { GetCurrentStyle = function() return GAMEPAD and 1 or 0 end }
local blizzMenus, popups = {}, {}
MenuUtil = { CreateContextMenu = function(owner, gen) blizzMenus[#blizzMenus + 1] = "context" end }
DropdownButtonMixin = { OpenMenu = function(self) blizzMenus[#blizzMenus + 1] = "dropdown" end }
GamepadMode = { FrameControlsManager = {
  HandlePopupShown = function(_, f) popups[#popups + 1] = "shown" end,
  HandlePopupHide = function(_, f) popups[#popups + 1] = "hidden" end } }
-- wie Blizzards DropdownButton: der eingebaute OnMouseDown ruft self:OpenMenu()
local function pressDropdown(dd) local open = rawget(dd, "OpenMenu") or DropdownButtonMixin.OpenMenu open(dd) end
local function check(label, got, want)
  print(("%-58s %s"):format(label, tostring(got)))
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
local function menu() return _G.AutoGroupFinderPadMenu end
local function rows()
  local out = {}
  for _, r in ipairs(menu() and rawget(menu(), "rows") or {}) do
    if rawget(r, "_shown") then out[#out + 1] = r end
  end
  return out
end
local function row(text)
  for _, r in ipairs(rows()) do
    local t = rawget(r.label, "_text") or ""
    if t:find(text, 1, true) then return r end
  end
end
local function click(r) rawget(r, "_scripts").OnClick(r, "LeftButton") end

print("== Maus: dasselbe eigene Menü")
local before = #blizzMenus
pressDropdown(env.gear)
check("kein Blizzard-Menü", #blizzMenus, before)
check("eigenes Menü offen", menu() and rawget(menu(), "_shown"), true)
check("ohne Controller keine Anmeldung bei dessen Steuerung", #popups, 0)
env.ShowPlayerMenu(UIParent, { name = "Heal", key = "Heal", roles = { HEALER = true } })
check("Rechtsklick: kein Blizzard-Kontextmenü", #blizzMenus, before)
check("Rechtsklick: eigenes Menü mit dem Namen", row("Heal") ~= nil, true)
menu():Hide()

print("== Controller: eigenes Menü statt Blizzards")
GAMEPAD = true
pressDropdown(env.gear)
check("kein Blizzard-Menü", #blizzMenus, before)
check("eigenes Menü offen", menu() and rawget(menu(), "_shown"), true)
check("Controller-Steuerung kennt das Menü", popups[#popups], "shown")
local opt = env.OPTIONS[1]
local r = row(opt[2])
check("Einstellung steht im Menü", r ~= nil, true)
local was = env.db[opt[1]] and true or false
click(r)
check("Häkchen schaltet die Einstellung", (env.db[opt[1]] and true or false), not was)
check("Menü bleibt bei Häkchen offen", rawget(menu(), "_shown"), true)
check("Häkchen zeigt den neuen Stand", rawget(row(opt[2]).tick, "_shown") and true or false, not was)
click(row(opt[2]))   -- zurück

print("== Controller: Untermenü")
click(row(env.T.PREF_LANG))
check("Untermenü zeigt die Sprachen", row(env.T.PREF_LANG_NONE) ~= nil, true)
click(row(env.LangName(env.LANGUAGES[1])))
check("Auswahl gesetzt", env.db.preferLang, env.LANGUAGES[1])
check("Auswahl schließt das Menü", rawget(menu(), "_shown"), false)
check("Controller-Steuerung gibt es frei", popups[#popups], "hidden")

print("== Controller: Rechtsklick auf Spieler")
env.ShowPlayerMenu(UIParent, { name = "Heal", key = "Heal", roles = { HEALER = true } })
check("kein Blizzard-Kontextmenü", #blizzMenus, before)
check("Titel ist der Name", row("Heal") ~= nil, true)
check("Flüstern im Menü", row(env.T.WHISPER) ~= nil, true)
check("zweites Öffnen am selben Ort schließt", (function()
  env.ShowPlayerMenu(UIParent, { name = "Heal", key = "Heal", roles = { HEALER = true } })
  return rawget(menu(), "_shown")
end)(), false)

print("== Controller: Auswahlfeld (Dungeon-Kategorie)")
local dd = env.dropdowns[1]
pressDropdown(dd)
check("kein Blizzard-Menü", #blizzMenus, before)
check("eigenes Menü offen", rawget(menu(), "_shown"), true)

print("== Auswahlfeld zeigt „offen“, solange sein Menü offen ist (Pfeil wie bei Blizzard)")
local states = 0
dd.OnButtonStateChanged = function() states = states + 1 end
menu():Hide()
check("zu: IsMenuOpen", dd:IsMenuOpen() and true or false, false)
pressDropdown(dd)
check("offen: IsMenuOpen", dd:IsMenuOpen() and true or false, true)
check("Pfeil aufgefrischt", states > 0, true)
-- zweiter Druck: Blizzards eingebauter Klick ruft SetMenuOpen(not IsMenuOpen()) -> CloseMenu
dd:CloseMenu()
check("CloseMenu schließt das eigene Menü", rawget(menu(), "_shown"), false)
check("zu: IsMenuOpen", dd:IsMenuOpen() and true or false, false)

print("== zurück zur Maus: weiter das eigene Menü")
menu():Hide()
GAMEPAD = false
pressDropdown(env.gear)
check("kein Blizzard-Menü", #blizzMenus, before)
check("eigenes Menü offen", rawget(menu(), "_shown"), true)
print("gamepad menus ok")
