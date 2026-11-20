local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Suche (Blizzard erlaubt sie nur direkt nach Klick oder Tastendruck)
-------------------------------------------------------------------------
function FoundPageOpen() return win and win:IsShown() and db.page == 2 end


function DoSearch(force)
  if not db then return end
  if HardwareTick then HardwareTick() end
  if InCombatLockdown() then return end
  if not force and not (state.queued or FoundPageOpen()) then return end
  -- Umwandeln ist ebenfalls nur nach Klick oder Taste erlaubt, darum hier.
  if state.queued and NeedsRaid() and CanInvite() then
    api.convertToRaid()
    Print(T.CHAT_CONVERTED)
  end
  local now = GetTime()
  if state.searching and now - state.searching < 10 then return end
  if now - state.lastSearchAt < (force and 2 or db.interval) then return end
  local tree, ids = ActivityTree(), {}
  for _, e in ipairs(tree.all) do ids[#ids + 1] = e.id end
  local cat = tree.cat
  if not cat or #ids == 0 then
    Print(T.CHAT_NO_ACTIVITIES)
    return
  end
  state.searching, state.lastSearchAt = now, now
  local ok, err = api.search(cat, ids, LanguageFilter())
  if not ok then
    state.searching = nil
    Print(T.CHAT_SEARCH_FAILED:format(tostring(err)))
  end
  if UpdateUI then UpdateUI() end
end

-------------------------------------------------------------------------
-- Einladen, Absagen, Zeitüberschreitung
-------------------------------------------------------------------------
function Pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  return (fmt:gsub("%%s", "(.+)"))
end
PAT = {
  invited = Pattern(ERR_INVITE_PLAYER_S),
  declined = Pattern(ERR_DECLINE_GROUP_S),
  busy = Pattern(ERR_ALREADY_IN_GROUP_S),
  bad = Pattern(ERR_BAD_PLAYER_NAME_S),
  ignoring = Pattern(ERR_IGNORING_YOU_S),
}

-- Flüstern braucht bei Blizzard einen Klick oder Tastendruck: Bei automatischen Einladungen
-- geht die Nachricht mit dem nächsten Klick raus, aber nur kurz danach.
whisperQueue = {}
function WhisperText(c, role)
  local text = (db.whisperText and db.whisperText ~= "") and db.whisperText or T.WHISPER_DEFAULT
  text = text:gsub("{dungeon}", c.activityText or c.activity or "")
  return (text:gsub("{role}", ROLE_NAME[role]))
end

function Invite(c, role, byClick)
  -- Ohne Bestätigungstext im Client lässt sich ein fehlgeschlagener Invite nicht erkennen.
  pending[c.key] = { role = role, t = GetTime(), confirmed = PAT.invited == nil }
  Estimate.Invited(role)
  expired[c.key] = nil
  api.invite(c.name)
  Print(T.CHAT_INVITING:format(Short(c.name), ROLE_NAME[role]))
  local comp = Composition()
  local enc = {}
  for _, r in ipairs(ROLES) do enc[#enc + 1] = comp[r][1] .. "," .. comp[r][2] end
  api.comm("INV", table.concat({ (c.activityText or c.activity or ""):sub(1, 120), role,
    math.max(1, api.groupSize()), select(3, Target()), db.playstyle or 0, table.concat(enc, ";"),
    c.matchedActivity or "" }, "\t"), c.name)
  if db.inviteWhisper then
    if byClick then
      api.whisper(c.name, WhisperText(c, role))
    else
      whisperQueue[#whisperQueue + 1] = { name = c.name, text = WhisperText(c, role), t = GetTime() }
    end
  end
end

function AutoInvite()
  if not (state.queued and db.autoInvite and CanInvite()) or InCombatLockdown() then return end
  local held = HeldRoles()
  for _, c in ipairs(candidates) do
    if RoomLeft() <= 0 then break end
    local _, open = Slots()
    for r in pairs(held) do open[r] = 0 end
    local role = not pending[c.key] and RoleFor(c, open)
    if role then Invite(c, role) end
  end
  Rebuild()
end

function DropPending(k, cooldown, msg)
  local p = pending[k]
  if not p then return end
  pending[k] = nil
  expired[k] = p.role
  db.skipUntil[k] = time() + cooldown
  if msg then Print(msg:format(Short(k))) end
  Rebuild()
  AutoInvite() -- sofort den Nächsten aus den vorhandenen Ergebnissen
end

function FindPending(name)
  local k = Key(name)
  if pending[k] then return k end
  for pk in pairs(pending) do
    if Short(pk) == Short(name) then return pk end
  end
end

function MsgName(msg, pat)
  local n = pat and msg:match(pat)
  if n then return n:match("%[(.-)%]") or n end
end
