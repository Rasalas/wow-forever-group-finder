local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Zusätzliches für den Verlauf aus Blizzards eigenen Systemen: Schadensmesser (Schaden, Heilung,
-- Tode je Spieler) und Beute je Boss. Nur lesen; fehlt ein System oder ist ein Wert geheim, bleibt es leer.
-------------------------------------------------------------------------
local DMT = (Enum and Enum.DamageMeterType) or {}
local METER = { d = DMT.DamageDone or 0, h = DMT.HealingDone or 2, x = DMT.Deaths or 9 }

local function Meter()
  local dm = _G.C_DamageMeter
  if not (dm and dm.GetAvailableCombatSessions and dm.GetCombatSessionFromID) then return nil end
  local ok, available = pcall(dm.IsDamageMeterAvailable)
  return ok and available and dm or nil
end
-- Höchste Nummer der vorhandenen Kampf-Abschnitte (fortlaufend je Kampf)
local function LastSession(dm)
  local ok, list = pcall(dm.GetAvailableCombatSessions)
  local max = 0
  for _, s in ipairs(ok and list or {}) do if s.sessionID > max then max = s.sessionID end end
  return max, ok and list or {}
end
-- Ein Abschnitt: Name -> { d, h, x, c }. Im Kampf geheime Einträge fehlen und kommen beim nächsten Lesen.
local function ReadSession(dm, id)
  local out = {}
  for key, kind in pairs(METER) do
    local ok, session = pcall(dm.GetCombatSessionFromID, id, kind)
    for _, s in ipairs(ok and session and session.combatSources or {}) do
      if Readable(s.name) and Readable(s.totalAmount) and s.name ~= "" then
        local e = out[s.name] or { c = s.classFilename }
        out[s.name] = e
        -- Tode: je Quelle ein Eintrag pro Tod oder eine Anzahl, je nach Client
        if key == "x" then e.x = (e.x or 0) + math.max(1, s.totalAmount or 1) else e[key] = (e[key] or 0) + (s.totalAmount or 0) end
      end
    end
  end
  return out
end
local function Add(into, add)
  for name, v in pairs(add or {}) do
    local e = into[name] or { c = v.c }
    into[name] = e
    for _, k in ipairs({ "d", "h", "x" }) do if v[k] then e[k] = (e[k] or 0) + v[k] end end
  end
end

-- Jeder Kampf ist ein Abschnitt mit fortlaufender Nummer. Ein Lauf hebt die Abschnitte seit dem Betreten
-- einzeln auf (fights), neue nur drinnen; draußen werden bekannte nur noch fertig gelesen.
-- Nach einem Zurücksetzen beginnen die Nummern neu, darum epoch im Schlüssel.
local outside
local function FightKey(r, id) return (r.meterEpoch or 0) * 100000 + id end
function History.MeterStart(r)
  local dm = Meter()
  local fresh = outside and GetTime() - outside.t < 120 and outside.last
  outside = nil -- nur für dieses Betreten
  local last = fresh or (dm and LastSession(dm))
  if last then r.meterFrom, r.fights = last + 1, {} end
end
function History.MeterUpdate(r)
  local dm = Meter()
  if not (dm and r and r.meterFrom) then return end
  local adding = not r.exit and IsInInstance()
  local _, list = LastSession(dm)
  for _, s in ipairs(list) do
    local id = s.sessionID
    local k = FightKey(r, id)
    local f = r.fights[k]
    if id >= r.meterFrom and (f or adding) then
      f = f or { t = time() } -- erstmals gelesen, kurz nach Kampfende
      if Readable(s.name) and s.name ~= "" then f.n = s.name end
      if Readable(s.durationSeconds) and s.durationSeconds then f.dur = math.floor(s.durationSeconds + 0.5) end
      f.m = f.m or {}
      for name, v in pairs(ReadSession(dm, id)) do f.m[name] = v end
      r.fights[k] = f
    end
  end
  local meter = {}
  for _, f in pairs(r.fights) do Add(meter, f.m) end
  r.meter = meter
end
-- Schlüssel des laufenden Kampfes (für den Boss bei ENCOUNTER_END)
function History.CurrentFight(r)
  local dm = Meter()
  if not (dm and r and r.meterFrom) then return nil end
  local last = LastSession(dm)
  return last >= r.meterFrom and FightKey(r, last) or nil
end
-- Ende eines Abschnitts; im Dungeon erst draußen fertig ablesen (dort ist nichts mehr geheim)
function History.MeterFinish(r)
  History.MeterUpdate(r)
  if r then r.meterPending = (IsInInstance() and r.meterFrom) and true or nil end
end
local function FinishPending()
  if IsInInstance() or not char then return end
  for i = 1, math.min(3, #char.history) do
    for _, r in ipairs(char.history[i].runs or {}) do
      if r.meterPending then History.MeterFinish(r) end
    end
  end
end
local function MeterReset()
  local r = History.Run(state.historyEntry)
  if not (r and r.meterFrom) then return end
  r.meterEpoch, r.meterFrom = (r.meterEpoch or 0) + 1, 0
end

-- Beute: wer bei welchem Boss was bekommen hat
local function LootDrop(encounterID, key)
  local LH = _G.C_LootHistory
  local r = History.Run(state.historyEntry)
  if not (r and LH and LH.GetSortedInfoForDrop) then return end
  local ok, info = pcall(LH.GetSortedInfoForDrop, encounterID, key)
  local w = ok and info and info.winner
  if not (w and Readable(w.playerName) and Readable(info.itemHyperlink)) then return end
  -- Würfe: state 0 Bedarf, 1 Zweitspez., 2 Transmog, 3 Gier, 4 kein Wurf, 5 Passen
  local rolls = {}
  for _, x in ipairs(info.rollInfos or {}) do
    if AllReadable(x, "playerName", "state", "roll") and x.state ~= 4 then
      rolls[#rolls + 1] = { n = x.playerName, c = x.playerClass, s = x.state, r = x.roll }
    end
  end
  r.loot = r.loot or {}
  r.loot[encounterID .. ":" .. key] = { enc = encounterID, link = info.itemHyperlink, who = w.playerName, c = w.playerClass,
    s = Readable(w.state) and w.state or nil, r = Readable(w.roll) and w.roll or nil, rolls = #rolls > 0 and rolls or nil }
end

local rec = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "DAMAGE_METER_RESET", "LOOT_HISTORY_UPDATE_DROP", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD" }) do
  pcall(rec.RegisterEvent, rec, e)
end
rec:SetScript("OnEvent", function(_, event, a1, a2)
  if not db then return end
  if event == "PLAYER_REGEN_ENABLED" then
    -- kurz warten, bis der Abschnitt abgeschlossen und nicht mehr geheim ist
    C_Timer.After(2, function() History.MeterUpdate(History.Run(state.historyEntry)) end)
  elseif event == "DAMAGE_METER_RESET" then
    MeterReset()
  elseif event == "LOOT_HISTORY_UPDATE_DROP" then
    LootDrop(a1, a2)
  elseif event == "PLAYER_LEAVING_WORLD" then
    local dm = not IsInInstance() and Meter()
    if dm then outside = { t = GetTime(), last = LastSession(dm) } end
  elseif event == "PLAYER_ENTERING_WORLD" then
    FinishPending()
  end
end)

-------------------------------------------------------------------------
