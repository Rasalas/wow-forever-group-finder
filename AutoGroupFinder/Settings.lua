local _, ns = ...
setfenv(1, ns.env) -- gemeinsamer, privater Namensraum aller Module (siehe Core.lua)

-- Einstellungen (Optionen → AddOns → GroupFinder)
-------------------------------------------------------------------------
function RegisterSettings()
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
  local category, layout = Settings.RegisterVerticalLayoutCategory(T.TITLE)
  local function header(text)
    if CreateSettingsListSectionHeaderInitializer and layout and layout.AddInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end
  header(T.SETTINGS_GENERAL)
  for _, o in ipairs(OPTIONS) do
    local setting = Settings.RegisterAddOnSetting(category, "AUTOGROUPFINDER_" .. o[1]:upper(), o[1], db,
      Settings.VarType.Boolean, o[2], DEFAULTS[o[1]])
    if o[4] then setting:SetValueChangedCallback(function() o[4]() end) end
    Settings.CreateCheckbox(category, setting, o[3])
  end
  if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer(T.OPT_WHISPER_TEXT, T.EDIT, EditWhisper, T.WHISPER_EDIT_PROMPT, true))
  end
  for _, size in ipairs(SIZES) do
    header((size == 5 and T.SIZE_PARTY or T.SIZE_RAID):format(size))
    for _, role in ipairs(ROLES) do
      local setting = Settings.RegisterAddOnSetting(category, ("AUTOGROUPFINDER_NEED_%d_%s"):format(size, role),
        role, db.need[size], Settings.VarType.Number, ROLE_PLURAL[role], DEFAULT_NEED[size][role])
      setting:SetValueChangedCallback(function() Rebuild() end)
      local options = Settings.CreateSliderOptions(0, size, 1)
      if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return tostring(math.floor(v + 0.5)) end)
      end
      Settings.CreateSlider(category, setting, options, T.COMPOSITION_TIP)
    end
  end
  -- Sprachen ganz unten: selten gebraucht
  header(T.SETTINGS_LANGUAGES)
  local myLocale = GetLocale() == "enGB" and "enUS" or GetLocale()
  if myLocale == "enUS" and db.languageMode == "mineEnglish" then db.languageMode = "mine" end
  local modeSetting = Settings.RegisterAddOnSetting(category, "AUTOGROUPFINDER_LANGMODE", "languageMode", db,
    Settings.VarType.String, T.LANG_MODE, "all")
  local modeInit = Settings.CreateDropdown(category, modeSetting, function()
    local c = Settings.CreateControlTextContainer()
    c:Add("all", T.LANG_ALL)
    c:Add("mine", T.LANG_MINE:format(LangName(myLocale)))
    if myLocale ~= "enUS" then
      c:Add("mineEnglish", T.LANG_MINE_EN:format(LangName(myLocale)))
    end
    c:Add("custom", T.LANG_CUSTOM)
    return c:GetData()
  end, T.LANG_TIP)
  for _, loc in ipairs(LANGUAGES) do
    local setting = Settings.RegisterAddOnSetting(category, "AUTOGROUPFINDER_LANG_" .. loc, loc, db.languages,
      Settings.VarType.Boolean, LangName(loc), false)
    local init = Settings.CreateCheckbox(category, setting)
    -- nur bei „Eigene Auswahl“ bedienbar
    if init and init.SetParentInitializer and modeInit then
      init:SetParentInitializer(modeInit, function() return db.languageMode == "custom" end)
    end
  end
  settingsCategory = category
  if RegisterAboutPage then pcall(RegisterAboutPage) end -- Unterseite „Über“ vor dem Registrieren anhängen
  Settings.RegisterAddOnCategory(category)
end

-------------------------------------------------------------------------
