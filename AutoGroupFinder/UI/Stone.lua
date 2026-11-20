local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Versammlungsstein als Porträt des Fensters: still, pulsierend während der Suche,
-- einmal hell bei voller Gruppe. Nur Animationsgruppen, kein OnUpdate.
-------------------------------------------------------------------------
PORTRAIT = "Interface\\AddOns\\AutoGroupFinder\\Media\\Portrait"
Stone = { all = {}, mode = "idle", foundUntil = 0 }

local function Round(tex)
  local ok = SetPortraitToTexture and pcall(SetPortraitToTexture, tex, PORTRAIT)
  if not ok then tex:SetTexture(PORTRAIT) end
end

-- portrait: vorhandene Porträt-Textur (PortraitFrameTemplate); der Rahmen liegt dann darüber
function Stone.Attach(portrait)
  Round(portrait)
  portrait:SetAlpha(1)
  local glow = portrait:GetParent():CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints(portrait)
  Round(glow)
  glow:SetBlendMode("ADD") -- hellt vor allem die Rune auf
  glow:SetAlpha(0)
  local pulse = glow:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local a = pulse:CreateAnimation("Alpha")
  a:SetFromAlpha(0) a:SetToAlpha(0.7) a:SetDuration(1.1)
  local flash = glow:CreateAnimationGroup()
  local up = flash:CreateAnimation("Alpha")
  up:SetFromAlpha(0) up:SetToAlpha(1) up:SetDuration(0.25) up:SetOrder(1)
  local down = flash:CreateAnimation("Alpha")
  down:SetFromAlpha(1) down:SetToAlpha(0) down:SetDuration(1.8) down:SetOrder(2)
  local s = { glow = glow, pulse = pulse, flash = flash }
  Stone.all[#Stone.all + 1] = s
  return s
end

local function Apply(s, mode)
  s.pulse:Stop() s.flash:Stop()
  s.glow:SetAlpha(0)
  if mode == "search" then s.pulse:Play() elseif mode == "found" then s.flash:Play() end
end

-- "idle", "search" oder "found" (einmal aufleuchten, dann je nach Suche weiter)
function Stone.Set(mode)
  local now = GetTime()
  if mode ~= "found" and Stone.mode == "found" and now < Stone.foundUntil then return end
  if mode == Stone.mode then return end
  Stone.mode = mode
  for _, s in ipairs(Stone.all) do Apply(s, mode) end
  if mode == "found" then
    Stone.foundUntil = now + 2.1
    C_Timer.After(2.2, function() if Stone.mode == "found" then Stone.Set(state.queued and "search" or "idle") end end)
  end
end

-------------------------------------------------------------------------
