local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Minimap-Symbol
-------------------------------------------------------------------------
mm = CreateFrame("Button", "AutoGroupFinderMinimapButton", Minimap)
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
fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(0.2)
fade:SetToAlpha(1)
fade:SetDuration(0.8)

function PlaceMinimap()
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
function _G.AutoGroupFinder_OnCompartmentClick(_, button)
  if button == "RightButton" then AutoGroupFinder_Next() else AutoGroupFinder_Toggle() end
end

-------------------------------------------------------------------------
