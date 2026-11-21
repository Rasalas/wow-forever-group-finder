local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Bilder: Dungeon-Vorschau, Spielweisen-Symbole, Rollenplätze
-------------------------------------------------------------------------
Art = { cache = {} }
LS = "Interface\\Glues\\LoadingScreens\\LoadScreen"
-- Ladebildschirme je Instanz-Karten-ID (unabhängig von der Spielsprache); mehrere Kandidaten,
-- genommen wird der erste, den dieser Client hat.
Art.LOADSCREEN = {
  [389] = { LS .. "RagefireChasm" }, [43] = { LS .. "WailingCaverns" }, [33] = { LS .. "ShadowFangKeep" },
  [36] = { LS .. "Deadmines" }, [48] = { LS .. "BlackFathomDeeps" }, [34] = { 131870, LS .. "Stockade" },
  [90] = { LS .. "Gnomeregan" }, [47] = { 131865, LS .. "RazorfenKraul" },
  [189] = { LS .. "ScarletMonastery", LS .. "ScarletMonastery2" }, [129] = { LS .. "RazorfenDowns" },
  [70] = { LS .. "Uldaman" }, [209] = { LS .. "ZulFarrak" }, [349] = { LS .. "Maraudon" },
  [109] = { LS .. "SunkenTemple" }, [230] = { LS .. "BlackrockDepths" }, [229] = { LS .. "BlackrockSpire" },
  [289] = { LS .. "Scholomance" }, [329] = { LS .. "Stratholme" }, [429] = { LS .. "DireMaul" },
  [409] = { LS .. "MoltenCore" }, [249] = { LS .. "OnyxiasLair" }, [469] = { LS .. "BlackwingLair" },
  [309] = { LS .. "ZulGurub" }, [509] = { LS .. "AhnQirajRuins" }, [531] = { LS .. "AhnQiraj" },
  [533] = { LS .. "Naxxramas" },
}
-- Forevers neue Dungeons haben eigene Ladebilder (Datei-Nummern), Zuordnung über den Namen
Art.LOADSCREEN_BY_NAME = { ["Excavation Site"] = { 7963777 }, ["City of Dalaran"] = { 7963775 } }

function FileExists(f)
  if type(f) == "number" then return true end
  if not GetFileIDFromPath then return true end
  local ok, id = pcall(GetFileIDFromPath, f)
  return ok and id ~= nil
end

-- { file, coords } für eine Aktivität: erst Blizzards Dungeon-Journal, sonst Ladebildschirm
function Art.Dungeon(activityID)
  local c = Art.cache[activityID]
  if c ~= nil then return c or nil end
  local result = false
  local a = activityID and L.GetActivityInfoTable(activityID)
  if a and a.mapID and EJ_GetInstanceInfo then
    local jid = JournalInstance(a.mapID)
    if jid then
      local ok2, _, _, _, _, _, button = pcall(EJ_GetInstanceInfo, jid)
      if ok2 and button and button ~= 0 and button ~= "" then result = { file = button, coords = { 0, 1, 0, 1 }, aspect = 1.81 } end
    end
  end
  if not result and a then
    local list = Art.LOADSCREEN[a.mapID]
    if not list then
      for name, l in pairs(Art.LOADSCREEN_BY_NAME) do
        if (a.fullName or ""):find(name, 1, true) then list = l end
      end
    end
    for _, f in ipairs(list or {}) do
      if FileExists(f) then result = { file = f, coords = { 0.02, 0.98, 0.25, 0.82 }, aspect = 1.78 } break end
    end
  end
  Art.cache[activityID] = result
  return result or nil
end

-- aspect: gewünschtes Breite/Höhe-Verhältnis; schneidet mittig zu statt zu verzerren
function Art.Apply(tex, art, aspect)
  if not art then tex:Hide() return false end
  tex:SetTexture(art.file)
  local l, r, t, b = unpack(art.coords)
  local source = art.aspect or 1.8
  if aspect and aspect > source then
    local keep = (b - t) * source / aspect
    t = t + ((b - t) - keep) / 2
    b = t + keep
  elseif aspect and aspect < source then
    local keep = (r - l) * aspect / source
    l = l + ((r - l) - keep) / 2
    r = l + keep
  end
  tex:SetTexCoord(l, r, t, b)
  tex:Show()
  return true
end

