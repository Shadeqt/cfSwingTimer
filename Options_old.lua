local addon = cfSwingTimer

local pendingState = {}

local function hasUnsavedChanges()
	local db = cfSwingTimerDB
	for _, moduleName in pairs(addon.MODULES) do
		if pendingState[moduleName] ~= db[moduleName].enabled then
			return true
		end
	end
	return false
end

local function saveChanges()
	local db = cfSwingTimerDB
	for _, moduleName in pairs(addon.MODULES) do
		db[moduleName].enabled = pendingState[moduleName]
	end
	ReloadUI()
end

local panel = CreateFrame("Frame", "cfSwingTimerPanel")
panel.name = "cfSwingTimer"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("cfSwingTimer Settings")

local function createSeparator(anchorTo, yOffset)
	local sep = panel:CreateTexture(nil, "ARTWORK")
	sep:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
	sep:SetSize(300, 1)
	sep:SetColorTexture(0.5, 0.5, 0.5, 0.5)
	return sep
end

local titleSep = createSeparator(title, -8)

local warning = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
local function updateWarning() warning:SetShown(hasUnsavedChanges()) end

local allRows = {}
local isRefreshing = false

local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function applyCoord(moduleName)
	local db = cfSwingTimerDB[moduleName]
	local f = addon.frames[moduleName]
	if f then
		f:ClearAllPoints()
		f:SetPoint("CENTER", db.x, db.y)
	end
end

local function setInputText(input, val)
	input:SetText(tostring(val))
	input:SetCursorPosition(0)
end

local function createEditBox(name, parent, xOffset, boxWidth)
	local input = CreateFrame("EditBox", name, panel, "BackdropTemplate")
	input:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
	input:SetSize(boxWidth or 50, 20)
	input:SetAutoFocus(false)
	input:SetBackdrop(BACKDROP)
	input:SetBackdropColor(0, 0, 0, 0.5)
	input:SetFontObject(GameFontHighlight)
	input:SetJustifyH("CENTER")
	input:SetTextInsets(8, 8, 2, 2)
	return input
end

local function wireInput(input, moduleName, dbKey, opts)
	local numeric = opts and opts.numeric
	input:SetScript("OnTextChanged", function(self)
		if isRefreshing then return end
		if numeric then
			local val = tonumber(self:GetText())
			if not val then return end
			if opts and opts.clamp then val = math.max(opts.clamp[1], math.min(opts.clamp[2], val)) end
			cfSwingTimerDB[moduleName][dbKey] = val
		else
			cfSwingTimerDB[moduleName][dbKey] = self:GetText()
		end
		if opts and opts.onApply then opts.onApply() end
	end)
end

local function createLabel(anchor, text)
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
	label:SetText(text)
	return label
end

local function setControlsEnabled(controls, enabled)
	local alpha = enabled and 1 or 0.4
	for _, ctrl in ipairs(controls) do
		if enabled then ctrl:Enable() else ctrl:Disable() end
		ctrl:SetAlpha(alpha)
	end
end

local function createColorSwatch(anchor, getColor, setColor)
	local btn = CreateFrame("Button", nil, panel)
	btn:SetSize(20, 20)
	btn:SetPoint("LEFT", anchor, "RIGHT", 8, 0)

	local border = btn:CreateTexture(nil, "BACKGROUND")
	border:SetColorTexture(1, 1, 1, 1)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)

	local swatch = btn:CreateTexture(nil, "ARTWORK")
	swatch:SetAllPoints()
	btn.swatch = swatch

	btn:SetScript("OnClick", function()
		local prev = getColor()
		prev = { r = prev.r, g = prev.g, b = prev.b }

		local function applyColor(r, g, b)
			setColor(r, g, b)
			swatch:SetColorTexture(r, g, b)
		end

		ColorPickerFrame.func = function()
			applyColor(ColorPickerFrame:GetColorRGB())
		end
		ColorPickerFrame.swatchFunc = ColorPickerFrame.func
		ColorPickerFrame.cancelFunc = function() applyColor(prev.r, prev.g, prev.b) end
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame:SetColorRGB(prev.r, prev.g, prev.b)
		ColorPickerFrame.previousValues = { prev.r, prev.g, prev.b }
		ColorPickerFrame:Show()
	end)

	return btn
end

local function wireVisibilityCheck(check, moduleName, dbKey, barElement, extraFn)
	check:SetScript("OnClick", function(self)
		local show = self:GetChecked()
		cfSwingTimerDB[moduleName][dbKey] = show
		local bar = addon.bars[moduleName]
		if bar then bar[barElement]:SetShown(show) end
		if extraFn then extraFn(show) end
	end)
end

