local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

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
      root:CreateCheckbox(RateTag(1) .. " " .. T.RATE_GOOD, function() return Rating(m.name) == 1 end, function() Rate(m.name, 1) end)
      root:CreateCheckbox(RateTag(-1) .. " " .. T.RATE_BAD, function() return Rating(m.name) == -1 end, function() Rate(m.name, -1) end)
      root:CreateButton(db.blocked[Key(m.name)] and T.CTX_UNBLOCK or T.CTX_BLOCK, function() ToggleBlocked(m.name) end)
    end)
  end

  local function EntryMenu(owner, index)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateButton(T.HISTORY_DELETE, function()
        table.remove(char.history, index)
        Rebuild()
      end)
    end)
  end

  local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:0|t"
  local function Mins(s) return math.max(1, math.floor(s / 60 + 0.5)) end
  local function Clock(t) return date("%H:%M", t) end

  -- Kopfzeile: Bosse und Wipes neben dem Namen, Dauer vor dem Datum
  local function Summary(e)
    local kills, wipes = 0, 0
    for _, r in ipairs(e.runs or {}) do kills, wipes = kills + r.kills, wipes + r.wipes end
    local parts = {}
    if kills > 0 then parts[#parts + 1] = SKULL .. kills end
    if wipes > 0 then parts[#parts + 1] = "|cffff6060" .. T.H_WIPES:format(wipes) .. "|r" end
    return #parts > 0 and ("  |cff999999" .. table.concat(parts, "  ") .. "|r") or ""
  end
  local function Duration(e)
    local s = (e.ended or e.last or e.t) - e.t
    return s >= 60 and (T.H_MIN:format(Mins(s)) .. " · ") or ""
  end

  local function EntryTooltip(owner, e)
    if not (e.wait or e.runs) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.name or "?")
    if e.wait then GameTooltip:AddLine(T.H_FULL:format(Mins(e.wait)), 0.8, 0.8, 0.8) end
    for _, r in ipairs(e.runs or {}) do
      if #e.runs > 1 then GameTooltip:AddLine(" ") GameTooltip:AddLine(r.name, 1, 0.82, 0) end
      local function line(t, text, red)
        if t then GameTooltip:AddDoubleLine(text, Clock(t), red and 1 or 1, red and 0.4 or 1, red and 0.4 or 1, 0.6, 0.6, 0.6) end
      end
      line(r.enter, T.H_ENTER)
      line(r.first, T.H_FIRST)
      for _, b in ipairs(r.bosses) do line(b.t, b.ok and b.n or T.H_WIPE:format(b.n), not b.ok) end
      line(r.last, T.H_LAST)
      line(r.exit, T.H_EXIT)
    end
    GameTooltip:Show()
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
    row:SetScript("OnEnter", function(self)
      local e = self.entryIndex and char.history[self.entryIndex]
      if e then EntryTooltip(self, e) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    for index, e in ipairs(char.history) do
      n = n + 1
      local row = Row(n)
      row:SetHeight(HEAD)
      row:SetPoint("TOPLEFT", 0, -y)
      y = y + HEAD + 2
      row.member, row.entryIndex = nil, index
      row.headBg:Show()
      row.title:SetText((e.name or "?") .. Summary(e))
      row.title:Show()
      row.date:SetText(Duration(e) .. date(T.DATE_FMT, e.t))
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
        -- früh gegangen: mindestens 5 Minuten vor dem Ende der Gruppe
        local stay = m.left and m.left - (m.joined or e.t)
        local early = stay and (e.ended or e.last or m.left) - m.left >= 300
        r.level:SetText(((m.level and m.level > 0) and m.level or "") .. "  " .. RateTag(Rating(m.name))
          .. (early and ("  |cff999999" .. T.H_LEFT_AFTER:format(Mins(stay)) .. "|r") or ""))
        r.level:Show()
        r:Show()
      end
      y = y + 6
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    list:SetContentHeight(y)
    empty:SetShown(#char.history == 0)
  end
end

-------------------------------------------------------------------------
