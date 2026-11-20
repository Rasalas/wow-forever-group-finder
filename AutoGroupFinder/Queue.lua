local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Warteschlange
-------------------------------------------------------------------------
function NeedText(rem)
  local parts = {}
  for _, r in ipairs(ROLES) do
    if rem[r] > 0 then parts[#parts + 1] = (rem[r] > 1 and rem[r] .. "× " or "") .. ROLE_NAME[r] end
  end
  return table.concat(parts, ", ")
end

function StartQueue()
  if InCombatLockdown() then Print(T.CHAT_IN_COMBAT) return end
  local reason = BlockReason()
  if reason then Print(reason); OpenWindow() return end
  if not CanInvite() then Print(T.CHAT_LEADER_ONLY) return end
  local _, ids = SearchActivities()
  if #ids == 0 then Print(T.PICK_ACTIVITY) return end
  if (db.playstyle or 0) == 0 then Print(GROUP_FINDER_PLAYSTYLE_REQUIRED or T.PLAYSTYLE_REQUIRED) return end
  local rem = Slots()
  if not AnyLeft(rem) then Print(T.CHAT_NO_ROLE) return end
  state.queued, state.queuedAt, state.lastSearchAt = true, GetTime(), 0
  wipe(state.lastSupply)
  Estimate.OnStart()
  local okList, err = api.list({
    activityIDs = ids,
    generalPlaystyle = db.playstyle,
    voiceMode = db.voice,
    newPlayerFriendly = db.newPlayerFriendly and true or false,
  }, { tank = char.myRoles.TANK or false, healer = char.myRoles.HEALER or false, dps = char.myRoles.DAMAGER or false })
  if not okList then Print(T.CHAT_LIST_FAILED:format(tostring(err))) end
  DoSearch(true)
  CloseWindow()
  Print(T.CHAT_STARTED:format(NeedText(rem)))
  UpdateMinimap()
end

function StopQueue(msg)
  state.queued = false
  api.unlist()
  if msg then Print(msg) end
  UpdateMinimap()
  if UpdateUI then UpdateUI() end
end

function FinishQueue()
  Estimate.RecordFill(GetTime() - state.queuedAt, state.lastJoinRole)
  state.completed, state.backfillNoted = true, false
  StopQueue(T.CHAT_COMPLETE)
  Eye.Set("found")
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
  else
    -- Starten nur über den Knopf im Fenster, wo Rollen, Dungeons und Spielstil zu sehen sind
    OpenWindow()
  end
end
function _G.AutoGroupFinder_Refresh() DoSearch(true) end

-------------------------------------------------------------------------
