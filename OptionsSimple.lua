local addon = cfSwingTimer

-- Main page
local mainPanel = CreateFrame("Frame", "cfSwingTimerPanel")
mainPanel.name = "cfSwingTimer"

local mainTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
mainTitle:SetPoint("TOP", 0, -16)
mainTitle:SetText("cfSwingTimer")

local function addTooltip(frame, text)
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text)
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function createSeparator(parent, anchor)
	local separator = parent:CreateTexture(nil, "ARTWORK")
	separator:SetPoint("LEFT", parent, "LEFT", 16, 0)
	separator:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
	separator:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
	separator:SetHeight(1)
	separator:SetColorTexture(0.5, 0.5, 0.5, 0.5)
	return separator
end

local function createCheckbox(parent, anchor, label, tooltip)
	local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
	checkbox.Text:SetText(label)
	addTooltip(checkbox, tooltip)
	return checkbox
end

local function createButton(parent, anchor, label, tooltip)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
	button:SetSize(120, 25)
	button:SetText(label)
	addTooltip(button, tooltip)
	return button
end

local mainSeparator = createSeparator(mainPanel, mainTitle)

local lockButton = createButton(mainPanel, mainSeparator, "Unlock Bars", "Toggle whether bars can be moved with the cursor.")

local moduleSeparator = createSeparator(mainPanel, lockButton)

local mainHandCheckbox = createCheckbox(mainPanel, moduleSeparator, "Main Hand", "Toggle the main hand swing timer. Requires reload.")
local offHandCheckbox = createCheckbox(mainPanel, mainHandCheckbox, "Off Hand", "Toggle the off hand swing timer. Requires reload.")
local rangedCheckbox = createCheckbox(mainPanel, offHandCheckbox, "Ranged", "Toggle the ranged swing timer. Requires reload.")

local saveButton = createButton(mainPanel, rangedCheckbox, "Save Changes", "Apply pending changes by reloading the UI.")
saveButton:Disable()

local warning = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
warning:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
warning:SetText("Reload required to apply changes")
warning:Hide()

-- Melee page
local meleePanel = CreateFrame("Frame", "cfSwingTimerMeleePanel")
meleePanel.name = "Melee"

local meleeTitle = meleePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
meleeTitle:SetPoint("TOP", 0, -16)
meleeTitle:SetText("Melee")

local meleeSeparator = createSeparator(meleePanel, meleeTitle)

-- Ranged page
local rangedPanel = CreateFrame("Frame", "cfSwingTimerRangedPanel")
rangedPanel.name = "Ranged"

local rangedTitle = rangedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
rangedTitle:SetPoint("TOP", 0, -16)
rangedTitle:SetText("Ranged")

local rangedSeparator = createSeparator(rangedPanel, rangedTitle)

-- Register
local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
category.ID = mainPanel.name
addon.settingsCategory = category

local meleeSubcat = Settings.RegisterCanvasLayoutSubcategory(category, meleePanel, meleePanel.name)
local rangedSubcat = Settings.RegisterCanvasLayoutSubcategory(category, rangedPanel, rangedPanel.name)

Settings.RegisterAddOnCategory(category)

function addon.initOptions()
	local db = cfSwingTimerDB
	local savedState = { mainHand = db.mainHand.enabled, offHand = db.offHand.enabled, ranged = db.ranged.enabled }

	mainHandCheckbox:SetChecked(db.mainHand.enabled)
	offHandCheckbox:SetChecked(db.offHand.enabled)
	rangedCheckbox:SetChecked(db.ranged.enabled)

	local function updateSaveState()
		if db.mainHand.enabled ~= savedState.mainHand
		or db.offHand.enabled ~= savedState.offHand
		or db.ranged.enabled ~= savedState.ranged then
			saveButton:Enable()
			warning:Show()
		else
			saveButton:Disable()
			warning:Hide()
		end
	end

	mainHandCheckbox:SetScript("OnClick", function(self)
		db.mainHand.enabled = self:GetChecked()
		updateSaveState()
	end)
	offHandCheckbox:SetScript("OnClick", function(self)
		db.offHand.enabled = self:GetChecked()
		updateSaveState()
	end)
	rangedCheckbox:SetScript("OnClick", function(self)
		db.ranged.enabled = self:GetChecked()
		updateSaveState()
	end)

	saveButton:SetScript("OnClick", ReloadUI)

	lockButton:SetText(db.locked and "Unlock Bars" or "Lock Bars")

	lockButton:SetScript("OnClick", function()
		db.locked = not db.locked
		for _, frame in pairs(addon.frames) do
			frame:EnableMouse(not db.locked)
		end
		lockButton:SetText(db.locked and "Unlock Bars" or "Lock Bars")
	end)
end
