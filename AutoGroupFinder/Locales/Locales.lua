local _, ns = ...

-- Spielsprache wählen; fehlende Texte kommen aus dem Englischen.
-- esMX nutzt die spanische Übersetzung, enGB die englische.
local ALIASES = { esMX = "esES", enGB = "enUS" }
local locale = GetLocale()
local current = ns.L[locale] or ns.L[ALIASES[locale] or ""] or {}
local base = ns.L.enUS
ns.T = setmetatable({}, {
  __index = function(_, k) return current[k] or base[k] or k end,
})
