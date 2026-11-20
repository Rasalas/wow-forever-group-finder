local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Datenquelle für Titan Panel, ElvUI, ChocolateBar & Co. (LibDataBroker-1.1):
-- Text zeigt Suche und offene Rollen, Linksklick öffnet das Fenster, Rechtsklick sucht bzw. öffnet.
-------------------------------------------------------------------------
local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then return end

broker = ldb:NewDataObject(T.TITLE, {
  type = "data source",
  label = T.TITLE,
  text = T.BROKER_IDLE,
  icon = ICON,
  OnClick = function(_, button)
    if button == "RightButton" then AutoGroupFinder_Next() else AutoGroupFinder_Toggle() end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine(T.TITLE)
    for _, line in ipairs(StatusLines()) do tooltip:AddLine(line, 1, 1, 1, true) end
    tooltip:AddLine(" ")
    tooltip:AddLine(T.MM_LEFT, 0.7, 0.7, 0.7, true)
    tooltip:AddLine(state.queued and T.MM_RIGHT_SEARCH or T.MM_RIGHT_OPEN, 0.7, 0.7, 0.7, true)
  end,
})

-- Jede Sekunde aus Tick; LibDataBroker meldet nur echte Änderungen an die Leisten weiter
function UpdateBroker()
  if not db then return end
  local text
  if state.queued then
    text = Clock(GetTime() - state.queuedAt) .. "  " .. NeedIcons((Slots()))
  elseif GroupReady() then
    text = T.GROUP_COMPLETE
  else
    text = T.BROKER_IDLE
  end
  if broker.text ~= text then broker.text = text end
end

-------------------------------------------------------------------------
