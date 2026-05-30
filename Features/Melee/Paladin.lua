local addon = cfSwingTimer
local initialized
local UpdatePaladinTwistMarkers

local function CreatePaladinTwist(bar)
	addon.paladinTwistMarker = addon.CreateMarker(bar, addon.CASTBAR_COLORS.NONINTERRUPTIBLE)
	addon.paladinTwistGCDMarker = addon.CreateMarker(bar, addon.CASTBAR_COLORS.FAILED)
	addon.paladinTwistFrame = CreateFrame("Frame")
	addon.paladinTwistFrame:SetScript("OnEvent", function(_, event, unit)
		if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
			UpdatePaladinTwistMarkers()
		end
	end)
	addon.paladinTwistFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon.paladinTwistFrame:RegisterEvent("UNIT_ATTACK_SPEED")
end

function UpdatePaladinTwistMarkers()
	if not initialized then return end

	local bar = addon.bars[addon.KEYS.MAINHAND]
	local active = addon.db[addon.KEYS.MAINHAND] and bar
	if not active then
		if addon.paladinTwistMarker then addon.paladinTwistMarker:Hide() end
		if addon.paladinTwistGCDMarker then addon.paladinTwistGCDMarker:Hide() end
		return
	end

	local speed = UnitAttackSpeed("player") or 0
	if speed == 0 then
		addon.paladinTwistMarker:Hide()
		addon.paladinTwistGCDMarker:Hide()
		return
	end

	local barWidth = bar:GetWidth()
	addon.paladinTwistMarker:ClearAllPoints()
	addon.paladinTwistMarker:SetPoint("CENTER", bar, "LEFT", (1 - 0.4 / speed) * barWidth, 0)
	addon.paladinTwistMarker:Show()
	addon.paladinTwistGCDMarker:ClearAllPoints()
	addon.paladinTwistGCDMarker:SetPoint("CENTER", bar, "LEFT", (1 - (0.4 + 1.5) / speed) * barWidth, 0)
	addon.paladinTwistGCDMarker:Show()
end

function addon.InitPaladinTwist()
	if select(2, UnitClass("player")) ~= "PALADIN" then return end

	if initialized then return end

	local bar = addon.bars[addon.KEYS.MAINHAND]
	if not bar then return end

	CreatePaladinTwist(bar)
	initialized = true
	UpdatePaladinTwistMarkers()
end
