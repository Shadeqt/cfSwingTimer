-- MeleeWarrior.lua — Slam pause + Heroic Strike/Cleave queue coloring
function cfSwingTimer.initMeleeWarrior()
	if select(2, UnitClass("player")) ~= "WARRIOR" then return end
	if not cfSwingTimer.mainHandBar then return end

	local playerGUID = cfSwingTimer.playerGUID
	local mainHandBar = cfSwingTimer.mainHandBar

	local Color = {
		DEFAULT       = { 1, 0.7, 0 },
		HEROIC_STRIKE = { 0.9, 0.6, 0.1 },
		CLEAVE        = { 0.1, 0.8, 0.2 },
	}

	local queuedSpellId = nil

	local function GetColor(spellId)
		if cfSwingTimer_HeroicStrike[spellId] then return Color.HEROIC_STRIKE end
		if cfSwingTimer_Cleave[spellId] then return Color.CLEAVE end
		return Color.DEFAULT
	end

	local function SetQueue(spellId)
		queuedSpellId = spellId
		mainHandBar:SetStatusBarColor(unpack(GetColor(spellId)))
	end

	-- OnUpdate: dequeue when IsCurrentSpell returns false
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function()
		if queuedSpellId and not C_Spell.IsCurrentSpell(queuedSpellId) then
			SetQueue(nil)
		end
	end)

	-- Events
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("UNIT_SPELLCAST_SENT")
	frame:SetScript("OnEvent", function(self, event, unit, _, spellId)
		if event == "UNIT_SPELLCAST_SENT" then
			if unit == "player" and cfSwingTimer_MeleeReplacer[spellId] then
				SetQueue(spellId)
			end
			return
		end

		-- CLEU: slam pause
		local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
		if sourceGUID ~= playerGUID then return end
		if not cfSwingTimer_Slam[cleuSpellId] then return end

		if subevent == "SPELL_CAST_START" then
			mainHandBar.paused = true
		elseif subevent == "SPELL_CAST_SUCCESS"
			or subevent == "SPELL_CAST_FAILED"
			or subevent == "SPELL_CAST_INTERRUPTED" then
			mainHandBar.paused = false
		end
	end)
end
