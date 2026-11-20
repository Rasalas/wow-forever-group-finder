local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Minimap-Symbol
-------------------------------------------------------------------------
-- Wird erst nach dem Laden der Einstellungen gebaut: Name und Aussehen hängen von minimapStandalone ab.
-- Sammel-Add-ons wie MinimapButtonButton erkennen Knöpfe am Namen ("...MinimapButton") beim Einloggen.
function BuildMinimap()
  local standalone = db.minimapStandalone
  mm = CreateFrame("Button", standalone and "AutoGroupFinderEye" or "AutoGroupFinderMinimapButton", Minimap)
  mm:SetSize(31, 31)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mm:RegisterForDrag("LeftButton")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmBg = mm:CreateTexture(nil, "BACKGROUND")
  mmBg:SetSize(20, 20)
  mmBg:SetPoint("TOPLEFT", 7, -5)
  mmBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  mmIcon = mm:CreateTexture(nil, "ARTWORK")
  mmIcon:SetSize(20, 20)
  mmIcon:SetPoint("TOPLEFT", 7, -5)
  mmIcon:SetTexture(ICON)
  mmBorder = mm:CreateTexture(nil, "OVERLAY")
  mmBorder:SetSize(53, 53)
  mmBorder:SetPoint("TOPLEFT")
  mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mmGlow = mm:CreateTexture(nil, "OVERLAY", nil, 1)
  mmGlow:SetSize(31, 31)
  mmGlow:SetPoint("CENTER")
  mmGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmGlow:SetBlendMode("ADD")
  mmGlow:Hide()
  pulse = mmGlow:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(0.2)
  fade:SetToAlpha(1)
  fade:SetDuration(0.8)

  -- Neuere Clients (mit Add-on-Fach an der Minimap) haben einen kleineren Ring; Maße wie LibDBIcon,
  -- damit das Symbol mittig sitzt und zu anderen Minimap-Knöpfen passt.
  if AddonCompartmentFrame then
    mmBorder:SetSize(50, 50)
    mmBg:SetSize(24, 24) mmBg:ClearAllPoints() mmBg:SetPoint("CENTER")
    mmIcon:SetSize(18, 18) mmIcon:ClearAllPoints() mmIcon:SetPoint("CENTER")
  end
  -- Rune statt Auge: Während der Suche zeigt Blizzard an der Minimap schon sein eigenes Auge.
  if mmIcon.SetMask then pcall(mmIcon.SetMask, mmIcon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end

  mm:SetMovable(true)
  mm:SetClampedToScreen(true)
  mm:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
      local x, y = ScreenCenter()
      db.minimap.free = { x = x, y = y }
      PlaceMinimap()
      self.freeDrag = true
      self:StartMoving()
      return
    end
    if db.minimap.free then db.minimap.free = nil; PlaceMinimap() end
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      PlaceMinimap()
    end)
  end)
  mm:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    if self.freeDrag then
      self.freeDrag = false
      self:StopMovingOrSizing()
      self:SetUserPlaced(false) -- Position steht in db, nicht in WoWs Layout-Speicher
      local x, y = ScreenCenter()
      db.minimap.free = { x = x, y = y }
      PlaceMinimap()
    end
  end)
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
    GameTooltip:AddLine(T.MM_LEFT, 0.7, 0.7, 0.7, true)
    if state.queued then
      GameTooltip:AddLine(T.MM_RIGHT_SEARCH, 0.7, 0.7, 0.7, true)
      GameTooltip:AddLine(T.MM_SHIFT_RIGHT, 0.7, 0.7, 0.7, true)
    end
    local owner = self:GetParent()
    if owner == Minimap or owner == UIParent then GameTooltip:AddLine(T.MM_DRAG, 0.7, 0.7, 0.7, true) end
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", GameTooltip_Hide)
end

-- Am Minimap-Rand (Winkel) oder frei auf dem Bildschirm (db.minimap.free = Mitte in UIParent)
function PlaceMinimap()
  local owner = mm:GetParent()
  if owner ~= Minimap and owner ~= UIParent then return end -- ein anderes Add-on verwaltet den Knopf
  local free = db.minimap.free
  mm:ClearAllPoints()
  if free then
    mm:SetParent(UIParent)
    mm:SetPoint("CENTER", UIParent, "BOTTOMLEFT", free.x, free.y)
  else
    mm:SetParent(Minimap)
    local a = math.rad(db.minimap.angle)
    local r = (Minimap:GetWidth() / 2) + 5
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
  end
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel(8)
end

-- Aktuelle Bildschirmmitte des Knopfs in UIParent-Koordinaten
function ScreenCenter()
  local x, y = mm:GetCenter()
  local s = mm:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return x * s, y * s
end

UpdateMinimap = function()
  if not db or not mm then return end
  mm:SetShown(not db.minimap.hide)
  Eye.Set(state.queued and "search" or "idle")
  mmGlow:SetShown(state.queued)
  if state.queued then
    if not pulse:IsPlaying() then pulse:Play() end
  else
    pulse:Stop()
  end
end

-- Für die Addon-Liste an der Minimap (## AddonCompartmentFunc in der .toc)
function _G.AutoGroupFinder_OnCompartmentClick(_, button)
  if button == "RightButton" then AutoGroupFinder_Next() else AutoGroupFinder_Toggle() end
end

-------------------------------------------------------------------------
