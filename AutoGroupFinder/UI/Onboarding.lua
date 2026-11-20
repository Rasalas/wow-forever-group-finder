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
-- Kurzanleitung: drei Bilder statt Text, darunter die Einstellungen, die man kennen sollte
-------------------------------------------------------------------------
onboarding = CreateFrame("Frame", nil, win)
onboarding:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -24)
onboarding:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
onboarding:SetFrameLevel(win:GetFrameLevel() + 100)
onboarding:EnableMouse(true) -- nichts darunter anklickbar, solange die Anleitung offen ist
onboarding.bg = onboarding:CreateTexture(nil, "BACKGROUND")
onboarding.bg:SetAllPoints()
onboarding.bg:SetColorTexture(0.06, 0.05, 0.04, 1)
onboarding.title = Label(onboarding, T.ONB_TITLE, "GameFontNormalLarge", "TOP", onboarding, "TOP", 0, -18)

-- Drei Schritte nebeneinander: Bild, Nummer, zwei bis fünf Wörter
local COL = (WIN_W - 8) / 3
local function Step(i, caption)
  local holder = CreateFrame("Frame", nil, onboarding)
  holder:SetSize(COL - 10, 64)
  holder:SetPoint("TOP", onboarding, "TOPLEFT", COL * (i - 0.5), -56)
  local text = Label(onboarding, i .. ".  " .. caption, "GameFontHighlight", "TOP", holder, "BOTTOM", 0, -8)
  text:SetWidth(COL - 14)
  return holder
end
local s1 = Step(1, T.ONB_S1)
for k, role in ipairs(ROLES) do
  local t = s1:CreateTexture(nil, "ARTWORK")
  t:SetSize(40, 40)
  t:SetPoint("CENTER", s1, "CENTER", (k - 2) * 34, 0)
  SetRoleTexture(t, role, true)
end
local s2 = Step(2, T.ONB_S2)
local card = s2:CreateTexture(nil, "ARTWORK")
card:SetSize(COL - 22, 56)
card:SetPoint("CENTER")
if not Atlas(card, "groupfinder-button-dungeons") then card:SetColorTexture(0.2, 0.25, 0.35, 1) end
local s3 = Step(3, T.ONB_S3)
local eye = s3:CreateTexture(nil, "ARTWORK")
eye:SetSize(60, 60)
eye:SetPoint("CENTER")
if not Atlas(eye, "groupfinder-eye-frame") then eye:SetTexture(ICON) end
for i = 1, 2 do -- Pfeile zwischen den Schritten
  local arrow = onboarding:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(22, 22)
  arrow:SetPoint("CENTER", onboarding, "TOPLEFT", COL * i, -88)
  arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
end

-- Einstellungen mit kurzer Beschriftung; Erklärung im Tooltip
local line = onboarding:CreateTexture(nil, "ARTWORK")
line:SetPoint("LEFT", onboarding, "TOPLEFT", 20, -196)
line:SetPoint("RIGHT", onboarding, "TOPRIGHT", -20, -196)
if not AtlasSized(line, "groupfinder-ScrollLine") then line:SetColorTexture(0.5, 0.4, 0.25, 0.5) line:SetHeight(1) end
local setupTitle = Label(onboarding, T.ONB_SETUP, "GameFontNormal", "TOPLEFT", onboarding, "TOPLEFT", 26, -212)

