local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Warteschlange
-------------------------------------------------------------------------
function NeedText(rem)
  if rem.any then return T.ANY_PLAYERS:format(rem.any) end
  local parts = {}
  for _, r in ipairs(ROLES) do
    if rem[r] > 0 then parts[#parts + 1] = (rem[r] > 1 and rem[r] .. "× " or "") .. ROLE_NAME[r] end
  end
  return table.concat(parts, ", ")
end

-- resume: Fortsetzen nach Abgang oder Auflösung; since = ursprünglicher Start, damit die Wartezeit stimmt
function StartQueue(resume)
  if InCombatLockdown() then Print(T.CHAT_IN_COMBAT) return end
  local reason = BlockReason()
  if reason then Print(reason); OpenWindow() return end
  if not CanInvite() then Print(T.CHAT_LEADER_ONLY) return end
  local _, ids = SearchActivities()
  if #ids == 0 then Print(T.PICK_ACTIVITY) return end
  if (db.playstyle or 0) == 0 then Print(GROUP_FINDER_PLAYSTYLE_REQUIRED or T.PLAYSTYLE_REQUIRED) return end
  local rem = Slots()
  if not AnyLeft(rem) then Print(T.CHAT_NO_ROLE) return end
  state.queued, state.queuedAt, state.lastSearchAt, state.searching = true, resume and resume.since or GetTime(), 0, nil
  state.resume, state.runDone, state.unlist = nil, nil, nil
  wipe(state.lastSupply)
  Estimate.OnStart()
  char.groupActivityID = ids[1]
  local okList, err = api.list({
    activityIDs = ids,
    generalPlaystyle = db.playstyle,
    voiceMode = db.voice,
    newPlayerFriendly = db.newPlayerFriendly and true or false,
  }, { tank = char.myRoles.TANK or false, healer = char.myRoles.HEALER or false, dps = char.myRoles.DAMAGER or false })
  if not okList then Print(T.CHAT_LIST_FAILED:format(tostring(err))) end
  -- Kein Suchen im selben Klick: Blizzard erlaubt nur eine geschützte Aktion pro Klick, das Eintragen hat sie
  -- verbraucht (sonst ADDON_ACTION_BLOCKED). Die erste Suche läuft beim nächsten Klick oder Tastendruck.
  if resume then
    Print(T.CHAT_RESUMED:format(NeedText(rem)))
  else
    CloseWindow()
    Print(T.CHAT_STARTED:format(NeedText(rem)))
    Print(T.CHAT_NEXT_CLICK)
  end
  UpdateMinimap()
end

-- click: Aufruf aus Klick oder Taste. Austragen ist geschützt; sonst erledigt es der nächste Klick.
function StopQueue(msg, click)
  state.queued = false
  if click then api.unlist() else state.unlist = true end
  if msg then Print(msg) end
  UpdateMinimap()
  if UpdateUI then UpdateUI() end
end

function FinishQueue()
  Estimate.RecordFill(GetTime() - state.queuedAt, state.lastJoinRole)
  char.lastFill = { s = GetTime() - state.queuedAt, t = time() }
  if state.historyEntry then state.historyEntry.wait = math.floor(char.lastFill.s) end
  db.page = 4 -- beim nächsten Öffnen die Gruppenübersicht
  state.completed, state.backfillNoted = true, false
  StopQueue(T.CHAT_COMPLETE)
  Stone.Set("found")
  Ding()
  if Notify then Notify(T.CHAT_COMPLETE) end
end

-- Gruppe steht und du führst: Taste, Minimap und Knopf starten den Bereitschaftscheck.
function GroupReady()
  return not state.queued and IsInGroup() and UnitIsGroupLeader("player") and not AnyLeft((Slots()))
end

function _G.AutoGroupFinder_Next()
  if GroupReady() then
    api.readyCheck()
  elseif state.queued then
    DoSearch(true)
  elseif state.resume then
    StartQueue(state.resume)
  else
    -- Starten nur über den Knopf im Fenster, wo Rollen, Dungeons und Spielstil zu sehen sind
    OpenWindow()
  end
end
function _G.AutoGroupFinder_Refresh() DoSearch(true) end

-------------------------------------------------------------------------
