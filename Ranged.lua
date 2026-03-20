function cfSwingTimer.initRanged()
	local MODULE = cfSwingTimer.MODULE
	local playerGUID = cfSwingTimer.playerGUID

	local RANGED_SLOT = 18
	local AUTO_SHOT = 75
	local RETRY_DURATION = 0.5
	local PUSHBACK = { 1.0, 1.8, 2.4, 2.8, 3.0 }

	local Color = {
		SHOOT  = cfSwingTimer.CLASS_COLORS.DEMONHUNTER,
		RELOAD = cfSwingTimer.CLASS_COLORS.PRIEST,
		RETRY  = cfSwingTimer.CASTBAR_COLORS.FAILED,
		CAST   = cfSwingTimer.CASTBAR_COLORS.CASTING,
	}

	-- Timers
	local shootStart = 0
	local shootEnd = 0
	local reloadStart = 0
	local reloadEnd = 0
	local retryEnd = 0
	local lastShotDuration = 0

	-- Cast state
	local castStart = 0
	local castEnd = 0
	local castSpellId = 0
	local pushbackCount = 0

	local showRangedBar = false

	-- Frame + bar
	local frame, bar = cfSwingTimer.CreateCenterBarFrame(MODULE.RANGED, -120, true)
	frame:Hide()

	-- Cast bar (anchored above swing bar)
	local castFrame, castBar = cfSwingTimer.CreateBarFrame(MODULE.RANGED_CAST)
	castFrame:SetPoint("BOTTOM", frame, "TOP", 0, cfSwingTimer.BAR_SPACING)
	castFrame:Hide()

	-- OnUpdate
	frame:SetScript("OnUpdate", function()
		local now = GetTime()

		-- Movement cancels shot cast, not reload
		if GetUnitSpeed("player") > 0 then
			shootEnd = 0
		end

		-- Shooting: cast in progress
		if shootEnd > now then
			cfSwingTimer.HideClipZone(bar)
			local duration = shootEnd - shootStart
			local elapsed = now - shootStart
			local progress = elapsed / duration
			bar:SetStatusBarColor(unpack(Color.SHOOT))
			cfSwingTimer.UpdateSwingBar(bar, progress, shootEnd - now)

		-- Reloading: countdown to next auto-shot
		elseif reloadEnd > now then
			local duration = reloadEnd - reloadStart
			local elapsed = now - reloadStart
			local progress = 1 - elapsed / duration
			bar:SetStatusBarColor(unpack(Color.RELOAD))
			cfSwingTimer.UpdateSwingBar(bar, progress, reloadEnd - now)

		-- Retrying: brief delay before next attempt
		elseif retryEnd > now then
			cfSwingTimer.HideClipZone(bar)
			local progress = 1 - (retryEnd - now) / RETRY_DURATION
			bar:SetStatusBarColor(unpack(Color.RETRY))
			cfSwingTimer.UpdateSwingBar(bar, progress, retryEnd - now)

		-- Idle: no active timer
		else
			cfSwingTimer.HideClipZone(bar)
			cfSwingTimer.UpdateSwingBar(bar, 0, 0)
		end

		-- Render: cast bar
		if castEnd > 0 then
			local castDuration = castEnd - castStart
			local pb = pushbackCount > 0 and PUSHBACK[pushbackCount] or 0
			local elapsed = now - castStart - math.min(pb, now - castStart)
			local progress = elapsed / castDuration
			local remaining = math.max(0, castDuration - elapsed)
			cfSwingTimer.UpdateSwingBar(castBar, progress, remaining)
		end
	end)

	local function GetShotTime(spellId)
		local rangedSpeed = UnitRangedDamage("player")
		local _, _, _, baseShotMs = GetSpellInfo(spellId)
		local baseShotTime = ((baseShotMs or 0) > 0 and baseShotMs or 500) / 1000
		local baseSpeed = cfSwingTimer.GetBaseWeaponSpeed(RANGED_SLOT)
		if not baseSpeed then return baseShotTime end
		return baseShotTime * rangedSpeed / baseSpeed
	end

	local function StopCast()
		castStart = 0
		castEnd = 0
		castSpellId = 0
		pushbackCount = 0
		castFrame:Hide()
	end

	-- Events
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
	frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

	frame:SetScript("OnEvent", function(self, event, ...)
		local now = GetTime()

		-- Update visibility on login/reload
		if event == "PLAYER_ENTERING_WORLD" then
			showRangedBar = UnitRangedDamage("player") > 0
			if showRangedBar then frame:Show() else frame:Hide(); castFrame:Hide() end
			return
		-- Update visibility on ranged weapon change
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			if (...) ~= RANGED_SLOT then return end
			showRangedBar = UnitRangedDamage("player") > 0
			if showRangedBar then frame:Show() else frame:Hide(); castFrame:Hide() end
			return
		end

		-- No ranged weapon equipped, skip all processing
		if not showRangedBar then return end

		-- Auto-shot stopped, clear retry state
		if event == "STOP_AUTOREPEAT_SPELL" then
			retryEnd = 0
			return
		end

		-- Combat log: track shots, casts, and pushback
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()

			-- Pushback: damage taken while casting
			if castEnd > 0 and destGUID == playerGUID and pushbackCount < #PUSHBACK then
				if subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "ENVIRONMENTAL_DAMAGE" then
					pushbackCount = pushbackCount + 1
				end
			end

			-- Only process our own cast starts
			if sourceGUID ~= playerGUID or subevent ~= "SPELL_CAST_START" then return end
			-- Ranged auto-attack: start shot timer
			if cfSwingTimer_RangedAttack[cleuSpellId] then
				lastShotDuration = GetShotTime(cleuSpellId)
				if shootEnd <= now then
					shootStart = now
					shootEnd = now + lastShotDuration
				end
			-- Hunter cast: start cast bar
			elseif cfSwingTimer_HunterCast[cleuSpellId] then
				local _, _, _, castTimeMs = GetSpellInfo(cleuSpellId)
				local dur = (castTimeMs and castTimeMs > 0) and (castTimeMs / 1000) or GetShotTime(cleuSpellId)
				if not dur or dur == 0 then return end
				shootEnd = 0
				retryEnd = 0
				castStart = now
				castSpellId = cleuSpellId
				pushbackCount = (castTimeMs and castTimeMs > 0) and 0 or (#PUSHBACK + 1)
				castEnd = now + dur
				castBar:SetStatusBarColor(unpack(Color.CAST))
				castFrame:Show()
			end
			return
		end

		-- Spellcast events: only process player casts
		local unit, _, spellId = ...
		if unit ~= "player" then return end

		-- Cast succeeded: start reload timer or finish cast
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if cfSwingTimer_RangedAttack[spellId] then
				local rangedSpeed = UnitRangedDamage("player")
				local reloadTime = cfSwingTimer_RangedAutoAttack[spellId] and (rangedSpeed - lastShotDuration) or rangedSpeed
				reloadStart = now
				reloadEnd = now + reloadTime
				shootEnd = 0
				cfSwingTimer.SetClipFraction(bar, GetShotTime(AUTO_SHOT) / reloadTime)
			elseif spellId == castSpellId then
				StopCast()
			end
		-- Cast failed: clear shot timer and/or cast state
		elseif event == "UNIT_SPELLCAST_FAILED" then
			if cfSwingTimer_RangedAttack[spellId] then
				shootEnd = 0
			end
			if spellId == castSpellId then
				StopCast()
			end
		-- Cast interrupted: clear cast state
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			if spellId == castSpellId then
				StopCast()
			end
		-- Failed quietly: start retry window
		elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
			if cfSwingTimer_RangedAttack[spellId] and castEnd == 0 then
				retryEnd = now + RETRY_DURATION
			end
		end
	end)
end
