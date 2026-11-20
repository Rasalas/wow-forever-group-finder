local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Kurzanleitung beim ersten Öffnen und Infoseite in den Einstellungen.
-- Kein Spendenaufruf im Spiel (Blizzards Add-on-Richtlinie, Regel 5); der steht nur auf GitHub.
-------------------------------------------------------------------------
REPO_URL = "https://github.com/Rasalas/wow-forever-group-finder"
-- Weitersagen: Text nur vorausfüllen, abgeschickt wird mit Enter. In der Gruppe an die Gruppe.
-- Immer Englisch: in Zufallsgruppen sprechen nicht alle die eigene Sprache.
SHARE_TEXT = "I use Auto Group Finder, it invites tanks, healers and DPS automatically: %s"
function ShareAddon()
  local prefix = IsInRaid() and "/ra " or IsInGroup() and "/p " or ""
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open then open(prefix .. SHARE_TEXT:format(REPO_URL)) end
end

function AddonVersion()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(ADDON, "Version") or "?"
end

-- Kopierbares Textfeld: WoW kann keine Links öffnen, also markieren und Strg+C
function CopyBox(parent, text, width)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(width, 22)
  box:SetAutoFocus(false)
  box:SetText(text)
  box:SetCursorPosition(0)
  box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(text) self:HighlightText() end end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return box
end

-------------------------------------------------------------------------
-- Erster Start: kleine Karte über dem abgedunkelten Fenster mit den Einstellungen, die man kennen sollte
-------------------------------------------------------------------------
onboarding = CreateFrame("Frame", nil, win)
onboarding:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -22)
onboarding:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 2)
onboarding:SetFrameLevel(win:GetFrameLevel() + 100)
onboarding:EnableMouse(true) -- nichts darunter anklickbar, solange die Karte offen ist
onboarding.dim = onboarding:CreateTexture(nil, "BACKGROUND")
onboarding.dim:SetAllPoints()
onboarding.dim:SetColorTexture(0, 0, 0, 0.6)

local CARD_W = 340
local card = CreateFrame("Frame", nil, onboarding, "BackdropTemplate")
card:SetWidth(CARD_W)
card:SetPoint("TOP", onboarding, "TOP", 0, -70)
if card.SetBackdrop and BACKDROP_DARK_DIALOG_32_32 then
  card:SetBackdrop(BACKDROP_DARK_DIALOG_32_32)
else
  local bg = card:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.06, 0.05, 0.04, 1)
end
onboarding.card = card
card.title = Label(card, T.ONB_TITLE, "GameFontNormalLarge", "TOP", card, "TOP", 0, -22)

onboarding.checks = {}
local ROW = 28
local function Check(key, label, tip, sub)
  local cb = BlizzCheck(card, 26)
  cb:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -54 - #onboarding.checks * ROW)
  cb.key = key
  cb.label = Label(card, label, "GameFontHighlight", "LEFT", cb, "RIGHT", 4, sub and 5 or 0)
  if sub then cb.sub = Label(card, sub, "GameFontDisableSmall", "TOPLEFT", cb.label, "BOTTOMLEFT", 0, -1) end
  Tooltip(cb, label, tip)
  onboarding.checks[#onboarding.checks + 1] = cb
  return cb
end
Check("autoInvite", T.ONB_AUTO, T.ONB_AUTO_TIP)
Check("shareStats", T.ONB_SHARE2, T.ONB_SHARE_TIP)

-- Sammelt ein anderes Add-on Minimap-Symbole ein? Dann fragen, ob das Auge einzeln bleiben soll.
function MinimapCollector()
  if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MinimapButtonButton") then return "MinimapButtonButton" end
  local owner = mm and mm:GetParent()
  if owner and owner ~= Minimap and owner ~= UIParent then return T.ONB_COLLECTOR end
end

-- Tastenkürzel: nur der Weg als Hinweis. Das Add-on öffnet Blizzards Einstellungen nicht selbst,
-- das würde beim Schließen eine Blizzard-Aktion blockieren (siehe OpenSettings).
local keyLink = CreateFrame("Frame", nil, card)
keyLink:SetHeight(20)
keyLink.icon = keyLink:CreateTexture(nil, "ARTWORK")
keyLink.icon:SetSize(16, 16)
keyLink.icon:SetPoint("LEFT", 5, 0)
keyLink.icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
keyLink.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
keyLink.text = Label(keyLink, T.ONB_KEY_PATH, "GameFontDisableSmall", "LEFT", keyLink.icon, "RIGHT", 9, 0)
keyLink.text:SetWidth(CARD_W - 70)
keyLink.text:SetJustifyH("LEFT")
keyLink:SetWidth(CARD_W - 40)

onboarding.go = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
onboarding.go:SetSize(160, 26)
onboarding.go:SetPoint("BOTTOM", card, "BOTTOM", 0, 20)

local mmCheck -- nur da, wenn ein Sammel-Add-on erkannt wurde
local function NeedsReload() return mmCheck and (mmCheck:GetChecked() and true or false) ~= (db.minimapStandalone and true or false) end
local function UpdateGo() onboarding.go:SetText(NeedsReload() and T.ONB_RELOAD or T.ONB_GO) end

-- Höhe und Link-Position hängen davon ab, ob die Minimap-Zeile dazukommt
local function Layout()
  local rows = #onboarding.checks
  local hasKey = true
  keyLink:ClearAllPoints()
  keyLink:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -54 - rows * ROW - 16)
  card:SetHeight(54 + rows * ROW + (hasKey and 40 or 0) + 70)
end

