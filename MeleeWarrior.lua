-- MeleeWarrior.lua — Slam reset + Heroic Strike/Cleave queue coloring
function cfSwingTimer.initMeleeWarrior()
	if select(2, UnitClass("player")) ~= "WARRIOR" then return end
	local M = cfSwingTimer.MODULE
	local mainHandBar = cfSwingTimer.bars[M.MAINHAND]
	if not mainHandBar then return end

	local playerGUID = cfSwingTimer.playerGUID

	local queuedSpellId = nil

	local function GetColor(spellId)
		if cfSwingTimer_HeroicStrike[spellId] then return cfSwingTimer.CLASS_COLORS.ROGUE end
		if cfSwingTimer_Cleave[spellId] then return cfSwingTimer.CLASS_COLORS.MONK end
		return cfSwingTimer.CLASS_COLORS.SHAMAN
	end

	local function SetQueue(spellId)
		queuedSpellId = spellId
		mainHandBar:SetStatusBarColor(unpack(GetColor(spellId)))
	end

	-- OnUpdate: dequeue when IsCurrentSpell returns false
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function()
		if queuedSpellId then
			local name = GetSpellInfo(queuedSpellId)
			if name and not IsCurrentSpell(name) then
				SetQueue(nil)
			end
		end
	end)

	-- Events
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("UNIT_SPELLCAST_SENT")
	frame:SetScript("OnEvent", function(self, event, ...)
		if event == "UNIT_SPELLCAST_SENT" then
			local unit, target, castGUID, spellId = ...
			if unit == "player" and cfSwingTimer_MeleeReplacer[spellId] then
				SetQueue(spellId)
			end
			return
		end

		-- CLEU: Slam reset — if Slam lands while MH swing is still active, reset it
		local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
		if sourceGUID ~= playerGUID then return end
		if subevent ~= "SPELL_CAST_SUCCESS" then return end
		if not cfSwingTimer_Slam[cleuSpellId] then return end

		local now = GetTime()
		if cfSwingTimer.mhSwingStart > 0 and (now - cfSwingTimer.mhSwingStart) < cfSwingTimer.mhSpeed then
			cfSwingTimer.mhSwingStart = now
		end
	end)
end
