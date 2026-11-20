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

-- Blizzards Auge statt Symbol und Rand, wie der Warteschlangen-Knopf an der Minimap
mmEye = Eye.Create(mm, false, mm:GetFrameLevel() + 1)
if mmEye then
  mmEye:SetSize(30, 30)
  mmEye:SetPoint("CENTER")
  mmEye:EnableMouse(false) -- Klicks, Ziehen und Tooltip bleiben beim Knopf
  mmBg:Hide(); mmIcon:Hide(); mmBorder:Hide()
  local hl = mm:GetHighlightTexture(); if hl then hl:SetAlpha(0) end
end

-- Am Minimap-Rand (Winkel) oder frei auf dem Bildschirm (db.minimap.free = Mitte in UIParent)
function PlaceMinimap()
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
local function ScreenCenter()
  local x, y = mm:GetCenter()
  local s = mm:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return x * s, y * s
end

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
  GameTooltip:AddLine(T.MM_LEFT, 0.7, 0.7, 0.7)
  GameTooltip:AddLine(state.queued and T.MM_RIGHT_SEARCH or T.MM_RIGHT_START, 0.7, 0.7, 0.7)
  if state.queued then GameTooltip:AddLine(T.MM_SHIFT_RIGHT, 0.7, 0.7, 0.7) end
  GameTooltip:AddLine(T.MM_DRAG, 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function()
  GameTooltip:Hide()
  if mmEye then mmEye.cursorOnButton = false; mmEye:OnLeave() end
end)
mm:HookScript("OnEnter", function() if mmEye then mmEye.cursorOnButton = true; mmEye:OnEnter() end end)
mm:HookScript("OnClick", function() if mmEye then mmEye:OnClick() end end)

UpdateMinimap = function()
  if not db then return end
  mm:SetShown(not db.minimap.hide)
  Eye.Set(state.queued and "search" or "idle")
  mmGlow:SetShown(state.queued and not mmEye)
  if state.queued and not mmEye then
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