onboarding:SetScript("OnShow", function()
  local collector = MinimapCollector()
  if collector and not mmCheck then
    mmCheck = Check("minimapStandalone", T.ONB_MM, T.ONB_MM_TIP, T.ONB_MM_SUB:format(collector))
    mmCheck:HookScript("OnClick", UpdateGo)
  end
  for _, cb in ipairs(onboarding.checks) do cb:SetChecked(db[cb.key] and true or false) end
  Layout()
  UpdateGo()
end)

onboarding.go:SetScript("OnClick", function()
  local reload = NeedsReload()
  for _, cb in ipairs(onboarding.checks) do db[cb.key] = cb:GetChecked() and true or false end
  Estimate.UpdateChannel()
  db.onboarded = ONBOARDING_VERSION
  onboarding:Hide()
  if reload then ReloadUI() end -- Name des Minimap-Knopfs gilt erst nach dem Neuladen
end)
onboarding:Hide()

function ShowOnboarding() OpenWindow() onboarding:Show() end
ONBOARDING_VERSION = 3 -- erhöhen, wenn man die Karte nach einem Update nochmal sehen sollte
win:HookScript("OnShow", function() if db and db.onboarded ~= ONBOARDING_VERSION then onboarding:Show() end end)

-------------------------------------------------------------------------
-- Info im eigenen Fenster (Zahnrad > Über): Blizzards Einstellungen öffnet das Add-on nicht selbst (Taint)
-------------------------------------------------------------------------
info = CreateFrame("Frame", nil, win)
info:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -22)
info:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 2)
info:SetFrameLevel(win:GetFrameLevel() + 100)
info:EnableMouse(true)
info.dim = info:CreateTexture(nil, "BACKGROUND")
info.dim:SetAllPoints()
info.dim:SetColorTexture(0, 0, 0, 0.6)
do
  local W = 340
  local c = CreateFrame("Frame", nil, info, "BackdropTemplate")
  c:SetWidth(W)
  c:SetPoint("TOP", info, "TOP", 0, -40)
  if c.SetBackdrop and BACKDROP_DARK_DIALOG_32_32 then c:SetBackdrop(BACKDROP_DARK_DIALOG_32_32) end
  local version = AddonVersion()
  local title = Label(c, T.TITLE .. "  |cff9d9d9d" .. version .. "|r", "GameFontNormalLarge", "TOPLEFT", c, "TOPLEFT", 24, -22)
  local parts = { title }
  local function Text(text, font, gap)
    local fs = Label(c, text, font, "TOPLEFT", parts[#parts], "BOTTOMLEFT", 0, -gap)
    fs:SetWidth(W - 48)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    parts[#parts + 1] = fs
    return fs
  end
  local code = Text(T.ABOUT_CODE, "GameFontHighlightSmall", 14)
  local box = CopyBox(c, REPO_URL, W - 56)
  box:SetPoint("TOPLEFT", code, "BOTTOMLEFT", 6, -6)
  parts[#parts + 1] = box
  local share = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
  share:SetSize(120, 22)
  share:SetPoint("BOTTOMRIGHT", c, "BOTTOM", -4, 18)
  share:SetText(T.SHARE)
  share:SetScript("OnClick", function() info:Hide() ShareAddon() end)
  Tooltip(share, T.SHARE, T.SHARE_TIP)
  local close = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
  close:SetSize(120, 22)
  close:SetPoint("BOTTOMLEFT", c, "BOTTOM", 4, 18)
  close:SetText(CLOSE or "Close")
  close:SetScript("OnClick", function() info:Hide() end)
  -- Höhe aus den Texten, erst beim Zeigen sind die Zeilen gemessen
  info:SetScript("OnShow", function()
    local h = 22 + 60
    for _, fs in ipairs(parts) do h = h + ((fs.GetStringHeight and fs:GetStringHeight()) or fs:GetHeight() or 14) + 8 end
    c:SetHeight(math.min(h, win:GetHeight() - 70))
  end)
end
info:Hide()
win:HookScript("OnHide", function() info:Hide() end)
function ShowInfo() OpenWindow() onboarding:Hide() info:Show() end

-------------------------------------------------------------------------
-- Infoseite: Einstellungen → AddOns → Auto Group Finder → Über
-------------------------------------------------------------------------
function RegisterAboutPage()
  if not (settingsCategory and Settings and Settings.RegisterCanvasLayoutSubcategory) then return end
  local page = CreateFrame("Frame")
  page.OnCommit, page.OnDefault, page.OnRefresh = function() end, function() end, function() end
  local version = AddonVersion()
  local title = Label(page, T.TITLE .. "  |cff9d9d9d" .. version .. "|r", "GameFontHighlightHuge", "TOPLEFT", page, "TOPLEFT", 16, -16)
  local text = Label(page, T.ABOUT_TEXT, "GameFontHighlight", "TOPLEFT", title, "BOTTOMLEFT", 0, -14)
  text:SetWidth(560)
  text:SetJustifyH("LEFT")
  text:SetSpacing(2)
  local codeLabel = Label(page, T.ABOUT_CODE, "GameFontNormal", "TOPLEFT", text, "BOTTOMLEFT", 0, -20)
  local box = CopyBox(page, REPO_URL, 420)
  box:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 6, -6)
  Label(page, T.ABOUT_COPY, "GameFontDisableSmall", "LEFT", box, "RIGHT", 10, 0)
  -- Kein Knopf, der das Einstellungsfenster öffnet oder schließt: das färbt Blizzards Fenster ein (siehe OpenSettings).
  aboutCategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, page, T.ABOUT)
end


-------------------------------------------------------------------------
