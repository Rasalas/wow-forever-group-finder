local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Zusätzliches für den Verlauf aus Blizzards eigenen Systemen: Schadensmesser (Schaden, Heilung,
-- Tode je Spieler) und Beute je Boss. Nur lesen; fehlt ein System oder ist ein Wert geheim, bleibt es leer.
-------------------------------------------------------------------------
local DMT = (Enum and Enum.DamageMeterType) or {}
local METER = { d = DMT.DamageDone or 0, h = DMT.HealingDone or 2, x = DMT.Deaths or 9 }
local OVERALL = (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall) or 0

-- Gesamtsitzung des Schadensmessers: Name -> { d, h, x, c }
local function ReadOverall()
  local DM = _G.C_DamageMeter
  if not (DM and DM.GetCombatSessionFromType) then return nil end
  local okA, available = pcall(DM.IsDamageMeterAvailable)
  if not (okA and available) then return nil end
  local out = {}
  for key, kind in pairs(METER) do
    local ok, session = pcall(DM.GetCombatSessionFromType, OVERALL, kind)
    for _, s in ipairs(ok and session and session.combatSources or {}) do
      local name = Readable(s.name) and s.name
      local amount = Readable(s.totalAmount) and s.totalAmount or nil
      if name and name ~= "" and (amount or key == "x") then
        local e = out[name] or { c = s.classFilename }
        out[name] = e
        -- Tode: je Quelle ein Eintrag pro Tod oder eine Anzahl, je nach Client
        if key == "x" then e.x = (e.x or 0) + math.max(1, amount or 1) else e[key] = (e[key] or 0) + amount end
      end
    end
  end
  return out
end

local function Diff(now, base)
  local out = {}
  for name, v in pairs(now or {}) do
    local b = base and base[name] or {}
    local e = { c = v.c }
    for _, k in ipairs({ "d", "h", "x" }) do
      local n = (v[k] or 0) - (b[k] or 0)
      if n > 0 then e[k] = n end
    end
    if e.d or e.h or e.x then out[name] = e end
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

-- Je Abschnitt: Stand beim Betreten (base), Gesammeltes vor einem Zurücksetzen (acc), Ergebnis (meter)
function History.MeterStart(r)
  r.meterBase = ReadOverall() or {}
end
function History.MeterUpdate(r)
  if not (r and r.meterBase) then return end
  local now = ReadOverall()
  if not now then return end
  r.meterLast = now
  r.meter = Diff(now, r.meterBase)
  Add(r.meter, r.meterAcc)
end
local function MeterReset()
  local r = History.Run(state.historyEntry)
  if not (r and r.meterBase) then return end
  r.meterAcc = r.meterAcc or {}
  Add(r.meterAcc, Diff(r.meterLast, r.meterBase))
  r.meterBase, r.meterLast = {}, nil
end

-- Beute: wer bei welchem Boss was bekommen hat
local function LootDrop(encounterID, key)
  local LH = _G.C_LootHistory
  local r = History.Run(state.historyEntry)
  if not (r and LH and LH.GetSortedInfoForDrop) then return end
  local ok, info = pcall(LH.GetSortedInfoForDrop, encounterID, key)
  local w = ok and info and info.winner
  if not (w and Readable(w.playerName) and Readable(info.itemHyperlink)) then return end
  r.loot = r.loot or {}
  r.loot[encounterID .. ":" .. key] = { enc = encounterID, link = info.itemHyperlink, who = w.playerName, c = w.playerClass }
end

local rec = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "DAMAGE_METER_RESET", "LOOT_HISTORY_UPDATE_DROP" }) do
  pcall(rec.RegisterEvent, rec, e)
end
rec:SetScript("OnEvent", function(_, event, a1, a2)
  if not db then return end
  if event == "PLAYER_REGEN_ENABLED" then
    History.MeterUpdate(History.Run(state.historyEntry))
  elseif event == "DAMAGE_METER_RESET" then
    MeterReset()
  elseif event == "LOOT_HISTORY_UPDATE_DROP" then
    LootDrop(a1, a2)
  end
end)

-------------------------------------------------------------------------
