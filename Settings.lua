local addon = cfSwingTimer
local M = addon.MODULE

local panel = CreateFrame("Frame", "cfSwingTimerSettingsPanel")
panel.name = "cfSwingTimer"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("cfSwingTimer")

local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
note:SetText("Changes require a /reload to take effect.")

local function CreateCheckbox(anchor, label, dbKey)
	local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
	checkbox.Text:SetText(label)
	checkbox:SetHitRectInsets(0, -checkbox.Text:GetStringWidth(), 0, 0)
	checkbox:SetScript("OnShow", function(self)
		self:SetChecked(cfSwingTimerDB and cfSwingTimerDB[dbKey])
	end)
	checkbox:SetScript("OnClick", function(self)
		cfSwingTimerDB[dbKey] = self:GetChecked()
	end)
	return checkbox
end

local mainhand = CreateCheckbox(note, "Main Hand", M.MAINHAND)
local offhand = CreateCheckbox(mainhand, "Off Hand", M.OFFHAND)
local ranged = CreateCheckbox(offhand, "Ranged", M.RANGED)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
