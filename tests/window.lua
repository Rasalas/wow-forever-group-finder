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
-- Fenster: Ziehen löst es aus Blizzards Verwaltung, nahe am Standardplatz rastet es ein, Schließen vergisst die Position
for line in io.lines(arg[1] .. "/AutoGroupFinder.toc") do
  local file = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if file then assert(loadfile(arg[1] .. "/" .. (file:gsub("\\", "/"))))("AutoGroupFinder", ns) end
end
fire("ADDON_LOADED", "AutoGroupFinder"); fire("PLAYER_LOGIN")
local db, E = AutoGroupFinderDB, ns.env
local win = AutoGroupFinderFrame
local function check(label, got, want)
  got, want = tostring(got), tostring(want)
  print(label, got, got == want and "ok" or ("FEHLER, erwartet " .. want))
  if got ~= want then error(label .. ": " .. got .. " statt " .. want) end
end
local attrs, L, Tp = {}, 16, 700
rawset(win, "SetAttribute", function(_, k, v) attrs[k] = v end)
rawset(win, "GetLeft", function() return L end)
rawset(win, "GetTop", function() return Tp end)
GetUIPanel = function(area) return area == "left" and win:IsShown() and not E.state.winPos and win or nil end
ShowUIPanel = function(f) f:Show() end
HideUIPanel = function(f) f:Hide() end

E.OpenWindow()
check("Von Blizzard verwaltet:", attrs["UIPanelLayout-area"], "left")
E.StartMoveWindow()
check("Während des Ziehens bleibt das Fenster offen:", win:IsShown(), true)
check("Während des Ziehens noch verwaltet:", attrs["UIPanelLayout-area"], "left")
check("Standardplatz gemerkt:", db.winHome and (db.winHome.x .. "," .. db.winHome.y), "16,700")
L, Tp = 400, 500
E.StopMoveWindow()
check("Nach dem Loslassen gelöst:", attrs["UIPanelLayout-area"], nil)
check("Und sichtbar:", win:IsShown(), true)
check("Neue Position gespeichert:", E.state.winPos and (E.state.winPos.x .. "," .. E.state.winPos.y), "400,500")
E.CloseWindow(); E.OpenWindow()
L, Tp = 16, 700 -- Blizzards Verwaltung setzt es wieder an den Standardplatz
check("Nach Schließen wieder am Standardplatz:", attrs["UIPanelLayout-area"], "left")
check("Verschiebung vergessen:", E.state.winPos, nil)
E.StartMoveWindow()
L, Tp = 30, 690
E.StopMoveWindow()
check("Nahe am Standardplatz eingerastet:", E.state.winPos, nil)
check("Wieder verwaltet:", attrs["UIPanelLayout-area"], "left")
E.StartMoveWindow(); L, Tp = 500, 300; E.StopMoveWindow()
rawget(E.titleHandle, "_scripts").OnDoubleClick(E.titleHandle)
check("Doppelklick setzt zurück:", E.state.winPos, nil)
check("Fenster wieder offen:", win:IsShown(), true)

print("== Ausblenden mitten im Ziehen")
local stopped = 0
rawset(win, "StopMovingOrSizing", function() stopped = stopped + 1 end)
E.StartMoveWindow()
win:Hide()
check("Ziehen beendet:", stopped, 1)
check("Nicht mehr am Ziehen:", E.winMoving, false)
E.OpenWindow()

print("== Kurzanleitung")
E.CloseWindow(); db.onboarded = nil
E.OpenWindow()
check("Beim ersten Öffnen sichtbar:", E.onboarding:IsShown(), true)
rawget(E.onboarding.go, "_scripts").OnClick(E.onboarding.go)
check("Weggeklickt:", E.onboarding:IsShown(), false)
E.CloseWindow(); E.OpenWindow()
check("Danach nicht mehr von selbst:", E.onboarding:IsShown(), false)
E.ShowOnboarding()
check("Über das Menü wieder aufrufbar:", E.onboarding:IsShown(), true)

print("== Kurzanleitung: Einstellungen")
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end
E.onboarding:Hide()
db.shareStats, db.minimapStandalone = true, false
E.ShowOnboarding()
check("Zwei Einstellungen ohne Sammel-Add-on:", #E.onboarding.checks, 2)
C_AddOns = { IsAddOnLoaded = function(n) return n == "MinimapButtonButton" end }
E.onboarding:Hide(); E.ShowOnboarding()
check("Mit MinimapButtonButton eine dritte:", #E.onboarding.checks, 3)
local share, mmc = E.onboarding.checks[2], E.onboarding.checks[3]
check("Häkchen spiegelt die Einstellung:", share:GetChecked(), true)
share:SetChecked(false)
mmc:SetChecked(true); rawget(mmc, "_scripts").OnClick(mmc)
check("Knopf kündigt Neuladen an:", rawget(E.onboarding.go, "_text"), E.T.ONB_RELOAD)
rawget(E.onboarding.go, "_scripts").OnClick(E.onboarding.go)
check("Teilen abgeschaltet:", db.shareStats, false)
check("Minimap-Symbol einzeln:", db.minimapStandalone, true)
check("Neu geladen:", reloads, 1)
