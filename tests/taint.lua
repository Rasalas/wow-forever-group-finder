-- Taint-Wächter: Add-on-Code darf Blizzards gemeinsame Fenster- und Popup-Verwaltung nicht anfassen
-- und keine fremden Globalen überschreiben. Durchsucht den Quelltext (ohne Libs und Kommentare).
local root = arg[1]
local FORBIDDEN = {
  { "ShowUIPanel%s*%(", "ShowUIPanel färbt Blizzards Fensterverwaltung ein" },
  { "HideUIPanel%s*%(", "HideUIPanel färbt Blizzards Fensterverwaltung ein" },
  { "UIPanelLayout%-", "UIPanelLayout-Attribute holen Blizzards Fensterverwaltung ins Spiel" },
  { "StaticPopup_Show", "StaticPopup-Rahmen sind geteilt; eigene Fenster benutzen" },
  { "StaticPopupDialogs", "StaticPopupDialogs nicht anfassen" },
  { "OpenToCategory", "Blizzards Einstellungen nicht selbst öffnen" },
  { "RemoveChannel", "Chatfenster nicht verändern" },
  { "SpellStopCasting", "geschützt" },
}
local OWN_GLOBAL = { "^AutoGroupFinder", "^SLASH_AUTOGROUPFINDER", "^BINDING_HEADER_AUTOGROUPFINDER", "^BINDING_NAME_AUTOGROUPFINDER" }
local files = {}
for line in io.lines(root .. "/AutoGroupFinder.toc") do
  local f = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
  if f and not f:match("^Libs") then files[#files + 1] = (f:gsub("\\", "/")) end
end
local bad = 0
for _, f in ipairs(files) do
  local n = 0
  for line in io.lines(root .. "/" .. f) do
    n = n + 1
    local code = line:gsub("%-%-.*$", "")
    for _, rule in ipairs(FORBIDDEN) do
      if code:find(rule[1]) then print(("FEHLER %s:%d: %s"):format(f, n, rule[2])) bad = bad + 1 end
    end
    for name in code:gmatch("_G%.([%w_]+)%s*=[^=]") do
      local own = false
      for _, p in ipairs(OWN_GLOBAL) do if name:match(p) then own = true end end
      if not own then print(("FEHLER %s:%d: fremde Globale _G.%s überschrieben"):format(f, n, name)) bad = bad + 1 end
    end
    for name in code:gmatch("function%s+_G%.([%w_]+)") do
      local own = name:match("^AutoGroupFinder")
      if not own then print(("FEHLER %s:%d: fremde Globale _G.%s"):format(f, n, name)) bad = bad + 1 end
    end
  end
end
print(("%d Dateien geprüft, %d Verstöße"):format(#files, bad))
if bad > 0 then error("Taint-Regeln verletzt") end
