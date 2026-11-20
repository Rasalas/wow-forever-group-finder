local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Wartezeit schätzen. Reihenfolge der Quellen, weil echte Wartezeiten jedes Modell schlagen:
--   1. fertige Gruppen (eigene und geteilte) mit gleichem Dungeon, Größe und gleichen offenen Rollen
--   2. Modell aus aktuellem Angebot, Ankünften und Annahmequote, korrigiert um den bisherigen Schätzfehler
--   3. fertige Gruppen mit gleichen offenen Rollen aus beliebigen Dungeons (grob)
-- Während der Suche zählt nur, was noch fehlt: Gruppen, die schneller voll waren, fallen heraus.
-------------------------------------------------------------------------
Estimate = {}
PROTO = 1                          -- Hauptversion des Nachrichtenformats; höhere werden ignoriert
SHARE_CHANNEL = "AutoGroupFinderStats"
local KEEP_SECONDS, KEEP_MAX = 30 * 86400, 400
local WINDOW = 1800                -- Ankünfte der letzten 30 Minuten
local ROLE_CODE = { TANK = "T", HEALER = "H", DAMAGER = "D" }

-- Instanzen (mapID) der gewählten Aktivitäten
function Estimate.SelectedMaps()
  local _, ids = SearchActivities()
  local maps, n, first = {}, 0, nil
  for _, id in ipairs(ids) do
    local a = L.GetActivityInfoTable(id)
    if a and (a.mapID or 0) > 0 and not maps[a.mapID] then
      maps[a.mapID] = true
      n = n + 1
      first = first or a.mapID
    end
  end
  return maps, n, first
end

-- Offene Rollen als Kennung, z. B. "1.1.2" (Tank, Heiler, Schaden)
function Estimate.NeedCode(rem)
  return ("%d.%d.%d"):format(rem.TANK or 0, rem.HEALER or 0, rem.DAMAGER or 0)
end