-- Rollenplätze wie in Blizzards Gruppenliste: besetzt farbig, fehlend blass.
-- comp = { TANK = { besetzt, gesamt }, ... }; bis 5 Plätze einzeln, darüber je Rolle mit Zahl.
function Art.CreateSlots(parent, size)
  local w = { slots = {}, counts = {} }
  for i = 1, 5 do
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    if i > 1 then t:SetPoint("LEFT", w.slots[i - 1], "RIGHT", 3, 0) end
    w.slots[i] = t
  end
  for i = 1, 3 do
    w.counts[i] = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  end
  -- freier Platz ohne bekannte Rolle: grauer Kreis in derselben Größe wie die Rollen-Symbole
  w.empties = {}
  for i, slot in ipairs(w.slots) do
    local e = parent:CreateTexture(nil, "ARTWORK")
    e:SetSize(size - 2, size - 2)
    e:SetPoint("CENTER", slot, "CENTER")
    e:SetColorTexture(0.55, 0.55, 0.55, 0.45)
    if parent.CreateMaskTexture then
      local mask = parent:CreateMaskTexture()
      mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(e)
      e:AddMaskTexture(mask)
    end
    e:Hide()
    w.empties[i] = e
  end
  w.size = size
  -- Ring in der Rollenfarbe hinter dem eigenen Platz: innen klar, nach außen weich auslaufend
  -- (drei Kreise mit abnehmender Deckkraft); pulsiert langsam nur in der Helligkeit
  w.rings = {}
  for i, spec in ipairs({ { 4, 0.8 }, { 9, 0.32 }, { 15, 0.12 } }) do
    local ring = parent:CreateTexture(nil, "ARTWORK", nil, -i)
    ring:SetSize(size + spec[1], size + spec[1])
    ring:SetColorTexture(1, 1, 1, 1)
    if parent.CreateMaskTexture then
      local mask = parent:CreateMaskTexture()
      mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(ring)
      ring:AddMaskTexture(mask)
    end
    ring:Hide()
    ring.pulse = ring:CreateAnimationGroup()
    ring.pulse:SetLooping("BOUNCE")
    local fade = ring.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(spec[2] * 0.45)
    fade:SetToAlpha(spec[2])
    fade:SetDuration(1.6)
    if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
    w.rings[i] = ring
  end
  return w
end

function Art.PlaceSlots(w, ...)
  w.point = { ... }
  w.slots[1]:ClearAllPoints()
  w.slots[1]:SetPoint(...)
end

ROLE_COLOR = { TANK = { 0.25, 0.55, 1 }, HEALER = { 0.3, 0.9, 0.4 }, DAMAGER = { 1, 0.3, 0.25 } }
function Art.Highlight(w, slot, role)
  for _, ring in ipairs(w.rings) do
    if not slot or not ROLE_COLOR[role] then
      ring:Hide()
      ring.pulse:Stop()
    else
      ring:SetVertexColor(unpack(ROLE_COLOR[role]))
      ring:ClearAllPoints()
      ring:SetPoint("CENTER", slot, "CENTER")
      ring:Show()
      ring.pulse:Stop() -- gemeinsam neu starten, damit alle drei im Takt bleiben
      ring.pulse:Play()
    end
  end
end

-- mine: Rolle des Eingeladenen; sein (noch freier) Platz wird farbig und leuchtet
function Art.SetSlots(w, comp, mine)
  local you
  local total = 0
  for _, r in ipairs(ROLES) do total = total + (comp[r] and comp[r][2] or 0) end
  for _, fs in ipairs(w.counts) do fs:Hide() end
  if total <= 5 then
    local i = 0
    w.slots[1]:ClearAllPoints()
    w.slots[1]:SetPoint(unpack(w.point))
    for k = 2, 5 do
      w.slots[k]:ClearAllPoints()
      w.slots[k]:SetPoint("LEFT", w.slots[k - 1], "RIGHT", 3, 0)
    end
    for _, r in ipairs(ROLES) do
      local filled, need = comp[r] and comp[r][1] or 0, comp[r] and comp[r][2] or 0
      for n = 1, need do
        i = i + 1
        local t = w.slots[i]
        SetRoleTexture(t, r, false)
        local isYou = not you and r == mine and n > filled
        if isYou then you = t end
        t:SetDesaturated(n > filled and not isYou)
        t:SetAlpha((n > filled and not isYou) and 0.65 or 1) -- frei: grau, aber gut erkennbar
        t:Show()
      end
    end
    for _, e in ipairs(w.empties) do e:Hide() end
    local empty = comp.EMPTY or 0 -- freie Plätze ohne bekannte Rolle
    while empty > 0 and i < 5 do
      i, empty = i + 1, empty - 1
      w.slots[i]:Hide() -- bleibt für die Anordnung, gezeigt wird der Kreis
      w.empties[i]:Show()
    end
    for k = i + 1, 5 do w.slots[k]:Hide() end
  else
    -- Schlachtzug: Rolle + „besetzt/gesamt“
    for i, r in ipairs(ROLES) do
      local t, fs = w.slots[i], w.counts[i]
      SetRoleTexture(t, r, false)
      local filled, need = comp[r] and comp[r][1] or 0, comp[r] and comp[r][2] or 0
      t:SetDesaturated(filled >= need)
      t:SetAlpha(1)
      if r == mine then you = t end
      t:ClearAllPoints()
      if i == 1 then t:SetPoint(unpack(w.point)) else t:SetPoint("LEFT", w.counts[i - 1], "RIGHT", 6, 0) end
      t:Show()
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", t, "RIGHT", 2, 0)
      fs:SetText(("%d/%d"):format(filled, need))
      fs:Show()
    end
    for k = 4, 5 do w.slots[k]:Hide() end
    for _, e in ipairs(w.empties) do e:Hide() end
  end
  Art.Highlight(w, you, mine)
end

-------------------------------------------------------------------------
