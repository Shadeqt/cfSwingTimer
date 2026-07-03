local _, addon = ...

-- cfSwingTimer settings page: one flat vertical-layout category. Bar toggles are reload-gated
-- (Init's ApplyToggles installs the gating Show-hooks at load, so a checkbox flip applies on the next
-- /reload); the eight position sliders apply LIVE via ApplyPositions. Built from Init's ADDON_LOADED
-- handler after InitDB(), so cfSwingTimerDB is populated before any RegisterAddOnSetting reads
-- cfSwingTimerDB[key] (registering against a nil backing value hands back an unusable setting object).
function addon.SetupSettings()
	local category = Settings.RegisterVerticalLayoutCategory("cfSwingTimer")
	local layout = SettingsPanel:GetLayout(category)

	-- Boolean setting bound to cfSwingTimerDB[key]; reload-gated (no value-changed callback).
	local function Checkbox(key, label, tooltip)
		local setting = Settings.RegisterAddOnSetting(category, "cfSwingTimer_" .. key, key, cfSwingTimerDB,
			Settings.VarType.Boolean, label, addon.defaults[key])
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	-- Numeric X/Y slider bound to cfSwingTimerDB[key]; applies LIVE via ApplyPositions on every change.
	-- Nested here so it closes over `category` (the sibling helper style).
	local function Slider(key, label, minV, maxV, step, tooltip)
		local setting = Settings.RegisterAddOnSetting(category, "cfSwingTimer_" .. key, key, cfSwingTimerDB,
			Settings.VarType.Number, label, addon.defaults[key])
		Settings.CreateSlider(category, setting, Settings.CreateSliderOptions(minV, maxV, step), tooltip)
		Settings.SetOnValueChangedCallback("cfSwingTimer_" .. key, function() addon.ApplyPositions() end)
	end

	local function Header(name)
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
	end

	-- Bars (reload-gated)
	Header("Bars  (changes apply after /reload)")
	Checkbox("MeleeBars",  "Melee bar",           "Show the main-hand swing bar (applies after /reload)")
	Checkbox("OffHandBar", "Off-hand bar",        "Show the off-hand swing bar while dual-wielding (applies after /reload)")
	Checkbox("RangedBar",  "Ranged bar (Hunter)", "Show the ranged swing bar; Hunter only (applies after /reload)")
	Checkbox("CastBar",    "Cast bar (Hunter)",   "Show the cast bar; Hunter only (applies after /reload)")

	-- Positions (live). Ranged/cast controls show for all classes but move nothing off a Hunter, matching
	-- how the cf* panels list every control regardless of applicability.
	Header("Main-hand bar position")
	Slider("MhX", "X", -800, 800, 1, "Horizontal offset of the main-hand bar from the screen center")
	Slider("MhY", "Y", -600, 600, 1, "Vertical offset of the main-hand bar from the screen center")

	Header("Off-hand bar position")
	Slider("OhX", "X", -800, 800, 1, "Horizontal offset of the off-hand bar from the screen center")
	Slider("OhY", "Y", -600, 600, 1, "Vertical offset of the off-hand bar from the screen center")

	Header("Ranged bar position (Hunter)")
	Slider("RangedX", "X", -800, 800, 1, "Horizontal offset of the ranged bar from the screen center")
	Slider("RangedY", "Y", -600, 600, 1, "Vertical offset of the ranged bar from the screen center")

	Header("Cast bar position (Hunter)")
	Slider("CastX", "X", -800, 800, 1, "Horizontal offset of the cast bar from the screen center")
	Slider("CastY", "Y", -600, 600, 1, "Vertical offset of the cast bar from the screen center")

	Settings.RegisterAddOnCategory(category)

	-- Raise the panel above high-strata world UI (matches the other cf addons' settings pages).
	SettingsPanel:SetFrameStrata("FULLSCREEN_DIALOG")

	-- Make the panel draggable by its empty areas (child controls still take their own clicks).
	SettingsPanel:SetMovable(true)
	SettingsPanel:EnableMouse(true)
	SettingsPanel:RegisterForDrag("LeftButton")
	SettingsPanel:SetScript("OnDragStart", SettingsPanel.StartMoving)
	SettingsPanel:SetScript("OnDragStop", SettingsPanel.StopMovingOrSizing)

	-- /cfst opens the panel; opening it shows the bars (via the hook below) so the sliders aren't dragged
	-- blind. Replaces the old standalone /cfst preview toggle that used to live in Features/Test.lua.
	SLASH_CFST1 = "/cfst"
	SlashCmdList.CFST = function() Settings.OpenToCategory(category:GetID()) end

	-- Auto-preview: show the bars while this category is open, hide them otherwise. DisplayCategory has no
	-- in-suite precedent and can't be verified against Blizzard internals from here, so guard its
	-- existence -- a bad name would error and abort SetupSettings. Installed LAST so the category + slash
	-- command above always register even if this fails. PreviewShow/Hide are nil-guarded so the panel
	-- still works if Features/Test.lua is removed (you just lose the live preview).
	if SettingsPanel.DisplayCategory then
		-- Match either the category object or its ID -- DisplayCategory's arg type isn't documented for
		-- Classic Era, so accept both rather than betting on one.
		local categoryID = category:GetID()
		hooksecurefunc(SettingsPanel, "DisplayCategory", function(_, displayed)
			if displayed == category or displayed == categoryID then
				if addon.PreviewShow then addon.PreviewShow() end
			elseif addon.PreviewHide then
				addon.PreviewHide()
			end
		end)
	end
	SettingsPanel:HookScript("OnHide", function()
		if addon.PreviewHide then addon.PreviewHide() end
	end)
end
