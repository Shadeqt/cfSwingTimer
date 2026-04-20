local addon = cfSwingTimer

addon.GUI = addon.GUI or {}

function addon.GUI.MakeSettingsPanelDraggable()
	if not SettingsPanel or SettingsPanel.cfDragEnabled then return end
	SettingsPanel.cfDragEnabled = true
	SettingsPanel:SetMovable(true)
	SettingsPanel:EnableMouse(true)
	SettingsPanel:RegisterForDrag("LeftButton")
	SettingsPanel:HookScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	SettingsPanel:HookScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
end

function addon.GUI.SetCheckboxEnabled(checkbox, enabled)
	if enabled then
		checkbox:Enable()
		checkbox.Text:SetTextColor(1, 0.82, 0)
	else
		checkbox:Disable()
		checkbox.Text:SetTextColor(0.5, 0.5, 0.5)
	end
end

function addon.GUI.CreateCheckbox(panel, anchor, label, key, onEnable, onDisable, dependency, col2)
	local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	if col2 then
		checkbox:SetPoint("TOPLEFT", anchor, "TOPLEFT", col2, 0)
	else
		checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
	end
	checkbox.Text:SetText(label)
	checkbox:SetHitRectInsets(0, -checkbox.Text:GetStringWidth(), 0, 0)
	checkbox:SetScript("OnShow", function(self)
		self:SetChecked(addon.db[key])
	end)
	checkbox:SetScript("OnClick", function(self)
		local enabled = self:GetChecked()
		addon.db[key] = enabled
		if enabled then
			if onEnable then onEnable() end
		else
			if onDisable then onDisable() end
		end
	end)

	if dependency then
		local function UpdateState()
			addon.GUI.SetCheckboxEnabled(checkbox, dependency:GetChecked())
		end
		dependency:HookScript("OnClick", UpdateState)
		dependency:HookScript("OnShow", UpdateState)
	end

	return checkbox
end

local reloadPopupKey = "CFSWINGTIMER_RELOAD_REQUIRED"
if not StaticPopupDialogs[reloadPopupKey] then
	StaticPopupDialogs[reloadPopupKey] = {
		text = "Reload UI to apply this change?",
		button1 = ACCEPT,
		button2 = CANCEL,
		OnAccept = ReloadUI,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = STATICPOPUP_NUMDIALOGS,
	}
end

function addon.GUI.CreateReloadCheckbox(panel, anchor, label, key, dependency, col2)
	local checkbox = addon.GUI.CreateCheckbox(panel, anchor, label, key, nil, nil, dependency, col2)
	checkbox:SetScript("OnClick", function(self)
		addon.db[key] = self:GetChecked()
		StaticPopup_Show(reloadPopupKey)
	end)
	return checkbox
end
