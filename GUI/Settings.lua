local addon = cfSwingTimer
local K = addon.KEYS
local F = addon.GUI

function addon.InitSettings()
	local panel = CreateFrame("Frame", "cfSwingTimerSettingsPanel")
	panel.name = "cfSwingTimer"
	panel:Hide()

	local title = F.Title(panel, "cfSwingTimer")

	local mainhand = F.Checkbox(panel, title, "Main Hand", K.MAINHAND, {
		onEnable = addon.EnableMainhand, onDisable = addon.DisableMainhand,
	})
	local offhand = F.Checkbox(panel, mainhand, "Off Hand", K.OFFHAND, {
		onEnable = addon.EnableOffhand, onDisable = addon.DisableOffhand,
	})
	local ranged = F.Checkbox(panel, offhand, "Ranged", K.RANGED, {
		onEnable = addon.EnableRanged, onDisable = addon.DisableRanged,
	})
	F.Checkbox(panel, ranged, "Ranged Cast", K.RANGED_CAST, {
		dependency = ranged,
		onEnable = addon.EnableRangedCast, onDisable = addon.DisableRangedCast,
	})

	local paladinTwist = F.Checkbox(panel, mainhand, "Paladin Twist", K.PALADIN_TWIST, {
		dependency = mainhand, requireReload = true, col2 = 260,
	})
	local warriorQueue = F.Checkbox(panel, paladinTwist, "Warrior Queue", K.WARRIOR_QUEUE, {
		dependency = mainhand, requireReload = true,
	})
	F.Checkbox(panel, warriorQueue, "Shaman Half", K.SHAMAN_HALF, {
		dependency = mainhand, requireReload = true,
	})

	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)

	panel:SetScript("OnShow", F.MakeSettingsPanelDraggable)
end
