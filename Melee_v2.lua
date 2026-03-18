function cfSwingTimer.initMelee()
	local MODULE = cfSwingTimer.MODULE
	local playerGUID = cfSwingTimer.playerGUID

	-- Frame + bars
	local mhFrame, mhBar = cfSwingTimer.CreateBarFrame(MODULE.MAINHAND, -150)
	mhBar:SetStatusBarColor(unpack(cfSwingTimer.CLASS_COLORS.SHAMAN))

	local ohFrame, ohBar = cfSwingTimer.CreateBarFrame(MODULE.OFFHAND, -175)
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

	mhFrame:SetScript("OnEvent", function(self, event, unit)
		if event == "PLAYER_ENTERING_WORLD" then
			InitWeaponSpeeds()
			return
		elseif event == "UNIT_ATTACK_SPEED" then
			if unit == "player" then InitWeaponSpeeds() end
			return
		end

		local now = GetTime()
		local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
		if sourceGUID ~= playerGUID then return end

		if subevent == "SWING_DAMAGE" then
			local swingDamageOffHandIndex = 21
			local isOffHand = select(swingDamageOffHandIndex, CombatLogGetCurrentEventInfo())
			StartSwing(isOffHand, now)
		elseif subevent == "SWING_MISSED" then
			local swingMissedOffHandIndex = 13
			local isOffHand = select(swingMissedOffHandIndex, CombatLogGetCurrentEventInfo())
			StartSwing(isOffHand, now)
		elseif subevent == "SPELL_EXTRA_ATTACKS" then
			local extraAttacksIndex = 15
			local amount = select(extraAttacksIndex, CombatLogGetCurrentEventInfo())
			extraAttacks = extraAttacks + amount
		elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
			if cfSwingTimer_MeleeReplacer[spellId] then StartSwing(false, now) end
		end

		if destGUID == playerGUID and subevent == "SWING_MISSED" and spellId == "PARRY" then
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
