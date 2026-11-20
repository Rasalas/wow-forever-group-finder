local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Gemeinsam: Seitenreiter, Fußleiste mit Zurück, Rollen-Icons und Bestätigungsknopf
-------------------------------------------------------------------------
tabs = {}
function ShowPage(i)
  db.page = i
  for j, p in ipairs(pages) do p:SetShown(j == i) end
  for j, t in ipairs(tabs) do if t.SetChecked then t:SetChecked(j == i) end end
  Rebuild()
end

-- Seitenreiter wie bei Blizzard (LargeSideTabButtonTemplate), sonst ein schlichter Knopf
function MakeSideTab(parent, iconPath, tip, onClick)
  local okTab, tab = pcall(CreateFrame, "Frame", nil, parent, "LargeSideTabButtonTemplate")
  if okTab and tab and tab.Icon and tab.SetCustomOnMouseUpHandler then
    tab.Icon:SetTexture(iconPath)
    if tab.SetFillToInterior then
      tab:SetFillToInterior(true) -- Icon füllt den Reiter wie bei Blizzard
    else
      tab.Icon:SetSize(30, 30)
    end
    tab.tooltipText = tip
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
      if button == "LeftButton" and upInside then onClick() end
    end)
  else
    tab = CreateFrame("Button", nil, parent)
    tab:SetSize(40, 40)
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Icon:SetAllPoints()
    tab.Icon:SetTexture(iconPath)
    tab:SetScript("OnClick", onClick)
    Tooltip(tab, tip)
  end
  return tab
end

for i, iconPath in ipairs(TAB_ICONS) do
  local tip = ({ T.TAB_FINDER, T.TAB_FOUND, T.TAB_HISTORY })[i]
  local tab = MakeSideTab(win, iconPath, tip, function() ShowPage(i) end)
  if i == 1 then
    tab:SetPoint("TOPLEFT", win, "TOPRIGHT", 0, -60)
  else
    tab:SetPoint("TOPLEFT", tabs[i - 1], "BOTTOMLEFT", 0, -2)
  end
  tabs[i] = tab
end

-- Eigene Ebene über den Seiten, sonst verdeckt deren Hintergrund die Knöpfe
footer = CreateFrame("Frame", nil, win)
footer:SetPoint("BOTTOMLEFT")
footer:SetPoint("BOTTOMRIGHT")
footer:SetHeight(60)
footer:SetFrameLevel((finder:GetFrameLevel() or 1) + 10)

backBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
backBtn:SetSize(111, 28)
backBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 21, 16)
backBtn:SetText(BACK or T.BACK)
backBtn:SetScript("OnClick", function()
  db.view = "categories"
  Rebuild()
end)

Clock = function(sec)
  sec = math.max(0, math.floor(sec))
  return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

-- Noch offene Rollen als kleine Icons mit Anzahl, während der Suche mit Uhr davor
need = CreateFrame("Frame", nil, footer)
need:SetSize(150, 24)
need:SetPoint("BOTTOM", win, "BOTTOM", 0, 18)
need.clock = Label(need, "", "GameFontHighlightSmall", "LEFT", need, "LEFT", 0, 0)
-- Ein Symbol je offenem Platz; bei großen Raids höchstens MAX_NEED_ICONS, der Rest als „+N“
MAX_NEED_ICONS = 7
need.pool = {}
need.more = Label(need, "", "GameFontHighlightSmall", "LEFT", need, "LEFT", 0, 0)

function UpdateNeed()
  local rem = Slots()
  local x, n, hidden = 0, 0, 0
  need.clock:SetText(state.queued and Clock(GetTime() - state.queuedAt) or "")
  if state.queued then x = need.clock:GetStringWidth() + 8 end
  for _, role in ipairs(ROLES) do
    for _ = 1, rem[role] do
      if n < MAX_NEED_ICONS then
        n = n + 1
        local t = need.pool[n]
        if not t then
          t = need:CreateTexture(nil, "ARTWORK")
          t:SetSize(20, 20)
          need.pool[n] = t
        end
        SetRoleTexture(t, role, false)
        t:ClearAllPoints()
        t:SetPoint("LEFT", need, "LEFT", x, 0)
        t:Show()
        x = x + 22
      else
        hidden = hidden + 1
      end
    end
  end
  for i = n + 1, #need.pool do need.pool[i]:Hide() end
  need.more:SetText(hidden > 0 and ("+" .. hidden) or "")
  need.more:ClearAllPoints()
  need.more:SetPoint("LEFT", need, "LEFT", x, 0)
  if hidden > 0 then x = x + need.more:GetStringWidth() + 2 end
  need:SetWidth(math.max(1, x))
end

mainBtn = CreateFrame("Button", "AutoGroupFinderStartButton", footer, "UIPanelButtonTemplate")
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

function BlockReason()
  if state.queued or GroupReady() then return nil end
  if db.view ~= "activities" then return T.PICK_CATEGORY end
  if (db.playstyle or 0) == 0 then return PLAYSTYLE_REQUIRED end
  local _, ids = SearchActivities()
  if #ids == 0 then return T.PICK_ACTIVITY end
end

-- Details für Tooltips von Knopf und Minimap-Symbol
function StatusLines()
  local lines = {}
  if state.queued then lines[#lines + 1] = T.SEARCHING_FOR:format(Clock(GetTime() - state.queuedAt)) end
  local needText = NeedText((Slots()))
  lines[#lines + 1] = needText ~= "" and T.STATUS_NEED:format(needText) or T.GROUP_COMPLETE
  local waiting = {}
  for k, p in pairs(pending) do waiting[#waiting + 1] = Short(k) .. " (" .. ROLE_NAME[p.role] .. ")" end
  if #waiting > 0 then lines[#lines + 1] = T.WAITING_FOR:format(table.concat(waiting, ", ")) end
  local held, scarce = HeldRoles()
  if next(held) then
    local first, later = {}, {}
    for _, r in ipairs(scarce) do first[#first + 1] = ROLE_PLURAL[r] end
    for _, r in ipairs(ROLES) do if held[r] then later[#later + 1] = ROLE_PLURAL[r] end end
    lines[#lines + 1] = T.STATUS_SCARCE:format(table.concat(first, ", "), table.concat(later, ", "))
  end
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

function _G.AutoGroupFinder_Toggle()
  if win:IsShown() then CloseWindow() else OpenWindow() end
end

-------------------------------------------------------------------------
