-- MeleePaladin.lua — Seal twist markers on main hand bar
function cfSwingTimer.initMeleePaladin()
	if select(2, UnitClass("player")) ~= "PALADIN" then return end
	local M = cfSwingTimer.MODULE
	local mainHandBar = cfSwingTimer.bars[M.MAINHAND]
	if not mainHandBar then return end
	local TWIST_WINDOW = 0.4
	local GCD = 1.5

	local Color = {
		TWIST = { 1, 0.996, 0.722, 1 },
		GCD   = { 1, 0, 0, 0.8 },
	}

	local function CreateMarker(color)
		local marker = mainHandBar:CreateTexture(nil, "OVERLAY")
		marker:SetColorTexture(unpack(color))
		marker:SetSize(2, mainHandBar:GetHeight())
		return marker
	end

	local twistMarker = CreateMarker(Color.TWIST)
	local gcdMarker = CreateMarker(Color.GCD)

	local function PlaceMarker(marker, timeBeforeSwing)
		local pos = (1 - timeBeforeSwing / mainHandBar.speed) * mainHandBar:GetWidth()
		if pos > 0 then
			marker:ClearAllPoints()
			marker:SetPoint("CENTER", mainHandBar, "LEFT", pos, 0)
			marker:Show()
		else
			marker:Hide()
		end
	end

	local function UpdateTwistMarkers()
		twistMarker:SetSize(2, mainHandBar:GetHeight())
		gcdMarker:SetSize(2, mainHandBar:GetHeight())
		PlaceMarker(twistMarker, TWIST_WINDOW)
		PlaceMarker(gcdMarker, TWIST_WINDOW + GCD)
	end
	cfSwingTimer.UpdateTwistMarkers = UpdateTwistMarkers

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("UNIT_ATTACK_SPEED")
	frame:SetScript("OnEvent", function(self, event, unit)
		if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
			UpdateTwistMarkers()
		end
	end)
end
