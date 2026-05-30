cfSwingTimer = cfSwingTimer or {}
local addon = cfSwingTimer

addon.KEYS = {
	MAINHAND = "MainHand",
	OFFHAND = "OffHand",
	RANGED = "Ranged",
	RANGED_CAST = "RangedCast",
	PALADIN_TWIST = "PaladinTwist",
	WARRIOR_QUEUE = "WarriorQueue",
	SHAMAN_HALF = "ShamanHalf",
}
addon.MODULE = addon.KEYS

local defaults = {
	[addon.KEYS.MAINHAND] = true,
	[addon.KEYS.OFFHAND] = true,
	[addon.KEYS.RANGED] = true,
	[addon.KEYS.RANGED_CAST] = true,
	[addon.KEYS.PALADIN_TWIST] = true,
	[addon.KEYS.WARRIOR_QUEUE] = true,
	[addon.KEYS.SHAMAN_HALF] = true,
}

cfSwingTimerDB = cfSwingTimerDB or {}
for key, value in pairs(defaults) do
	if cfSwingTimerDB[key] == nil then
		cfSwingTimerDB[key] = value
	end
end
for key in pairs(cfSwingTimerDB) do
	if defaults[key] == nil then
		cfSwingTimerDB[key] = nil
	end
end

addon.db = cfSwingTimerDB

local meleeEnabled
local rangedEnabled

function addon.EnsureMelee()
	if meleeEnabled then return end
	meleeEnabled = true
	addon.EnableMelee()
end

function addon.EnsureRanged()
	if rangedEnabled then return end
	rangedEnabled = true
	addon.SetupRanged()
end

function addon.EnableMainhand()
	addon.EnsureMelee()
	addon.UpdateMeleeVisibility()
end

function addon.DisableMainhand()
	if addon.UpdateMeleeVisibility then
		addon.UpdateMeleeVisibility()
	end
end

function addon.EnableOffhand()
	addon.EnsureMelee()
	addon.UpdateMeleeVisibility()
end

function addon.DisableOffhand()
	if addon.UpdateMeleeVisibility then
		addon.UpdateMeleeVisibility()
	end
end

function addon.EnableRanged()
	if not rangedEnabled then
		addon.EnsureRanged()
		return
	end
	addon.UpdateRangedVisibility()
end

function addon.DisableRanged()
	if addon.UpdateRangedVisibility then
		addon.UpdateRangedVisibility()
	end
end

function addon.EnableRangedCast()
	addon.EnsureRanged()
	addon.UpdateRangedVisibility()
end

function addon.DisableRangedCast()
	if addon.UpdateRangedVisibility then
		addon.UpdateRangedVisibility()
	end
end

EventUtil.ContinueOnAddOnLoaded("cfSwingTimer", function()
	addon.InitSettings()

	if addon.db[addon.KEYS.MAINHAND] or addon.db[addon.KEYS.OFFHAND] then
		addon.EnsureMelee()
		addon.UpdateMeleeVisibility()
	end

	if addon.db[addon.KEYS.RANGED] or addon.db[addon.KEYS.RANGED_CAST] then
		addon.EnsureRanged()
		addon.UpdateRangedVisibility()
	end
end)
