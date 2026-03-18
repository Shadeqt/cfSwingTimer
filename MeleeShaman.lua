-- MeleeShaman.lua — 50% swing marker on main hand and off-hand bars
function cfSwingTimer.initMeleeShaman()
	if select(2, UnitClass("player")) ~= "SHAMAN" then return end
	local M = cfSwingTimer.MODULE
	local mainHandBar = cfSwingTimer.bars[M.MAINHAND]
	if not mainHandBar then return end

	local offHandBar = cfSwingTimer.bars[M.OFFHAND]

	local Color = {
		HALF = { 1, 1, 1, 0.8 },
	}

	local function CreateMarker(bar, color)
		local marker = bar:CreateTexture(nil, "OVERLAY")
		marker:SetColorTexture(unpack(color))
		marker:SetSize(2, bar:GetHeight())
		return marker
	end

	local function PlaceMarker(marker, bar, fraction)
		marker:SetSize(2, bar:GetHeight())
		marker:ClearAllPoints()
		marker:SetPoint("CENTER", bar, "LEFT", fraction * bar:GetWidth(), 0)
		marker:Show()
	end

	local mhMarker = CreateMarker(mainHandBar, Color.HALF)
	local ohMarker = offHandBar and CreateMarker(offHandBar, Color.HALF)

	local function UpdateMarkers()
		PlaceMarker(mhMarker, mainHandBar, 0.5)
		if ohMarker then PlaceMarker(ohMarker, offHandBar, 0.5) end
	end
	cfSwingTimer.UpdateShamanMarkers = UpdateMarkers

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("UNIT_ATTACK_SPEED")
	frame:SetScript("OnEvent", function(self, event, unit)
		if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
			UpdateMarkers()
		end
	end)
end
