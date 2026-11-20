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
-- Kurzanleitung über dem Fensterinhalt
-------------------------------------------------------------------------
onboarding = CreateFrame("Frame", nil, win)
onboarding:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -24)
onboarding:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
onboarding:SetFrameLevel(win:GetFrameLevel() + 100)
onboarding:EnableMouse(true) -- nichts darunter anklickbar, solange die Anleitung offen ist
onboarding.bg = onboarding:CreateTexture(nil, "BACKGROUND")
onboarding.bg:SetAllPoints()
onboarding.bg:SetColorTexture(0.05, 0.04, 0.03, 0.96)

local y = -40
local function Line(text, font, indent, gap)
  local fs = Label(onboarding, text, font or "GameFontHighlight", "TOPLEFT", onboarding, "TOPLEFT", 28 + (indent or 0), y)
  fs:SetWidth(WIN_W - 70 - (indent or 0))
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(2)
  y = y - fs:GetStringHeight() - (gap or 12)
  return fs
end
onboarding.title = Label(onboarding, T.ONB_TITLE, "GameFontNormalLarge", "TOP", onboarding, "TOP", 0, -14)
for i, key in ipairs({ "ONB_STEP1", "ONB_STEP2", "ONB_STEP3" }) do
  local n = Label(onboarding, i .. ".", "GameFontNormalLarge", "TOPLEFT", onboarding, "TOPLEFT", 28, y)
  n:SetTextColor(1, 0.82, 0)
  Line(T[key], "GameFontHighlight", 24)
end
y = y - 6
Line(T.ONB_TIPS, "GameFontHighlightSmall")
Line(T.ONB_SHARE, "GameFontDisableSmall")

onboarding.go = CreateFrame("Button", nil, onboarding, "UIPanelButtonTemplate")
onboarding.go:SetSize(140, 28)
onboarding.go:SetPoint("BOTTOM", onboarding, "BOTTOM", 0, 14)
onboarding.go:SetText(T.ONB_GO)
onboarding.go:SetScript("OnClick", function()
  db.onboarded = true
  onboarding:Hide()
end)
onboarding:Hide()

function ShowOnboarding() OpenWindow() onboarding:Show() end
win:HookScript("OnShow", function() if db and not db.onboarded then onboarding:Show() end end)

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