local function Median(list)
  if #list == 0 then return nil end
  local t = {}
  for i, v in ipairs(list) do t[i] = v end
  table.sort(t)
  return t[math.floor((#t + 1) / 2)]
end

-------------------------------------------------------------------------
-- Messwerte während der Suche
-------------------------------------------------------------------------
-- Andere Auswahl = neue Beobachtung der Ankünfte
function Estimate.OnResults()
  local _, ids = SearchActivities()
  local key = table.concat(ids, ",")
  if key ~= state.estKey then
    state.estKey, state.observeSince = key, nil
    state.arrivals = { TANK = {}, HEALER = {}, DAMAGER = {} }
  end
  state.observeSince = state.observeSince or GetTime()
end

-- Nach dem Neuaufbau: erste Modellschätzung dieser Suche merken, um sie später mit der Wirklichkeit zu vergleichen
function Estimate.AfterResults()
  if not state.queued or state.estShown then return end
  local _, mid = Estimate.Live()
  if mid and mid < math.huge then state.estShown = { at = GetTime() - state.queuedAt, mid = mid } end
end

-- Ankünfte älter als das Fenster werden nicht mehr gebraucht
function Estimate.Prune()
  local now = GetTime()
  for _, r in ipairs(ROLES) do
    local keep = {}
    for _, at in ipairs(state.arrivals[r]) do if now - at < WINDOW then keep[#keep + 1] = at end end
    state.arrivals[r] = keep
  end
end

-- Neuer Kandidat; wer bei den ersten Ergebnissen schon wartete, ist keine Ankunft
function Estimate.Arrived(c)
  local now = GetTime()
  if not state.observeSince or now - state.observeSince < 5 then return end
  for _, r in ipairs(ROLES) do
    if c.roles[r] then tinsert(state.arrivals[r], now) end
  end
end

-- Einladungen und Zusagen je Rolle, über alle Sitzungen
function Estimate.Invited(role)
  local s = db.inviteStats[role]
  if s then s.sent = s.sent + 1 end
end
function Estimate.Joined(role)
  local s = db.inviteStats[role]
  if s then s.joined = s.joined + 1 end
end
local function AcceptRate(role)
  local s = db.inviteStats[role]
  return s and (s.joined + 1) / (s.sent + 2) or 0.5 -- mit wenig Daten vorsichtig bei der Hälfte
end

-- Wie weit lag das Modell bisher daneben? Median aus tatsächlich / geschätzt, ab drei Vergleichen
function Estimate.Calibration()
  if #db.calib < 3 then return 1 end
  return math.min(5, math.max(0.5, Median(db.calib)))
end

-------------------------------------------------------------------------
-- Modell: Angebot, Ankünfte, Annahmequote
-------------------------------------------------------------------------
-- Rückgabe: untere Grenze, Mitte, obere Grenze (Sekunden) und Engpass-Rolle, oder nil bei zu wenig Daten
function Estimate.Live()
  if not state.observeSince then return nil end
  local rem, open = Slots()
  local supply, now = SupplyNow(), GetTime()
  local window = math.min(WINDOW, now - state.observeSince)
  local lo, mid, hi, role = 0, 0, 0, nil
  for _, r in ipairs(ROLES) do
    if rem[r] > 0 then
      local p = AcceptRate(r)
      local missing = math.max(0, open[r] - supply[r] * p) / p -- benötigte Ankünfte, wenn nur ein Teil zusagt
      local rLo, rMid, rHi = 30, 60, 120
      if missing > 0.5 then
        local n = 0
        for _, at in ipairs(state.arrivals[r]) do if now - at < WINDOW then n = n + 1 end end
        if n > 0 and window >= 180 then
          local rate = n / window
          local mean, sd = missing / rate, math.sqrt(missing) / rate
          rLo = 60 + math.max(0.29 / rate, mean - 0.67 * sd)
          rMid, rHi = 60 + mean, 60 + mean + 0.67 * sd
        elseif window >= 600 then
          rLo, rMid, rHi = window * 0.5, window * missing, math.huge -- lange niemand gekommen
        else
          return nil
        end
      end
      if rMid > mid then mid, role = rMid, r end
      lo, hi = math.max(lo, rLo), math.max(hi, rHi)
    end
  end
  if not role then return nil end
  local heldRoles = HeldRoles()
  local held = next(heldRoles) and 60 or 0 -- reichliche Rollen kommen erst nach den knappen
  local f = Estimate.Calibration()
  return (lo + held) * f, (mid + held) * f, (hi + held) * f, role
end

-------------------------------------------------------------------------
-- Fertige Gruppen
-------------------------------------------------------------------------
local function Prune()
  local cutoff, keep = time() - KEEP_SECONDS, {}
  for _, f in ipairs(db.fills) do if f.t >= cutoff then keep[#keep + 1] = f end end
  while #keep > KEEP_MAX do table.remove(keep, 1) end
  db.fills = keep
end

-- Kennung zum Aussortieren doppelter Meldungen (dieselbe Gruppe kommt über Gruppe, Gilde und Kanal)
local function Id(f) return ("%d.%d.%d.%s"):format(f.t, f.m, f.s, f.q) end
local known
local function Add(f)
  if not known then
    known = {}
    for _, g in ipairs(db.fills) do known[Id(g)] = true end
  end
  local id = Id(f)
  if known[id] then return false end
  known[id] = true
  tinsert(db.fills, f)
  Prune()
  return true
end

-- Restzeiten (Viertel, Mitte, Dreiviertel) aus fertigen Gruppen; sameDungeon = nur die gewählte Instanz.
-- Gleiche Uhrzeit (±2 h) bevorzugt, sofern es davon genug gibt.
function Estimate.History(elapsed, sameDungeon)
  local maps = Estimate.SelectedMaps()
  local size = Target()
  local need = state.queued and state.startNeed or Estimate.NeedCode((Slots()))
  local hour = tonumber(date("!%H"))
  local near, all = {}, {}
  for _, f in ipairs(db.fills) do
    if f.z == size and f.q == need and (not sameDungeon or maps[f.m]) and f.s > elapsed then
      local left = f.s - elapsed
      all[#all + 1] = left
      local d = math.abs(f.h - hour)
      if math.min(d, 24 - d) <= 2 then near[#near + 1] = left end
    end
  end
  local list = #near >= 3 and near or all
  if #list < 3 then return nil end
  table.sort(list)
  local function q(p) return list[math.min(#list, math.max(1, math.floor(p * (#list - 1) + 1.5)))] end
  return q(0.25), q(0.5), q(0.75), #list
end

-- Beim Start: was fehlt? (für den Vergleich mit Gruppen in derselben Lage)
function Estimate.OnStart()
  state.startNeed, state.estShown = Estimate.NeedCode((Slots())), nil
end

-- Gruppe voll: Wartezeit speichern, Schätzfehler lernen, auf Wunsch teilen
function Estimate.RecordFill(seconds, lastRole)
  if state.estShown and state.estShown.mid > 0 then
    tinsert(db.calib, (seconds - state.estShown.at) / state.estShown.mid)
    while #db.calib > 30 do table.remove(db.calib, 1) end
  end
  local _, n, mapID = Estimate.SelectedMaps()
  if n ~= 1 or not state.startNeed or seconds < 10 or seconds > 4 * 3600 then return end -- gemischte Auswahl lässt sich nicht zuordnen
  local f = { m = mapID, s = math.floor(seconds), b = ROLE_CODE[lastRole] or "D", z = (Target()),
    q = state.startNeed, h = tonumber(date("!%H")), t = time(), o = "me" }
  Add(f)
  Estimate.Share(f)
end

-------------------------------------------------------------------------
-- Teilen: eine Meldung je fertiger Gruppe an Kanal und Gilde, dazu Austausch in der Gruppe,
-- damit sich Wartezeiten von Gruppe zu Gruppe weiterverbreiten. Namen werden nicht gespeichert.
-------------------------------------------------------------------------
-- Benannte Felder, unbekannte werden ignoriert, z. B. "v=1;k=fill;m=90;s=372;b=T;z=5;q=1.1.2;h=20;t=1795180000"
function Estimate.Encode(f)
  return ("v=%d;k=fill;m=%d;s=%d;b=%s;z=%d;q=%s;h=%d;t=%d"):format(PROTO, f.m, f.s, f.b, f.z, f.q, f.h, f.t)
end

local function Fields(msg)
  local fields = {}
  for k, v in msg:gmatch("(%w+)=([^;]*)") do fields[k] = v end
  if math.floor(tonumber(fields.v) or 0) ~= PROTO then return nil end
  return fields
end

function Estimate.Decode(msg)
  local fields = Fields(msg)
  if not fields or fields.k ~= "fill" then return nil end
  local m, s, z, h = tonumber(fields.m), tonumber(fields.s), tonumber(fields.z), tonumber(fields.h)
  if not (m and m > 0 and s and s >= 10 and s <= 4 * 3600 and z and DEFAULT_NEED[z] and h and h >= 0 and h < 24) then return nil end
  if fields.b ~= "T" and fields.b ~= "H" and fields.b ~= "D" then return nil end
  if not (fields.q and fields.q:match("^%d+%.%d+%.%d+$")) then return nil end
  local now = time()
  local t = math.floor(tonumber(fields.t) or now)
  if t < now - KEEP_SECONDS or t > now + 3600 then return nil end
  return { m = m, s = math.floor(s), b = fields.b, z = z, q = fields.q, h = math.floor(h), t = t, o = "net" }
end

local function Send(kind, target, msg)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, msg, kind, target) end
end
local function GroupKind() return IsInRaid() and "RAID" or "PARTY" end

-- Eigene fertige Gruppe: an den Kanal und an die Gilde
function Estimate.Share(f)
  if not db.shareStats then return end
  local msg = Estimate.Encode(f)
  local id = GetChannelName and GetChannelName(SHARE_CHANNEL)
  if id and id ~= 0 then Send("CHANNEL", tostring(id), msg) end
  if IsInGuild and IsInGuild() then Send("GUILD", nil, msg) end
end

-- In der Gruppe: einmal „hallo“; wer das Add-on hat, antwortet mit seinen letzten Wartezeiten
local GOSSIP_MAX = 10
function Estimate.OnRoster()
  if not db or not db.shareStats then return end
  if not IsInGroup() then state.hiSent = nil return end
  if not state.hiSent then
    state.hiSent = true
    Send(GroupKind(), nil, ("v=%d;k=hi"):format(PROTO))
  end
end

function Estimate.Gossip()
  local now = GetTime()
  if state.gossipAt and now - state.gossipAt < 30 then return end
  state.gossipAt = now
  local kind, n = GroupKind(), 0
  for i = #db.fills, 1, -1 do
    if n >= GOSSIP_MAX then break end
    n = n + 1
    local msg = Estimate.Encode(db.fills[i])
    C_Timer.After(n * 1.5, function() if IsInGroup() then Send(kind, nil, msg) end end) -- gedrosselt
  end
end

-- Empfang; je Absender höchstens 30 Meldungen in 10 Minuten
local fromCount = {}
function Estimate.OnNet(msg, sender)
  if not db or not db.shareStats or not sender then return end
  local k = Key(sender)
  if k == Key(UnitName("player")) then return end
  local fields = Fields(msg)
  if not fields then return end
  if fields.k == "hi" then
    Estimate.OnRoster() -- falls wir selbst noch nicht gegrüßt haben
    Estimate.Gossip()
    return
  end
  local now, c = GetTime(), fromCount[k]
  if not c or now - c.since > 600 then c = { n = 0, since = now }; fromCount[k] = c end
  if c.n >= 30 then return end
  local f = Estimate.Decode(msg)
  if not f then return end
  c.n = c.n + 1
  Add(f)
end

-- Versteckter Kanal: beitreten, aus allen Chatfenstern nehmen, Beitrittsmeldung unterdrücken; abgeschaltet verlassen
local function MentionsChannel(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and v:find(SHARE_CHANNEL, 1, true) then return true end
  end
end
local filterAdded
function Estimate.UpdateChannel()
  if not db then return end
  if not filterAdded then
    filterAdded = true
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then pcall(add, "CHAT_MSG_CHANNEL_NOTICE", function(_, _, ...) return MentionsChannel(...) end) end
  end
  local joinedNow = GetChannelName and GetChannelName(SHARE_CHANNEL) or 0
  if db.shareStats and joinedNow == 0 then
    local join = JoinTemporaryChannel or JoinChannelByName
    if join then pcall(join, SHARE_CHANNEL) end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local frame = _G["ChatFrame" .. i]
      if frame and frame.RemoveChannel then pcall(frame.RemoveChannel, frame, SHARE_CHANNEL)
      elseif frame and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, frame, SHARE_CHANNEL) end
    end
  elseif not db.shareStats and joinedNow ~= 0 and LeaveChannelByName then
    pcall(LeaveChannelByName, SHARE_CHANNEL)
  end
  -- Einmaliger Hinweis, dass geteilt wird und wie man es abschaltet
  if db.shareStats and not db.shareNoticeShown then
    db.shareNoticeShown = true
    Print(T.SHARE_NOTICE)
  end
end

-------------------------------------------------------------------------
-- Anzeige
-------------------------------------------------------------------------
local function Minutes(sec)
  local m = math.max(1, math.floor(sec / 60 + 0.5))
  if m > 20 then m = math.floor(m / 5 + 0.5) * 5 end -- große Zahlen nicht genauer tun, als sie sind
  return m
end

function Estimate.FormatRange(lo, hi)
  if lo >= 3600 then return T.EST_OVER:format(60) end
  if hi == math.huge then return T.EST_OVER:format(math.max(15, Minutes(lo))) end
  if hi < 120 then return T.EST_UNDER:format(2) end
  local a, b = Minutes(lo), Minutes(hi)
  return a == b and T.EST_ABOUT:format(a) or T.EST_RANGE:format(a, b)
end

-- Eine Hauptzeile mit Zeitspanne, eine graue Zeile mit der Grundlage
function Estimate.Lines()
  local elapsed = state.queued and (GetTime() - state.queuedAt) or 0
  local lo, mid, hi, n = Estimate.History(elapsed, true)
  local source
  if n and n >= 5 then
    source = T.EST_SRC_HIST:format(n)
  end
  local lLo, lMid, lHi, role = Estimate.Live()
  if not source and lMid then
    lo, mid, hi, source = lLo, lMid, lHi, T.EST_SRC_LIVE
  elseif not source and n then
    source = T.EST_SRC_HIST:format(n)
  elseif not source then
    lo, mid, hi, n = Estimate.History(elapsed, false)
    if n then source = T.EST_SRC_ROUGH:format(n) end
  end
  if not source then
    return state.queued and { T.EST_UNKNOWN } or {}
  end
  local text = (state.queued and T.EST_REMAIN or T.EST_LIVE):format(Estimate.FormatRange(lo, hi))
  if role and hi > 120 then text = text .. T.EST_BOTTLENECK:format(ROLE_NAME[role]) end
  return { text, "|cff9d9d9d" .. source .. "|r" }
end

-------------------------------------------------------------------------