onboarding.checks = {}
local function Check(key, label, tip, sub)
  local prev = onboarding.checks[#onboarding.checks]
  local cb = BlizzCheck(onboarding, 26)
  if prev then cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev.sub and -14 or -4)
  else cb:SetPoint("TOPLEFT", setupTitle, "BOTTOMLEFT", -4, -8) end
  cb.key = key
  cb.label = Label(onboarding, label, "GameFontHighlight", "LEFT", cb, "RIGHT", 4, 0)
  if sub then
    cb.sub = Label(onboarding, sub, "GameFontDisableSmall", "TOPLEFT", cb.label, "BOTTOMLEFT", 0, -1)
  end
  Tooltip(cb, label, tip)
  onboarding.checks[#onboarding.checks + 1] = cb
  return cb
end
Check("autoInvite", T.ONB_AUTO, T.OPT_AUTOINVITE_TIP)
Check("shareStats", T.ONB_SHARE2, T.OPT_SHARE_TIP:format(SHARE_CHANNEL))

-- Sammelt ein anderes Add-on Minimap-Symbole ein? Dann fragen, ob das Auge einzeln bleiben soll.
function MinimapCollector()
  if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MinimapButtonButton") then return "MinimapButtonButton" end
  local owner = mm and mm:GetParent()
  if owner and owner ~= Minimap and owner ~= UIParent then return T.ONB_COLLECTOR end
end

onboarding.go = CreateFrame("Button", nil, onboarding, "UIPanelButtonTemplate")
onboarding.go:SetSize(170, 28)
onboarding.go:SetPoint("BOTTOM", onboarding, "BOTTOM", 0, 14)

local keyBtn = CreateFrame("Button", nil, onboarding, "UIPanelButtonTemplate")
keyBtn:SetSize(170, 22)
keyBtn:SetPoint("BOTTOM", onboarding.go, "TOP", 0, 10)
keyBtn:SetText(T.ONB_KEY)
keyBtn:SetScript("OnClick", function()
  if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, _G.BINDING_HEADER_AUTOGROUPFINDER)
  end
end)
Tooltip(keyBtn, T.ONB_KEY, T.BIND_NEXT)

local mmCheck -- nur da, wenn ein Sammel-Add-on erkannt wurde
local function NeedsReload() return mmCheck and (mmCheck:GetChecked() and true or false) ~= (db.minimapStandalone and true or false) end
local function UpdateGo() onboarding.go:SetText(NeedsReload() and T.ONB_RELOAD or T.ONB_GO) end

onboarding:SetScript("OnShow", function()
  local collector = MinimapCollector()
  if collector and not mmCheck then
    mmCheck = Check("minimapStandalone", T.ONB_MM, T.OPT_MM_STANDALONE_TIP, T.ONB_MM_SUB:format(collector))
    mmCheck:HookScript("OnClick", UpdateGo)
  end
  for _, cb in ipairs(onboarding.checks) do
    cb:SetChecked(db[cb.key] and true or false)
  end
  keyBtn:SetShown(Settings and Settings.KEYBINDINGS_CATEGORY_ID and true or false)
  UpdateGo()
end)

onboarding.go:SetScript("OnClick", function()
  local reload = NeedsReload()
  for _, cb in ipairs(onboarding.checks) do
    if cb.key ~= "minimapStandalone" then db[cb.key] = cb:GetChecked() and true or false end
  end
  if mmCheck then db.minimapStandalone = mmCheck:GetChecked() and true or false end
  Estimate.UpdateChannel()
  db.onboarded = ONBOARDING_VERSION
  onboarding:Hide()
  if reload then ReloadUI() end -- Name des Minimap-Knopfs gilt erst nach dem Neuladen
end)
onboarding:Hide()

function ShowOnboarding() OpenWindow() onboarding:Show() end
ONBOARDING_VERSION = 2 -- erhöhen, wenn sich die Anleitung so ändert, dass man sie nochmal sehen sollte
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
  local again = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  again:SetSize(180, 24)
  again:SetPoint("TOPLEFT", ptext, "BOTTOMLEFT", 0, -20)
  again:SetText(T.ONB_SHOW)
  again:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
    ShowOnboarding()
  end)
  aboutCategory = Settings.RegisterCanvasLayoutSubcategory(settingsCategory, page, T.ABOUT)
end

function OpenAbout()
  if aboutCategory and Settings and Settings.OpenToCategory then Settings.OpenToCategory(aboutCategory:GetID()) end
end

-------------------------------------------------------------------------
