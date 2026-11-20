local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Zusätzlicher Seitenreiter in Blizzards Gruppensuche: wechselt zu unserem Fenster.
-- Blizzards Fenster wird nicht verändert, der Reiter hängt nur als eigenes Kind daran.
-------------------------------------------------------------------------
BLIZZ_LFG = "Blizzard_GroupFinder_VanillaStyle" -- lädt erst beim ersten Öffnen

-- Unser Fenster genau über Blizzards. Blizzards Fenster schließen wir nicht selbst: HideUIPanel
-- aus Add-on-Code färbt Blizzards Fensterverwaltung ein (Taint), siehe Window.lua.
function OpenFromBlizzard()
  local blizz = _G.LFGParentFrame
  local x, y = blizz and blizz:IsShown() and blizz:GetLeft(), blizz and blizz:GetTop()
  OpenWindow()
  if x and y then
    state.winPos = { x = x, y = y }
    ApplyWindowMode()
  end
end

local function AddTab()
  local blizz = _G.LFGParentFrame
  if not blizz or blizzTab then return end
  local last = blizz.WhoListingTab or blizz.BrowsingTab or blizz.ListingTab
  blizzTab = MakeSideTab(blizz, ICON, T.TITLE, OpenFromBlizzard)
  if last then
    blizzTab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
  else
    blizzTab:SetPoint("TOPLEFT", blizz, "TOPRIGHT", 0, -60)
  end
end

local linkEv = CreateFrame("Frame")
linkEv:RegisterEvent("ADDON_LOADED")
linkEv:RegisterEvent("PLAYER_LOGIN")
linkEv:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" or name == BLIZZ_LFG then AddTab() end
  if blizzTab then linkEv:UnregisterAllEvents() end
end)

-------------------------------------------------------------------------
