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
  -- Symbol und Qualität sofort aus dem Link (ohne auf den Server zu warten)
  local function ItemLook(link)
    local icon, quality
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
      local ok, _, _, _, _, ic = pcall(instant, link)
      if ok then icon = ic end
    end
    local q = C_Item and C_Item.GetItemQualityByID
    if q then
      local ok, v = pcall(q, link)
      if ok then quality = v end
    end
    return icon, quality
  end
  local ROLL = { [0] = T.H_ROLL_NEED, [1] = T.H_ROLL_OFF, [2] = T.H_ROLL_MOG, [3] = T.H_ROLL_GREED, [5] = T.H_ROLL_PASS }
  local function RollText(s, r)
    local name = s and ROLL[s]
    if not name then return "" end
    return name .. (r and (" " .. r) or "")
  end

  -- Beim Überfahren: was nicht schon in der Liste steht (Dauer, Bosse, Beute)
  local function SummaryTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.name or "?", 1, 0.82, 0)
    GameTooltip:AddLine(History.When(e.t), 0.6, 0.6, 0.6)
    local stats = History.Stats(e)
    if stats ~= "" then GameTooltip:AddLine(stats, 1, 1, 1) end
    if e.wait then GameTooltip:AddLine(T.H_FULL:format(Mins(e.wait)), 0.8, 0.8, 0.8) end
    local items, bosses = 0, false
    for _, r in ipairs(e.runs or {}) do
      for _, b in ipairs(r.bosses or {}) do
        if b.ok then
          if not bosses then GameTooltip:AddLine(" ") bosses = true end
          GameTooltip:AddDoubleLine(SKULL .. " " .. b.n, b.t and Clock(b.t) or "", 0.9, 0.9, 0.9, 0.6, 0.6, 0.6)
        end
      end
      for _ in pairs(r.loot or {}) do items = items + 1 end
    end
    if items > 0 then GameTooltip:AddLine(T.H_ITEMS:format(items), 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T.H_DETAILS, 0.1, 1, 0.1)
    GameTooltip:Show()
  end

  local function OpenDetail(e)
    GameTooltip:Hide()
    History.detail = e
    Rebuild() -- auch die Fußleiste (Zurück)
  end

  -- Liste: Kopfzeile je Gruppe, darunter die Mitspieler
  local rows = {}
  local HEAD, MEMBER = 28, 24
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
    row.kind = row:CreateTexture(nil, "ARTWORK")
    row.kind:SetSize(16, 16)
    row.kind:SetPoint("LEFT", 10, 0)
    row.title = Label(row, "", "GameFontNormal", "LEFT", row, "LEFT", 30, 0)
    row.date = Label(row, "", "GameFontDisableSmall", "RIGHT", row, "RIGHT", -12, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 30, 0)
    row.name = Label(row, "", "GameFontHighlight", "LEFT", row.icon, "RIGHT", 6, 0)
    row.level = Label(row, "", "GameFontDisableSmall", "LEFT", row.name, "RIGHT", 6, 0)
    row.note = Label(row, "", "GameFontDisableSmall", "RIGHT", row, "RIGHT", -12, 0)
    row:SetScript("OnEnter", function(self) if self.head and self.entry then SummaryTooltip(self, self.entry) end end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self, button)
      if self.member then
        if IsShiftKeyDown() then InsertChat(Short(self.member.name))
        elseif button == "RightButton" then MemberMenu(self, self.member)
        else OpenDetail(self.entry) end
      elseif self.entry then
        if IsShiftKeyDown() then InsertChat(self.entry.name)
        elseif button == "RightButton" then EntryMenu(self, self.entry)
        else OpenDetail(self.entry) end
      end
    end)
    rows[i] = row
    return row
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
    -- Spaltenköpfe zum Sortieren (Tode, Heilung, Schaden); erneuter Klick: wieder nach Rolle
    r.sort = {}
    for i, key in ipairs({ "x", "h", "d" }) do
      local b = CreateFrame("Button", nil, r)
      b:SetSize(56, 18)
      b:SetPoint("RIGHT", r, "RIGHT", ({ -4, -52, -112 })[i], 0)
      b:SetScript("OnClick", function()
        History.sort = History.sort ~= key and key or nil
        History.Update()
      end)
      b:Hide()
      r.sort[i] = b
    end
    -- Beute wie in den Taschen: Symbol mit Rahmen in Qualitätsfarbe
    r.item = r:CreateTexture(nil, "ARTWORK")
    r.item:SetSize(22, 22)
    r.item:SetPoint("LEFT", r, "LEFT", 60, 0)
    r.itemBorder = r:CreateTexture(nil, "OVERLAY")
    r.itemBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    r.itemBorder:SetAllPoints(r.item)
    r:SetScript("OnEnter", function(self)
      if self.fightM then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.fightTitle)
        local list = {}
        for name, v in pairs(self.fightM) do list[#list + 1] = { name = name, v = v } end
        table.sort(list, function(a, b) return (a.v.d or 0) > (b.v.d or 0) end)
        if #list > 0 then GameTooltip:AddDoubleLine(" ", T.H_DMG .. "  |cff60ff60" .. T.H_HEAL .. "|r", 1, 1, 1, 0.6, 0.6, 0.6) end
        for _, x in ipairs(list) do
          local right = Num(x.v.d or 0) .. "  |cff60ff60" .. Num(x.v.h or 0) .. "|r"
            .. ((x.v.x and x.v.x > 0) and ("  |cffff6060† " .. x.v.x .. "|r") or "")
          GameTooltip:AddDoubleLine(Colored(x.name, x.v.c), right, 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
        return
      end
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
      r.kind, r.order, r.link, r.rolls, r.member, r.fightM = kind, n, nil, nil, nil, nil
      r.bg:SetShown(kind == "section")
      r.hl:SetShown(kind == "member" or kind == "loot" or kind == "fight")
      r.icon:Hide() r.item:Hide() r.itemBorder:Hide()
      for _, b in ipairs(r.sort) do b:SetShown(kind == "cols") end
      r.time:SetText("") r.c1:SetText("") r.c2:SetText("") r.c3:SetText("")
      r.text:ClearAllPoints()
      r.text:SetPoint("LEFT", r, "LEFT", kind == "section" and 12 or 60, 0)
      r.text:SetPoint("RIGHT", r, "RIGHT", kind == "loot" and -130 or (kind == "member" or kind == "fight") and -170 or -12, 0)
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
    -- Ein Kampf oder mehrere zusammen: Dauer, Schaden der Gruppe, Tote in Rot; Überfahren zeigt je Spieler
    local function fight(t, label, list, inGroup)
      local m, dur, dmg, dead = {}, 0, 0, {}
      for _, f in ipairs(list) do
        dur = dur + (f.dur or 0)
        for name, v in pairs(f.m or {}) do
          if inGroup[Short(name)] then
            local x = m[name] or { c = v.c }
            m[name] = x
            for _, k in ipairs({ "d", "h", "x" }) do if v[k] then x[k] = (x[k] or 0) + v[k] end end
            dmg = dmg + (v.d or 0)
            if v.x and v.x > 0 then dead[Short(name)] = true end
          end
        end
      end
      local r = add("fight", 20)
      r.time:SetText(t and Clock(t) or "")
      local names = {}
      for name in pairs(dead) do names[#names + 1] = "† " .. name end
      table.sort(names)
      r.text:SetText(label .. (#names > 0 and ("  |cffff6060" .. table.concat(names, ", ") .. "|r") or ""))
      r.c2:SetText(dur > 0 and ("|cff999999" .. ("%d:%02d"):format(math.floor(dur / 60), dur % 60) .. "|r") or "")
      r.c1:SetText(dmg > 0 and Num(dmg) or "")
      r.fightM, r.fightTitle = m, label
    end
    local function loot(l)
      local r = add("loot", 26)
      local icon, quality = ItemLook(l.link)
      r.item:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      r.item:Show()
      local qc = quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
      if qc then r.itemBorder:SetVertexColor(qc.r, qc.g, qc.b) end
      r.itemBorder:SetShown(qc and true or false)
      r.text:SetPoint("LEFT", r, "LEFT", 88, 0)
      r.text:SetText(l.link)
      r.link, r.rolls = l.link, l.rolls
      r.c1:SetText(Colored(l.who, l.c) .. (l.s and ("  |cff999999" .. RollText(l.s, l.r) .. "|r") or ""))
    end

    dTitle:SetText(e.name or "?")
    dWhen:SetText(History.When(e.t))

    -- Gruppe mit Schaden, Heilung und Toden über alle Läufe; nur Mitspieler und du
    local me = Short(MyName())
    local inGroup = { [me] = true }
    for _, m in ipairs(e.members or {}) do inGroup[Short(m.name)] = true end
    local total = {}
    for _, run in ipairs(e.runs or {}) do
      for name, v in pairs(run.meter or {}) do
        local k = Short(name)
        if inGroup[k] then
          local x = total[k] or { c = v.c }
          total[k] = x
          for _, key in ipairs({ "d", "h", "x" }) do if v[key] then x[key] = (x[key] or 0) + v[key] end end
        end
      end
    end
    local hasMeter = next(total) ~= nil
    local stats = History.Stats(e)
    section(T.H_GROUP, stats .. (e.wait and ((stats ~= "" and " · " or "") .. T.H_FULL:format(Mins(e.wait))) or ""))
    local people = {}
    for i, m in ipairs(e.members or {}) do people[#people + 1] = { m = m, i = i, v = total[Short(m.name)] } end
    if total[me] then people[#people + 1] = { name = MyName(), i = 999, v = total[me] } end
    if hasMeter then
      local h = add("cols", 18)
      local function col(key, label) return (History.sort == key and "|cffffd100" or "|cff999999") .. label .. "|r" end
      h.c3:SetText(col("d", T.H_DMG))
      h.c2:SetText(col("h", T.H_HEAL))
      h.c1:SetText(col("x", T.H_DEATHS))
    end
    local key = History.sort
    table.sort(people, function(a, b)
      if key then
        local va, vb = a.v and a.v[key] or 0, b.v and b.v[key] or 0
        if va ~= vb then return va > vb end
      end
      return a.i < b.i
    end)
    for _, p in ipairs(people) do
      local r = add("member", 22)
      local m = p.m
      if m then
        r.member = m
        if m.role then
          SetRoleTexture(r.icon, m.role, false)
          r.icon:ClearAllPoints()
          r.icon:SetPoint("LEFT", 30, 0)
          r.icon:Show()
        end
        local early = LeftEarly(e, m)
        r.text:SetText(Colored(m.name, m.class) .. ((m.level and m.level > 0) and ("  |cff999999" .. m.level .. "|r") or "")
          .. "  " .. RateTag(Rating(m.name)) .. (early and ("  |cff999999" .. early .. "|r") or ""))
      else
        r.text:SetText(Colored(p.name, p.v and p.v.c) .. "  |cff999999(" .. T.H_YOU .. ")|r")
      end
      if hasMeter then
        local v = p.v or {}
        r.c3:SetText(Num(v.d or 0))
        r.c2:SetText("|cff60ff60" .. Num(v.h or 0) .. "|r")
        r.c1:SetText((v.x and v.x > 0) and ("|cffff6060† " .. v.x .. "|r") or "|cff666666–|r")
      end
    end

    -- Je Dungeonlauf: Ablauf mit Kämpfen und Beute unter dem Boss
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
      -- Kämpfe: Bosse einzeln, Trash zwischen zwei Bossen (oder Ausflügen nach draußen) zusammengefasst
      local fights, bossFight = {}, {}
      for k, f in pairs(run.fights or {}) do fights[#fights + 1] = { k = k, f = f } end
      table.sort(fights, function(a, b) return a.k < b.k end)
      for _, b in ipairs(run.bosses or {}) do if b.sid then bossFight[b.sid] = true end end
      local marks = {}
      for _, b in ipairs(run.bosses or {}) do marks[#marks + 1] = { t = b.t or 0, boss = b } end
      for _, g in ipairs(run.gaps or {}) do marks[#marks + 1] = { t = g.out or 0, gap = g } end
      table.sort(marks, function(a, b) return a.t < b.t end)
      local trash = {}
      for _, x in ipairs(fights) do
        if not bossFight[x.k] then
          local i = #marks + 1
          for j, mk in ipairs(marks) do if (x.f.t or 0) <= mk.t then i = j break end end
          trash[i] = trash[i] or {}
          table.insert(trash[i], x.f)
        end
      end

      event(run.enter, T.H_ENTER)
      if #fights == 0 then event(run.first, T.H_FIRST) end
      for i = 1, #marks + 1 do
        if trash[i] then fight(trash[i][1].t, T.H_TRASH:format(#trash[i]), trash[i], inGroup) end
        local mk = marks[i]
        if mk and mk.boss then
          local b = mk.boss
          local label = b.ok and (SKULL .. " " .. b.n) or ("|cffff6060" .. T.H_WIPE:format(b.n) .. "|r")
          local f = b.sid and run.fights and run.fights[b.sid]
          if f then fight(b.t, label, { f }, inGroup) else event(b.t, label) end
          if b.ok and b.id then lootFor(b.id) end
        elseif mk and mk.gap then
          local g = mk.gap
          event(g.out, g.dead and ("|cffff6060† " .. T.H_GHOST:format(Clock(g.back)) .. "|r") or T.H_OUTSIDE:format(Clock(g.back)))
        end
      end
      for k in pairs(run.loot or {}) do -- Beute ohne erkannten Boss
        if not used[k] then
          local r = add("event", 18)
          r.text:SetText("|cff999999" .. T.H_OTHER_LOOT .. "|r")
          lootFor(nil)
          break
        end
      end
      if #fights == 0 then event(run.last, T.H_LAST) end
      event(run.exit, run.exitDead and ("|cffff6060† " .. T.H_EXIT_DEAD .. "|r") or T.H_EXIT)

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
        local row = Row(n)
        row:SetHeight(HEAD)
        row:SetPoint("TOPLEFT", 0, -y)
        y = y + HEAD + 2
        row.entry, row.member, row.head = x, nil, true
        row.headBg:Show()
        local icon = x.instance and (x.kind == "raid" and "Raid" or "Dungeon")
        if icon and not Atlas(row.kind, icon) then row.kind:SetTexture("Interface\\Minimap\\Dungeon") end
        row.kind:SetShown(icon and true or false)
        row.title:SetFontObject(x.instance and "GameFontNormal" or "GameFontHighlight")
        row.title:SetText(x.name or "?")
        row.title:Show()
        local s = (x.ended or x.last or x.t) - x.t
        row.date:SetText((s >= 60 and (T.H_MIN:format(Mins(s)) .. " · ") or "") .. History.When(x.t))
        row.date:Show()
        row.icon:Hide() row.name:Hide() row.level:Hide() row.note:Hide()
        row:Show()
        for _, m in ipairs(x.members or {}) do
          n = n + 1
          local r = Row(n)
          r:SetHeight(MEMBER)
          r:SetPoint("TOPLEFT", 0, -y)
          y = y + MEMBER
          r.entry, r.member, r.head = x, m, nil
          r.headBg:Hide() r.title:Hide() r.date:Hide() r.kind:Hide()
          if m.role then SetRoleTexture(r.icon, m.role, false) end
          r.icon:SetShown(m.role ~= nil)
          r.name:SetText(Colored(m.name, m.class))
          r.name:Show()
          r.level:SetText(((m.level and m.level > 0) and m.level or "") .. "  " .. RateTag(Rating(m.name)))
          r.level:Show()
          r.note:SetText(LeftEarly(x, m) or "")
          r.note:Show()
          r:Show()
        end
        y = y + 6
      end
    end
    for i = n + 1, #rows do rows[i]:Hide() end
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
