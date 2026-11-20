local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Kurzanleitung beim ersten Öffnen und Infoseite in den Einstellungen.
-- Kein Spendenaufruf im Spiel (Blizzards Add-on-Richtlinie, Regel 5); der steht nur auf GitHub.
-------------------------------------------------------------------------
REPO_URL = "https://github.com/Rasalas/wow-forever-group-finder"

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

-- Taste festlegen: kleiner Link mit Schlüssel, kein zweiter großer Knopf
local keyLink = CreateFrame("Button", nil, card)
keyLink:SetHeight(20)
keyLink.icon = keyLink:CreateTexture(nil, "ARTWORK")
keyLink.icon:SetSize(16, 16)
keyLink.icon:SetPoint("LEFT", 5, 0)
keyLink.icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
keyLink.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
keyLink.text = Label(keyLink, T.ONB_KEY, "GameFontNormalSmall", "LEFT", keyLink.icon, "RIGHT", 9, 0)
keyLink:SetWidth(keyLink.text:GetStringWidth() + 34)
keyLink:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
keyLink:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 0.82, 0) end)
-- Tastaturbelegung öffnen und zu unserem Abschnitt scrollen. Bewusst nicht selbst aufklappen: Ein Klick des
-- Add-ons auf Blizzards Plus färbt das Einstellungsfenster ein, beim Schließen wird dann SpellStopCasting blockiert.
function OpenHotkeys()
  if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, _G.BINDING_HEADER_AUTOGROUPFINDER)
  end
end
keyLink:SetScript("OnClick", OpenHotkeys)

onboarding.go = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
onboarding.go:SetSize(160, 26)
onboarding.go:SetPoint("BOTTOM", card, "BOTTOM", 0, 20)

local mmCheck -- nur da, wenn ein Sammel-Add-on erkannt wurde
local function NeedsReload() return mmCheck and (mmCheck:GetChecked() and true or false) ~= (db.minimapStandalone and true or false) end
local function UpdateGo() onboarding.go:SetText(NeedsReload() and T.ONB_RELOAD or T.ONB_GO) end

-- Höhe und Link-Position hängen davon ab, ob die Minimap-Zeile dazukommt
local function Layout()
  local rows = #onboarding.checks
  local hasKey = Settings and Settings.KEYBINDINGS_CATEGORY_ID and true or false
  keyLink:SetShown(hasKey)
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
-- Infoseite: Einstellungen → AddOns → Auto Group Finder → Über
-------------------------------------------------------------------------
function RegisterAboutPage()
  if not (settingsCategory and Settings and Settings.RegisterCanvasLayoutSubcategory) then return end
  local page = CreateFrame("Frame")
  page.OnCommit, page.OnDefault, page.OnRefresh = function() end, function() end, function() end
  local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "?"
  local title = Label(page, T.TITLE .. "  |cff9d9d9d" .. version .. "|r", "GameFontHighlightHuge", "TOPLEFT", page, "TOPLEFT", 16, -16)
  local text = Label(page, T.ABOUT_TEXT, "GameFontHighlight", "TOPLEFT", title, "BOTTOMLEFT", 0, -14)
  text:SetWidth(560)
  text:SetJustifyH("LEFT")
  text:SetSpacing(2)
  local codeLabel = Label(page, T.ABOUT_CODE, "GameFontNormal", "TOPLEFT", text, "BOTTOMLEFT", 0, -20)
  local box = CopyBox(page, REPO_URL, 420)
  box:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 6, -6)
  Label(page, T.ABOUT_COPY, "GameFontDisableSmall", "LEFT", box, "RIGHT", 10, 0)
  local privacy = Label(page, T.ABOUT_PRIVACY_TITLE, "GameFontNormal", "TOPLEFT", box, "BOTTOMLEFT", -6, -24)
  local ptext = Label(page, T.ABOUT_PRIVACY, "GameFontHighlightSmall", "TOPLEFT", privacy, "BOTTOMLEFT", 0, -6)
  ptext:SetWidth(560)
  ptext:SetJustifyH("LEFT")
  ptext:SetSpacing(2)
  -- Kein Knopf, der das Einstellungsfenster selbst schließt: das färbt Blizzards Fenster ein (siehe OpenHotkeys).
  aboutCategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, page, T.ABOUT)
end

function OpenAbout()
  if aboutCategory and Settings and Settings.OpenToCategory then Settings.OpenToCategory(aboutCategory:GetID()) end
end

-------------------------------------------------------------------------
