local addon = cfSwingTimer
local initialized
local UpdateShamanHalfMarkers

local function CreateShamanHalf(mhBar)
	addon.shamanHalfOffhandBar = addon.bars[addon.KEYS.OFFHAND]
	addon.shamanHalfMarker = addon.CreateMarker(mhBar, addon.CASTBAR_COLORS.NONINTERRUPTIBLE)
	addon.shamanHalfMarker:SetPoint("CENTER", mhBar, "LEFT", 0.5 * mhBar:GetWidth(), 0)
	if addon.shamanHalfOffhandBar then
		addon.shamanHalfOffhandMarker = addon.CreateMarker(addon.shamanHalfOffhandBar, addon.CASTBAR_COLORS.NONINTERRUPTIBLE)
		addon.shamanHalfOffhandMarker:SetPoint("CENTER", addon.shamanHalfOffhandBar, "LEFT", 0.5 * addon.shamanHalfOffhandBar:GetWidth(), 0)
	end
end

function UpdateShamanHalfMarkers()
	if not initialized then return end

	if addon.shamanHalfMarker then
		addon.shamanHalfMarker:SetShown(addon.db[addon.KEYS.MAINHAND])
	end
	if addon.shamanHalfOffhandMarker then
		addon.shamanHalfOffhandMarker:SetShown(addon.db[addon.KEYS.OFFHAND] and addon.shamanHalfOffhandBar:IsShown())
	end
end

function addon.InitShamanHalf()
	if select(2, UnitClass("player")) ~= "SHAMAN" then return end

	if initialized then return end

	local mhBar = addon.bars[addon.KEYS.MAINHAND]
	if not mhBar then return end

	CreateShamanHalf(mhBar)
	initialized = true
	UpdateShamanHalfMarkers()
end
