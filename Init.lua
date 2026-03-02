local addon = cfSwingTimer

-- Module name constants
addon.MODULES = {
	MAIN_HAND = "mainHand",
	OFF_HAND  = "offHand",
	RANGED    = "ranged",
}

-- Database defaults
local dbDefaults = {
	locked   = true,
	mainHand = {
		enabled = true, x = 0, y = -150,
		color = { r = 1, g = 0.7, b = 0 }, showBorder = true, alphaIC = 1, alphaOOC = 1,
		width = 195, height = 13, showLeftText = true, showRightText = true,
		leftText = "Main Hand", fontSize = 11, textColor = { r = 1, g = 1, b = 1 },
	},
	offHand = {
		enabled = true, x = 0, y = -175,
		color = { r = 1, g = 0.7, b = 0 }, showBorder = true, alphaIC = 1, alphaOOC = 1,
		width = 195, height = 13, showLeftText = true, showRightText = true,
		leftText = "Off Hand", fontSize = 11, textColor = { r = 1, g = 1, b = 1 },
	},
	ranged = {
		enabled = true, x = 0, y = -200,
		showBorder = true, alphaIC = 1, alphaOOC = 1,
		width = 195, height = 13, showLeftText = true, showRightText = true,
		leftText = "Ranged", fontSize = 11, textColor = { r = 1, g = 1, b = 1 },
	},
}

-- ADDON_LOADED: SavedVariablesPerCharacter are now available
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
	if loadedAddon ~= "cfSwingTimer" then return end
	self:UnregisterEvent("ADDON_LOADED")

	-- Initialize database if it doesn't exist
	if not cfSwingTimerDB then
		cfSwingTimerDB = {}
	end

	local db = cfSwingTimerDB

	-- Apply defaults for missing keys (nested for tables)
	for key, default in pairs(dbDefaults) do
		if db[key] == nil then
			db[key] = default
		elseif type(default) == "table" then
			for subkey, subdefault in pairs(default) do
				if db[key][subkey] == nil then
					db[key][subkey] = subdefault
				end
			end
		end
	end

	-- Remove stale keys (nested for tables)
	for key in pairs(db) do
		if dbDefaults[key] == nil then
			db[key] = nil
		elseif type(dbDefaults[key]) == "table" then
			for subkey in pairs(db[key]) do
				if dbDefaults[key][subkey] == nil then
					db[key][subkey] = nil
				end
			end
		end
	end

	-- Initialize all modules (order matters: options before UI, melee before class modules)
	addon.initOptions()
	addon.initMelee()
	addon.initMeleePaladin()
	addon.initMeleeWarrior()
	addon.initMeleeShaman()
	addon.initRanged()
	addon.ApplyDarkMode()
end)
