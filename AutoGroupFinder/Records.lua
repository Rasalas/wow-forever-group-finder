local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Zusätzliches für den Verlauf aus Blizzards eigenen Systemen: Schadensmesser (Schaden, Heilung,
-- Tode je Spieler) und Beute je Boss. Nur lesen; fehlt ein System oder ist ein Wert geheim, bleibt es leer.
-------------------------------------------------------------------------
local DMT = (Enum and Enum.DamageMeterType) or {}
-- d Schaden, h Heilung, t erlitten, a davon vermeidbar, i Unterbrechungen, p Bannen, x Tode
local METER = { d = DMT.DamageDone or 0, h = DMT.HealingDone or 2, t = DMT.DamageTaken or 7,
  a = DMT.AvoidableDamageTaken or 8, i = DMT.Interrupts or 5, p = DMT.Dispels or 6, x = DMT.Deaths or 9 }
METER_KEYS = { "d", "h", "t", "a", "i", "p", "x" }

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
        if key == "x" then
          e.x = (e.x or 0) + math.max(1, s.totalAmount or 1)
          if Readable(s.deathRecapID) and s.deathRecapID and s.deathRecapID > 0 then e.r = s.deathRecapID end -- Todesbericht
        else
          e[key] = (e[key] or 0) + (s.totalAmount or 0)
        end
      end
    end
  end
  return out
end
local function Add(into, add)
  for name, v in pairs(add or {}) do
    local e = into[name] or { c = v.c }
    into[name] = e
    for _, k in ipairs(METER_KEYS) do if v[k] then e[k] = (e[k] or 0) + v[k] end end
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
  local adding = History.Counting(r)
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

-- Eigene Werte je Lauf (nie geheim): Erfahrung, Stufen, Gold, Haltbarkeit, erledigte Quests, eigene Beute.
-- Gezählt wird nur drinnen; draußen wird nur der Vergleichsstand nachgeführt.
-------------------------------------------------------------------------
local xpLast, moneyLast, bagsLast
-- Zählt gerade: Dungeon-Lauf drinnen, Abschnitt „world“ draußen
local function Inside(r)
  if not r or r.exit then return false end
  local inside = IsInInstance() and true or false
  return inside ~= (r.world or false)
end
History.Counting = Inside
local function XP()
  if not (UnitXP and UnitXPMax) then return nil end
  return { lvl = UnitLevel("player"), xp = UnitXP("player"), max = UnitXPMax("player") }
end
local function Money() return GetMoney and GetMoney() or nil end
-- Durchschnittliche Haltbarkeit der Ausrüstung in Prozent
local function Durability()
  local cur, max = 0, 0
  if not GetInventoryItemDurability then return nil end
  for slot = 1, 18 do
    local c, m = GetInventoryItemDurability(slot)
    if c and m and m > 0 then cur, max = cur + c, max + m end
  end
  return max > 0 and math.floor(cur / max * 100 + 0.5) or nil
end
-- Alles in Taschen und am Körper: itemID -> { n, link, q }; Umziehen ändert so nichts
local function Inventory()
  local out = {}
  local C = _G.C_Container
  if C and C.GetContainerNumSlots then
    for bag = 0, 5 do
      local okN, n = pcall(C.GetContainerNumSlots, bag)
      for slot = 1, okN and n or 0 do
        local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
        if ok and info and info.itemID then
          local x = out[info.itemID] or { n = 0, link = info.hyperlink, q = info.quality }
          out[info.itemID] = x
          x.n = x.n + (info.stackCount or 1)
        end
      end
    end
  end
  for slot = 1, GetInventoryItemID and 19 or 0 do
    local id = GetInventoryItemID("player", slot)
    if id then
      local x = out[id] or { n = 0, link = GetInventoryItemLink("player", slot) }
      out[id] = x
      x.n = x.n + 1
    end
  end
  return out
end
local function CompleteQuests()
  local out, Q = {}, _G.C_QuestLog
  if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo and Q.IsComplete) then return out end
  for i = 1, Q.GetNumQuestLogEntries() or 0 do
    local info = Q.GetInfo(i)
    if info and not info.isHeader and info.questID and Q.IsComplete(info.questID) then out[info.questID] = info.title or true end
  end
  return out
end

function History.PersonalStart(r, resumed)
  xpLast, moneyLast, bagsLast = XP(), Money(), Inventory()
  if not resumed then r.durStart = Durability() end
  r.durEnd = nil
  r.questBase = CompleteQuests()
end
function History.PersonalExit(r)
  r.durEnd = Durability()
  -- Quests, deren Ziele in diesem Lauf fertig wurden
  for id, title in pairs(CompleteQuests()) do
    if r.questBase and not r.questBase[id] then
      r.quests = r.quests or {}
      r.quests[id] = type(title) == "string" and title or r.quests[id] or true
    end
  end
  r.questBase = nil
end

local function OnXP()
  local now, r = XP(), History.Run(state.historyEntry)
  local last = xpLast
  xpLast = now
  if not (now and last and Inside(r)) then return end
  local gain = now.lvl == last.lvl and now.xp - last.xp or now.lvl == last.lvl + 1 and (last.max - last.xp) + now.xp or 0
  if gain > 0 then r.xp = (r.xp or 0) + gain end
  if now.lvl > last.lvl then r.lvlFrom, r.lvlTo = r.lvlFrom or last.lvl, now.lvl end
end
local function OnMoney()
  local now, r = Money(), History.Run(state.historyEntry)
  local gain = now and moneyLast and now - moneyLast or 0
  moneyLast = now
  if gain > 0 and Inside(r) then r.money = (r.money or 0) + gain end
end
local function OnBags()
  local now, r = Inventory(), History.Run(state.historyEntry)
  local last = bagsLast
  bagsLast = now
  if not (last and Inside(r)) then return end
  for id, x in pairs(now) do
    local gain = x.n - (last[id] and last[id].n or 0)
    if gain > 0 and x.q ~= 0 then -- ohne Graues
      r.mine = r.mine or {}
      local m = r.mine[id] or { link = x.link, n = 0, t = time() }
      r.mine[id] = m
      m.n = m.n + gain
    end
  end
end
local function OnQuestDone(questID)
  local r = History.Run(state.historyEntry)
  if not (r and Readable(questID) and questID) then return end
  local Q = _G.C_QuestLog
  local title = Q and Q.GetTitleForQuestID and Q.GetTitleForQuestID(questID)
  r.quests = r.quests or {}
  r.quests[questID] = title or r.quests[questID] or true
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
  local k = encounterID .. ":" .. key
  local seen = r.loot[k] and r.loot[k].t -- wann gefallen: für Trash-Beute (Boss 0) im Ablauf
  r.loot[k] = { enc = encounterID, t = seen or time(), link = info.itemHyperlink, who = w.playerName, c = w.playerClass,
    s = Readable(w.state) and w.state or nil, r = Readable(w.roll) and w.roll or nil, rolls = #rolls > 0 and rolls or nil }
end

local rec = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "DAMAGE_METER_RESET", "LOOT_HISTORY_UPDATE_DROP", "PLAYER_LEAVING_WORLD",
  "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "BAG_UPDATE_DELAYED",
  "PLAYER_EQUIPMENT_CHANGED", "QUEST_TURNED_IN" }) do
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
    if not xpLast then xpLast, moneyLast, bagsLast = XP(), Money(), Inventory() end
  elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    OnXP()
  elseif event == "PLAYER_MONEY" then
    OnMoney()
  elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
    OnBags()
  elseif event == "QUEST_TURNED_IN" then
    OnQuestDone(a1)
  end
end)

-------------------------------------------------------------------------