-- Creates an EditBox with optional label, wires to DB, auto-tracks in row
local function createField(row, suffix, parent, xOffset, dbKey, labelText, opts)
	local input = createEditBox("cfSwingTimer_" .. row.moduleName .. "_" .. suffix, parent, xOffset, opts and opts.boxWidth)
	if opts and opts.justifyH then input:SetJustifyH(opts.justifyH) end
	local lbl = labelText and createLabel(input, labelText) or nil
	wireInput(input, row.moduleName, dbKey, opts)
	row.inputs[#row.inputs + 1] = { input, dbKey }
	row.controls[#row.controls + 1] = input
	return input, lbl
end

-- Module section
local function createModuleSection(anchorTo, label, moduleName, hasColor)
	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -8)
	header:SetText(label)

	local check = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	check.Text:SetText("Enabled")

	local barApply = function()
		local bar = addon.bars[moduleName]
		if bar then addon.ApplyBarSettings(bar, moduleName) end
	end
	local coordOpts = { numeric = true, onApply = function() applyCoord(moduleName) end }
	local alphaOpts = { numeric = true, clamp = {0, 1}, onApply = addon.ApplyAlpha }

	local row = { moduleName = moduleName, check = check, inputs = {}, checks = {}, controls = {} }

	-- Row 1: X / Y / Bar Color
	local xInput = createField(row, "X", check, 130, "x", "X", coordOpts)
	local yInput, yLabel = createField(row, "Y", check, 250, "y", "Y", coordOpts)
	row.xInput, row.yInput = xInput, yInput

	if hasColor then
		row.colorBtn = createColorSwatch(yLabel,
			function() return cfSwingTimerDB[moduleName].color end,
			function(r, g, b)
				cfSwingTimerDB[moduleName].color = { r = r, g = g, b = b }
				local bar = addon.bars[moduleName]
				if bar then bar:SetStatusBarColor(r, g, b) end
			end)
		row.controls[#row.controls + 1] = row.colorBtn
	end

	-- Row 2: Show Border / Combat alpha / OOC alpha
	local borderCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	borderCheck:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -2)
	borderCheck.Text:SetText("Show Border")
	wireVisibilityCheck(borderCheck, moduleName, "showBorder", "border")
	row.checks[#row.checks + 1] = { borderCheck, "showBorder" }
	row.controls[#row.controls + 1] = borderCheck

	createField(row, "IC", borderCheck, 130, "alphaIC", "Combat", alphaOpts)
	createField(row, "OOC", borderCheck, 250, "alphaOOC", "Out of Combat", alphaOpts)

	-- Row 3: Width / Height
	local sizeAnchor = CreateFrame("Frame", nil, panel)
	sizeAnchor:SetSize(1, 20)
	sizeAnchor:SetPoint("TOPLEFT", borderCheck, "BOTTOMLEFT", 0, -6)

	createField(row, "W", sizeAnchor, 130, "width", "Width", { numeric = true, clamp = {50, 500}, onApply = barApply })
	createField(row, "H", sizeAnchor, 250, "height", "Height", { numeric = true, clamp = {5, 50}, onApply = barApply })

	-- Row 4: Left Text toggle + input / Right Text toggle
	local leftTextCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	leftTextCheck:SetPoint("TOPLEFT", sizeAnchor, "BOTTOMLEFT", 0, -2)
	leftTextCheck.Text:SetText("Left Text")

	local leftTextInput = createField(row, "LT", leftTextCheck, 130, "leftText", nil, {
		boxWidth = 100, justifyH = "LEFT",
		onApply = function()
			local bar = addon.bars[moduleName]
			if bar then bar.label:SetText(cfSwingTimerDB[moduleName].leftText) end
		end,
	})
	row.leftTextInput = leftTextInput

	local rightTextCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	rightTextCheck:SetPoint("LEFT", leftTextCheck, "LEFT", 250, 0)
	rightTextCheck.Text:SetText("Right Text")

	wireVisibilityCheck(leftTextCheck, moduleName, "showLeftText", "label", function(show)
		if show then leftTextInput:Enable() else leftTextInput:Disable() end
		leftTextInput:SetAlpha(show and 1 or 0.4)
	end)
	wireVisibilityCheck(rightTextCheck, moduleName, "showRightText", "text")

	row.checks[#row.checks + 1] = { leftTextCheck, "showLeftText" }
	row.checks[#row.checks + 1] = { rightTextCheck, "showRightText" }
	row.controls[#row.controls + 1] = leftTextCheck
	row.controls[#row.controls + 1] = rightTextCheck

	-- Row 5: Font Size + Text Color
	local fontAnchor = CreateFrame("Frame", nil, panel)
	fontAnchor:SetSize(1, 20)
	fontAnchor:SetPoint("TOPLEFT", leftTextCheck, "BOTTOMLEFT", 0, -6)

	local _, fontSizeLabel = createField(row, "FS", fontAnchor, 130, "fontSize", "Font Size",
		{ numeric = true, clamp = {6, 24}, onApply = barApply })

	row.textColorBtn = createColorSwatch(fontSizeLabel,
		function() return cfSwingTimerDB[moduleName].textColor end,
		function(r, g, b)
			cfSwingTimerDB[moduleName].textColor = { r = r, g = g, b = b }
			local bar = addon.bars[moduleName]
			if bar then
				bar.label:SetTextColor(r, g, b)
				bar.text:SetTextColor(r, g, b)
			end
		end)
	row.controls[#row.controls + 1] = row.textColorBtn

	local sep = createSeparator(fontAnchor, -28)

	check:SetScript("OnClick", function(self)
		local enabled = self:GetChecked()
		pendingState[moduleName] = enabled
		local f = addon.frames[moduleName]
		if f then f:SetShown(enabled) end
		setControlsEnabled(row.controls, enabled)
		if enabled and not leftTextCheck:GetChecked() then
			leftTextInput:Disable()
			leftTextInput:SetAlpha(0.4)
		end
		updateWarning()
	end)

	table.insert(allRows, row)
	return sep
end

-- Module sections
local mhSep     = createModuleSection(titleSep, "Main Hand", addon.MODULES.MAIN_HAND, true)
local ohSep     = createModuleSection(mhSep, "Off-Hand", addon.MODULES.OFF_HAND, true)
local rangedSep = createModuleSection(ohSep, "Ranged", addon.MODULES.RANGED)

-- Lock Bars checkbox (immediate)
local lockCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", rangedSep, "BOTTOMLEFT", 0, -8)
lockCheck.Text:SetText("Lock Bars")
lockCheck:SetScript("OnClick", function(self)
	local locked = self:GetChecked()
	cfSwingTimerDB.locked = locked
	for _, f in pairs(addon.frames) do f:EnableMouse(not locked) end
end)

local lockSep = createSeparator(lockCheck, -8)

-- Save Changes button
local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
saveBtn:SetPoint("TOPLEFT", lockSep, "BOTTOMLEFT", 0, -8)
saveBtn:SetSize(120, 25)
saveBtn:SetText("Save Changes")
saveBtn:SetScript("OnClick", saveChanges)

warning:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
warning:SetText("Click '|cffffd100Save Changes|r' to apply")
warning:Hide()

local info = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
info:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 4, -8)
info:SetText("Type |cffffffff/cfst|r to open this panel")

-- Register with Settings API
if Settings and Settings.RegisterCanvasLayoutCategory then
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	category.ID = panel.name
	Settings.RegisterAddOnCategory(category)
end

-- Refresh all UI elements from current state
local function refreshUI()
	local db = cfSwingTimerDB
	if not db then return end
	isRefreshing = true
	for _, row in ipairs(allRows) do
		local mod = db[row.moduleName]
		local enabled = pendingState[row.moduleName]
		row.check:SetChecked(enabled)
		for _, f in ipairs(row.inputs) do setInputText(f[1], mod[f[2]]) end
		for _, f in ipairs(row.checks) do f[1]:SetChecked(mod[f[2]]) end
		if row.colorBtn and mod.color then
			row.colorBtn.swatch:SetColorTexture(mod.color.r, mod.color.g, mod.color.b)
		end
		row.textColorBtn.swatch:SetColorTexture(mod.textColor.r, mod.textColor.g, mod.textColor.b)
		setControlsEnabled(row.controls, enabled)
		if enabled and not mod.showLeftText then
			row.leftTextInput:Disable()
			row.leftTextInput:SetAlpha(0.4)
		end
	end
	lockCheck:SetChecked(db.locked)
	isRefreshing = false
	updateWarning()
end

function addon.initOptions()
	local db = cfSwingTimerDB
	for _, moduleName in pairs(addon.MODULES) do
		pendingState[moduleName] = db[moduleName].enabled
	end
	refreshUI()
end

panel:HookScript("OnShow", refreshUI)

-- Live-sync coords from frame positions (updates during drag)
panel:SetScript("OnUpdate", function()
	local ux, uy = UIParent:GetCenter()
	for _, row in ipairs(allRows) do
		local f = addon.frames[row.moduleName]
		if f and not row.xInput:HasFocus() and not row.yInput:HasFocus() then
			local cx, cy = f:GetCenter()
			local xStr = tostring(math.floor(cx - ux + 0.5))
			local yStr = tostring(math.floor(cy - uy + 0.5))
			if row.xInput:GetText() ~= xStr then setInputText(row.xInput, xStr) end
			if row.yInput:GetText() ~= yStr then setInputText(row.yInput, yStr) end
		end
	end
end)
