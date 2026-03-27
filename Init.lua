local addon = cfSwingTimer

local M = {
	MAINHAND    = "MainHand",
	OFFHAND     = "OffHand",
	RANGED      = "Ranged",
	RANGED_CAST = "RangedCast",
}
addon.MODULE = M

local DEFAULTS = {
	[M.MAINHAND] = true,
	[M.OFFHAND]  = true,
	[M.RANGED]   = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
	if loadedAddon ~= "cfSwingTimer" then return end
	self:UnregisterEvent("ADDON_LOADED")

	cfSwingTimerDB = cfSwingTimerDB or {}

	for key, value in pairs(DEFAULTS) do
		if cfSwingTimerDB[key] == nil then
			cfSwingTimerDB[key] = value
		end
	end

	for key in pairs(cfSwingTimerDB) do
		if DEFAULTS[key] == nil then
			cfSwingTimerDB[key] = nil
		end
	end

	if cfSwingTimerDB[M.MAINHAND] then
		addon.initMelee()
		addon.initMeleePaladin()
		addon.initMeleeWarrior()
		addon.initMeleeShaman()
	end

	if cfSwingTimerDB[M.RANGED] then
		addon.initRanged()
	end
end)
