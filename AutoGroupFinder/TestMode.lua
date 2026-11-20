local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Testlauf mit erfundenen Spielern: keine echte Suche, keine echten Einladungen
-------------------------------------------------------------------------
function Shot()
  if test and test.shots and Screenshot then Screenshot() end
end

function EndTest()
  if not test then return end
  for k, v in pairs(test.saved) do db[k] = v end
  char.myRoles = test.myRoles
  test = nil
  api = real
  state.queued = false
  UpdateMinimap()
  wipe(pending) wipe(joined) wipe(expired) wipe(seen)
  Rebuild()
  Print(T.TEST_DONE)
end

function RunTest(shots)
  if test then Print(T.TEST_RUNNING) return end
  if state.queued then Print(T.TEST_STOP_REAL) return end
  test = { results = {}, party = {}, nextId = 1, shots = shots,
    saved = { skipUntil = db.skipUntil, inviteWhisper = db.inviteWhisper,
      inviteTimeout = db.inviteTimeout, autoInvite = db.autoInvite,
      category = db.category, page = db.page, view = db.view, playstyle = db.playstyle } }
  test.myRoles, char.myRoles = char.myRoles, { DAMAGER = true }
  db.inviteTimeout, db.autoInvite, db.category, db.page = 10, true, 2, 1
  db.view, db.playstyle = "activities", (db.playstyle ~= 0 and db.playstyle or 2)
  db.skipUntil = {}
  local _, ids = SearchActivities()
  local act = ids[1]
  if not act then
    for k, v in pairs(test.saved) do db[k] = v end
    char.myRoles = test.myRoles
    test = nil
    Print(T.TEST_NO_DUNGEON)
    return
  end
  wipe(pending) wipe(joined) wipe(expired) wipe(seen)

  local outcome = {}
  local function add(name, class, roles, age, result, extra)
    local id = test.nextId
    test.nextId = id + 1
    local info = { searchResultID = id, leaderName = name, numMembers = 1, isDelisted = false,
      hasSelf = false, activityIDs = { act }, age = age, generalPlaystyle = 2, voiceMode = 0 }
    for k, v in pairs(extra or {}) do info[k] = v end
    test.results[id] = { info = info,
      leader = { name = name, lfgRoles = roles, classFilename = class, level = UnitLevel("player") } }
    outcome[name] = result
  end
  add("Ulgrim Steinfaust", "WARRIOR", { tank = true }, 600, "accept")
  add("Brakthor Eisenhand", "PALADIN", { tank = true, dps = true }, 5, "decline")
  add("Hagen Gruppfeld", "WARRIOR", { tank = true }, 1, "accept", { numMembers = 3 })
  add("Mira Quellsang", "PRIEST", { healer = true }, 1, "accept", { isDelisted = true })
  add("Rowan Falkner", "DRUID", { healer = true }, 2, "accept", { activityIDs = { -1 } })
  add("Lunaria Silberblatt", "PRIEST", { healer = true }, 30, "silent")
  add("Kaelis Schattenklinge", "ROGUE", { dps = true }, 40, "busy")
  add("Vexa Sternfeuer", "MAGE", { dps = true }, 50, "accept")
  add("Morrin Wolfsherz", "HUNTER", { dps = true }, 70, "accept")

  local after = C_Timer.After
  api = {
    results = function()
      local t = {}
      for id in pairs(test.results) do t[#t + 1] = id end
      table.sort(t)
      return t
    end,
    info = function(id) return test.results[id].info end,
    leader = function(id) return test.results[id].leader end,
    search = function()
      Print(T.TEST_SEARCH)
      after(0.8, function() if test then OnResults() end end)
      return true
    end,
    invite = function(name)
      OnSystem(ERR_INVITE_PLAYER_S:format(name))
      local o = outcome[name]
      if o == "decline" then
        after(2, function() if test then OnSystem(ERR_DECLINE_GROUP_S:format(name)) end end)
      elseif o == "busy" then
        after(1.5, function() if test then OnSystem(ERR_ALREADY_IN_GROUP_S:format(name)) end end)
      elseif o == "accept" then
        after(3, function()
          if test then tinsert(test.party, name) OnRoster() end
        end)
      end -- "silent" antwortet nie und läuft in die Zeitüberschreitung
    end,
    members = function()
      local t = {}
      for i, n in ipairs(test.party) do t[i] = { unit = "party" .. i, name = n } end
      return t
    end,
    unitRole = function() return "NONE" end,
    groupSize = function() return #test.party > 0 and #test.party + 1 or 0 end,
    isRaid = function() return false end,
    convertToRaid = function() end,
    list = function() return true end,
    unlist = function() end,
    setRole = function() return true end,
    whisper = function(name, text) Print("[Test] → " .. name .. ": " .. text) end,
    canInvite = function() return true end,
    readyCheck = function() Print("[Test] ready check") end,
    comm = function() end,
  }

  Print(T.TEST_START)
  win:Show()
  ShowPage(1)
  after(1.5, Shot)
  after(3, function() if test then StartQueue() end end)
  after(6.5, function() if test then win:Show() ShowPage(2) end end)
  after(7.5, Shot)
  after(9, function() if test then win:Hide() end end)
  after(15, function()
    if not test then return end
    Print(T.TEST_NEW_HEALER)
    add("Seraphine Lichtweber", "PRIEST", { healer = true }, 2, "accept")
    state.lastSearchAt = 0
    DoSearch(false)
  end)
  after(21, function() if test then win:Show() ShowPage(1) end end)
  after(22, Shot)
  after(24, EndTest)
end

-- /gf test minimap: wo steckt das Symbol, und spielt es die Animationen ab?
function TestMinimap()
  if db.minimap.hide then Print(T.TEST_MM_HIDDEN:format(SLASH)) return end
  local p = mm:GetParent()
  Print(p == Minimap and T.TEST_MM_RIM or p == UIParent and T.TEST_MM_FREE or T.TEST_MM_COLLECTED)
  Print(T.TEST_MM_ANIM)
  if not mmEye then mmGlow:Show(); pulse:Play() end
  Eye.Set("search")
  C_Timer.After(6, function() Eye.Set("found") end)
  C_Timer.After(9, UpdateMinimap)
end
