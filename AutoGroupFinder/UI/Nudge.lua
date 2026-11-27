local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- „Bin noch da“ oben in der Bildschirmmitte: Blizzard lässt nur nach einem Klick suchen. Läuft eine Suche,
-- wurde aber länger nicht gesucht (oder noch gar nicht, direkt nach dem Eintragen), bietet der Knopf den Klick an.
-------------------------------------------------------------------------
nudge = CreateFrame("Button", "AutoGroupFinderNudge", UIParent, "BackdropTemplate")
nudge:SetSize(190, 44)
nudge:SetPoint("TOP", UIParent, "TOP", 0, -110)
nudge:SetFrameStrata("MEDIUM")
if nudge.SetBackdrop and BACKDROP_TOOLTIP_16_16_5555 then
  nudge:SetBackdrop(BACKDROP_TOOLTIP_16_16_5555)
  nudge:SetBackdropColor(0.06, 0.05, 0.04, 0.92)
end
nudge.eye = nudge:CreateTexture(nil, "ARTWORK")
nudge.eye:SetSize(32, 32)
nudge.eye:SetPoint("LEFT", 8, 0)
if not Atlas(nudge.eye, "groupfinder-eye-frame") then nudge.eye:SetTexture(ICON) end
nudge.text = Label(nudge, T.NUDGE, "GameFontNormalLarge", "LEFT", nudge.eye, "RIGHT", 8, 0)
nudge:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

-- sanftes Leuchten, damit man es aus dem Augenwinkel bemerkt
nudge.glow = nudge:CreateTexture(nil, "BACKGROUND")
nudge.glow:SetPoint("TOPLEFT", -8, 8)
nudge.glow:SetPoint("BOTTOMRIGHT", 8, -8)
nudge.glow:SetColorTexture(1, 0.82, 0, 0.18)
nudge.pulse = nudge.glow:CreateAnimationGroup()
nudge.pulse:SetLooping("BOUNCE")
local fade = nudge.pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(0.2)
fade:SetToAlpha(1)
fade:SetDuration(1.4)
nudge:Hide()

nudge:SetScript("OnClick", function()
  -- der Klick ist der Tastendruck, den Blizzard verlangt
  if state.resume and not state.queued then StartQueue(state.resume) else DoSearch(true) end
  nudge:Hide()
end)
nudge:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(self.text:GetText())
  GameTooltip:AddLine(T.NUDGE_TIP, 1, 1, 1, true)
  GameTooltip:Show()
end)
nudge:SetScript("OnLeave", GameTooltip_Hide)
nudge:SetScript("OnShow", function(self)
  self.pulse:Play()
  if db.sound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856, "SFX") end
end)
nudge:SetScript("OnHide", function(self) self.pulse:Stop() end)

-- Bewegung zeigt, dass jemand da ist; Suchen darf sie trotzdem nicht auslösen (kein Klick)
local lastMove = 0
local moveEv = CreateFrame("Frame")
moveEv:RegisterEvent("PLAYER_STARTED_MOVING")
moveEv:RegisterEvent("PLAYER_STOPPED_MOVING")
moveEv:SetScript("OnEvent", function() lastMove = GetTime() end)

-- Jede Sekunde aus Tick: zeigen, wenn gesucht werden sollte, sonst verstecken.
-- „Bin noch da“ nur, wenn man länger stillsteht; wer gerade läuft, bekommt „Jetzt suchen“.
function UpdateNudge()
  if not db then return end
  local now = GetTime()
  local first = state.lastSearchAt == 0 -- direkt nach dem Eintragen: noch nie gesucht
  local want = db.nudge and state.queued and not InCombatLockdown() and not state.searching
    and AnyLeft((Slots())) and (first or now - state.lastSearchAt > NUDGE_AFTER)
  -- Ohne Weltklicks (Controller) erledigt der Knopf auch Vorgemerktes (Rollen, Flüstern, Austragen)
  local pending = not want and db.nudge and not InCombatLockdown() and not WorldClicks() and PendingRestricted()
  if pending then want = true end
  -- Abgang oder Auflösung: „Weitersuchen“ anbieten
  if state.resume and not state.queued and not InCombatLockdown() then
    nudge.text:SetText(T.NUDGE_RESUME)
    nudge:Show()
    return
  end
  if want then
    local active = first or (IsPlayerMoving and IsPlayerMoving()) or now - lastMove < 60
    nudge.text:SetText(pending and T.NUDGE_PENDING or active and T.NUDGE_FIRST or T.NUDGE)
  end
  nudge:SetShown(want and true or false)
end

-------------------------------------------------------------------------
