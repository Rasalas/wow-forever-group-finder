local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Seite 3: Letzte Gruppen. Liste mit kurzer Zusammenfassung beim Überfahren; Klick öffnet die Details.
-------------------------------------------------------------------------
do
  local page = pages[3]
  Inset(page, -60)
  local list = Scroller(page, win, 12, -68, -12, 62)
  local detail = Scroller(page, win, 12, -68, -12, 62)
  detail:Hide()

  -- Suche: jedes Wort muss irgendwo vorkommen (Ort, Name, Klasse, Rolle), Groß/klein egal
  local okS, search = pcall(CreateFrame, "EditBox", nil, page, "SearchBoxTemplate")
  if not okS then search = CreateFrame("EditBox", nil, page, "InputBoxTemplate") end
  search:SetSize(200, 20)
  search:SetPoint("TOPLEFT", win, "TOPLEFT", 70, -38)
  search:SetAutoFocus(false)
  search:HookScript("OnTextChanged", function() if History.Update then History.Update() end end)
  search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
  History.search = search
  local empty = Label(page, T.HISTORY_EMPTY, "GameFontDisable", "TOP", win, "TOP", 0, -120)
  empty:SetWidth(WIN_W - 60)
  -- Kopf der Detailseite an der Stelle der Suche
  local dTitle = Label(page, "", "GameFontNormalLarge", "TOPLEFT", win, "TOPLEFT", 70, -40)
  local dWhen = Label(page, "", "GameFontDisableSmall", "TOPRIGHT", win, "TOPRIGHT", -24, -44)
  dTitle:SetPoint("RIGHT", dWhen, "LEFT", -8, 0)
  dTitle:SetJustifyH("LEFT")
  dTitle:SetWordWrap(false)

  local function Mins(s) return math.max(1, math.floor(s / 60 + 0.5)) end
  local function Clock(t) return date("%H:%M", t) end
  local function Colored(name, class)
    local c = class and RAID_CLASS_COLORS[class]
    return c and c:WrapTextInColorCode(Short(name)) or Short(name)
  end

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
      root:CreateCheckbox(RateTag(1) .. " " .. T.RATE_GOOD, function() return Rating(m.name) == 1 end, function() Rate(m.name, 1) end)
      root:CreateCheckbox(RateTag(-1) .. " " .. T.RATE_BAD, function() return Rating(m.name) == -1 end, function() Rate(m.name, -1) end)
      root:CreateButton(db.blocked[Key(m.name)] and T.CTX_UNBLOCK or T.CTX_BLOCK, function() ToggleBlocked(m.name) end)
    end)
  end

  local function EntryMenu(owner, e)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateButton(T.HISTORY_DELETE, function()
        for i, x in ipairs(char.history) do if x == e then table.remove(char.history, i) break end end
        if History.detail == e then History.detail = nil end
        Rebuild()
      end)
    end)
  end

  local function Haystack(e)
    local words = { e.name or "" }
    for _, m in ipairs(e.members or {}) do
      words[#words + 1] = Short(m.name)
      if m.class then
        words[#words + 1] = m.class
        words[#words + 1] = (LOCALIZED_CLASS_NAMES_MALE or {})[m.class] or ""
        words[#words + 1] = (LOCALIZED_CLASS_NAMES_FEMALE or {})[m.class] or ""
      end
      if m.role then words[#words + 1] = ROLE_NAME[m.role] or m.role end
    end
    return table.concat(words, " "):lower()
  end
  function History.Matches(e, query)
    if not query or query == "" then return true end
    local hay = Haystack(e)
    for word in query:lower():gmatch("%S+") do
      if not hay:find(word, 1, true) then return false end
    end
    return true
  end
  -- Heute/gestern statt Datum, sonst Tag zuerst (11/21 verwirrt)
  function History.When(t)
    local today = date("*t")
    local midnight = time({ year = today.year, month = today.month, day = today.day, hour = 0 })
    if t >= midnight then return T.H_TODAY .. " " .. date("%H:%M", t) end
    if t >= midnight - 86400 then return T.H_YESTERDAY .. " " .. date("%H:%M", t) end
    return date(T.DATE_FMT, t)
  end

  -- „85 Min · 6/6 Bosse · 1× Wipe“
  function History.Stats(e)
    local parts = {}
    local s = (e.ended or e.last or e.t) - e.t
    if s >= 60 then parts[#parts + 1] = T.H_MIN:format(Mins(s)) end
    local kills, total, wipes = History.EntryProgress(e)
    if total and total > 0 then parts[#parts + 1] = T.H_BOSSES:format(kills, total)
    elseif kills > 0 then parts[#parts + 1] = T.H_BOSSES_N:format(kills) end
    if wipes > 0 then parts[#parts + 1] = "|cffff6060" .. T.H_WIPES:format(wipes) .. "|r" end
    return table.concat(parts, " · ")
  end
  -- früh gegangen: vor dem letzten Boss, sonst mindestens 5 Minuten vor dem Ende der Gruppe
  local function LeftEarly(e, m)
    local stay = m.left and m.left - (m.joined or e.t)
    local early = stay and (e.done and m.left < e.done or not e.done and (e.ended or e.last or m.left) - m.left >= 300)
    return early and T.H_LEFT_AFTER:format(Mins(stay)) or nil
  end

  local function Num(n)
    if n >= 1e6 then return ("%.1fM"):format(n / 1e6) end
    if n >= 1e4 then return ("%.0fk"):format(n / 1e3) end
    if n >= 1e3 then return ("%.1fk"):format(n / 1e3) end
    return tostring(math.floor(n))
  end
  local ROLL = { [0] = T.H_ROLL_NEED, [1] = T.H_ROLL_OFF, [2] = T.H_ROLL_MOG, [3] = T.H_ROLL_GREED, [5] = T.H_ROLL_PASS }
  local function RollText(s, r)
    local name = s and ROLL[s]
    if not name then return "" end
    return name .. (r and (" " .. r) or "")
  end

  -- Kurzfassung beim Überfahren eines Eintrags
  local function SummaryTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.name or "?", 1, 0.82, 0)
    GameTooltip:AddLine(History.When(e.t), 0.6, 0.6, 0.6)
    local stats = History.Stats(e)
    if stats ~= "" then GameTooltip:AddLine(stats, 1, 1, 1) end
    if e.wait then GameTooltip:AddLine(T.H_FULL:format(Mins(e.wait)), 0.8, 0.8, 0.8) end
    if #(e.members or {}) > 0 then GameTooltip:AddLine(" ") end
    for _, m in ipairs(e.members or {}) do
      local left = (m.role and (RoleIconText(m.role, 14) .. " ") or "") .. Colored(m.name, m.class)
        .. ((m.level and m.level > 0) and ("  |cff999999" .. m.level .. "|r") or "")
      GameTooltip:AddDoubleLine(left, LeftEarly(e, m) or "", 1, 1, 1, 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T.H_DETAILS, 0.1, 1, 0.1)
    GameTooltip:Show()
  end

  -- Liste: je Gruppe eine Karte mit zwei Zeilen
  local cards = {}
  local CARD = 44
  local function Card(i)
    if cards[i] then return cards[i] end
    local c = CreateFrame("Button", nil, list.child)
    c:SetHeight(CARD)
    c:SetPoint("RIGHT", list.child, "RIGHT")
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    if not Atlas(c.bg, "common-button-list-collapseExpand") then c.bg:SetColorTexture(0.3, 0.2, 0.1, 0.6) end
    c.hl = c:CreateTexture(nil, "HIGHLIGHT")
    c.hl:SetAllPoints()
    c.hl:SetColorTexture(1, 1, 1, 0.06)
    c.kind = c:CreateTexture(nil, "ARTWORK")
    c.kind:SetSize(16, 16)
    c.kind:SetPoint("TOPLEFT", 10, -7)
    c.title = Label(c, "", "GameFontNormal", "TOPLEFT", c, "TOPLEFT", 30, -8)
    c.date = Label(c, "", "GameFontDisableSmall", "TOPRIGHT", c, "TOPRIGHT", -12, -9)
    c.title:SetPoint("RIGHT", c.date, "LEFT", -8, 0)
    c.title:SetJustifyH("LEFT")
    c.title:SetWordWrap(false)
    c.stats = Label(c, "", "GameFontHighlightSmall", "BOTTOMLEFT", c, "BOTTOMLEFT", 30, 8)
    c.stats:SetTextColor(0.75, 0.75, 0.75)
    c.classes = Label(c, "", "GameFontHighlightSmall", "BOTTOMRIGHT", c, "BOTTOMRIGHT", -12, 7)
    c:SetScript("OnEnter", function(self) if self.entry then SummaryTooltip(self, self.entry) end end)
    c:SetScript("OnLeave", GameTooltip_Hide)
    c:SetScript("OnClick", function(self, button)
      if not self.entry then return end
      if IsShiftKeyDown() then InsertChat(self.entry.name)
      elseif button == "RightButton" then EntryMenu(self, self.entry)
      else
        GameTooltip:Hide()
        History.detail = self.entry
        Rebuild() -- auch die Fußleiste (Zurück)
      end
    end)
    cards[i] = c
    return c
  end

  -- Detailseite: Zeilen verschiedener Art (Abschnitt, Mitglied, Ablauf, Beute, Schadensmesser)
  local lines = {}
  local function Line(i)
    if lines[i] then return lines[i] end
    local r = CreateFrame("Button", nil, detail.child)
    r:SetPoint("RIGHT", detail.child, "RIGHT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if not Atlas(r.bg, "common-button-list-collapseExpand") then r.bg:SetColorTexture(0.3, 0.2, 0.1, 0.6) end
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.05)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.time = Label(r, "", "GameFontDisableSmall", "LEFT", r, "LEFT", 14, 0)
    r.text = Label(r, "", "GameFontHighlight", "LEFT", r, "LEFT", 60, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.c1 = Label(r, "", "GameFontHighlightSmall", "RIGHT", r, "RIGHT", -12, 0)
    r.c2 = Label(r, "", "GameFontHighlightSmall", "RIGHT", r, "RIGHT", -60, 0)
    r.c3 = Label(r, "", "GameFontHighlightSmall", "RIGHT", r, "RIGHT", -120, 0)
    r:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) then GameTooltip:SetText(self.link) end
        if self.rolls then
          GameTooltip:AddLine(" ")
          for _, x in ipairs(self.rolls) do
            GameTooltip:AddDoubleLine(Colored(x.n, x.c), RollText(x.s, x.r), 1, 1, 1, 0.8, 0.8, 0.8)
          end
        end
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r:SetScript("OnClick", function(self, button)
      if self.link then
        if IsShiftKeyDown() then InsertChat(self.link) end
      elseif self.member then
        if IsShiftKeyDown() then InsertChat(Short(self.member.name))
        elseif button == "RightButton" then MemberMenu(self, self.member) end
      end
    end)
    lines[i] = r
    return r
  end

  local function BuildDetail(e)
    local n, y = 0, 0
    local function add(kind, h)
      n = n + 1
      local r = Line(n)
      r:SetHeight(h)
      r:SetPoint("TOPLEFT", 0, -y)
      y = y + h
      r.kind, r.link, r.rolls, r.member = kind, nil, nil, nil
      r.bg:SetShown(kind == "section")
      r.hl:SetShown(kind == "member" or kind == "loot")
      r.icon:Hide()
      r.time:SetText("") r.c1:SetText("") r.c2:SetText("") r.c3:SetText("")
      r.text:ClearAllPoints()
      r.text:SetPoint("LEFT", r, "LEFT", kind == "section" and 12 or 60, 0)
      r.text:SetPoint("RIGHT", r, "RIGHT", kind == "loot" and -130 or kind == "meter" and -170 or -12, 0)
      r.text:SetFontObject(kind == "section" and "GameFontNormal" or "GameFontHighlight")
      r:Show()
      return r
    end
    local function section(text, right)
      if n > 0 then y = y + 8 end
      local r = add("section", 24)
      r.text:SetText(text)
      r.c1:SetText(right or "")
    end
    local function event(t, text)
      if not t then return end
      local r = add("event", 18)
      r.time:SetText(Clock(t))
      r.text:SetText(text)
    end
    local function loot(l)
      local r = add("loot", 18)
      r.text:SetPoint("LEFT", r, "LEFT", 78, 0)
      r.text:SetText(l.link)
      r.link, r.rolls = l.link, l.rolls
      r.c1:SetText(Colored(l.who, l.c) .. (l.s and ("  |cff999999" .. RollText(l.s, l.r) .. "|r") or ""))
    end

    dTitle:SetText(e.name or "?")
    dWhen:SetText(History.When(e.t))

    -- Gruppe
    local stats = History.Stats(e)
    section(T.H_GROUP, stats .. (e.wait and ((stats ~= "" and " · " or "") .. T.H_FULL:format(Mins(e.wait))) or ""))
    for _, m in ipairs(e.members or {}) do
      local r = add("member", 22)
      r.member = m
      if m.role then
        SetRoleTexture(r.icon, m.role, false)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", 30, 0)
        r.icon:Show()
      end
      r.text:SetText(Colored(m.name, m.class) .. ((m.level and m.level > 0) and ("  |cff999999" .. m.level .. "|r") or "")
        .. "  " .. RateTag(Rating(m.name)))
      local early = LeftEarly(e, m)
      r.c1:SetText(early and ("|cff999999" .. early .. "|r") or "")
    end

    -- Je Dungeonlauf: Ablauf mit Beute unter dem Boss, dann der Schadensmesser
    local inGroup = { [Short(MyName())] = true }
    for _, m in ipairs(e.members or {}) do inGroup[Short(m.name)] = true end
    for _, run in ipairs(e.runs or {}) do
      section(run.name or "?", run.enter and (Clock(run.enter) .. " – " .. (run.exit and Clock(run.exit) or "…")) or nil)
      local used = {}
      local function lootFor(enc)
        local drops = {}
        for k, l in pairs(run.loot or {}) do
          if not used[k] and (enc == nil or l.enc == enc) then used[k] = true; drops[#drops + 1] = l end
        end
        table.sort(drops, function(a, b) return (a.link or "") < (b.link or "") end)
        for _, l in ipairs(drops) do loot(l) end
      end
      event(run.enter, T.H_ENTER)
      event(run.first, T.H_FIRST)
      for _, b in ipairs(run.bosses or {}) do
        event(b.t, b.ok and (SKULL .. " " .. b.n) or ("|cffff6060" .. T.H_WIPE:format(b.n) .. "|r"))
        if b.ok and b.id then lootFor(b.id) end
      end
      for k in pairs(run.loot or {}) do -- Beute ohne erkannten Boss
        if not used[k] then
          local r = add("event", 18)
          r.text:SetText("|cff999999" .. T.H_OTHER_LOOT .. "|r")
          lootFor(nil)
          break
        end
      end
      event(run.last, T.H_LAST)
      event(run.exit, T.H_EXIT)

      local meter = {}
      for name, v in pairs(run.meter or {}) do
        if inGroup[Short(name)] then meter[#meter + 1] = { name = name, v = v } end
      end
      if #meter > 0 then
        table.sort(meter, function(a, b) return (a.v.d or 0) > (b.v.d or 0) end)
        y = y + 6
        local h = add("meter", 18)
        h.text:SetText("|cffffd100" .. T.H_METER .. "|r")
        h.c3:SetText("|cff999999" .. T.H_DMG .. "|r")
        h.c2:SetText("|cff999999" .. T.H_HEAL .. "|r")
        h.c1:SetText("|cff999999" .. T.H_DEATHS .. "|r")
        for _, x in ipairs(meter) do
          local r = add("meter", 18)
          r.text:SetText(Colored(x.name, x.v.c))
          r.c3:SetText(Num(x.v.d or 0))
          r.c2:SetText("|cff60ff60" .. Num(x.v.h or 0) .. "|r")
          r.c1:SetText((x.v.x and x.v.x > 0) and tostring(x.v.x) or "|cff666666–|r")
        end
      end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
    detail:SetContentHeight(y + 6)
  end

  History.Update = function()
    local e = History.detail
    -- Eintrag inzwischen gelöscht oder Charakter gewechselt: zurück zur Liste
    if e then
      local found = false
      for _, x in ipairs(char.history) do if x == e then found = true break end end
      if not found then e, History.detail = nil, nil end
    end
    list:SetShown(not e)
    search:SetShown(not e)
    detail:SetShown(e and true or false)
    dTitle:SetShown(e and true or false)
    dWhen:SetShown(e and true or false)
    if e then
      empty:Hide()
      BuildDetail(e)
      return
    end

    local n, y, shown = 0, 0, 0
    local query = strtrim(search:GetText() or "")
    for _, x in ipairs(char.history) do
      if History.Matches(x, query) then
        shown = shown + 1
        n = n + 1
        local c = Card(n)
        c:SetPoint("TOPLEFT", 0, -y)
        y = y + CARD + 4
        c.entry = x
        local icon = x.instance and (x.kind == "raid" and "Raid" or "Dungeon")
        if icon and not Atlas(c.kind, icon) then c.kind:SetTexture("Interface\\Minimap\\Dungeon") end
        c.kind:SetShown(icon and true or false)
        c.title:SetFontObject(x.instance and "GameFontNormal" or "GameFontHighlight")
        c.title:SetText(x.name or "?")
        c.date:SetText(History.When(x.t))
        c.stats:SetText(History.Stats(x))
        local icons = {}
        for _, m in ipairs(x.members or {}) do icons[#icons + 1] = ClassIconText(m.class, 14) end
        c.classes:SetText(table.concat(icons, " "))
        c:Show()
      end
    end
    for i = n + 1, #cards do cards[i]:Hide() end
    list:SetContentHeight(y)
    empty:SetText(#char.history == 0 and T.HISTORY_EMPTY or T.H_NO_MATCH)
    empty:SetShown(shown == 0)
  end

  function History.Back()
    History.detail = nil
    Rebuild()
  end
end

-------------------------------------------------------------------------
