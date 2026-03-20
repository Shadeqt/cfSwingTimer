-- MeleePaladin.lua — Seal twist markers on main hand bar
function cfSwingTimer.initMeleePaladin()
	if select(2, UnitClass("player")) ~= "PALADIN" then return end

	local M = cfSwingTimer.MODULE
	local bar = cfSwingTimer.bars[M.MAINHAND]
	if not bar then return end

	local TWIST_WINDOW = 0.4
	local GCD = 1.5
	local barWidth = bar:GetWidth()

	local twistMarker = cfSwingTimer.CreateMarker(bar, cfSwingTimer.CASTBAR_COLORS.NONINTERRUPTIBLE)
	local gcdMarker = cfSwingTimer.CreateMarker(bar, cfSwingTimer.CASTBAR_COLORS.FAILED)

	local function PlaceMarker(marker, pos)
		if pos > 0 then
			marker:ClearAllPoints()
			marker:SetPoint("CENTER", bar, "LEFT", pos, 0)
			marker:Show()
		else
			marker:Hide()
		end
	end

	local function UpdateMarkers()
		local speed = UnitAttackSpeed("player") or 0
		if speed == 0 then return end
		PlaceMarker(twistMarker, (1 - TWIST_WINDOW / speed) * barWidth)
		PlaceMarker(gcdMarker, (1 - (TWIST_WINDOW + GCD) / speed) * barWidth)
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("UNIT_ATTACK_SPEED")
	frame:SetScript("OnEvent", function(self, event, unit)
		if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
			UpdateMarkers()
		end
	end)
end
