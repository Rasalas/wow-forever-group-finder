local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Blizzards animiertes Gruppensuche-Auge (LFGEyeTemplate aus Blizzard_LFGUtil).
-- Fehlt die Vorlage, liefert Create nil und der Aufrufer behält sein altes Symbol.
-------------------------------------------------------------------------
Eye = { all = {}, mode = "idle", foundUntil = 0 }

function Eye.Create(parent, big, level)
  local ok, eye = pcall(CreateFrame, "Button", nil, parent, big and "LFGEyeBigTemplate" or "LFGEyeTemplate")
  if not ok or not eye or not eye.StartSearchingAnimation then return nil end
  if level then eye:SetFrameLevel(level) end
  -- Die Animationsebenen sind in der Vorlage fest auf MEDIUM. Sie folgen dem Knopf, auch wenn
  -- ein anderes Add-on (MinimapButtonButton) ihn umhängt, sonst lägen sie dahinter.
  local function Sync()
    for _, child in ipairs({ eye:GetChildren() }) do
      child:SetFrameStrata(eye:GetFrameStrata())
      child:SetFrameLevel(eye:GetFrameLevel() + 1)
    end
  end
  Sync()
  hooksecurefunc(parent, "SetFrameStrata", Sync)
  hooksecurefunc(parent, "SetFrameLevel", Sync)
  hooksecurefunc(parent, "SetParent", Sync)
  eye:SetStaticMode(true)
  eye:Show()
  Eye.all[#Eye.all + 1] = eye
  return eye
end

local function Apply(eye, mode)
  eye:StopAnimating()
  if mode == "found" and not eye.EyeFoundInitial then mode = "idle" end -- großes Auge hat keine Fund-Animation
  eye:SetStaticMode(mode == "idle")
  if mode == "search" then eye:StartInitialAnimation() -- geht von selbst in die Suchschleife über
  elseif mode == "found" then eye:StartFoundAnimationInit() end
end

-- "idle" (still), "search" (sucht) oder "found" (einmal aufleuchten, dann still)
function Eye.Set(mode)
  local now = GetTime()
  if mode ~= "found" and Eye.mode == "found" and now < Eye.foundUntil then return end
  if mode == Eye.mode then return end
  Eye.mode = mode
  for _, eye in ipairs(Eye.all) do Apply(eye, mode) end
  if mode == "found" then
    Eye.foundUntil = now + 2.2
    C_Timer.After(2.3, function() if Eye.mode == "found" then Eye.Set(state.queued and "search" or "idle") end end)
  end
end

-------------------------------------------------------------------------
