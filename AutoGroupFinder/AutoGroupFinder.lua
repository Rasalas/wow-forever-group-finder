local ADDON, ns = ...
local T = ns.T
local SLASH = "/gf"

local loadError
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff" .. T.TITLE .. ":|r " .. tostring(msg))
end

-- Zeigt, was der Client an Group-Finder-Schnittstellen hat.
local function Diag()
  Print("Client: " .. tostring(select(4, GetBuildInfo())) .. " / " .. tostring((GetBuildInfo())))
  local L = C_LFGList
  Print("C_LFGList: " .. tostring(L ~= nil))
  if not L then return end
  for _, f in ipairs({ "Search", "GetSearchResults", "GetSearchResultInfo", "GetSearchResultLeaderInfo",
      "GetActivityInfoTable", "GetAvailableCategories", "GetAvailableActivities",
      "GetAvailableActivityGroups", "GetActivityGroupInfo", "GetLfgCategoryInfo" }) do
    Print("  " .. f .. ": " .. tostring(L[f] ~= nil))
  end
  if L.GetAvailableCategories then
    for _, c in ipairs(L.GetAvailableCategories() or {}) do
      local ci = L.GetLfgCategoryInfo and L.GetLfgCategoryInfo(c)
      local acts = L.GetAvailableActivities and L.GetAvailableActivities(c) or {}
      Print(("  %s: %s (%d)"):format(tostring(c), tostring(type(ci) == "table" and ci.name or ci), #acts))
    end
  end
end

-- Zuerst registrieren, damit der Befehl auch antwortet, wenn der Rest beim Laden scheitert.
SLASH_AUTOGROUPFINDER1 = SLASH
SLASH_AUTOGROUPFINDER2 = "/groupfinder"
SlashCmdList.AUTOGROUPFINDER = function(msg)
  local raw = strtrim(msg or "")
  msg = strlower(raw)
  if msg == "diag" or loadError or not AutoGroupFinder_Slash then
    if loadError then Print("|cffff4040" .. T.LOAD_FAILED .. "|r " .. loadError) end
    Diag()
    return
  end
  AutoGroupFinder_Slash(msg, raw)
end

local function Init()
  local L = C_LFGList
  if not (L and L.Search and L.GetSearchResults and L.GetSearchResultInfo) then
    error("C_LFGList is missing in this client")
  end

  BINDING_HEADER_AUTOGROUPFINDER = T.TITLE
  BINDING_NAME_AUTOGROUPFINDER_NEXT = T.BIND_NEXT
  BINDING_NAME_AUTOGROUPFINDER_REFRESH = T.BIND_REFRESH
  BINDING_NAME_AUTOGROUPFINDER_TOGGLE = T.BIND_TOGGLE

  local ROLES = { "TANK", "HEALER", "DAMAGER" }
  local ROLE_NAME = { TANK = T.ROLE_TANK, HEALER = T.ROLE_HEALER, DAMAGER = T.ROLE_DAMAGER }
  local ROLE_PLURAL = { TANK = T.ROLES_TANK, HEALER = T.ROLES_HEALER, DAMAGER = T.ROLES_DAMAGER }
  -- Dieselben Grafiken wie Blizzards Forever-Gruppensuche
  local ROLE_BIG = { TANK = "UI-LFG-RoleIcon-Tank", HEALER = "UI-LFG-RoleIcon-Healer", DAMAGER = "UI-LFG-RoleIcon-DPS" }
  local ROLE_SMALL = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
  }
  local ROLE_TEXCOORD = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
  }
  local ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"
  -- Blizzard filtert nach Client-Sprache; es gibt genau diese elf
  local LANGUAGES = { "deDE", "enUS", "frFR", "esES", "esMX", "itIT", "ruRU", "ptBR", "koKR", "zhCN", "zhTW" }
  local COMM_PREFIX = "AutoGrpFinder" -- versteckte Addon-Nachrichten zwischen Nutzern
  local TAB_ICONS = { "Interface\\ICONS\\INV_SideTab_GroupFinder_c60", "Interface\\ICONS\\INV_SideTab_GroupBrowsing_c60",
    "Interface\\ICONS\\INV_Misc_Book_09" }

  -- Gruppengrößen mit Standard-Rollenverteilung (inklusive dir), in den Einstellungen änderbar
  local SIZES = { 5, 10, 20, 40 }
  local DEFAULT_NEED = {
    [5] = { TANK = 1, HEALER = 1, DAMAGER = 3 },
    [10] = { TANK = 2, HEALER = 3, DAMAGER = 5 },
    [20] = { TANK = 2, HEALER = 5, DAMAGER = 13 },
    [40] = { TANK = 4, HEALER = 10, DAMAGER = 26 },
  }

  local DEFAULTS = {
    myRoles = { DAMAGER = true }, -- eigene Rollen, mehrere möglich
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
    inviteWhisper = false, -- beim Einladen kurz anflüstern
    whisperText = nil,     -- nil = Standardtext
    notify = true,         -- Meldung in der Bildschirmmitte und Taskleiste blinken
    skipUntil = {},        -- key -> time(); übersteht /reload
    showDemand = true,     -- Balken: wie viele warten auf welche Aktivität
    history = {},          -- Gruppen, in denen du warst (neueste zuerst)
    popular = {},          -- activityID -> { Anführer -> time() zuletzt gesehen }
    blocked = {},          -- key -> true: nie wieder einladen
    languageMode = "all",  -- all, mine, mineEnglish, custom
    languages = {},        -- WowLocale -> true, nur bei "custom"
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
  }

  local db
  local state = { queued = false, queuedAt = 0, lastSearchAt = 0, demand = {},
    trees = {}, treeVersion = 0, listings = {} }
  local History = {} -- Verlauf: Aufzeichnen und Seite 3
  local pending = {}   -- key -> { role, t, confirmed }
  local joined = {}    -- key -> Rolle, für die wir eingeladen haben
  local expired = {}   -- key -> Rolle; Einladung abgelaufen, könnte aber noch angenommen werden
  local seen = {}
  local candidates = {}
  local UpdateUI, UpdateMinimap
  local win -- Hauptfenster, unten gebaut

  -- Alles, was das Spiel berührt. "/gf test" tauscht es gegen Attrappen.
  local real = {
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
  local api = real

  local function Key(name) return Ambiguate(name, "none") end
  local function Short(name) return Ambiguate(name, "short") end
  local function Ding() if db.sound then PlaySound(SOUNDKIT.READY_CHECK or 8960, "Master") end end

  local function HasAtlas(a)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a) ~= nil
  end
  local function Atlas(tex, name)
    if HasAtlas(name) then tex:SetAtlas(name) return true end
  end
  local function SetRoleTexture(tex, role, big)
    if not Atlas(tex, (big and ROLE_BIG or ROLE_SMALL)[role]) then
      tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
      tex:SetTexCoord(unpack(ROLE_TEXCOORD[role]))
    end
  end

  -------------------------------------------------------------------------
  -- Kategorien und Aktivitäten
  -------------------------------------------------------------------------
  local function CategoryName(c)
    local ci = L.GetLfgCategoryInfo and L.GetLfgCategoryInfo(c)
    return (type(ci) == "table" and ci.name) or ci or tostring(c)
  end

  local function Categories()
    local out = {}
    for _, c in ipairs(L.GetAvailableCategories and L.GetAvailableCategories() or {}) do
      out[#out + 1] = { id = c, name = CategoryName(c) }
    end
    return out
  end

  local function CurrentCategory()
    local cats = Categories()
    for _, c in ipairs(cats) do if c.id == db.category then return c.id end end
    for _, c in ipairs(cats) do if c.id == 2 then return 2 end end -- Dungeons
    return cats[1] and cats[1].id
  end

  local function ActivityEntry(id, lvl)
    local a = L.GetActivityInfoTable(id)
    if not a then return nil end
    local lo, hi = a.minLevelSuggestion or 0, a.maxLevelSuggestion or 0
    return {
      id = id,
      name = (a.shortName and a.shortName ~= "") and a.shortName or a.fullName or "?",
      lo = lo, hi = hi, order = a.orderIndex or 0, max = a.maxNumPlayers or 0,
      fits = not ((lo > 0 and lo > lvl) or (hi > 0 and hi < lvl)),
    }
  end

  local function SortActivities(list)
    table.sort(list, function(x, y)
      if x.order ~= y.order then return x.order > y.order end
      if x.hi ~= y.hi then return x.hi > y.hi end
      if x.lo ~= y.lo then return x.lo > y.lo end
      return x.name < y.name
    end)
  end

  -- Wie Blizzards Liste: lose Aktivitäten zuerst, dann Gruppen. Ausgeblendetes zählt nicht.
  local function ActivityTree(catOverride)
    local cat = catOverride or CurrentCategory()
    local cached = state.trees[cat or 0]
    if cached and cached.version == state.treeVersion then return cached.tree end
    local tree = { cat = cat, loose = {}, groups = {}, all = {} }
    if not cat then return tree end
    local lvl = UnitLevel("player")
    local function visible(e) return e.fits or db.allLevels or db.activities[e.id] end
    for _, id in ipairs(L.GetAvailableActivities(cat, 0) or {}) do
      local e = ActivityEntry(id, lvl)
      if e and visible(e) then tree.loose[#tree.loose + 1] = e end
    end
    SortActivities(tree.loose)
    local groupIDs = L.GetAvailableActivityGroups and L.GetAvailableActivityGroups(cat) or {}
    for _, gid in ipairs(groupIDs) do
      local g = { id = gid, items = {}, anyFits = false }
      g.name, g.order = L.GetActivityGroupInfo(gid)
      for _, id in ipairs(L.GetAvailableActivities(cat, gid) or {}) do
        local e = ActivityEntry(id, lvl)
        if e and visible(e) then
          g.items[#g.items + 1] = e
          g.anyFits = g.anyFits or e.fits
        end
      end
      if #g.items > 0 then
        SortActivities(g.items)
        tree.groups[#tree.groups + 1] = g
      end
    end
    table.sort(tree.groups, function(x, y)
      if (x.order or 0) ~= (y.order or 0) then return (x.order or 0) < (y.order or 0) end
      return (x.name or "") < (y.name or "")
    end)
    for _, e in ipairs(tree.loose) do tree.all[#tree.all + 1] = e end
    for _, g in ipairs(tree.groups) do
      for _, e in ipairs(g.items) do tree.all[#tree.all + 1] = e end
    end
    state.trees[cat or 0] = { version = state.treeVersion, tree = tree }
    return tree
  end

  -- Beim ersten Kontakt mit einer Aktivität: angehakt, wenn sie zur Stufe passt.
  local function IsPicked(e)
    local v = db.activities[e.id]
    if v == nil then return e.fits end
    return v
  end

  local function SearchActivities()
    local tree = ActivityTree()
    local ids, maxPlayers = {}, 0
    for _, e in ipairs(tree.all) do
      if IsPicked(e) then
        ids[#ids + 1] = e.id
        maxPlayers = math.max(maxPlayers, e.max)
      end
    end
    return tree.cat, ids, maxPlayers
  end

  local function SizeBucket(maxPlayers)
    if not maxPlayers or maxPlayers <= 5 then return 5 end
    for _, s in ipairs(SIZES) do if maxPlayers <= s then return s end end
    return 40
  end

  -- Kurz: erster Eintrag plus Anzahl weiterer; lang: alle Namen
  local function ActivityName(info, full)
    local ids = info.activityIDs or {}
    if full then
      local names = {}
      for _, id in ipairs(ids) do
        local a = L.GetActivityInfoTable(id)
        if a then names[#names + 1] = a.fullName ~= "" and a.fullName or a.shortName end
      end
      return table.concat(names, ", ")
    end
    local a = ids[1] and L.GetActivityInfoTable(ids[1])
    local name = a and ((a.shortName ~= "" and a.shortName) or a.fullName) or ""
    if #ids > 1 then name = name .. " +" .. (#ids - 1) end
    return name
  end

  -------------------------------------------------------------------------
  -- Bilder: Dungeon-Vorschau, Spielweisen-Symbole, Rollenplätze
  -------------------------------------------------------------------------
  local Art = { cache = {} }
  local LS = "Interface\\Glues\\LoadingScreens\\LoadScreen"
  -- Ladebildschirme je Instanz-Karten-ID (unabhängig von der Spielsprache); mehrere Kandidaten,
  -- genommen wird der erste, den dieser Client hat.
  Art.LOADSCREEN = {
    [389] = { LS .. "RagefireChasm" }, [43] = { LS .. "WailingCaverns" }, [33] = { LS .. "ShadowFangKeep" },
    [36] = { LS .. "Deadmines" }, [48] = { LS .. "BlackFathomDeeps" }, [34] = { 131870, LS .. "Stockade" },
    [90] = { LS .. "Gnomeregan" }, [47] = { 131865, LS .. "RazorfenKraul" },
    [189] = { LS .. "ScarletMonastery", LS .. "ScarletMonastery2" }, [129] = { LS .. "RazorfenDowns" },
    [70] = { LS .. "Uldaman" }, [209] = { LS .. "ZulFarrak" }, [349] = { LS .. "Maraudon" },
    [109] = { LS .. "SunkenTemple" }, [230] = { LS .. "BlackrockDepths" }, [229] = { LS .. "BlackrockSpire" },
    [289] = { LS .. "Scholomance" }, [329] = { LS .. "Stratholme" }, [429] = { LS .. "DireMaul" },
    [409] = { LS .. "MoltenCore" }, [249] = { LS .. "OnyxiasLair" }, [469] = { LS .. "BlackwingLair" },
    [309] = { LS .. "ZulGurub" }, [509] = { LS .. "AhnQirajRuins" }, [531] = { LS .. "AhnQiraj" },
    [533] = { LS .. "Naxxramas" },
  }
  -- Forevers neue Dungeons haben eigene Ladebilder (Datei-Nummern), Zuordnung über den Namen
  Art.LOADSCREEN_BY_NAME = { ["Excavation Site"] = { 7963777 }, ["City of Dalaran"] = { 7963775 } }

  local function FileExists(f)
    if type(f) == "number" then return true end
    if not GetFileIDFromPath then return true end
    local ok, id = pcall(GetFileIDFromPath, f)
    return ok and id ~= nil
  end

  -- { file, coords } für eine Aktivität: erst Blizzards Dungeon-Journal, sonst Ladebildschirm
  function Art.Dungeon(activityID)
    local c = Art.cache[activityID]
    if c ~= nil then return c or nil end
    local result = false
    local a = activityID and L.GetActivityInfoTable(activityID)
    if a and a.mapID and C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap and EJ_GetInstanceInfo then
      local ok, jid = pcall(C_EncounterJournal.GetInstanceForGameMap, a.mapID)
      if ok and jid then
        local ok2, _, _, _, _, _, button = pcall(EJ_GetInstanceInfo, jid)
        if ok2 and button and button ~= 0 and button ~= "" then result = { file = button, coords = { 0, 1, 0, 1 }, aspect = 1.81 } end
      end
    end
    if not result and a then
      local list = Art.LOADSCREEN[a.mapID]
      if not list then
        for name, l in pairs(Art.LOADSCREEN_BY_NAME) do
          if (a.fullName or ""):find(name, 1, true) then list = l end
        end
      end
      for _, f in ipairs(list or {}) do
        if FileExists(f) then result = { file = f, coords = { 0.02, 0.98, 0.25, 0.82 }, aspect = 1.78 } break end
      end
    end
    Art.cache[activityID] = result
    return result or nil
  end

  -- aspect: gewünschtes Breite/Höhe-Verhältnis; schneidet mittig zu statt zu verzerren
  function Art.Apply(tex, art, aspect)
    if not art then tex:Hide() return false end
    tex:SetTexture(art.file)
    local l, r, t, b = unpack(art.coords)
    local source = art.aspect or 1.8
    if aspect and aspect > source then
      local keep = (b - t) * source / aspect
      t = t + ((b - t) - keep) / 2
      b = t + keep
    elseif aspect and aspect < source then
      local keep = (r - l) * aspect / source
      l = l + ((r - l) - keep) / 2
      r = l + keep
    end
    tex:SetTexCoord(l, r, t, b)
    tex:Show()
    return true
  end

  -- Rollenplätze wie in Blizzards Gruppenliste: besetzt farbig, fehlend blass.
  -- comp = { TANK = { besetzt, gesamt }, ... }; bis 5 Plätze einzeln, darüber je Rolle mit Zahl.
  function Art.CreateSlots(parent, size)
    local w = { slots = {}, counts = {} }
    for i = 1, 5 do
      local t = parent:CreateTexture(nil, "ARTWORK")
      t:SetSize(size, size)
      if i > 1 then t:SetPoint("LEFT", w.slots[i - 1], "RIGHT", 3, 0) end
      w.slots[i] = t
    end
    for i = 1, 3 do
      w.counts[i] = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end
    -- freier Platz ohne bekannte Rolle: grauer Kreis in derselben Größe wie die Rollen-Symbole
    w.empties = {}
    for i, slot in ipairs(w.slots) do
      local e = parent:CreateTexture(nil, "ARTWORK")
      e:SetSize(size - 2, size - 2)
      e:SetPoint("CENTER", slot, "CENTER")
      e:SetColorTexture(0.55, 0.55, 0.55, 0.45)
      if parent.CreateMaskTexture then
        local mask = parent:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(e)
        e:AddMaskTexture(mask)
      end
      e:Hide()
      w.empties[i] = e
    end
    w.size = size
    -- Ring in der Rollenfarbe hinter dem eigenen Platz: innen klar, nach außen weich auslaufend
    -- (drei Kreise mit abnehmender Deckkraft); pulsiert langsam nur in der Helligkeit
    w.rings = {}
    for i, spec in ipairs({ { 4, 0.8 }, { 9, 0.32 }, { 15, 0.12 } }) do
      local ring = parent:CreateTexture(nil, "ARTWORK", nil, -i)
      ring:SetSize(size + spec[1], size + spec[1])
      ring:SetColorTexture(1, 1, 1, 1)
      if parent.CreateMaskTexture then
        local mask = parent:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(ring)
        ring:AddMaskTexture(mask)
      end
      ring:Hide()
      ring.pulse = ring:CreateAnimationGroup()
      ring.pulse:SetLooping("BOUNCE")
      local fade = ring.pulse:CreateAnimation("Alpha")
      fade:SetFromAlpha(spec[2] * 0.45)
      fade:SetToAlpha(spec[2])
      fade:SetDuration(1.6)
      if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
      w.rings[i] = ring
    end
    return w
  end

  function Art.PlaceSlots(w, ...)
    w.point = { ... }
    w.slots[1]:ClearAllPoints()
    w.slots[1]:SetPoint(...)
  end

  local ROLE_COLOR = { TANK = { 0.25, 0.55, 1 }, HEALER = { 0.3, 0.9, 0.4 }, DAMAGER = { 1, 0.3, 0.25 } }
  function Art.Highlight(w, slot, role)
    for _, ring in ipairs(w.rings) do
      if not slot or not ROLE_COLOR[role] then
        ring:Hide()
        ring.pulse:Stop()
      else
        ring:SetVertexColor(unpack(ROLE_COLOR[role]))
        ring:ClearAllPoints()
        ring:SetPoint("CENTER", slot, "CENTER")
        ring:Show()
        ring.pulse:Stop() -- gemeinsam neu starten, damit alle drei im Takt bleiben
        ring.pulse:Play()
      end
    end
  end

  -- mine: Rolle des Eingeladenen; sein (noch freier) Platz wird farbig und leuchtet
  function Art.SetSlots(w, comp, mine)
    local you
    local total = 0
    for _, r in ipairs(ROLES) do total = total + (comp[r] and comp[r][2] or 0) end
    for _, fs in ipairs(w.counts) do fs:Hide() end
    if total <= 5 then
      local i = 0
      w.slots[1]:ClearAllPoints()
      w.slots[1]:SetPoint(unpack(w.point))
      for k = 2, 5 do
        w.slots[k]:ClearAllPoints()
        w.slots[k]:SetPoint("LEFT", w.slots[k - 1], "RIGHT", 3, 0)
      end
      for _, r in ipairs(ROLES) do
        local filled, need = comp[r] and comp[r][1] or 0, comp[r] and comp[r][2] or 0
        for n = 1, need do
          i = i + 1
          local t = w.slots[i]
          SetRoleTexture(t, r, false)
          local isYou = not you and r == mine and n > filled
          if isYou then you = t end
          t:SetDesaturated(n > filled and not isYou)
          t:SetAlpha((n > filled and not isYou) and 0.65 or 1) -- frei: grau, aber gut erkennbar
          t:Show()
        end
      end
      for _, e in ipairs(w.empties) do e:Hide() end
      local empty = comp.EMPTY or 0 -- freie Plätze ohne bekannte Rolle
      while empty > 0 and i < 5 do
        i, empty = i + 1, empty - 1
        w.slots[i]:Hide() -- bleibt für die Anordnung, gezeigt wird der Kreis
        w.empties[i]:Show()
      end
      for k = i + 1, 5 do w.slots[k]:Hide() end
    else
      -- Schlachtzug: Rolle + „besetzt/gesamt“
      for i, r in ipairs(ROLES) do
        local t, fs = w.slots[i], w.counts[i]
        SetRoleTexture(t, r, false)
        local filled, need = comp[r] and comp[r][1] or 0, comp[r] and comp[r][2] or 0
        t:SetDesaturated(filled >= need)
        t:SetAlpha(1)
        if r == mine then you = t end
        t:ClearAllPoints()
        if i == 1 then t:SetPoint(unpack(w.point)) else t:SetPoint("LEFT", w.counts[i - 1], "RIGHT", 6, 0) end
        t:Show()
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", t, "RIGHT", 2, 0)
        fs:SetText(("%d/%d"):format(filled, need))
        fs:Show()
      end
      for k = 4, 5 do w.slots[k]:Hide() end
      for _, e in ipairs(w.empties) do e:Hide() end
    end
    Art.Highlight(w, you, mine)
  end

  -------------------------------------------------------------------------
  -- Gruppe und offene Plätze
  -------------------------------------------------------------------------
  local function Target()
    local _, _, maxPlayers = SearchActivities()
    local size = SizeBucket(maxPlayers)
    return size, db.need[size] or DEFAULT_NEED[size], math.max(maxPlayers or 0, 5)
  end

  local function MemberKeys()
    local t = {}
    for _, m in ipairs(api.members()) do t[Key(m.name)] = m.unit end
    return t
  end

  -- Gibt die Belegung inklusive dir zurück und welche deiner Rollen du übernimmst:
  -- die seltenste, die noch fehlt (Tank vor Heiler vor Schaden).
  local function Filled()
    local f = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    for k, unit in pairs(MemberKeys()) do
      local r = joined[k] or expired[k] or api.unitRole(unit)
      if r ~= "TANK" and r ~= "HEALER" then r = "DAMAGER" end -- ohne Rolle zählt als Schaden
      f[r] = f[r] + 1
    end
    local _, need = Target()
    local me
    for _, r in ipairs(ROLES) do
      if db.myRoles[r] and (need[r] or 0) - f[r] > 0 then me = r break end
    end
    if not me then
      for _, r in ipairs(ROLES) do if db.myRoles[r] then me = r break end end
    end
    me = me or "DAMAGER"
    f[me] = f[me] + 1
    return f, me
  end

  -- rem = noch zu besetzen, open = davon noch ohne laufende Einladung
  local function Slots()
    local _, need = Target()
    local f = Filled()
    local rem, open = {}, {}
    for _, r in ipairs(ROLES) do
      rem[r] = math.max(0, (need[r] or 0) - f[r])
      open[r] = rem[r]
    end
    for _, p in pairs(pending) do open[p.role] = math.max(0, open[p.role] - 1) end
    return rem, open
  end

  local function Composition()
    local _, need = Target()
    local f = Filled()
    local comp = {}
    for _, r in ipairs(ROLES) do comp[r] = { math.min(f[r], need[r] or 0), need[r] or 0 } end
    return comp
  end

  local function AnyLeft(t)
    for _, r in ipairs(ROLES) do if t[r] > 0 then return true end end
    return false
  end

  local function PendingCount()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
  end

  -- Eine Gruppe fasst 5; mehr erst nach dem Umwandeln in einen Schlachtzug.
  local function RoomLeft()
    local _, _, cap = Target()
    if not api.isRaid() then cap = math.min(cap, 5) end
    return cap - math.max(1, api.groupSize()) - PendingCount()
  end

  local function NeedsRaid()
    local size = Target()
    return size > 5 and not api.isRaid() and api.groupSize() >= 5 and AnyLeft((Slots()))
  end

  local function CanInvite() return api.canInvite() end

  local function RoleFor(c, open)
    for _, r in ipairs(ROLES) do
      if c.roles[r] and open[r] > 0 then return r end
    end
  end

  -------------------------------------------------------------------------
  -- Kandidaten aus den Suchergebnissen
  -------------------------------------------------------------------------
  local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

  -- Sprachfilter für die Suche (WowLocale-Struktur) oder nil für alle Sprachen
  local function LanguageFilter()
    local mine = GetLocale()
    if mine == "enGB" then mine = "enUS" end
    local pick = {}
    if db.languageMode == "mine" then
      pick[mine] = true
    elseif db.languageMode == "mineEnglish" then
      pick[mine], pick.enUS = true, true
    elseif db.languageMode == "custom" then
      pick = db.languages
    end
    if not next(pick) then return nil end
    local filter = {}
    for _, loc in ipairs(LANGUAGES) do filter[loc] = pick[loc] and true or false end
    return filter
  end

  local function IsIgnoredName(name)
    if not (C_FriendList and C_FriendList.IsIgnored) then return false end
    local ok, ignored = pcall(C_FriendList.IsIgnored, name)
    return ok and ignored
  end

  local function NewDemand() return { players = 0, groups = 0, TANK = 0, HEALER = 0, DAMAGER = 0 } end

  -- Wer gerade wartet, täuscht: Beliebte Dungeons leeren sich schnell. Deshalb zählen wir,
  -- wie viele verschiedene Spieler und Gruppen sich in den letzten 30 Minuten eingetragen haben.
  local POPULAR_WINDOW = 1800
  local function Popularity(activityID)
    local seenBy = db.popular[activityID]
    if not seenBy then return 0 end
    local n, cutoff = 0, time() - POPULAR_WINDOW
    for k, t in pairs(seenBy) do
      if t < cutoff then seenBy[k] = nil else n = n + 1 end
    end
    return n
  end

  local function Rebuild()
    wipe(candidates)
    if not db then return end
    state.treeVersion = state.treeVersion + 1 -- Auswahl oder Daten können sich geändert haben
    local now = GetTime()
    local _, open = Slots()
    local wanted = {}
    for _, e in ipairs(ActivityTree().all) do
      if IsPicked(e) then wanted[e.id] = e end
    end
    local members = MemberKeys()
    local me = UnitName("player")
    local demand = wipe(state.demand)
    for _, id in ipairs(api.results()) do
      local info = api.info(id)
      if info and not info.isDelisted and not info.hasSelf then
        local solo = info.numMembers == 1
        local p = solo and api.leader(id)
        local r = p and p.lfgRoles
        -- Einträge merken, um spätere Einladungen dieser Anführer einordnen zu können
        if info.leaderName then
          local first = info.activityIDs and info.activityIDs[1]
          local a = first and L.GetActivityInfoTable(first)
          local counts = L.GetSearchResultMemberCounts and L.GetSearchResultMemberCounts(id)
          local max = (a and a.maxNumPlayers and a.maxNumPlayers > 0) and a.maxNumPlayers or 5
          -- Dungeons haben bei Blizzard eine feste Verteilung (1/1/3); daraus folgt, was fehlt
          local expected = a and (a.useDungeonRoleExpectations or max == 5) and DEFAULT_NEED[5]
          local comp, used = {}, 0
          for _, r in ipairs(ROLES) do
            local n = counts and counts[r] or 0
            local need = expected and math.max(n, expected[r]) or n
            comp[r] = { n, need }
            used = used + need
          end
          comp.EMPTY = math.max(0, max - used)
          state.listings[Key(info.leaderName)] = { activity = ActivityName(info, true), activityID = first,
            comp = comp, playstyle = info.generalPlaystyle, listing = true, seenAt = now }
        end
        -- Nachfrage je Aktivität: Solo-Spieler nach Rolle, dazu suchende Gruppen
        local who = info.leaderName and Key(info.leaderName) or ("#" .. id)
        for _, a in ipairs(info.activityIDs or {}) do
          local d = demand[a] or NewDemand()
          demand[a] = d
          db.popular[a] = db.popular[a] or {}
          db.popular[a][who] = time()
          if solo then
            d.players = d.players + 1
            if r then
              if r.tank then d.TANK = d.TANK + 1 end
              if r.healer then d.HEALER = d.HEALER + 1 end
              if r.dps then d.DAMAGER = d.DAMAGER + 1 end
            end
          else
            d.groups = d.groups + 1
          end
        end
        -- Kandidaten nur aus Solo-Einträgen: wer mit anderen gelistet ist, steckt schon in einer Gruppe.
        local k = solo and info.leaderName and Key(info.leaderName)
        if k and r and not db.blocked[k] and not IsIgnoredName(info.leaderName)
            and (not db.samePlaystyle or db.playstyle == 0 or info.generalPlaystyle == db.playstyle)
            and k ~= me and not members[k] and not pending[k] and (db.skipUntil[k] or 0) <= time() then
          local matches = {}
          for _, a in ipairs(info.activityIDs or {}) do
            if wanted[a] then matches[#matches + 1] = wanted[a] end
          end
          -- Zu niedrige Stufe für alle gewünschten Aktivitäten? Höhere Stufen sind willkommen.
          local levelOk = not db.levelCheck or not p.level or p.level == 0
          if not levelOk then
            for _, e in ipairs(matches) do
              if e.lo == 0 or p.level >= e.lo - db.levelTolerance then levelOk = true break end
            end
          end
          if #matches > 0 and levelOk then
            local c = {
              id = id, name = info.leaderName, key = k,
              roles = { TANK = r.tank, HEALER = r.healer, DAMAGER = r.dps },
              class = p.classFilename, level = p.level, activity = ActivityName(info),
              activityText = ActivityName(info, true), comment = info.comment,
              matchedActivity = matches[1] and matches[1].id,
              playstyle = info.generalPlaystyle,
              friend = (info.numCharFriends or 0) + (info.numBNetFriends or 0) > 0,
              guild = (info.numGuildMates or 0) > 0,
            }
            c.role = RoleFor(c, open)
            if c.role then
              seen[k] = seen[k] or now
              c.listedAt = info.age and (now - info.age) or seen[k]
              candidates[#candidates + 1] = c
            end
          end
        end
      end
    end
    -- Tanks, dann Heiler, dann Schaden; innerhalb einer Rolle standardmäßig die Neuesten zuerst.
    table.sort(candidates, function(a, b)
      if a.role ~= b.role then return ROLE_ORDER[a.role] < ROLE_ORDER[b.role] end
      if db.preferFriends then
        local af, bf = a.friend or a.guild, b.friend or b.guild
        if af ~= bf then return af end
      end
      if db.oldestFirst then return a.listedAt < b.listedAt end
      return a.listedAt > b.listedAt
    end)
    if UpdateUI then UpdateUI() end
  end

  local function ToggleBlocked(name)
    local k = Key(name)
    db.blocked[k] = not db.blocked[k] or nil
    Print((db.blocked[k] and T.CHAT_BLOCKED or T.CHAT_UNBLOCKED):format(Short(name)))
    Rebuild()
  end

  -------------------------------------------------------------------------
  -- Suche (Blizzard erlaubt sie nur direkt nach Klick oder Tastendruck)
  -------------------------------------------------------------------------
  local function FoundPageOpen() return win and win:IsShown() and db.page == 2 end

  local HardwareTick -- unten definiert: Rollen setzen, Flüstern nachschicken

  local function DoSearch(force)
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
  local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    return (fmt:gsub("%%s", "(.+)"))
  end
  local PAT = {
    invited = Pattern(ERR_INVITE_PLAYER_S),
    declined = Pattern(ERR_DECLINE_GROUP_S),
    busy = Pattern(ERR_ALREADY_IN_GROUP_S),
    bad = Pattern(ERR_BAD_PLAYER_NAME_S),
    ignoring = Pattern(ERR_IGNORING_YOU_S),
  }

  -- Flüstern braucht bei Blizzard einen Klick oder Tastendruck: Bei automatischen Einladungen
  -- geht die Nachricht mit dem nächsten Klick raus, aber nur kurz danach.
  local whisperQueue = {}
  local function WhisperText(c, role)
    local text = (db.whisperText and db.whisperText ~= "") and db.whisperText or T.WHISPER_DEFAULT
    text = text:gsub("{dungeon}", c.activityText or c.activity or "")
    return (text:gsub("{role}", ROLE_NAME[role]))
  end

  local function Invite(c, role, byClick)
    -- Ohne Bestätigungstext im Client lässt sich ein fehlgeschlagener Invite nicht erkennen.
    pending[c.key] = { role = role, t = GetTime(), confirmed = PAT.invited == nil }
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

  local function AutoInvite()
    if not (state.queued and db.autoInvite and CanInvite()) or InCombatLockdown() then return end
    for _, c in ipairs(candidates) do
      if RoomLeft() <= 0 then break end
      local _, open = Slots()
      local role = not pending[c.key] and RoleFor(c, open)
      if role then Invite(c, role) end
    end
    Rebuild()
  end

  local function DropPending(k, cooldown, msg)
    local p = pending[k]
    if not p then return end
    pending[k] = nil
    expired[k] = p.role
    db.skipUntil[k] = time() + cooldown
    if msg then Print(msg:format(Short(k))) end
    Rebuild()
    AutoInvite() -- sofort den Nächsten aus den vorhandenen Ergebnissen
  end

  local function FindPending(name)
    local k = Key(name)
    if pending[k] then return k end
    for pk in pairs(pending) do
      if Short(pk) == Short(name) then return pk end
    end
  end

  local function MsgName(msg, pat)
    local n = pat and msg:match(pat)
    if n then return n:match("%[(.-)%]") or n end
  end

  -- Wofür lädt mich jemand ein? Blizzards Fenster zeigt nur den Namen. Wir hängen ein Kästchen
  -- darunter: genau (Einladender hat das Add-on) oder laut seinem Eintrag in der Gruppensuche.
  local InviteInfo = { byAddon = {} }
  do
    local box = CreateFrame("Frame", "AutoGroupFinderInviteInfo", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetFrameStrata("DIALOG")
    box:SetSize(306, 96)
    if box.SetBackdrop then
      box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      box:SetBackdropColor(0, 0, 0, 0.9)
    end
    -- Bild randlos im Rahmen, darüber ein Verlauf: links dunkel für den Text, rechts das Motiv
    box.art = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    box.art:SetPoint("TOPLEFT", 4, -4)
    box.art:SetPoint("BOTTOMRIGHT", -4, 4)
    box.shade = box:CreateTexture(nil, "BACKGROUND", nil, 2)
    box.shade:SetAllPoints(box.art)
    box.shade:SetColorTexture(1, 1, 1, 1)
    local okGradient = CreateColor and pcall(box.shade.SetGradient, box.shade, "HORIZONTAL",
      CreateColor(0, 0, 0, 0.88), CreateColor(0, 0, 0, 0.2))
    if not okGradient then box.shade:SetColorTexture(0, 0, 0, 0.6) end
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    box.title:SetJustifyH("LEFT")
    box.title:SetWordWrap(false)
    box.slots = Art.CreateSlots(box, 22)
    box.line = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.line:SetJustifyH("LEFT")
    box:Hide()
    box:SetScript("OnUpdate", function(self)
      if not (self.dialog and self.dialog:IsShown()) then self:Hide() end
    end)

    local function VisibleInviteDialog()
      if LFGInvitePopup and LFGInvitePopup:IsShown() then return LFGInvitePopup end
      return StaticPopup_FindVisible and StaticPopup_FindVisible("PARTY_INVITE")
    end

    -- Laut Gruppensuche: gemerkter Eintrag des Einladenden aus den Suchen der letzten 30 Minuten
    local function FromListing(inviter)
      Rebuild() -- aktuelle Ergebnisse einarbeiten, falls die Einladung schneller war
      local l = state.listings[Key(inviter)]
      if l and GetTime() - l.seenAt < 1800 then return l end
    end

    -- Für welche Rolle bin ich gedacht? Eine angebotene Rolle ist eindeutig; bei mehreren die,
    -- die ich selbst gewählt habe und die in der Gruppe noch fehlt.
    local function OfferedRole(offered, comp)
      if not offered then return nil end
      local list = {}
      for _, r in ipairs(ROLES) do if offered[r] then list[#list + 1] = r end end
      if #list == 1 then return list[1] end
      for _, r in ipairs(list) do
        local c = comp and comp[r]
        if db.myRoles[r] and (not c or c[1] < c[2]) then return r end
      end
    end

    function InviteInfo.Show(inviter, tries, offered)
      local k = inviter and Key(inviter)
      if not k then return end
      InviteInfo.offered = offered or InviteInfo.offered
      local exact = InviteInfo.byAddon[k]
      local data = (exact and GetTime() - exact.t < 90 and exact) or FromListing(inviter)
      if data and not data.role then
        data = setmetatable({ role = OfferedRole(InviteInfo.offered, data.comp) }, { __index = data })
      end
      local dialog = VisibleInviteDialog()
      if not dialog then
        -- Blizzard öffnet sein Fenster evtl. erst nach uns: kurz nochmal versuchen
        if (tries or 0) < 10 then C_Timer.After(0.1, function() InviteInfo.Show(inviter, (tries or 0) + 1, offered) end) end
        return
      end
      if data then InviteInfo.Attach(dialog, inviter, data) end
    end

    -- Der Name steht schon in Blizzards Fenster; hier nur, wofür.
    function InviteInfo.Attach(dialog, inviter, data)
      box.dialog = dialog
      box:SetWidth(dialog:GetWidth() or 306)
      local hasArt = Art.Apply(box.art, data.activityID and Art.Dungeon(data.activityID),
        (box:GetWidth() - 8) / (box:GetHeight() - 8))
      box.shade:SetShown(hasArt)
      box.title:ClearAllPoints()
      box.title:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -14)
      box.title:SetPoint("RIGHT", box, "RIGHT", -10, 0)
      box.title:SetText(data.activity or "?")
      Art.PlaceSlots(box.slots, "TOPLEFT", box.title, "BOTTOMLEFT", 0, -8)
      Art.SetSlots(box.slots, data.comp or {}, data.role)
      -- Die eigene Rolle zeigt das Leuchten; hier nur noch die Spielweise
      local parts = {}
      local styleName = data.playstyle and _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. data.playstyle]
      if styleName and styleName ~= "" then parts[#parts + 1] = "|cffb8b8b8" .. styleName .. "|r" end
      if data.listing then parts[#parts + 1] = "|cffb8b8b8" .. T.INVITE_FROM_LISTING .. "|r" end
      box.line:ClearAllPoints()
      box.line:SetPoint("TOPLEFT", box.slots.slots[1], "BOTTOMLEFT", 0, -8)
      box.line:SetText(table.concat(parts, " · "))
      box:ClearAllPoints()
      -- unter dem Fenster, wenn dort Platz ist, sonst darüber
      if (dialog:GetBottom() or 200) > box:GetHeight() + 20 then
        box:SetPoint("TOP", dialog, "BOTTOM", 0, -4)
      else
        box:SetPoint("BOTTOM", dialog, "TOP", 0, 4)
      end
      box:Show()
      state.lastInviter = inviter
    end

    -- /gf testinvite: Beispiel mit einem Fenster wie Blizzards Einladung, schließt nach 10 Sekunden
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs.AUTOGROUPFINDER_FAKE_INVITE = {
      text = INVITATION or T.FAKE_INVITATION,
      button1 = ACCEPT,
      button2 = DECLINE,
      OnAccept = function() Print(T.TEST_INVITE_BUTTON) end,
      OnCancel = function() Print(T.TEST_INVITE_BUTTON) end,
      timeout = 10,
      whileDead = 1,
      hideOnEscape = 1,
    }
    -- Nachbau von Blizzards Einladung mit Rollenauswahl (LFGInvitePopup). Das echte Fenster
    -- rufen wir nicht auf: Add-on-Code darin könnte das nächste echte Annehmen blockieren (Taint).
    local function DemoRolePopup()
      local f = InviteInfo.demoFrame
      if not f then
        f = CreateFrame("Frame", "AutoGroupFinderDemoInvite", UIParent)
        f:SetSize(306, 180)
        f:SetPoint("TOP", UIParent, "TOP", 0, -135)
        f:SetFrameStrata("DIALOG")
        pcall(CreateFrame, "Frame", nil, f, "DialogBorderTemplate")
        f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        f.text:SetSize(240, 38)
        f.text:SetPoint("TOP", 0, -15)
        f.accept = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.accept:SetSize(115, 22)
        f.accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -3, 15)
        f.accept:SetText(ACCEPT or "Accept")
        f.decline = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.decline:SetSize(115, 22)
        f.decline:SetPoint("LEFT", f.accept, "RIGHT", 6, 0)
        f.decline:SetText(DECLINE or "Decline")
        for _, b in ipairs({ f.accept, f.decline }) do
          b:SetScript("OnClick", function() Print(T.TEST_INVITE_BUTTON) f:Hide() end)
        end
        f.roles = {}
        local function UpdateAccept()
          local any = false
          for _, b in ipairs(f.roles) do any = any or b.checkButton:GetChecked() end
          f.accept:SetEnabled(any)
        end
        for i, role in ipairs(ROLES) do
          local okB, b = pcall(CreateFrame, "Button", nil, f, "LFGRoleButtonTemplate")
          if not okB or not b.checkButton then
            b = CreateFrame("Button", nil, f)
            b.checkButton = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
            b.checkButton:SetPoint("BOTTOMLEFT", -5, -4)
          end
          b:SetSize(70, 70)
          if i == 1 then b:SetPoint("TOPLEFT", 35, -55) else b:SetPoint("LEFT", f.roles[i - 1], "RIGHT", 15, 0) end
          b.role = role
          if LFGRoleButtonTemplate_OnLoad then pcall(LFGRoleButtonTemplate_OnLoad, b) end
          if not b:GetNormalTexture() then
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetAllPoints()
            SetRoleTexture(t, role, true)
          end
          -- nur eine Rolle, wie bei Einladungen ohne Mehrfachauswahl
          b.checkButton:SetScript("OnClick", function(self)
            if self:GetChecked() then
              for _, other in ipairs(f.roles) do if other ~= b then other.checkButton:SetChecked(false) end end
            end
            UpdateAccept()
          end)
          b:SetScript("OnClick", function(self) if self:IsEnabled() then self.checkButton:Click() end end)
          f.roles[i] = b
        end
        f.UpdateAccept = UpdateAccept
        f:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_PLAYER_INVITE or 880) end)
        InviteInfo.demoFrame = f
      end
      -- Beispiel: Tank und Schaden angeboten, Heiler nicht
      local offered = { TANK = true, HEALER = false, DAMAGER = true }
      for _, b in ipairs(f.roles) do
        b.checkButton:SetChecked(false)
        local fn = offered[b.role] and LFG_EnableRoleButton or LFG_DisableRoleButton
        if not (fn and pcall(fn, b)) then
          b:SetEnabled(offered[b.role])
          b.checkButton:SetEnabled(offered[b.role])
        end
      end
      f.UpdateAccept()
      return f
    end

    function InviteInfo.Demo(variant)
      local simple = variant == "simple"
      local inviter = "Ulgrim Steinfaust"
      local dialog
      if simple then
        dialog = StaticPopup_Show and StaticPopup_Show("AUTOGROUPFINDER_FAKE_INVITE", inviter)
      else
        dialog = DemoRolePopup()
        dialog.text:SetFormattedText(INVITATION or T.FAKE_INVITATION, inviter)
        dialog:Show()
        local token = {}
        dialog.token = token
        C_Timer.After(10, function() if dialog.token == token then dialog:Hide() end end)
      end
      if not dialog then return end
      local _, ids = SearchActivities()
      if variant == "listing" then
        -- Ohne Add-on beim Einladenden: nur, was seine Gruppe in der Suche zeigt
        -- Gruppe hat Heiler + 2 Schaden; 1/1/3 heißt: Tank und ein Schaden fehlen; angeboten wird Tank
        InviteInfo.Attach(dialog, inviter, {
          activity = "Scarlet Library", activityID = ids[1], playstyle = 2, listing = true, role = "TANK",
          comp = { TANK = { 0, 1 }, HEALER = { 1, 1 }, DAMAGER = { 2, 3 } },
        })
      else
        -- Mit Add-on: Heiler und zwei Schaden sind da, du wirst als Tank eingeladen
        InviteInfo.Attach(dialog, inviter, {
          activity = "Scarlet Library", activityID = ids[1], role = "TANK", playstyle = 2,
          comp = { TANK = { 0, 1 }, HEALER = { 1, 1 }, DAMAGER = { 2, 3 } },
        })
      end
    end
  end

  -- Hat der Einladende das Add-on auch, schickt er mit, wofür er einlädt.
  local function OnAddonMessage(prefix, message, _, sender)
    if prefix ~= COMM_PREFIX or not message or not sender then return end
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

  local function OnSystem(msg)
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
  -- Warteschlange
  -------------------------------------------------------------------------
  local function NeedText(rem)
    local parts = {}
    for _, r in ipairs(ROLES) do
      if rem[r] > 0 then parts[#parts + 1] = (rem[r] > 1 and rem[r] .. "× " or "") .. ROLE_NAME[r] end
    end
    return table.concat(parts, ", ")
  end

  local function StartQueue()
    if InCombatLockdown() then Print(T.CHAT_IN_COMBAT) return end
    if not CanInvite() then Print(T.CHAT_LEADER_ONLY) return end
    local _, ids = SearchActivities()
    if #ids == 0 then Print(T.PICK_ACTIVITY) return end
    if (db.playstyle or 0) == 0 then Print(GROUP_FINDER_PLAYSTYLE_REQUIRED or T.PLAYSTYLE_REQUIRED) return end
    local rem = Slots()
    if not AnyLeft(rem) then Print(T.CHAT_NO_ROLE) return end
    state.queued, state.queuedAt, state.lastSearchAt = true, GetTime(), 0
    local okList, err = api.list({
      activityIDs = ids,
      generalPlaystyle = db.playstyle,
      voiceMode = db.voice,
      newPlayerFriendly = db.newPlayerFriendly and true or false,
    }, { tank = db.myRoles.TANK or false, healer = db.myRoles.HEALER or false, dps = db.myRoles.DAMAGER or false })
    if not okList then Print(T.CHAT_LIST_FAILED:format(tostring(err))) end
    DoSearch(true)
    if win then win:Hide() end
    Print(T.CHAT_STARTED:format(NeedText(rem)))
    UpdateMinimap()
  end

  local function StopQueue(msg)
    state.queued = false
    api.unlist()
    if msg then Print(msg) end
    UpdateMinimap()
    if UpdateUI then UpdateUI() end
  end

  local Notify -- unten definiert
  local function FinishQueue()
    state.completed, state.backfillNoted = true, false
    StopQueue(T.CHAT_COMPLETE)
    Ding()
    if Notify then Notify(T.CHAT_COMPLETE) end
  end

  -- Gruppe steht und du führst: Taste, Minimap und Knopf starten den Bereitschaftscheck.
  local function GroupReady()
    return not state.queued and IsInGroup() and UnitIsGroupLeader("player") and not AnyLeft((Slots()))
  end

  function AutoGroupFinder_Next()
    if GroupReady() then
      api.readyCheck()
    elseif state.queued then
      DoSearch(true)
    else
      StartQueue()
    end
  end
  function AutoGroupFinder_Refresh() DoSearch(true) end

  -------------------------------------------------------------------------
  -- Hauptfenster, aufgebaut wie Blizzards „Looking For Group“-Fenster
  -------------------------------------------------------------------------
  local WIN_W, WIN_H = 458, 535 -- Maße von Blizzards Gruppensuche
  local ok
  ok, win = pcall(CreateFrame, "Frame", "AutoGroupFinderFrame", UIParent, "PortraitFrameTemplate")
  if not ok then win = CreateFrame("Frame", "AutoGroupFinderFrame", UIParent, "BasicFrameTemplateWithInset") end
  win:SetSize(WIN_W, WIN_H)
  win:SetPoint("CENTER")
  win:SetFrameStrata("HIGH")
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetClampedToScreen(true)
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:Hide()
  tinsert(UISpecialFrames, "AutoGroupFinderFrame") -- Esc schließt
  if win.SetTitle then win:SetTitle(T.TITLE) end
  if win.SetPortraitToAsset then pcall(win.SetPortraitToAsset, win, ICON) end

  local function Label(parent, text, font, ...)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint(...)
    fs:SetText(text)
    return fs
  end

  local function Tooltip(frame, title, body)
    frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(title)
      if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
  end

  -- Shift-Klick: in ein offenes Chat-Eingabefeld einfügen, sonst den Chat damit öffnen
  local function InsertChat(text)
    if not text or text == "" then return end
    local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if insert and insert(text) then return end
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open then open(text) end
  end

  local function Whisper(name)
    local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if tell then tell(name) end
  end

  -- Hintergrund des eingelassenen Bereichs (Dungeon-Motiv mit Rahmen)
  local function Inset(parent, top)
    local bg = parent:CreateTexture(nil, "BORDER", nil, -2)
    bg:SetPoint("TOPLEFT", win, "TOPLEFT", 6, top - 3)
    bg:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -5, 6)
    Atlas(bg, "groupfinder-background")
    local border = parent:CreateTexture(nil, "BORDER", nil, 1)
    border:SetPoint("TOPLEFT", win, "TOPLEFT", 4, top - 1)
    border:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 3)
    Atlas(border, "common-insideframe")
  end

  -- Scrollbereich, dessen Balken nur erscheint, wenn es etwas zu scrollen gibt
  local function Scroller(parent, anchor, left, top, right, bottom)
    local okS, sf = pcall(CreateFrame, "ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    if not okS then
      sf = CreateFrame("ScrollFrame", nil, parent)
      sf:EnableMouseWheel(true)
      sf:SetScript("OnMouseWheel", function(self, d)
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
      end)
    end
    local function place(r)
      sf:ClearAllPoints()
      sf:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, top)
      sf:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", r, bottom)
    end
    place(right)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(WIN_W - 40, 10)
    sf:SetScrollChild(child)
    sf.child = child
    sf:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then child:SetWidth(w) end end)
    -- Volle Breite wie bei Blizzard; Platz für den Balken nur, wenn wirklich gescrollt werden muss
    function sf:SetContentHeight(h)
      child:SetHeight(math.max(10, h))
      local needBar = h > (self:GetHeight() or 0) + 1
      if needBar ~= self.barShown then
        self.barShown = needBar
        place(needBar and right - 22 or right)
      end
      local w = self:GetWidth()
      if w and w > 0 then child:SetWidth(w) end
      if self.ScrollBar then self.ScrollBar:SetShown(needBar) end
      if not needBar then self:SetVerticalScroll(0) end
    end
    return sf
  end

  local pages = { CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win), CreateFrame("Frame", nil, win) }
  for _, p in ipairs(pages) do p:SetAllPoints() end
  local finder, found = pages[1], pages[2]

  -------------------------------------------------------------------------
  -- Seite 1: Gruppe suchen – Rollen oben, darunter Kategorien oder Aktivitäten (wie Blizzards „List Self“)
  -------------------------------------------------------------------------
  local rolesBg = finder:CreateTexture(nil, "BORDER", nil, -3)
  rolesBg:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -25)
  rolesBg:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", -2, -127)
  Atlas(rolesBg, "groupfinder-roles-background")
  Inset(finder, -118)

  local function AtlasSized(tex, name)
    if HasAtlas(name) then tex:SetAtlas(name, true) return true end
  end

  -- Blizzards klassische Kästchen (größer als UICheckButtonTemplate)
  local function BlizzCheck(parent, size)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(size, size)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    return cb
  end

  -- Vier Plätze (3 Rollen + Fahne) gleichmäßig über die Breite, gleicher Rand links und rechts
  local SLOT = 110
  local function SlotCenter(i) return WIN_W / 2 + (i - 2.5) * SLOT end

  -- Wie Blizzards Rollen-Knöpfe: Drüberfahren lässt das Häkchen leuchten, Drücken drückt es mit
  -- und rückt das Icon einen Pixel (wie bei den Seitenreitern).
  local function RoleButtonFeel(b)
    b:HookScript("OnEnter", function(self) if self.check:IsEnabled() then self.check:LockHighlight() end end)
    b:HookScript("OnLeave", function(self) self.check:UnlockHighlight() end)
    b:SetScript("OnMouseDown", function(self)
      self.check:SetButtonState("PUSHED")
      self.icon:AdjustPointsOffset(1, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
      self.check:SetButtonState("NORMAL")
      self.icon:AdjustPointsOffset(-1, 1)
    end)
  end
  local function CheckSound(on)
    PlaySound(on and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
  end

  -- Eigene Rolle: farbige Rund-Icons mit Leuchten, Auswahl über das Häkchen
  local myRoleBtns = {}
  for i, role in ipairs(ROLES) do
    local b = CreateFrame("Button", nil, finder)
    b:SetSize(64, 64)
    b:SetPoint("CENTER", win, "TOPLEFT", SlotCenter(i), -76)
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetPoint("CENTER")
    if not AtlasSized(b.glow, ROLE_BIG[role] .. "-Background") then b.glow:SetSize(80, 80) end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    if not AtlasSized(b.icon, ROLE_BIG[role]) then
      b.icon:SetSize(64, 64)
      SetRoleTexture(b.icon, role, true)
    end
    b.check = BlizzCheck(b, 24)
    b.check:SetPoint("BOTTOMLEFT", -5, -5)
    local function pick()
      db.myRoles[role] = not db.myRoles[role] or nil
      if not next(db.myRoles) then db.myRoles[role] = true end -- mindestens eine Rolle
      CheckSound(db.myRoles[role])
      Rebuild()
    end
    b:SetScript("OnClick", pick)
    b.check:SetScript("OnClick", pick)
    Tooltip(b, T.YOUR_ROLE:format(ROLE_NAME[role]))
    RoleButtonFeel(b)
    b.role = role
    myRoleBtns[i] = b
  end

  -- Trennlinie und Fahne „Neulingsfreundlich“ wie bei Blizzard
  local divider = finder:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.55, 0.45, 0.3, 0.6)
  divider:SetSize(1, 78)
  divider:SetPoint("CENTER", win, "TOPLEFT", SlotCenter(3.5), -76)
  local npf = CreateFrame("Button", nil, finder)
  npf:SetSize(84, 84)
  npf:SetPoint("CENTER", win, "TOPLEFT", SlotCenter(4), -76)
  npf.icon = npf:CreateTexture(nil, "ARTWORK")
  npf.icon:SetPoint("CENTER")
  if not AtlasSized(npf.icon, "UI-LFG-RoleIcon-Leader") then
    npf.icon:SetSize(64, 64)
    npf.icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  end
  local newcomer = npf:CreateTexture(nil, "OVERLAY")
  newcomer:SetSize(20, 20)
  newcomer:SetPoint("TOPRIGHT", -8, -7)
  Atlas(newcomer, "newplayerchat-chaticon-newcomer")
  npf.check = BlizzCheck(npf, 24)
  npf.check:SetPoint("BOTTOMLEFT", 6, 5)
  npf.check:SetScript("OnClick", function(self)
    db.newPlayerFriendly = self:GetChecked() and true or false
    CheckSound(db.newPlayerFriendly)
  end)
  npf:SetScript("OnClick", function(self) self.check:Click() end)
  Tooltip(npf, LFG_LIST_NEW_PLAYER_FRIENDLY_TOOLTIP or T.NEWCOMER_TIP)
  RoleButtonFeel(npf)

  -- Kategorien als Karten, wie Blizzards Startseite
  local CATEGORY_ART = {
    [2] = "groupfinder-button-dungeons",
    [114] = "groupfinder-button-raids-warlords",
    [116] = "groupfinder-button-questing",
    [118] = "groupfinder-button-battlegrounds",
    [120] = "groupfinder-button-custom-pve",
  }
  local catView = CreateFrame("Frame", nil, finder)
  catView:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -124)
  catView:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 40)
  local cards = {}
  local coverInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("groupfinder-button-cover")
  local CARD_W, CARD_H = coverInfo and coverInfo.width or 400, coverInfo and coverInfo.height or 64

  local function Card(i)
    local card = cards[i]
    if card then return card end
    card = CreateFrame("Button", nil, catView)
    card:SetSize(CARD_W, CARD_H)
    if i == 1 then
      card:SetPoint("TOP", catView, "TOP", 0, -8)
    else
      card:SetPoint("TOP", cards[i - 1], "BOTTOM", 0, -4)
    end
    card.art = card:CreateTexture(nil, "BACKGROUND")
    card.art:SetPoint("TOPLEFT", 5, -8)
    card.art:SetPoint("BOTTOMRIGHT", -5, 5)
    card.cover = card:CreateTexture(nil, "ARTWORK")
    card.cover:SetPoint("CENTER")
    AtlasSized(card.cover, "groupfinder-button-cover")
    if card.SetPushedAtlas and HasAtlas("groupfinder-button-cover-down") then card:SetPushedAtlas("groupfinder-button-cover-down") end
    if card.SetHighlightAtlas and HasAtlas("groupfinder-button-cover-hover") then card:SetHighlightAtlas("groupfinder-button-cover-hover") end
    card.label = Label(card, "", "GameFontNormalLarge", "LEFT", card, "LEFT", 20, 0)
    card:SetScript("OnClick", function(self)
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
      db.category, db.view = self.categoryID, "activities"
      Rebuild()
    end)
    cards[i] = card
    return card
  end

  local function UpdateCards()
    local n = 0
    for _, c in ipairs(Categories()) do
      if #ActivityTree(c.id).all > 0 then
        n = n + 1
        local card = Card(n)
        card.categoryID = c.id
        card.label:SetText(c.name)
        if not Atlas(card.art, CATEGORY_ART[c.id] or "groupfinder-button-questing") then
          card.art:SetColorTexture(0.15, 0.2, 0.3, 0.9)
        end
        card:Show()
      end
    end
    for i = n + 1, #cards do cards[i]:Hide() end
  end

  -- Aktivitätsansicht
  local actView = CreateFrame("Frame", nil, finder)
  actView:SetPoint("TOPLEFT", win, "TOPLEFT", 7, -125)
  actView:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -7, 40)

  -- Auswahlfeld im Stil von Blizzards Dropdowns; ohne Vorlage ein Knopf, der durchschaltet.
  local dropdowns = {}
  local function Dropdown(parent, width, options, placeholder, get, set, ...)
    local okDd, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if okDd and dd and dd.SetupMenu then
      dd:SetWidth(width)
      dd:SetPoint(...)
      if placeholder and dd.SetDefaultText then dd:SetDefaultText(placeholder) end
      dd:SetupMenu(function(_, root)
        for _, o in ipairs(type(options) == "function" and options() or options) do
          root:CreateRadio(o[2], function(v) return get() == v end, function(v) set(v) end, o[1])
        end
      end)
    else
      dd = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      dd:SetSize(width, 24)
      dd:SetPoint(...)
      dd:SetScript("OnClick", function()
        local opts, idx = type(options) == "function" and options() or options, 0
        for i, o in ipairs(opts) do if o[1] == get() then idx = i end end
        if opts[1] then set(opts[idx % #opts + 1][1]) end
      end)
      dd.cycle = function()
        dd:SetText(placeholder or "")
        for _, o in ipairs(type(options) == "function" and options() or options) do
          if o[1] == get() then dd:SetText(o[2]) end
        end
      end
    end
    dropdowns[#dropdowns + 1] = dd
    return dd
  end

  local PLAYSTYLE_OPTIONS = {
    { 1, GROUP_FINDER_GENERAL_PLAYSTYLE1 or "Learning" },
    { 2, GROUP_FINDER_GENERAL_PLAYSTYLE2 or "Relaxed" },
    { 3, GROUP_FINDER_GENERAL_PLAYSTYLE3 or "Competitive" },
    { 4, GROUP_FINDER_GENERAL_PLAYSTYLE4 or "Carry Offered" },
  }
  local VOICE_OPTIONS = {
    { 0, VOICE_CHAT_MODE_NONE or "None" },
    { 1, VOICE_CHAT_MODE_LEGACY or "In-game" },
    { 2, VOICE_CHAT_MODE_DISCORD or "Discord" },
    { 3, VOICE_CHAT_MODE_CUSTOM or "Custom" },
  }
  local PLAYSTYLE_NAME = {}
  for _, o in ipairs(PLAYSTYLE_OPTIONS) do PLAYSTYLE_NAME[o[1]] = o[2] end
  local PLAYSTYLE_REQUIRED = GROUP_FINDER_PLAYSTYLE_REQUIRED or T.PLAYSTYLE_REQUIRED

  Dropdown(actView, 210, PLAYSTYLE_OPTIONS,
    DISABLED_FONT_COLOR and DISABLED_FONT_COLOR:WrapTextInColorCode(PLAYSTYLE_REQUIRED) or PLAYSTYLE_REQUIRED,
    function() return db.playstyle end,
    function(v) db.playstyle = v; Rebuild() end,
    "TOPLEFT", actView, "TOPLEFT", 28, -10)

  local levelCheck = CreateFrame("CheckButton", nil, actView, "UICheckButtonTemplate")
  levelCheck:SetSize(26, 26)
  -- mittig zur Spielweise-Auswahl, rechtsbündig mit der Liste darunter
  levelCheck:SetPoint("RIGHT", actView, "TOPRIGHT", -10, -22)
  local levelText = Label(actView, T.ALL_LEVELS, "GameFontNormalSmall", "RIGHT", levelCheck, "LEFT", -2, 0)
  levelText:SetJustifyH("RIGHT")
  levelCheck:SetHitRectInsets(-levelText:GetStringWidth() - 4, 0, 0, 0)
  levelCheck:SetScript("OnClick", function(self)
    db.allLevels = self:GetChecked() and true or false
    Rebuild()
  end)

  local barTop = actView:CreateTexture(nil, "ARTWORK")
  barTop:SetPoint("LEFT", actView, "TOPLEFT", 0, -42)
  barTop:SetPoint("RIGHT", actView, "TOPRIGHT", 0, -42)
  if not AtlasSized(barTop, "groupfinder-ScrollLine") then barTop:SetColorTexture(0.5, 0.4, 0.25, 0.5) barTop:SetHeight(1) end
  local barBottom = actView:CreateTexture(nil, "ARTWORK")
  barBottom:SetPoint("LEFT", actView, "BOTTOMLEFT", 0, 46)
  barBottom:SetPoint("RIGHT", actView, "BOTTOMRIGHT", 0, 46)
  if not AtlasSized(barBottom, "groupfinder-ScrollLine") then barBottom:SetColorTexture(0.5, 0.4, 0.25, 0.5) barBottom:SetHeight(1) end

  local voiceDd = Dropdown(actView, 220, VOICE_OPTIONS, nil,
    function() return db.voice end,
    function(v) db.voice = v end,
    "BOTTOMRIGHT", actView, "BOTTOMRIGHT", -20, 12)
  Label(actView, VOICE_CHAT or T.VOICE_CHAT, "GameFontNormalSmall", "RIGHT", voiceDd, "LEFT", -8, 0)

  -- Aktivitäten als Baum wie bei Blizzard: Gruppe mit Plus/Minus, Einträge eine Stufe eingerückt
  local tree = Scroller(actView, actView, 22, -48, -12, 52)
  local treeRows = {}
  local ROW = 22

  local function SetPicked(entries, value)
    for _, e in ipairs(entries) do db.activities[e.id] = value end
    Rebuild()
  end

  local BAR_W = 50 -- Breite der Balkenspalte

  local function TreeRow(i)
    local row = treeRows[i]
    if row then return row end
    row = CreateFrame("Button", nil, tree.child)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
    row:SetPoint("RIGHT", tree.child, "RIGHT")
    row.expand = CreateFrame("Button", nil, row)
    row.expand:SetSize(16, 16)
    row.expand:SetPoint("LEFT", 0, 0)
    row.expand:SetHitRectInsets(1, -4, -2, -2)
    row.expand:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    row.check = BlizzCheck(row, 30)
    row.level = Label(row, "", "GameFontNormal", "RIGHT", row, "RIGHT", 0, 0)
    row.level:SetWidth(60)
    row.level:SetJustifyH("LEFT")
    -- fast unsichtbarer Balken in eigener Spalte links neben den Stufen (Länge = Beliebtheit)
    row.bar = row:CreateTexture(nil, "BACKGROUND")
    row.bar:SetPoint("TOPRIGHT", row.level, "TOPLEFT", -4, -3)
    row.bar:SetPoint("BOTTOMRIGHT", row.level, "BOTTOMLEFT", -4, 3)
    row.bar:SetColorTexture(1, 0.82, 0, 0.12)
    row.bar:Hide()
    row.name = Label(row, "", "GameFontNormal", "LEFT", row.check, "RIGHT", 0, 0)
    row.name:SetPoint("RIGHT", row.level, "LEFT", -(BAR_W + 10), 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
      if IsShiftKeyDown() then InsertChat(self.linkText) else self.check:Click() end
    end)
    row:SetScript("OnEnter", function(self)
      self.check:LockHighlight()
      if not (db.showDemand and self.activity) then return end
      local d = state.demand[self.activity]
      local popular = Popularity(self.activity)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.linkText)
      if popular == 0 and state.lastSearchAt == 0 then
        GameTooltip:AddLine(T.DEMAND_NO_DATA, 0.6, 0.6, 0.6, true)
      else
        GameTooltip:AddLine(T.DEMAND_POPULAR:format(popular), 1, 1, 1)
        GameTooltip:AddLine(T.DEMAND_BASIS, 0.6, 0.6, 0.6, true)
        if d and (d.players > 0 or d.groups > 0) then
          GameTooltip:AddLine(T.DEMAND_NOW:format(d.players, d.TANK, d.HEALER, d.DAMAGER), 0.8, 0.8, 0.8, true)
          if d.groups > 0 then GameTooltip:AddLine(T.DEMAND_GROUPS:format(d.groups), 0.8, 0.8, 0.8) end
        else
          GameTooltip:AddLine(T.DEMAND_NONE, 0.6, 0.6, 0.6)
        end
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
      self.check:UnlockHighlight()
      GameTooltip:Hide()
    end)
    row.check:SetScript("OnClick", function(self)
      local r = self:GetParent()
      -- Teilweise angehakte Gruppe: Klick wählt alles ab, wie bei Blizzard
      SetPicked(r.entries, not r.anyPicked)
    end)
    row.expand:SetScript("OnClick", function(self)
      local r = self:GetParent()
      db.collapsed[r.groupID] = not r.isCollapsed
      Rebuild()
    end)
    treeRows[i] = row
    return row
  end

  local function EntryFont(e, fs)
    local lvl = UnitLevel("player")
    if e.hi ~= 0 and e.hi < lvl then
      fs:SetFontObject(_G.LFGActivityEntryTrivial or "GameFontDisable")
      if not _G.LFGActivityEntryTrivial then fs:SetTextColor(0.6, 0.6, 0.6) end
    elseif e.lo ~= 0 and e.lo > lvl then
      fs:SetFontObject(_G.LFGActivityEntryDifficult or "GameFontNormal")
      if not _G.LFGActivityEntryDifficult then fs:SetTextColor(1, 0.25, 0.1) end
    else
      fs:SetFontObject(_G.LFGActivityEntry or "GameFontNormal")
      if not _G.LFGActivityEntry then fs:SetTextColor(1, 0.82, 0) end
    end
  end

  local function UpdateTree()
    local t = ActivityTree()
    local n = 0
    -- Längster Balken = meiste Wartende unter den sichtbaren Aktivitäten
    local maxDemand = 0
    if db.showDemand then
      for _, e in ipairs(t.all) do maxDemand = math.max(maxDemand, Popularity(e.id)) end
    end
    local barSpace = BAR_W
    local function header(text, entries, groupID, collapsed)
      n = n + 1
      local row = TreeRow(n)
      row.activity = nil
      row.bar:Hide()
      local picked = 0
      for _, e in ipairs(entries) do if IsPicked(e) then picked = picked + 1 end end
      row.entries, row.groupID, row.isCollapsed, row.anyPicked = entries, groupID, collapsed, picked > 0
      row.expand:SetShown(groupID ~= nil)
      row.check:ClearAllPoints()
      if groupID then
        row.expand:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        row.check:SetPoint("LEFT", row.expand, "RIGHT", 4, 0)
      else
        row.check:SetPoint("LEFT", row.expand, "LEFT", 4, 0)
      end
      row.check:SetChecked(picked > 0)
      row.check:SetCheckedTexture(picked > 0 and picked < #entries and "Interface\\Buttons\\UI-MultiCheck-Up"
        or "Interface\\Buttons\\UI-CheckBox-Check")
      row.name:SetFontObject(_G.LFGActivityHeader or "GameFontHighlight")
      if not _G.LFGActivityHeader then row.name:SetTextColor(1, 1, 1) end
      row.name:SetText(text)
      row.linkText = text
      row.level:SetText("")
      row:Show()
    end
    local function item(e)
      n = n + 1
      local row = TreeRow(n)
      row.entries, row.groupID, row.anyPicked = { e }, nil, IsPicked(e)
      row.activity = e.id
      local amount = db.showDemand and Popularity(e.id) or 0
      if maxDemand > 0 and amount >= 5 then -- kleine Zahlen sind Zufall
        row.bar:SetWidth(math.max(2, barSpace * amount / maxDemand))
        row.bar:Show()
      else
        row.bar:Hide()
      end
      row.expand:Hide()
      row.check:ClearAllPoints()
      row.check:SetPoint("LEFT", row.expand, "RIGHT", 4, 0)
      row.check:SetChecked(IsPicked(e))
      row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      EntryFont(e, row.name)
      EntryFont(e, row.level)
      row.name:SetText(e.name)
      row.linkText = e.name
      row.level:SetText(e.lo > 0 and ("(%d - %d)"):format(e.lo, e.hi) or "")
      row:Show()
    end
    if t.cat then
      -- Zeile „alles“ nur, wenn es mehr als eine Gruppe gibt; sonst übernimmt das die Gruppe selbst.
      local multi = #t.groups > 1 or (#t.groups > 0 and #t.loose > 0)
      if multi then header(CategoryName(t.cat), t.all) end
      for _, e in ipairs(t.loose) do item(e) end
      for _, g in ipairs(t.groups) do
        local collapsed = false
        if multi then
          collapsed = db.collapsed[g.id]
          if collapsed == nil then collapsed = not g.anyFits end
        end
        header(g.name or "?", g.items, multi and g.id or nil, collapsed)
        if not collapsed then
          for _, e in ipairs(g.items) do item(e) end
        end
      end
    end
    for i = n + 1, #treeRows do treeRows[i]:Hide() end
    tree:SetContentHeight(n * ROW)
  end

  local function UpdateFinder()
    local showActs = db.view == "activities"
    catView:SetShown(not showActs)
    actView:SetShown(showActs)
    for _, b in ipairs(myRoleBtns) do b.check:SetChecked(db.myRoles[b.role] and true or false) end
    npf.check:SetChecked(db.newPlayerFriendly)
    if showActs then
      levelCheck:SetChecked(db.allLevels)
      for _, dd in ipairs(dropdowns) do if dd.cycle then dd.cycle() end end
      UpdateTree()
    else
      UpdateCards()
    end
  end

  -- Optionen hinter dem Zahnrad in der Titelleiste
  local settingsCategory
  local OPTIONS = {
    { "autoInvite", T.OPT_AUTOINVITE, T.OPT_AUTOINVITE_TIP, function() AutoInvite() end },
    { "keySearch", T.OPT_CLICKSEARCH, T.OPT_CLICKSEARCH_TIP:format(DEFAULTS.interval) },
    { "oldestFirst", T.OPT_OLDEST, T.OPT_OLDEST_TIP, function() Rebuild() end },
    { "samePlaystyle", T.OPT_SAME_PLAYSTYLE, T.OPT_SAME_PLAYSTYLE_TIP, function() Rebuild() end },
    { "levelCheck", T.OPT_LEVEL, T.OPT_LEVEL_TIP, function() Rebuild() end },
    { "preferFriends", T.OPT_FRIENDS, T.OPT_FRIENDS_TIP, function() Rebuild() end },
    { "inviteWhisper", T.OPT_WHISPER, T.OPT_WHISPER_TIP:format(SLASH) },
    { "notify", T.OPT_NOTIFY, T.OPT_NOTIFY_TIP },
    { "showDemand", T.OPT_DEMAND, T.OPT_DEMAND_TIP, function() Rebuild() end },
    { "sound", T.OPT_SOUND, T.OPT_SOUND_TIP },
  }
  local function ToggleOption(o)
    db[o[1]] = not db[o[1]]
    if o[4] then o[4]() end
  end
  -- Flüstertext in Blizzards Eingabefenster ändern; leer = Standardtext
  local function DialogEditBox(d) return d.GetEditBox and d:GetEditBox() or d.editBox end
  local function SaveWhisper(text)
    text = strtrim(text or "")
    db.whisperText = text ~= "" and text or nil
    Print(T.CHAT_WHISPER_SET:format(db.whisperText or T.WHISPER_DEFAULT))
  end
  StaticPopupDialogs = StaticPopupDialogs or {}
  StaticPopupDialogs.AUTOGROUPFINDER_WHISPER = {
    text = T.WHISPER_EDIT_PROMPT,
    button1 = ACCEPT or OKAY,
    button2 = CANCEL,
    button3 = DEFAULT or T.DEFAULT,
    hasEditBox = 1,
    editBoxWidth = 350,
    OnShow = function(d)
      local eb = DialogEditBox(d)
      eb:SetMaxLetters(200)
      eb:SetText(db.whisperText or T.WHISPER_DEFAULT)
      eb:HighlightText()
    end,
    OnAccept = function(d) SaveWhisper(DialogEditBox(d):GetText()) end,
    OnAlt = function() SaveWhisper("") end,
    EditBoxOnEnterPressed = function(eb)
      SaveWhisper(eb:GetText())
      eb:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
  }
  local function EditWhisper() if StaticPopup_Show then StaticPopup_Show("AUTOGROUPFINDER_WHISPER") end end

  local function OpenSettings()
    if settingsCategory and Settings and Settings.OpenToCategory then
      Settings.OpenToCategory(settingsCategory:GetID())
    end
  end

  local okGear, gear = pcall(CreateFrame, "DropdownButton", nil, win)
  local menuOk = okGear and gear and gear.SetupMenu
  if not menuOk then gear = CreateFrame("Button", nil, win) end
  gear:SetSize(16, 16)
  gear:SetPoint("TOPRIGHT", win, "TOPRIGHT", -36, -4)
  -- Über der Titelleiste, sonst verdeckt deren Rahmen das Zahnrad
  local closeLevel = win.CloseButton and win.CloseButton:GetFrameLevel()
  gear:SetFrameLevel((closeLevel or (win:GetFrameLevel() or 1) + 600) + 1)
  gear.Icon = gear:CreateTexture(nil, "ARTWORK")
  gear.Icon:SetAllPoints()
  if not Atlas(gear.Icon, "OptionsIcon-Brown") then gear.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton") end
  gear.Icon:SetAlpha(0.8)
  gear:SetScript("OnEnter", function(self)
    self.Icon:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(T.OPTIONS)
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function(self)
    self.Icon:SetAlpha(0.8)
    GameTooltip:Hide()
  end)

  local fallbackChecks = {}
  if menuOk then
    gear:SetupMenu(function(_, root)
      for _, o in ipairs(OPTIONS) do
        local item = root:CreateCheckbox(o[2], function() return db[o[1]] end, function() ToggleOption(o) end)
        if o[3] and item and item.SetTooltip then
          item:SetTooltip(function(tooltip)
            GameTooltip_SetTitle(tooltip, o[2])
            GameTooltip_AddNormalLine(tooltip, o[3])
          end)
        end
      end
      if next(db.blocked) then
        local list = root:CreateButton(T.BLOCKED_LIST)
        for k in pairs(db.blocked) do
          list:CreateButton(T.UNBLOCK_ENTRY:format(Short(k)), function() ToggleBlocked(k) end)
        end
      end
      root:CreateDivider()
      root:CreateButton(T.EDIT_WHISPER, EditWhisper)
      if settingsCategory then root:CreateButton(T.SETTINGS, OpenSettings) end
    end)
  else
    -- Ohne Menü-API: kleines Aufklappfenster mit Häkchen
    local pop = CreateFrame("Frame", nil, gear, BackdropTemplateMixin and "BackdropTemplate" or nil)
    pop:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 0, -4)
    pop:SetFrameStrata("DIALOG")
    if pop.SetBackdrop then
      pop:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      pop:SetBackdropColor(0, 0, 0, 0.92)
    end
    pop:Hide()
    local widest = 0
    for i, o in ipairs(OPTIONS) do
      local cb = CreateFrame("CheckButton", nil, pop, "UICheckButtonTemplate")
      cb:SetSize(24, 24)
      cb:SetPoint("TOPLEFT", 12, -12 - (i - 1) * 24)
      local fs = Label(cb, o[2], "GameFontHighlightSmall", "LEFT", cb, "RIGHT", 2, 0)
      widest = math.max(widest, fs:GetStringWidth())
      cb:SetScript("OnClick", function() ToggleOption(o) end)
      if o[3] then Tooltip(cb, o[2], o[3]) end
      cb.key = o[1]
      fallbackChecks[#fallbackChecks + 1] = cb
    end
    pop:SetSize(widest + 64, 24 + #OPTIONS * 24)
    gear:SetScript("OnClick", function() pop:SetShown(not pop:IsShown()) end)
  end

  -------------------------------------------------------------------------
  -- Seite 2: Gefundene Spieler, gruppiert nach Rolle
  -------------------------------------------------------------------------
  Inset(found, -72)

  -- Leiste wie in Blizzards Browse-Ansicht: Kategorie, Aktivitäten, Aktualisieren.
  -- Dieselbe Auswahl wie auf der ersten Seite.
  local catDd = Dropdown(found, 150, function()
      local opts = {}
      for _, c in ipairs(Categories()) do
        if #ActivityTree(c.id).all > 0 then opts[#opts + 1] = { c.id, c.name } end
      end
      return opts
    end, nil,
    function() return CurrentCategory() end,
    function(v) db.category, db.view = v, "activities"; Rebuild() end,
    "TOPLEFT", win, "TOPLEFT", 62, -38)

  local function ActivitySummary()
    local t, picked = ActivityTree(), {}
    for _, e in ipairs(t.all) do if IsPicked(e) then picked[#picked + 1] = e end end
    if #picked == 0 then return T.NOTHING_PICKED end
    if #picked == #t.all and #picked > 1 then return T.ALL_ACTIVITIES:format(#picked) end
    if #picked == 1 then return picked[1].name end
    return picked[1].name .. " +" .. (#picked - 1)
  end

  local okAct, actDd = pcall(CreateFrame, "DropdownButton", nil, found, "WowStyle1DropdownTemplate")
  if okAct and actDd and actDd.SetupMenu then
    actDd:SetWidth(170)
    actDd:SetupMenu(function(_, root)
      local t = ActivityTree()
      local multi = #t.groups > 1 or (#t.groups > 0 and #t.loose > 0)
      local function add(e)
        root:CreateCheckbox(e.name, function() return IsPicked(e) end, function()
          db.activities[e.id] = not IsPicked(e)
          Rebuild()
        end)
      end
      for _, e in ipairs(t.loose) do add(e) end
      for _, g in ipairs(t.groups) do
        if multi then root:CreateTitle(g.name or "?") end
        for _, e in ipairs(g.items) do add(e) end
      end
    end)
  else
    actDd = CreateFrame("Frame", nil, found)
    actDd:SetSize(170, 24)
    actDd.Text = Label(actDd, "", "GameFontHighlightSmall", "LEFT", actDd, "LEFT", 4, 0)
  end
  actDd:SetPoint("LEFT", catDd, "RIGHT", 8, 0)

  local refresh = CreateFrame("Button", nil, found)
  refresh:SetSize(32, 32)
  refresh:SetPoint("LEFT", actDd, "RIGHT", 9, 0)
  refresh:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
  refresh:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
  refresh:SetDisabledTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
  refresh:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  refresh.Icon = refresh:CreateTexture(nil, "ARTWORK", nil, 5)
  refresh.Icon:SetSize(16, 16)
  refresh.Icon:SetPoint("CENTER", -1, 0)
  refresh.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
  refresh:SetScript("OnClick", function() DoSearch(true) end)
  Tooltip(refresh, T.REFRESH)

  local list = Scroller(found, win, 12, -80, -12, 62)
  local listEmpty = Label(found, "", "GameFontDisable", "TOP", win, "TOP", 0, -120)
  listEmpty:SetWidth(WIN_W - 60)
  local HEAD_H, PLAYER_H = 28, 58
  local ShowPlayerMenu
  local listRows = {}

  -- Rechtsklick auf einen Spieler: Aktionen wie bei Blizzard
  function ShowPlayerMenu(owner, c)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then Whisper(c.name) return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(Short(c.name))
      root:CreateButton(T.WHISPER, function() Whisper(c.name) end)
      for _, r in ipairs(ROLES) do
        if c.roles[r] then
          root:CreateButton(T.CTX_INVITE_AS:format(ROLE_NAME[r]), function()
            if CanInvite() then Invite(c, r, true) Rebuild() else Print(T.CHAT_LEADER_ONLY) end
          end)
        end
      end
      if C_FriendList and C_FriendList.AddFriend then
        root:CreateButton(T.ADD_FRIEND, function() C_FriendList.AddFriend(c.name) end)
      end
      root:CreateButton(T.CTX_SKIP, function()
        db.skipUntil[c.key] = time() + 3600
        Rebuild()
      end)
      root:CreateButton(T.CTX_BLOCK, function() ToggleBlocked(c.name) end)
    end)
  end

  -- Ist gerade ein anderer Spieler in diese Zeile gerutscht? Dann kurz keine Klicks annehmen.
  local function JustChanged(row) return GetTime() - (row.changedAt or 0) < 0.5 end
  local function SetRowKey(row, key)
    if row.key ~= key or not row:IsShown() then
      row.key, row.changedAt = key, GetTime()
    end
  end

  local function ListRow(i)
    local row = listRows[i]
    if row then return row end
    row = CreateFrame("Button", nil, list.child)
    row:SetPoint("RIGHT", list.child, "RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Blizzards Listen-Grafiken: Eintrag, Aufleuchten beim Drüberfahren, Überschriften-Leiste
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetPoint("TOPLEFT", 3, -2)
    row.bg:SetPoint("BOTTOMRIGHT", -3, 0)
    if not Atlas(row.bg, "common-button-list-mid2") then row.bg:SetColorTexture(0, 0, 0, 0.4) end
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetPoint("TOPLEFT", 3, -3)
    row.hl:SetPoint("BOTTOMRIGHT", -3, -1)
    if Atlas(row.hl, "common-button-list-mid2-hover") then row.hl:SetBlendMode("ADD") else row.hl:SetColorTexture(1, 1, 1, 0.06) end
    row.headBg = row:CreateTexture(nil, "BACKGROUND")
    row.headBg:SetAllPoints()
    if not Atlas(row.headBg, "common-button-list-collapseExpand") then row.headBg:SetColorTexture(0.3, 0.2, 0.1, 0.6) end
    row.head = Label(row, "", "GameFontNormal", "LEFT", row, "LEFT", 14, 0)
    row.avatar = row:CreateTexture(nil, "ARTWORK")
    row.avatar:SetSize(40, 40)
    row.avatar:SetPoint("LEFT", 12, -1)
    -- Rechte Spalte vor dem Knopf: Wartezeit oben, Spielweise darunter
    local META_RIGHT = -98
    row.age = Label(row, "", "GameFontHighlightSmall", "BOTTOMRIGHT", row, "RIGHT", META_RIGHT, 1)
    row.clock = row:CreateTexture(nil, "ARTWORK")
    row.clock:SetSize(13, 12)
    row.clock:SetPoint("RIGHT", row.age, "LEFT", -2, 0)
    if not Atlas(row.clock, "groupfinder-waitdot") then row.clock:Hide() end
    row.style = Label(row, "", "GameFontDisableSmall", "TOPRIGHT", row, "RIGHT", META_RIGHT, -3)
    -- Mitte: Name als Titel (mit Markierungen), darunter der Dungeon
    row.name = Label(row, "", "GameFontNormal", "BOTTOMLEFT", row, "LEFT", 62, 1)
    row.name:SetPoint("BOTTOMRIGHT", row, "RIGHT", META_RIGHT - 70, 1)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.sub = Label(row, "", "GameFontHighlightSmall", "TOPLEFT", row, "LEFT", 62, -3)
    row.sub:SetPoint("TOPRIGHT", row, "RIGHT", META_RIGHT - 70, -3)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    -- Stufe unten links am Avatar, wie bei Blizzards Einheitenrahmen
    row.level = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.level:SetPoint("BOTTOMLEFT", row.avatar, "BOTTOMLEFT", -3, -2)
    -- Weitere Rollen als kleine Abzeichen unten rechts am Avatar
    row.extra = {}
    for j = 1, 2 do
      local t = row:CreateTexture(nil, "OVERLAY")
      t:SetSize(16, 16)
      t:SetPoint("BOTTOMRIGHT", row.avatar, "BOTTOMRIGHT", 4 - (j - 1) * 13, -3)
      row.extra[j] = t
    end
    row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.btn:SetSize(74, 22)
    row.btn:SetPoint("RIGHT", -14, -1)
    row.btn:SetText(T.INVITE)
    row.btn:SetScript("OnClick", function(self)
      if JustChanged(self:GetParent()) then return end
      local c = self:GetParent().cand
      local _, open = Slots()
      local role = c and RoleFor(c, open)
      if role and CanInvite() then Invite(c, role, true) Rebuild() end
    end)
    row:SetScript("OnClick", function(self, button)
      local c = self.cand
      if not c or JustChanged(self) then return end
      if IsShiftKeyDown() then
        InsertChat(self.sub:IsMouseOver() and c.activityText or Short(c.name))
      elseif button == "RightButton" then
        ShowPlayerMenu(self, c)
      end
    end)
    row:SetScript("OnEnter", function(self)
      local c = self.cand
      if not c then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local color = c.class and RAID_CLASS_COLORS[c.class]
      GameTooltip:SetText(Short(c.name), color and color.r or 1, color and color.g or 1, color and color.b or 1)
      if c.level and c.level > 0 then GameTooltip:AddLine(T.LEVEL:format(c.level), 1, 1, 1) end
      local roles = {}
      for _, r in ipairs(ROLES) do if c.roles[r] then roles[#roles + 1] = ROLE_NAME[r] end end
      GameTooltip:AddLine(table.concat(roles, ", "), 1, 1, 1)
      GameTooltip:AddLine(c.activityText, 1, 0.82, 0, true)
      if c.playstyle and c.playstyle > 0 and PLAYSTYLE_NAME[c.playstyle] then
        GameTooltip:AddLine(PLAYSTYLE_NAME[c.playstyle], 0.13, 1, 0.13)
      end
      if type(c.comment) == "string" and c.comment ~= "" then
        GameTooltip:AddLine("\"" .. c.comment .. "\"", 0.9, 0.9, 0.9, true)
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(T.ROW_HINT, 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    listRows[i] = row
    return row
  end

  local function Age(c)
    local s = math.max(0, math.floor(GetTime() - c.listedAt))
    return s < 60 and T.AGE_S:format(s) or T.AGE_M:format(math.floor(s / 60))
  end

  local function UpdateFound()
    local summary = ActivitySummary()
    if actDd.OverrideText then actDd:OverrideText(summary) elseif actDd.Text then actDd.Text:SetText(summary) end
    for _, dd in ipairs(dropdowns) do if dd.cycle then dd.cycle() end end
    refresh:SetEnabled(not state.searching)
    local n, y, lastRole = 0, 0, nil
    local counts = {}
    for _, c in ipairs(candidates) do counts[c.role] = (counts[c.role] or 0) + 1 end
    for _, c in ipairs(candidates) do
      if c.role ~= lastRole then
        lastRole = c.role
        n = n + 1
        local row = ListRow(n)
        row:SetHeight(HEAD_H)
        row:SetPoint("TOPLEFT", 0, -y)
        SetRowKey(row, "head:" .. c.role)
        y = y + HEAD_H
        row.cand = nil
        row.bg:Hide()
        row.hl:Hide()
        row.headBg:Show()
        row.head:SetText(("%s (%d)"):format(ROLE_PLURAL[c.role], counts[c.role]))
        row.head:Show()
        row.avatar:Hide() row.name:Hide() row.level:Hide() row.sub:Hide() row.btn:Hide()
        row.age:Hide() row.clock:Hide() row.style:Hide()
        for _, t in ipairs(row.extra) do t:Hide() end
        row:Show()
      end
      n = n + 1
      local row = ListRow(n)
      row:SetHeight(PLAYER_H)
      row:SetPoint("TOPLEFT", 0, -y)
      SetRowKey(row, c.key)
      y = y + PLAYER_H
      row.cand = c
      row.bg:Show()
      row.hl:Show()
      row.headBg:Hide()
      row.head:Hide()
      SetRoleTexture(row.avatar, c.role, true)
      row.avatar:Show()
      local color = c.class and RAID_CLASS_COLORS[c.class]
      local title = Short(c.name)
      title = color and color:WrapTextInColorCode(title) or title
      local tags = {}
      if c.friend then tags[#tags + 1] = "|cff82c5ff" .. T.TAG_FRIEND .. "|r" end
      if c.guild then tags[#tags + 1] = "|cff40ff40" .. T.TAG_GUILD .. "|r" end
      if #tags > 0 then title = title .. "  " .. table.concat(tags, " ") end
      row.name:SetText(title)
      row.name:Show()
      row.level:SetText((c.level and c.level > 0) and c.level or "")
      row.level:Show()
      row.sub:SetText(c.activity)
      row.sub:Show()
      row.age:SetText(Age(c))
      row.age:Show()
      row.clock:SetShown(HasAtlas("groupfinder-waitdot"))
      row.style:SetText((c.playstyle and c.playstyle > 0 and PLAYSTYLE_NAME[c.playstyle]) or "")
      row.style:Show()
      -- weitere Rollen, die der Spieler auch angegeben hat
      local j = 0
      for _, r in ipairs(ROLES) do
        if c.roles[r] and r ~= c.role and j < 2 then
          j = j + 1
          SetRoleTexture(row.extra[j], r, false)
          row.extra[j]:Show()
        end
      end
      for k = j + 1, 2 do row.extra[k]:Hide() end
      row.btn:Show()
      row:Show()
    end
    for i = n + 1, #listRows do listRows[i]:Hide() end
    list:SetContentHeight(y)
    local _, pickedIDs = SearchActivities()
    if #pickedIDs == 0 then
      listEmpty:SetText(T.PICK_ACTIVITY)
    elseif #candidates == 0 then
      listEmpty:SetText(state.searching and T.SEARCHING or (T.FOUND_EMPTY .. "\n" .. T.FOUND_EMPTY_HINT))
    else
      listEmpty:SetText("")
    end
  end

  -------------------------------------------------------------------------
  -- Seite 3: Letzte Gruppen – wer mit dir in welchem Dungeon oder Raid war
  -------------------------------------------------------------------------
  do
    local page = pages[3]
    Inset(page, -60)
    local list = Scroller(page, win, 12, -68, -12, 62)
    local empty = Label(page, T.HISTORY_EMPTY, "GameFontDisable", "TOP", win, "TOP", 0, -120)
    empty:SetWidth(WIN_W - 60)
    local rows = {}
    local HEAD, MEMBER = 28, 26

    local function MemberMenu(owner, m)
      if not (MenuUtil and MenuUtil.CreateContextMenu) then Whisper(m.name) return end
      MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(Short(m.name))
        root:CreateButton(T.WHISPER, function() Whisper(m.name) end)
        root:CreateButton(T.INVITE, function()
          if CanInvite() then api.invite(m.name) else Print(T.CHAT_LEADER_ONLY) end
        end)
        if C_FriendList and C_FriendList.AddFriend then
          root:CreateButton(T.ADD_FRIEND, function() C_FriendList.AddFriend(m.name) end)
        end
        root:CreateButton(db.blocked[Key(m.name)] and T.CTX_UNBLOCK or T.CTX_BLOCK, function() ToggleBlocked(m.name) end)
      end)
    end

    local function EntryMenu(owner, index)
      if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
      MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(T.HISTORY_DELETE, function()
          table.remove(db.history, index)
          Rebuild()
        end)
      end)
    end

    local function Row(i)
      if rows[i] then return rows[i] end
      local row = CreateFrame("Button", nil, list.child)
      row:SetPoint("RIGHT", list.child, "RIGHT")
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row.headBg = row:CreateTexture(nil, "BACKGROUND")
      row.headBg:SetAllPoints()
      if not Atlas(row.headBg, "common-button-list-collapseExpand") then row.headBg:SetColorTexture(0.3, 0.2, 0.1, 0.6) end
      row.hl = row:CreateTexture(nil, "HIGHLIGHT")
      row.hl:SetAllPoints()
      row.hl:SetColorTexture(1, 1, 1, 0.05)
      row.title = Label(row, "", "GameFontNormal", "LEFT", row, "LEFT", 14, 0)
      row.date = Label(row, "", "GameFontDisableSmall", "RIGHT", row, "RIGHT", -12, 0)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(20, 20)
      row.icon:SetPoint("LEFT", 30, 0)
      row.name = Label(row, "", "GameFontHighlight", "LEFT", row.icon, "RIGHT", 6, 0)
      row.level = Label(row, "", "GameFontDisableSmall", "LEFT", row.name, "RIGHT", 6, 0)
      row:SetScript("OnClick", function(self, button)
        if self.member then
          if IsShiftKeyDown() then InsertChat(Short(self.member.name))
          elseif button == "RightButton" then MemberMenu(self, self.member) end
        elseif self.entryIndex then
          if IsShiftKeyDown() then InsertChat(self.title:GetText())
          elseif button == "RightButton" then EntryMenu(self, self.entryIndex) end
        end
      end)
      rows[i] = row
      return row
    end

    History.Update = function()
      local n, y = 0, 0
      for index, e in ipairs(db.history) do
        n = n + 1
        local row = Row(n)
        row:SetHeight(HEAD)
        row:SetPoint("TOPLEFT", 0, -y)
        y = y + HEAD + 2
        row.member, row.entryIndex = nil, index
        row.headBg:Show()
        row.title:SetText(e.name or "?")
        row.title:Show()
        row.date:SetText(date(T.DATE_FMT, e.t))
        row.date:Show()
        row.icon:Hide() row.name:Hide() row.level:Hide()
        row:Show()
        for _, m in ipairs(e.members or {}) do
          n = n + 1
          local r = Row(n)
          r:SetHeight(MEMBER)
          r:SetPoint("TOPLEFT", 0, -y)
          y = y + MEMBER
          r.member, r.entryIndex = m, nil
          r.headBg:Hide() r.title:Hide() r.date:Hide()
          if m.role then SetRoleTexture(r.icon, m.role, false) end
          r.icon:SetShown(m.role ~= nil)
          local color = m.class and RAID_CLASS_COLORS[m.class]
          r.name:SetText(color and color:WrapTextInColorCode(Short(m.name)) or Short(m.name))
          r.name:Show()
          r.level:SetText((m.level and m.level > 0) and m.level or "")
          r.level:Show()
          r:Show()
        end
        y = y + 6
      end
      for i = n + 1, #rows do rows[i]:Hide() end
      list:SetContentHeight(y)
      empty:SetShown(#db.history == 0)
    end
  end

  -------------------------------------------------------------------------
  -- Gemeinsam: Seitenreiter, Fußleiste mit Zurück, Rollen-Icons und Bestätigungsknopf
  -------------------------------------------------------------------------
  local tabs = {}
  local function ShowPage(i)
    db.page = i
    for j, p in ipairs(pages) do p:SetShown(j == i) end
    for j, t in ipairs(tabs) do if t.SetChecked then t:SetChecked(j == i) end end
    Rebuild()
  end

  for i, iconPath in ipairs(TAB_ICONS) do
    local tip = ({ T.TAB_FINDER, T.TAB_FOUND, T.TAB_HISTORY })[i]
    local okTab, tab = pcall(CreateFrame, "Frame", nil, win, "LargeSideTabButtonTemplate")
    if okTab and tab and tab.Icon and tab.SetCustomOnMouseUpHandler then
      tab.Icon:SetTexture(iconPath)
      if tab.SetFillToInterior then
        tab:SetFillToInterior(true) -- Icon füllt den Reiter wie bei Blizzard
      else
        tab.Icon:SetSize(30, 30)
      end
      tab.tooltipText = tip
      tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside then ShowPage(i) end
      end)
    else
      tab = CreateFrame("Button", nil, win)
      tab:SetSize(40, 40)
      tab.Icon = tab:CreateTexture(nil, "ARTWORK")
      tab.Icon:SetAllPoints()
      tab.Icon:SetTexture(iconPath)
      tab:SetScript("OnClick", function() ShowPage(i) end)
      Tooltip(tab, tip)
    end
    if i == 1 then
      tab:SetPoint("TOPLEFT", win, "TOPRIGHT", 0, -60)
    else
      tab:SetPoint("TOPLEFT", tabs[i - 1], "BOTTOMLEFT", 0, -2)
    end
    tabs[i] = tab
  end

  -- Eigene Ebene über den Seiten, sonst verdeckt deren Hintergrund die Knöpfe
  local footer = CreateFrame("Frame", nil, win)
  footer:SetPoint("BOTTOMLEFT")
  footer:SetPoint("BOTTOMRIGHT")
  footer:SetHeight(60)
  footer:SetFrameLevel((finder:GetFrameLevel() or 1) + 10)

  local backBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
  backBtn:SetSize(111, 28)
  backBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 21, 16)
  backBtn:SetText(BACK or T.BACK)
  backBtn:SetScript("OnClick", function()
    db.view = "categories"
    Rebuild()
  end)

  local Clock = function(sec)
    sec = math.max(0, math.floor(sec))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
  end

  -- Noch offene Rollen als kleine Icons mit Anzahl, während der Suche mit Uhr davor
  local need = CreateFrame("Frame", nil, footer)
  need:SetSize(150, 24)
  need:SetPoint("BOTTOM", win, "BOTTOM", 0, 18)
  need.clock = Label(need, "", "GameFontHighlightSmall", "LEFT", need, "LEFT", 0, 0)
  need.icons, need.counts = {}, {}
  for i, role in ipairs(ROLES) do
    local t = need:CreateTexture(nil, "ARTWORK")
    t:SetSize(20, 20)
    SetRoleTexture(t, role, false)
    need.icons[i] = t
    need.counts[i] = Label(need, "", "GameFontHighlightSmall", "LEFT", t, "RIGHT", 1, 0)
  end

  local function UpdateNeed()
    local rem = Slots()
    local x = 0
    need.clock:SetText(state.queued and Clock(GetTime() - state.queuedAt) or "")
    if state.queued then x = need.clock:GetStringWidth() + 8 end
    for i, role in ipairs(ROLES) do
      local t, c = need.icons[i], need.counts[i]
      if rem[role] > 0 then
        t:ClearAllPoints()
        t:SetPoint("LEFT", need, "LEFT", x, 0)
        c:SetText(rem[role] > 1 and ("×" .. rem[role]) or "")
        t:Show() c:Show()
        x = x + 22 + (rem[role] > 1 and c:GetStringWidth() + 4 or 0)
      else
        t:Hide() c:Hide()
      end
    end
    need:SetWidth(math.max(1, x))
  end

  local mainBtn = CreateFrame("Button", "AutoGroupFinderStartButton", footer, "UIPanelButtonTemplate")
  mainBtn:SetSize(134, 28)
  mainBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -21, 16)
  mainBtn:SetMotionScriptsWhileDisabled(true)
  mainBtn:SetScript("OnClick", function()
    if GroupReady() then
      api.readyCheck()
    elseif state.queued then
      StopQueue(T.CHAT_STOPPED)
    else
      StartQueue()
    end
  end)

  local function BlockReason()
    if state.queued or GroupReady() then return nil end
    if db.view ~= "activities" then return T.PICK_CATEGORY end
    if (db.playstyle or 0) == 0 then return PLAYSTYLE_REQUIRED end
    local _, ids = SearchActivities()
    if #ids == 0 then return T.PICK_ACTIVITY end
  end

  -- Details für Tooltips von Knopf und Minimap-Symbol
  local function StatusLines()
    local lines = {}
    if state.queued then lines[#lines + 1] = T.SEARCHING_FOR:format(Clock(GetTime() - state.queuedAt)) end
    local needText = NeedText((Slots()))
    lines[#lines + 1] = needText ~= "" and T.STATUS_NEED:format(needText) or T.GROUP_COMPLETE
    local waiting = {}
    for k, p in pairs(pending) do waiting[#waiting + 1] = Short(k) .. " (" .. ROLE_NAME[p.role] .. ")" end
    if #waiting > 0 then lines[#lines + 1] = T.WAITING_FOR:format(table.concat(waiting, ", ")) end
    if state.queued and NeedsRaid() then lines[#lines + 1] = "|cffffd100" .. T.NEED_CONVERT .. "|r" end
    return lines
  end

  mainBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local reason = BlockReason()
    if reason then
      GameTooltip:SetText(reason, RED_FONT_COLOR and RED_FONT_COLOR.r or 1, 0.2, 0.2, 1, true)
    else
      GameTooltip:SetText(self:GetText())
      for _, line in ipairs(StatusLines()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  mainBtn:SetScript("OnLeave", GameTooltip_Hide)

  UpdateUI = function()
    if not db or not win:IsShown() then return end
    if db.page == 1 then
      UpdateFinder()
      for _, cb in ipairs(fallbackChecks) do cb:SetChecked(db[cb.key]) end
    elseif db.page == 2 then
      UpdateFound()
    else
      History.Update()
    end
    if win.SetTitle then
      win:SetTitle(({ T.TITLE, T.FOUND_TITLE:format(#candidates), T.TAB_HISTORY })[db.page] or T.TITLE)
    end
    backBtn:SetShown(db.page == 1)
    backBtn:SetEnabled(db.view == "activities" and not state.queued)
    UpdateNeed()
    mainBtn:SetText(GroupReady() and (READY_CHECK or T.READY_CHECK) or state.queued and T.LEAVE_QUEUE or T.FIND_GROUP)
    mainBtn:SetEnabled(BlockReason() == nil)
  end

  win:SetScript("OnShow", function() ShowPage(db.page or 1) end)

  function AutoGroupFinder_Toggle()
    win:SetShown(not win:IsShown())
  end

  -------------------------------------------------------------------------
  -- Einstellungen (Optionen → AddOns → GroupFinder)
  -------------------------------------------------------------------------
  local function RegisterSettings()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local category, layout = Settings.RegisterVerticalLayoutCategory(T.TITLE)
    local function header(text)
      if CreateSettingsListSectionHeaderInitializer and layout and layout.AddInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
      end
    end
    header(T.SETTINGS_GENERAL)
    for _, o in ipairs(OPTIONS) do
      local setting = Settings.RegisterAddOnSetting(category, "AUTOGROUPFINDER_" .. o[1]:upper(), o[1], db,
        Settings.VarType.Boolean, o[2], DEFAULTS[o[1]])
      if o[4] then setting:SetValueChangedCallback(function() o[4]() end) end
      Settings.CreateCheckbox(category, setting, o[3])
    end
    if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
      layout:AddInitializer(CreateSettingsButtonInitializer(T.OPT_WHISPER_TEXT, T.EDIT, EditWhisper, T.WHISPER_EDIT_PROMPT, true))
    end
    header(T.SETTINGS_LANGUAGES)
    local myLocale = GetLocale() == "enGB" and "enUS" or GetLocale()
    if myLocale == "enUS" and db.languageMode == "mineEnglish" then db.languageMode = "mine" end
    local modeSetting = Settings.RegisterAddOnSetting(category, "AUTOGROUPFINDER_LANGMODE", "languageMode", db,
      Settings.VarType.String, T.LANG_MODE, "all")
    local modeInit = Settings.CreateDropdown(category, modeSetting, function()
      local c = Settings.CreateControlTextContainer()
      c:Add("all", T.LANG_ALL)
      c:Add("mine", T.LANG_MINE:format(T["LANG_" .. myLocale] or myLocale))
      if myLocale ~= "enUS" then
        c:Add("mineEnglish", T.LANG_MINE_EN:format(T["LANG_" .. myLocale] or myLocale))
      end
      c:Add("custom", T.LANG_CUSTOM)
      return c:GetData()
    end, T.LANG_TIP)
    for _, loc in ipairs(LANGUAGES) do
      local setting = Settings.RegisterAddOnSetting(category, "AUTOGROUPFINDER_LANG_" .. loc, loc, db.languages,
        Settings.VarType.Boolean, T["LANG_" .. loc], false)
      local init = Settings.CreateCheckbox(category, setting, T.LANG_TIP)
      -- nur bei „Eigene Auswahl“ bedienbar
      if init and init.SetParentInitializer and modeInit then
        init:SetParentInitializer(modeInit, function() return db.languageMode == "custom" end)
      end
    end
    for _, size in ipairs(SIZES) do
      header((size == 5 and T.SIZE_PARTY or T.SIZE_RAID):format(size))
      for _, role in ipairs(ROLES) do
        local setting = Settings.RegisterAddOnSetting(category, ("AUTOGROUPFINDER_NEED_%d_%s"):format(size, role),
          role, db.need[size], Settings.VarType.Number, ROLE_PLURAL[role], DEFAULT_NEED[size][role])
        setting:SetValueChangedCallback(function() Rebuild() end)
        local options = Settings.CreateSliderOptions(0, size, 1)
        if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
          options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return tostring(math.floor(v + 0.5)) end)
        end
        Settings.CreateSlider(category, setting, options, T.COMPOSITION_TIP)
      end
    end
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
  end

  -------------------------------------------------------------------------
  -- Minimap-Symbol
  -------------------------------------------------------------------------
  local mm = CreateFrame("Button", "AutoGroupFinderMinimapButton", Minimap)
  mm:SetSize(31, 31)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mm:RegisterForDrag("LeftButton")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local mmBg = mm:CreateTexture(nil, "BACKGROUND")
  mmBg:SetSize(20, 20)
  mmBg:SetPoint("TOPLEFT", 7, -5)
  mmBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local mmIcon = mm:CreateTexture(nil, "ARTWORK")
  mmIcon:SetSize(20, 20)
  mmIcon:SetPoint("TOPLEFT", 7, -5)
  mmIcon:SetTexture(ICON)
  local mmBorder = mm:CreateTexture(nil, "OVERLAY")
  mmBorder:SetSize(53, 53)
  mmBorder:SetPoint("TOPLEFT")
  mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  local mmGlow = mm:CreateTexture(nil, "OVERLAY", nil, 1)
  mmGlow:SetSize(31, 31)
  mmGlow:SetPoint("CENTER")
  mmGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmGlow:SetBlendMode("ADD")
  mmGlow:Hide()
  local pulse = mmGlow:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(0.2)
  fade:SetToAlpha(1)
  fade:SetDuration(0.8)

  local function PlaceMinimap()
    local a = math.rad(db.minimap.angle)
    local r = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end

  mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      PlaceMinimap()
    end)
  end)
  mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      if IsShiftKeyDown() then
        if state.queued then StopQueue(T.CHAT_STOPPED) end
      else
        AutoGroupFinder_Next()
      end
    else
      AutoGroupFinder_Toggle()
    end
  end)
  mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(T.TITLE)
    for _, line in ipairs(StatusLines()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T.MM_LEFT, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(state.queued and T.MM_RIGHT_SEARCH or T.MM_RIGHT_START, 0.7, 0.7, 0.7)
    if state.queued then GameTooltip:AddLine(T.MM_SHIFT_RIGHT, 0.7, 0.7, 0.7) end
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", GameTooltip_Hide)

  UpdateMinimap = function()
    if not db then return end
    mm:SetShown(not db.minimap.hide)
    mmGlow:SetShown(state.queued)
    if state.queued then
      if not pulse:IsPlaying() then pulse:Play() end
    else
      pulse:Stop()
    end
  end

  -- Für die Addon-Liste an der Minimap (## AddonCompartmentFunc in der .toc)
  function AutoGroupFinder_OnCompartmentClick(_, button)
    if button == "RightButton" then AutoGroupFinder_Next() else AutoGroupFinder_Toggle() end
  end

  -------------------------------------------------------------------------
  -- Ereignisse
  -------------------------------------------------------------------------
  local test -- Testlauf, siehe RunTest

  local function OnResults()
    state.searching = nil
    Rebuild()
    AutoInvite()
  end

  -- Meldung in der Bildschirmmitte und Taskleiste blinken lassen (falls WoW im Hintergrund ist)
  function Notify(text)
    if not db.notify then return end
    local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING
    if RaidWarningUtil and RaidWarningUtil.AddMessage then
      pcall(RaidWarningUtil.AddMessage, text, color)
    elseif RaidNotice_AddMessage and RaidWarningFrame then
      pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color)
    end
    if FlashClientIcon then pcall(FlashClientIcon) end
  end

  -- Rollen setzen erlaubt Blizzard nur nach Klick oder Taste; vorgemerkt und beim nächsten Klick gesetzt.
  local roleQueue = {}
  HardwareTick = function()
    if not db or InCombatLockdown() then return end
    if IsInGroup() and UnitIsGroupLeader("player") then
      for k, unit in pairs(MemberKeys()) do
        local role = roleQueue[k]
        if role and api.unitRole(unit) ~= role then api.setRole(unit, role) end
        roleQueue[k] = nil
      end
      -- eigene Rolle nur einmal pro Änderung setzen, nicht bei jedem Klick
      local _, me = Filled()
      if api.unitRole("player") ~= me and state.selfRole ~= me then
        api.setRole("player", me)
        state.selfRole = me
      end
    end
    local now = GetTime()
    for _, w in ipairs(whisperQueue) do
      if now - w.t < 20 then api.whisper(w.name, w.text) end
    end
    wipe(whisperQueue)
  end

  -- Verlauf: ein Eintrag je Gruppe, vom Entstehen bis zum Auflösen. Draußen heißt er nach der
  -- Zone; betretene Dungeons und Raids ersetzen bzw. ergänzen den Namen.
  function History.Snapshot()
    local list = {}
    for _, m in ipairs(api.members()) do
      local _, class = UnitClass(m.unit)
      local role = joined[Key(m.name)] or api.unitRole(m.unit)
      if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = nil end
      list[#list + 1] = { name = m.name, class = class, role = role, level = UnitLevel(m.unit) }
    end
    return list
  end

  function History.Merge(entry)
    local have = {}
    for _, m in ipairs(entry.members) do have[Key(m.name)] = m end
    for _, m in ipairs(History.Snapshot()) do
      local old = have[Key(m.name)]
      if old then
        old.role = old.role or m.role
        old.level = m.level or old.level
      else
        entry.members[#entry.members + 1] = m
      end
    end
  end

  -- Nach /reload: den letzten Eintrag fortsetzen, wenn er frisch ist und jemand von damals dabei ist
  local function ContinuesLast()
    local last = db.history[1]
    if not last or time() - (last.last or last.t) > 6 * 3600 then return nil end
    local now = MemberKeys()
    for _, m in ipairs(last.members) do
      if now[Key(m.name)] then return last end
    end
  end

  function History.Track()
    if not IsInGroup() then
      state.historyEntry = nil
      return
    end
    local e = state.historyEntry or ContinuesLast()
    if not e then
      e = { t = time(), name = GetRealZoneText and GetRealZoneText() or "?", members = {} }
      table.insert(db.history, 1, e)
      while #db.history > 100 do table.remove(db.history) end
    end
    state.historyEntry = e
    local inInstance, kind = IsInInstance()
    if inInstance and (kind == "party" or kind == "raid") then
      local name = GetInstanceInfo()
      if not e.instance then
        e.name, e.instance = name, true
      elseif name and not e.name:find(name, 1, true) then
        e.name = e.name .. ", " .. name
      end
    end
    e.last = time()
    History.Merge(e)
  end

  local function OnRoster()
    if not IsInGroup() then state.selfRole = nil end
    local members = MemberKeys()
    for name in pairs(members) do
      local k = FindPending(name)
      if k then
        joined[k] = pending[k].role
        pending[k] = nil
        roleQueue[k] = joined[k]
        Print(T.CHAT_JOINED:format(Short(k), ROLE_NAME[joined[k]]))
        Notify(T.CHAT_JOINED:format(Short(k), ROLE_NAME[joined[k]]))
      elseif expired[name] and not joined[name] then
        joined[name] = expired[name]
        roleQueue[name] = joined[name]
        Print(T.CHAT_LATE:format(Short(name), ROLE_NAME[joined[name]]))
      end
    end
    for k in pairs(joined) do if not members[k] then joined[k] = nil end end
    Rebuild()
    if not IsInGroup() then state.completed = false end
    -- Fertige Gruppe wieder unvollständig: Neustart braucht einen Klick, also nur Bescheid geben.
    if not state.queued and state.completed and IsInGroup() and CanInvite() then
      local rem = Slots()
      if AnyLeft(rem) and not state.backfillNoted then
        state.backfillNoted = true
        Print(T.CHAT_BACKFILL:format(NeedText(rem)))
        Notify(T.NOTIFY_BACKFILL:format(NeedText(rem)))
      elseif not AnyLeft(rem) then
        state.backfillNoted = false
      end
    end
    if state.queued then
      local _, _, cap = Target()
      if not AnyLeft((Slots())) or api.groupSize() >= cap then
        FinishQueue()
      else
        AutoInvite() -- auch wenn jemand gegangen ist: Platz wird neu besetzt
      end
    end
  end

  local function Tick()
    if not db then return end
    local now = GetTime()
    local drop = {}
    for k, p in pairs(pending) do
      if not p.confirmed and now - p.t > 5 then
        drop[#drop + 1] = { k, 60, T.CHAT_NOT_SENT }
      elseif now - p.t > db.inviteTimeout then
        drop[#drop + 1] = { k, db.declineCooldown, T.CHAT_NO_ANSWER }
      end
    end
    for _, d in ipairs(drop) do DropPending(d[1], d[2], d[3]) end
    if state.searching and now - state.searching > 10 then state.searching = nil end
    if UpdateUI then UpdateUI() end
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "CHAT_MSG_ADDON",
      "PARTY_INVITE_REQUEST",
      "PLAYER_ENTERING_WORLD",
      "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_SEARCH_FAILED",
      "LFG_LIST_AVAILABILITY_UPDATE", "GROUP_ROSTER_UPDATE", "CHAT_MSG_SYSTEM" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
      if arg1 ~= ADDON then return end
      AutoGroupFinderDB = AutoGroupFinderDB or {}
      db = AutoGroupFinderDB
      for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = type(v) == "table" and CopyTable(v) or v end
      end
      for k, v in pairs(DEFAULTS.minimap) do if db.minimap[k] == nil then db.minimap[k] = v end end
      for _, size in ipairs(SIZES) do
        db.need[size] = db.need[size] or CopyTable(DEFAULT_NEED[size])
      end
      if (db.voice or 0) < 0 then db.voice = 0 end
      if db.myRole then db.myRoles = { [db.myRole] = true }; db.myRole = nil end -- alte Einstellung übernehmen
      local nowEpoch = time()
      for k, t in pairs(db.skipUntil) do if t <= nowEpoch then db.skipUntil[k] = nil end end
      for a, seenBy in pairs(db.popular) do
        for k, t in pairs(seenBy) do if t < nowEpoch - 1800 then seenBy[k] = nil end end
        if next(seenBy) == nil then db.popular[a] = nil end
      end
      pcall(RegisterSettings)
      return
    end
    if not db then return end
    if event == "PLAYER_LOGIN" then
      if L.RequestAvailableActivities then pcall(L.RequestAvailableActivities) end
      PlaceMinimap()
      UpdateMinimap()
      WorldFrame:HookScript("OnMouseDown", function()
        HardwareTick()
        if db.keySearch then DoSearch(false) end
      end)
      C_Timer.NewTicker(1, Tick)
      History.Track() -- nach /reload in der laufenden Gruppe weitermachen
      if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM_PREFIX) end
      Print(T.LOADED:format(SLASH))
    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
      if not test then OnResults() end
    elseif event == "LFG_LIST_SEARCH_FAILED" then
      state.searching = nil
    elseif event == "PARTY_INVITE_REQUEST" then
      state.lastInviter = arg1
      -- arg2-4: Rollen, die der Einladende anbietet (Tank, Heiler, Schaden)
      local offered = (arg2 or arg3 or arg4) and { TANK = arg2, HEALER = arg3, DAMAGER = arg4 } or nil
      InviteInfo.offered = offered
      InviteInfo.Show(arg1, 0, offered)
    elseif event == "CHAT_MSG_ADDON" then
      OnAddonMessage(arg1, arg2, arg3, arg4)
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
      -- kommt oft in Schüben: einmal neu aufbauen statt bei jedem Eintrag
      if not state.rebuildQueued then
        state.rebuildQueued = true
        C_Timer.After(0.2, function() state.rebuildQueued = false Rebuild() end)
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      AutoInvite() -- im Kampf liegengebliebene Einladungen nachholen
    elseif event == "PLAYER_ENTERING_WORLD" then
      History.Track()
      local inInstance, kind = IsInInstance()
      if state.queued and inInstance and (kind == "party" or kind == "raid") then
        StopQueue(T.CHAT_IN_INSTANCE)
      end
    elseif event == "GROUP_ROSTER_UPDATE" then
      History.Track()
      OnRoster()
    elseif event == "CHAT_MSG_SYSTEM" then
      OnSystem(arg1)
    else
      Rebuild()
    end
  end)

  -------------------------------------------------------------------------
  -- Testlauf mit erfundenen Spielern: keine echte Suche, keine echten Einladungen
  -------------------------------------------------------------------------
  local function Shot()
    if test and test.shots and Screenshot then Screenshot() end
  end

  local function EndTest()
    if not test then return end
    for k, v in pairs(test.saved) do db[k] = v end
    test = nil
    api = real
    state.queued = false
    UpdateMinimap()
    wipe(pending) wipe(joined) wipe(expired) wipe(seen)
    Rebuild()
    Print(T.TEST_DONE)
  end

  local function RunTest(shots)
    if test then Print(T.TEST_RUNNING) return end
    if state.queued then Print(T.TEST_STOP_REAL) return end
    test = { results = {}, party = {}, nextId = 1, shots = shots,
      saved = { skipUntil = db.skipUntil, inviteWhisper = db.inviteWhisper,
        myRoles = db.myRoles, inviteTimeout = db.inviteTimeout, autoInvite = db.autoInvite,
        category = db.category, page = db.page, view = db.view, playstyle = db.playstyle } }
    db.myRoles, db.inviteTimeout, db.autoInvite, db.category, db.page = { DAMAGER = true }, 10, true, 2, 1
    db.view, db.playstyle = "activities", (db.playstyle ~= 0 and db.playstyle or 2)
    db.skipUntil = {}
    local _, ids = SearchActivities()
    local act = ids[1]
    if not act then
      for k, v in pairs(test.saved) do db[k] = v end
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

  function AutoGroupFinder_Slash(msg, raw)
    if msg == "" then
      AutoGroupFinder_Toggle()
    elseif msg:match("^whisper") then
      local text = strtrim((raw or msg):sub(8))
      db.whisperText = text ~= "" and text or nil
      Print(T.CHAT_WHISPER_SET:format(db.whisperText or T.WHISPER_DEFAULT))
    elseif msg == "config" or msg == "settings" then
      OpenSettings()
    elseif msg:match("^testinvite") then
      InviteInfo.Demo(msg:match("^testinvite%s+(%a+)"))
    elseif msg == "test" or msg == "test shots" then
      RunTest(msg == "test shots")
    elseif msg == "start" then
      StartQueue()
    elseif msg == "stop" then
      StopQueue(T.CHAT_STOPPED)
    elseif msg == "minimap" then
      db.minimap.hide = not db.minimap.hide
      UpdateMinimap()
      Print(T.CHAT_MINIMAP:format(db.minimap.hide and T.OFF or T.ON))
    elseif msg == "sound" then
      db.sound = not db.sound
      Print(T.CHAT_SOUND:format(db.sound and T.ON or T.OFF))
    elseif msg:match("^interval %d+$") then
      db.interval = math.max(3, tonumber(msg:match("%d+")))
      Print(T.CHAT_INTERVAL:format(db.interval))
    elseif msg == "reset" then
      wipe(seen) wipe(db.skipUntil) wipe(pending) wipe(expired)
      Print(T.CHAT_RESET)
      Rebuild()
    elseif msg == "dump" then
      local _, ids = L.GetSearchResults()
      local id = ids and ids[1]
      if not id then Print(T.CHAT_NO_RESULTS) return end
      for k, v in pairs(L.GetSearchResultInfo(id) or {}) do print("  ", k, tostring(v)) end
      for k, v in pairs(L.GetSearchResultLeaderInfo(id) or {}) do
        if type(v) == "table" then
          for k2, v2 in pairs(v) do print("  ", k .. "." .. k2, tostring(v2)) end
        else
          print("  ", k, tostring(v))
        end
      end
    else
      Print(T.HELP:gsub("%%s", SLASH))
    end
  end
end -- Init

local ok, err = pcall(Init)
if not ok then
  loadError = tostring(err)
  AutoGroupFinder_Slash = nil
  local function Report()
    Print("|cffff4040" .. T.LOAD_FAILED .. "|r " .. loadError .. " " .. T.LOAD_FAILED_HINT:format(SLASH))
  end
  AutoGroupFinder_Next, AutoGroupFinder_Refresh, AutoGroupFinder_Toggle, AutoGroupFinder_OnCompartmentClick =
    Report, Report, Report, Report
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", Report)
end
