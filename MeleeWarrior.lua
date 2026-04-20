local addon = cfSwingTimer
local initialized
local UpdateWarriorQueueState

local function CreateWarriorQueue(playerGUID)
	addon.warriorQueueFrame = CreateFrame("Frame")
	addon.warriorQueueFrame:SetScript("OnUpdate", function()
		if not addon.db[addon.KEYS.MAINHAND] then return end
		if addon.warriorQueuedSpellId then
			local name = GetSpellInfo(addon.warriorQueuedSpellId)
			if name and not IsCurrentSpell(name) then
				addon.warriorQueuedSpellId = nil
				UpdateWarriorQueueState()
			end
		end
	end)
	addon.warriorQueueFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_SPELLCAST_SENT" then
			if not addon.db[addon.KEYS.MAINHAND] then return end
			local unit, _, _, spellId = ...
			if unit == "player" and cfSwingTimer_MeleeReplacer[spellId] then
				addon.warriorQueuedSpellId = spellId
				UpdateWarriorQueueState()
			end
			return
		end

		local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
		if sourceGUID ~= playerGUID then return end
		if subevent ~= "SPELL_CAST_SUCCESS" then return end
		if not cfSwingTimer_Slam[cleuSpellId] then return end

		local now = GetTime()
		if addon.mhSwingStart > 0 and (now - addon.mhSwingStart) < addon.mhSpeed then
			addon.mhSwingStart = now
		end
	end)
	addon.warriorQueueFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	addon.warriorQueueFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
end

function UpdateWarriorQueueState()
	if not initialized or not addon.warriorQueueBar then return end

	if addon.db[addon.KEYS.MAINHAND] and addon.warriorQueuedSpellId then
		local spellId = addon.warriorQueuedSpellId
		if cfSwingTimer_HeroicStrike[spellId] then
			addon.warriorQueueBar:SetStatusBarColor(unpack(addon.CLASS_COLORS.ROGUE))
		elseif cfSwingTimer_Cleave[spellId] then
			addon.warriorQueueBar:SetStatusBarColor(unpack(addon.CLASS_COLORS.MONK))
		else
			addon.warriorQueueBar:SetStatusBarColor(unpack(addon.CLASS_COLORS.SHAMAN))
		end
	else
		addon.warriorQueuedSpellId = nil
		addon.warriorQueueBar:SetStatusBarColor(unpack(addon.CLASS_COLORS.SHAMAN))
	end
end

function addon.InitWarriorQueue()
	if select(2, UnitClass("player")) ~= "WARRIOR" then return end

	if initialized then return end

	local playerGUID = addon.playerGUID
	addon.warriorQueueBar = addon.bars[addon.KEYS.MAINHAND]
	if not addon.warriorQueueBar then return end

	CreateWarriorQueue(playerGUID)
	initialized = true
	UpdateWarriorQueueState()
end
