local SWING_DAMAGE_OFFHAND_INDEX = 21
local SWING_MISSED_OFFHAND_INDEX = 13
local EXTRA_ATTACKS_AMOUNT_INDEX = 15

function cfSwingTimer.initMelee()
	local MODULE = cfSwingTimer.MODULE
	local playerGUID = cfSwingTimer.playerGUID

	-- Frame + bars
	local mhFrame, mhBar = cfSwingTimer.CreateBarFrame(MODULE.MAINHAND, -150)
	mhBar:SetStatusBarColor(unpack(cfSwingTimer.CLASS_COLORS.SHAMAN))

	local ohFrame, ohBar = cfSwingTimer.CreateBarFrame(MODULE.OFFHAND)
	ohFrame:SetPoint("TOP", mhFrame, "BOTTOM", 0, -cfSwingTimer.BAR_SPACING)
	ohBar:SetStatusBarColor(unpack(cfSwingTimer.CLASS_COLORS.MAGE))
	ohBar:Hide()

	-- Swing state
	local mhSwingStart = 0
	local ohSwingStart = 0
	local mhSpeed = 0
	local ohSpeed = 0
	local extraAttacks = 0

	local function UpdateBar(bar, swingStart, speed, now)
		if speed == 0 or swingStart == 0 then return end
		local elapsed = now - swingStart
		if elapsed >= speed then
			cfSwingTimer.UpdateSwingBar(bar, 0, 0)
			return true
		end
		local progress = elapsed / speed
		local remaining = speed - elapsed
		cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
	end

	mhFrame:SetScript("OnUpdate", function()
		local now = GetTime()
		if UpdateBar(mhBar, mhSwingStart, mhSpeed, now) then mhSwingStart = 0 end
		if UpdateBar(ohBar, ohSwingStart, ohSpeed, now) then ohSwingStart = 0 end
	end)

	local function InitWeaponSpeeds()
		local mh, oh = UnitAttackSpeed("player")
		mhSpeed = mh or 0
		ohSpeed = oh or 0
		if ohSpeed > 0 then ohBar:Show() else ohBar:Hide() end
	end

	local function StartSwing(isOffHand, now)
		if isOffHand then
			ohSwingStart = now
		elseif extraAttacks > 0 then
			extraAttacks = extraAttacks - 1
		else
			mhSwingStart = now
		end
	end

	-- Events
	mhFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	mhFrame:RegisterEvent("UNIT_ATTACK_SPEED")
	mhFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	mhFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
	mhFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")

	mhFrame:SetScript("OnEvent", function(self, event, unit)
		local now = GetTime()

		-- Initialize weapon speeds on login/reload
		if event == "PLAYER_ENTERING_WORLD" then
			InitWeaponSpeeds()
			return
		-- Update weapon speeds when attack speed changes
		elseif event == "UNIT_ATTACK_SPEED" then
			if unit == "player" then InitWeaponSpeeds() end
			return
		-- Auto-attack toggled on: push OH back to half-speed if past halfway
		elseif event == "PLAYER_ENTER_COMBAT" then
			if ohSwingStart > 0 and ohSpeed > 0 then
				local halfSpeed = ohSpeed / 2
				local remaining = ohSpeed - (now - ohSwingStart)
				if remaining < halfSpeed then
					ohSwingStart = now - halfSpeed
				end
			end
			return
		-- Auto-attack toggled off: no action needed
		elseif event == "PLAYER_LEAVE_COMBAT" then return
		end

		local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellIdOrMissType = CombatLogGetCurrentEventInfo()
		-- Only process our own combat events
		if sourceGUID ~= playerGUID then return end

		-- Melee hit landed: start new swing
		if subevent == "SWING_DAMAGE" then
			local isOffHand = select(SWING_DAMAGE_OFFHAND_INDEX, CombatLogGetCurrentEventInfo())
			StartSwing(isOffHand, now)
		-- Melee swing missed: start new swing
		elseif subevent == "SWING_MISSED" then
			local isOffHand = select(SWING_MISSED_OFFHAND_INDEX, CombatLogGetCurrentEventInfo())
			StartSwing(isOffHand, now)
		-- Extra attacks (e.g. Windfury): queue them
		elseif subevent == "SPELL_EXTRA_ATTACKS" then
			local amount = select(EXTRA_ATTACKS_AMOUNT_INDEX, CombatLogGetCurrentEventInfo())
			extraAttacks = extraAttacks + amount
		-- Spell replaces melee swing (e.g. Heroic Strike)
		elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
			if cfSwingTimer_MeleeReplacer[spellIdOrMissType] then StartSwing(false, now) end
		end

		-- Parry haste: enemy parried, accelerate our main-hand swing
		if destGUID == playerGUID and subevent == "SWING_MISSED" and spellIdOrMissType == "PARRY" then
			if mhSwingStart > 0 then
				local parryReduction = mhSpeed * 0.4
				local parryFloor = mhSpeed * 0.2
				local elapsed = now - mhSwingStart
				local elapsedAfterParry = elapsed + parryReduction
				local elapsedCap = mhSpeed - parryFloor
				local newElapsed = math.min(elapsedAfterParry, elapsedCap)
				mhSwingStart = now - newElapsed
			end
		end
	end)
end
