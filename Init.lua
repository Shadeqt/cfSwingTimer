local addon = cfSwingTimer

-- Module identifiers (used as DB keys and display names)
addon.MODULE = {
	MAINHAND = "MainHand",
	OFFHAND  = "OffHand",
	RANGED   = "Ranged",
}

-- ADDON_LOADED
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
	if loadedAddon ~= "cfSwingTimer" then return end
	self:UnregisterEvent("ADDON_LOADED")

	addon.initMelee()
	addon.initMeleePaladin()
	addon.initMeleeWarrior()
	addon.initMeleeShaman()
	addon.initRanged()
	addon.ApplyDarkMode()
end)
