local ADDON, ns = ...

-- Alle Module teilen sich einen privaten Namensraum: Namen ohne "local" landen hier statt in WoWs
-- globaler Tabelle, Unbekanntes wird in _G nachgeschlagen. Echte Globale stehen als _G.Name im Code.
local env = setmetatable({ ADDON = ADDON, ns = ns, T = ns.T, SLASH = "/gf" }, { __index = _G })
ns.env = env
-- Blizzards C-Funktionen (z. B. C_Texture.GetAtlasInfo) suchen Mixins roh im Namensraum des Aufrufers, ohne __index.
for k, v in pairs(_G) do
  if type(k) == "string" and k:sub(-5) == "Mixin" then env[k] = v end
end
setfenv(1, env)

function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff" .. T.TITLE .. ":|r " .. tostring(msg))
end

-- Eigene Lua-Fehler mitschreiben: /gf diag zeigt sie, außerdem stehen sie in den SavedVariables.
errors = {}
if geterrorhandler and seterrorhandler then
  local prev = geterrorhandler()
  seterrorhandler(function(msg, ...)
    local text = tostring(msg)
    local stack = debugstack and debugstack(2) or ""
    if #errors < 30 and (text:find("AutoGroupFinder", 1, true) or stack:find("AutoGroupFinder", 1, true)) then
      local where = stack:match("AddOns/AutoGroupFinder/[^\n]*") or ""
      errors[#errors + 1] = date("%H:%M:%S ") .. text .. (text:find("AutoGroupFinder", 1, true) and "" or " @ " .. where)
    end
    return prev(msg, ...)
  end)
end
-- Unabhängig vom restlichen Add-on: beim Einloggen melden, beim Ausloggen/Reload speichern
local errFrame = CreateFrame("Frame")
errFrame:RegisterEvent("PLAYER_LOGIN")
errFrame:RegisterEvent("PLAYER_LOGOUT")
errFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGOUT" then
    if type(_G.AutoGroupFinderDB) == "table" then _G.AutoGroupFinderDB.errors = errors end
  elseif #errors > 0 then
    Print(("|cffff4040%d Lua-Fehler|r – %s diag: %s"):format(#errors, SLASH, errors[1]:sub(1, 200)))
  end
end)

L = C_LFGList
if not (L and L.Search and L.GetSearchResults and L.GetSearchResultInfo) then
  error("C_LFGList is missing in this client")
end

_G.BINDING_HEADER_AUTOGROUPFINDER = T.TITLE
_G.BINDING_NAME_AUTOGROUPFINDER_NEXT = T.BIND_NEXT
_G.BINDING_NAME_AUTOGROUPFINDER_REFRESH = T.BIND_REFRESH
_G.BINDING_NAME_AUTOGROUPFINDER_TOGGLE = T.BIND_TOGGLE

ROLES = { "TANK", "HEALER", "DAMAGER" }
ROLE_NAME = { TANK = T.ROLE_TANK, HEALER = T.ROLE_HEALER, DAMAGER = T.ROLE_DAMAGER }
ROLE_PLURAL = { TANK = T.ROLES_TANK, HEALER = T.ROLES_HEALER, DAMAGER = T.ROLES_DAMAGER }
-- Dieselben Grafiken wie Blizzards Forever-Gruppensuche
ROLE_BIG = { TANK = "UI-LFG-RoleIcon-Tank", HEALER = "UI-LFG-RoleIcon-Healer", DAMAGER = "UI-LFG-RoleIcon-DPS" }
ROLE_SMALL = {
  TANK = "groupfinder-icon-role-large-tank",
  HEALER = "groupfinder-icon-role-large-heal",
  DAMAGER = "groupfinder-icon-role-large-dps",
}
ROLE_TEXCOORD = {
  TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
  HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
  DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"
-- Blizzard filtert nach Client-Sprache; es gibt genau diese elf
-- Spielsprachen je Region (Korea, Taiwan, China haben eigene Server und kommen in Forever nicht vor)
local REGION_LANGUAGES = {
  [1] = { "enUS", "esMX", "ptBR" },                                   -- Amerika
  [3] = { "deDE", "enUS", "esES", "frFR", "itIT", "ptBR", "ruRU" },   -- Europa
}
LANGUAGES = REGION_LANGUAGES[GetCurrentRegion and GetCurrentRegion() or 0]
  or { "deDE", "enUS", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU" }

-- Name einer Spielsprache, wie Blizzard ihn anzeigt; sonst unsere Übersetzung
function LangName(loc)
  local name = LocaleUtil and LocaleUtil.GetLocaleDisplayName and LocaleUtil.GetLocaleDisplayName(loc)
  if name and name ~= loc:upper() then return name end
  return T["LANG_" .. loc] or loc
end
COMM_PREFIX = "AutoGrpFinder" -- versteckte Addon-Nachrichten zwischen Nutzern
TAB_ICONS = { "Interface\\ICONS\\INV_SideTab_GroupFinder_c60", "Interface\\ICONS\\INV_SideTab_GroupBrowsing_c60",
  "Interface\\ICONS\\INV_Misc_Book_09", "Interface\\ICONS\\INV_Misc_GroupLooking" }

-- Gruppengrößen mit Standard-Rollenverteilung (inklusive dir), in den Einstellungen änderbar
SIZES = { 5, 10, 20, 40 }
DEFAULT_NEED = {
  [5] = { TANK = 1, HEALER = 1, DAMAGER = 3 },
  [10] = { TANK = 2, HEALER = 3, DAMAGER = 5 },
  [20] = { TANK = 2, HEALER = 5, DAMAGER = 13 },
  [40] = { TANK = 4, HEALER = 10, DAMAGER = 26 },
}

DEFAULTS = {
  category = nil,        -- nil = Dungeons
  activities = {},       -- activityID -> true/false (nil = noch nie angefasst)
  collapsed = {},        -- activityGroupID -> true
  allLevels = false,
  view = "categories",   -- Startseite mit Kategorie-Karten oder Aktivitäten
  playstyle = 0,         -- Pflicht für den eigenen Eintrag; 0 = noch nicht gewählt
  voice = 0,             -- Enum.LFGEntryVoiceMode des eigenen Eintrags
  newPlayerFriendly = false,
  samePlaystyle = false, -- nur Spieler mit gleicher Spielweise einladen
  levelCheck = true,     -- Spieler unter dem Stufenbereich überspringen
  levelTolerance = 2,
  preferFriends = true,  -- Freunde und Gildenmitglieder zuerst
  shareStats = true,     -- Wartezeiten mit anderen Nutzern teilen: Gilde, Kanal, eigene Gruppe (Estimate.lua)
  fills = {},            -- fertige Gruppen: eigene und geteilte Wartezeiten
  ratings = {},          -- Spieler -> { v = 1 (gerne wieder) | -1 (nicht wieder), t }
  calib = {},            -- tatsächlich / geschätzt, um den Schätzfehler zu lernen
  inviteStats = { TANK = { sent = 0, joined = 0 }, HEALER = { sent = 0, joined = 0 }, DAMAGER = { sent = 0, joined = 0 } },
  nudge = true,          -- „Bin noch da“-Knopf, wenn länger nicht gesucht wurde
  hereSuggest = true,    -- am Dungeon eine Karte zum Sofort-Suchen anbieten
  preferNear = true,     -- Spieler am Dungeon (Zone des Eingangs oder schon drin) zuerst
  inviteWhisper = false, -- beim Einladen kurz anflüstern
  whisperText = nil,     -- nil = Standardtext
  notify = true,         -- Meldung in der Bildschirmmitte und Taskleiste blinken
  skipUntil = {},        -- key -> time(); übersteht /reload
  asked = {},            -- Anführer, die du schon um Aufnahme gebeten hast: key -> time()
  showDemand = true,     -- Balken: wie viele warten auf welche Aktivität
  popular = {},          -- activityID -> { Anführer -> time() zuletzt gesehen }
  blocked = {},          -- key -> true: nie wieder einladen
  preferLang = "none",   -- bevorzugte Spielsprache (WowLocale) oder "none"
  autoInvite = true,
  keySearch = true,      -- bei Mausklicks in die Spielwelt neu suchen
  oldestFirst = false,
  sound = true,
  page = 1,
  interval = 8,          -- Sekunden zwischen Suchen
  inviteTimeout = 65,    -- Blizzards Einladung läuft nach 60 s ab und zählt dann als Absage
  declineCooldown = 900, -- wer ablehnt oder nicht antwortet, wird so lange übersprungen
  need = {},
  minimap = { angle = 200, hide = false },
  scarceFirst = true,        -- seltene Rollen zuerst einladen
  minimapStandalone = false, -- true: nicht von Sammel-Add-ons einsammeln lassen
}

NUDGE_AFTER = 60 -- Sekunden ohne Suche, bis „Bin noch da“ erscheint (UI/Nudge.lua)

state = { queued = false, queuedAt = 0, lastSearchAt = 0, demand = {},
  trees = {}, treeVersion = 0, listings = {}, lastSupply = {},
  arrivals = { TANK = {}, HEALER = {}, DAMAGER = {} }, langOf = {} }
History = {} -- Verlauf: Aufzeichnen und Seite 3
pending = {}   -- key -> { role, t, confirmed }
joined = {}    -- key -> Rolle, für die wir eingeladen haben
expired = {}   -- key -> Rolle; Einladung abgelaufen, könnte aber noch angenommen werden
seen = {}
candidates = {}

-- Alles, was das Spiel berührt. "/gf test" tauscht es gegen Attrappen.
real = {
  results = function() local _, ids = L.GetSearchResults() return ids or {} end,
  info = function(id) return L.GetSearchResultInfo(id) end,
  leader = function(id) return L.GetSearchResultLeaderInfo and L.GetSearchResultLeaderInfo(id) end,
  search = function(cat, ids, languages)
    return pcall(L.Search, cat, 0, 0, languages, false, nil, ids)
  end,
  invite = function(name) C_PartyInfo.InviteUnit(name) end,
  members = function()
    local t = {}
    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if not UnitIsUnit(unit, "player") then
          local n = GetUnitName(unit, true)
          if n then t[#t + 1] = { unit = unit, name = n } end
        end
      end
    else
      for i = 1, 4 do
        local n = GetUnitName("party" .. i, true)
        if n then t[#t + 1] = { unit = "party" .. i, name = n } end
      end
    end
    return t
  end,
  unitRole = function(unit) return UnitGroupRolesAssigned(unit) end,
  groupSize = function() return GetNumGroupMembers() end,
  isRaid = function() return IsInRaid() end,
  convertToRaid = function() C_PartyInfo.ConvertToRaid() end,
  -- Eigener Eintrag wie Blizzards „List Self“; Kommentar setzt Blizzard nur selbst.
  list = function(data, roles)
    if not IsInGroup() and C_LFGListRoles and C_LFGListRoles.SetRoles then pcall(C_LFGListRoles.SetRoles, roles) end
    if L.HasActiveEntryInfo and L.HasActiveEntryInfo() then return pcall(L.UpdateListing, data) end
    return pcall(L.CreateListing, data)
  end,
  unlist = function()
    if L.HasActiveEntryInfo and L.HasActiveEntryInfo() and L.RemoveListing then pcall(L.RemoveListing) end
  end,
  setRole = function(unit, role) return pcall(UnitSetRole, unit, role) end,
  whisper = function(name, text)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if send then pcall(send, text, "WHISPER", nil, name) end
  end,
  canInvite = function()
    return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
  end,
  readyCheck = function() pcall(DoReadyCheck) end,
  comm = function(kind, text, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
      pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, kind .. "\t" .. (text or ""), "WHISPER", target)
    end
  end,
}
api = real

-- In manchen Lagen (z. B. in Instanzen) liefert Blizzard „geheime“ Werte, die Add-ons nicht auswerten dürfen
function Readable(v) return not (issecretvalue and issecretvalue(v)) end
function AllReadable(t, ...)
  if not t then return false end
  for i = 1, select("#", ...) do if not Readable(t[select(i, ...)]) then return false end end
  return true
end

function Key(name) return Ambiguate(name, "none") end
function Short(name) return Ambiguate(name, "short") end
-- Forever-Namen haben einen Nachnamen; UnitName("player") liefert nur den Vornamen
function MyName()
  local full = GetUnitName and GetUnitName("player", true)
  return (full and full ~= "") and full or UnitName("player")
end
function Ding() if db.sound then PlaySound(SOUNDKIT.READY_CHECK or 8960, "Master") end end

function HasAtlas(a)
  return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a) ~= nil
end
function Atlas(tex, name)
  if HasAtlas(name) then tex:SetAtlas(name) return true end
end
-- Rollensymbol als Text-Markierung, z. B. für Tooltips
function RoleIconText(role, size)
  size = size or 16
  if HasAtlas(ROLE_SMALL[role]) then return ("|A:%s:%d:%d|a"):format(ROLE_SMALL[role], size, size) end
  local c = ROLE_TEXCOORD[role]
  return ("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:0:64:64:%d:%d:%d:%d|t"):format(
    size, size, c[1] * 64, c[2] * 64, c[3] * 64, c[4] * 64)
end

-- Bewertung: 1 = gerne wieder (wird bevorzugt), -1 = nicht wieder (wird nicht mehr eingeladen)
function Rate(name, v)
  local k = Key(name)
  local cur = db.ratings[k]
  db.ratings[k] = (not cur or cur.v ~= v) and { v = v, t = time() } or nil
  Rebuild()
end
function Rating(name) local r = db.ratings[Key(name)] return r and r.v end

RATE_ICON = { [1] = "Interface\\RaidFrame\\ReadyCheck-Ready", [-1] = "Interface\\RaidFrame\\ReadyCheck-NotReady" }
function RateTag(v, size)
  size = size or 14
  return v and ("|T%s:%d:%d|t"):format(RATE_ICON[v], size, size) or ""
end

-- Offene Plätze als Symbole: eines je Platz, bei vielen „Symbol ×N“
function NeedIcons(rem)
  local parts = {}
  for _, r in ipairs(ROLES) do
    local n = rem[r] or 0
    if n > 0 and n <= 5 then
      for _ = 1, n do parts[#parts + 1] = RoleIconText(r) end
    elseif n > 5 then
      parts[#parts + 1] = RoleIconText(r) .. "×" .. n
    end
  end
  return table.concat(parts, " ")
end

function SetRoleTexture(tex, role, big)
  if not Atlas(tex, (big and ROLE_BIG or ROLE_SMALL)[role]) then
    tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    tex:SetTexCoord(unpack(ROLE_TEXCOORD[role]))
  end
end

-------------------------------------------------------------------------
