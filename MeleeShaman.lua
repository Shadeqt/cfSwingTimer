-- MeleeShaman.lua — 50% swing marker on main hand and off-hand bars
function cfSwingTimer.initMeleeShaman()
	if select(2, UnitClass("player")) ~= "SHAMAN" then return end

	local M = cfSwingTimer.MODULE
	local mhBar = cfSwingTimer.bars[M.MAINHAND]
	if not mhBar then return end
	local ohBar = cfSwingTimer.bars[M.OFFHAND]

	local color = cfSwingTimer.CASTBAR_COLORS.NONINTERRUPTIBLE

	local function PlaceHalfMarker(bar)
		local marker = cfSwingTimer.CreateMarker(bar, color)
		marker:SetPoint("CENTER", bar, "LEFT", 0.5 * bar:GetWidth(), 0)
	end

	PlaceHalfMarker(mhBar)
	if ohBar then PlaceHalfMarker(ohBar) end
end
