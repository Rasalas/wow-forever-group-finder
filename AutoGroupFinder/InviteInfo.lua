local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Wofür lädt mich jemand ein? Blizzards Fenster zeigt nur den Namen. Wir hängen ein Kästchen
-- darunter: genau (Einladender hat das Add-on) oder laut seinem Eintrag in der Gruppensuche.
InviteInfo = { byAddon = {} }
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
  _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
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
