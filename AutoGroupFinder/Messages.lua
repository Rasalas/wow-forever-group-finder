local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Hat der Einladende das Add-on auch, schickt er mit, wofür er einlädt.
function OnAddonMessage(prefix, message, _, sender)
  if prefix ~= COMM_PREFIX or not message or not sender then return end
  if message:sub(1, 2) == "v=" then Estimate.OnNet(message, sender) return end -- Format mit benannten Feldern
  local kind, activity, role, _, _, playstyle, enc, activityID = strsplit("\t", message)
  if kind == "INV" then
    local comp, i = {}, 0
    for pair in (enc or ""):gmatch("[^;]+") do
      i = i + 1
      local f, n = pair:match("(%d+),(%d+)")
      if ROLES[i] and f then comp[ROLES[i]] = { tonumber(f), tonumber(n) } end
    end
    local data = { activity = activity, role = role, playstyle = tonumber(playstyle),
      comp = comp, activityID = tonumber(activityID), t = GetTime() }
    InviteInfo.byAddon[Key(sender)] = data
    Print(T.COMM_INVITED:format(Short(sender), (activity or "?") .. " · " .. (ROLE_NAME[role] or role or "?")))
    -- Nachricht kann nach dem Einladungsfenster ankommen
    if state.lastInviter and Key(state.lastInviter) == Key(sender) then InviteInfo.Show(sender) end
  end
end

function OnSystem(msg)
  local n = MsgName(msg, PAT.invited)
  if n then
    local k = FindPending(n)
    if k then pending[k].confirmed = true end
    return
  end
  local cases = {
    { PAT.declined, db.declineCooldown, T.CHAT_DECLINED },
    { PAT.busy, 600, T.CHAT_BUSY },
    { PAT.bad, 1800, T.CHAT_UNREACHABLE },
    { PAT.ignoring, 86400, T.CHAT_IGNORING },
  }
  for _, case in ipairs(cases) do
    n = MsgName(msg, case[1])
    if n then
      local k = FindPending(n)
      if k then DropPending(k, case[2], case[3]) end
      return
    end
  end
end

-------------------------------------------------------------------------
