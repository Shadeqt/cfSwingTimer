function cfSwingTimer.initRanged()
	local MODULE = cfSwingTimer.MODULE
	local playerGUID = cfSwingTimer.playerGUID

	local RANGED_SLOT = 18
	local AUTO_SHOT = 75
	local RETRY_DURATION = 0.5

	local State = {
		RETRY  = -1,
		IDLE   = 0,
		RELOAD = 1,
		SHOOT  = 2,
		CAST   = 3,
	}

	local StateColor = {
		[State.SHOOT]  = cfSwingTimer.CLASS_COLORS.DEMONHUNTER,
		[State.CAST]   = cfSwingTimer.CASTBAR_COLORS.CASTING,
		[State.RELOAD] = cfSwingTimer.CLASS_COLORS.PRIEST,
		[State.RETRY]  = cfSwingTimer.CASTBAR_COLORS.FAILED,
	}

-- State
	local state = State.IDLE
	local stateStart = 0
	local stateDuration = 0
	local lastShotDuration = 0
	local reloadStart = 0
	local reloadDuration = 0
	local retryEnd = 0

	-- Frame + bar
	local frame, bar = cfSwingTimer.CreateCenterBarFrame(MODULE.RANGED, -200)

	local function GetShotTime(spellId)
		local rangedSpeed = UnitRangedDamage("player")
		local _, _, _, baseShotMs = GetSpellInfo(spellId)
		local baseShotTime = ((baseShotMs or 0) > 0 and baseShotMs or 500) / 1000
		local baseSpeed = cfSwingTimer.GetBaseWeaponSpeed(RANGED_SLOT)
		if not baseSpeed then return baseShotTime end
		return baseShotTime * rangedSpeed / baseSpeed
	end

	-- Clip zone overlay: shows when casting would delay the next auto shot
	local clipZones = {}
	local clipZoneWidth = 0
	local barWidth = cfSwingTimer.BAR_WIDTH
	local barHeight = cfSwingTimer.BAR_HEIGHT

	if bar.isCenter then
		local left = bar.overlayMid:CreateTexture(nil, "OVERLAY")
		left:SetColorTexture(1, 0, 0, 0.3)
		left:SetPoint("LEFT", bar, "CENTER", 0, 0)
		left:Hide()
		local right = bar.overlayMid:CreateTexture(nil, "OVERLAY")
		right:SetColorTexture(1, 0, 0, 0.3)
		right:SetPoint("RIGHT", bar, "CENTER", 0, 0)
		right:Hide()
		clipZones = { left, right }
	else
		local clip = bar:CreateTexture(nil, "OVERLAY")
		clip:SetColorTexture(1, 0, 0, 0.3)
		clip:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
		clip:Hide()
		clipZones = { clip }
	end

	local function UpdateClipZone()
		if state == State.RELOAD and stateDuration > 0 then
			local castDur = GetShotTime(AUTO_SHOT)
			if castDur then
				local fraction = castDur / stateDuration
				local maxWidth = bar.isCenter and (barWidth / 2) or barWidth
				clipZoneWidth = math.min(fraction * maxWidth, maxWidth)
			else
				clipZoneWidth = 0
			end
			for _, tex in ipairs(clipZones) do
				tex:SetSize(clipZoneWidth, barHeight)
				tex:Show()
			end
		else
			for _, tex in ipairs(clipZones) do tex:Hide() end
		end
	end

	local function SetState(newState, duration)
		if newState == State.CAST and state == State.RELOAD then
			reloadStart = stateStart
			reloadDuration = stateDuration
		else
			reloadStart = 0
			reloadDuration = 0
		end

		state = newState
		stateStart = GetTime()
		stateDuration = duration or 0
		UpdateClipZone()
	end

	local function StopCast(now)
		if state ~= State.CAST then return end
		if reloadStart > 0 and now < reloadStart + reloadDuration then
			state = State.RELOAD
			stateStart = reloadStart
			stateDuration = reloadDuration
			reloadStart = 0
			reloadDuration = 0
			UpdateClipZone()
		else
			SetState(State.IDLE, 0)
		end
	end

	local function InterruptState(now)
		if state == State.CAST then
			StopCast(now)
		else
			SetState(State.IDLE, 0)
		end
	end

	-- OnUpdate
	frame:SetScript("OnUpdate", function()
		local now = GetTime()
		local isMoving = GetUnitSpeed("player") > 0

		-- Transition: movement resets SHOOT and CAST, but not RELOAD
		if isMoving and (state == State.SHOOT or state == State.CAST) then
			print(string.format("[cfSwing] OnUpdate INTERRUPT by movement state=%d elapsed=%.3f", state, now - stateStart))
			InterruptState(now)
		end

		-- Transition: state expired
		if state ~= State.IDLE and (now - stateStart) >= stateDuration then
			print(string.format("[cfSwing] OnUpdate INTERRUPT by expiry state=%d elapsed=%.3f dur=%.3f", state, now - stateStart, stateDuration))
			InterruptState(now)
		end

		-- Render: idle + retry
		if state == State.IDLE then
			if retryEnd > now then
				local retryElapsed = RETRY_DURATION - (retryEnd - now)
				local progress = 1 - retryElapsed / RETRY_DURATION
				bar:SetStatusBarColor(unpack(StateColor[State.RETRY]))
				cfSwingTimer.UpdateSwingBar(bar, progress, retryEnd - now)
			else
				cfSwingTimer.UpdateSwingBar(bar, 0, 0)
			end

		-- Render: active states (SHOOT, RELOAD, CAST)
		else
			local elapsed = now - stateStart
			local remaining = math.max(0, stateDuration - elapsed)
			local progress = elapsed / stateDuration
			if state == State.RELOAD then
				progress = 1 - progress
			end
			bar:SetStatusBarColor(unpack(StateColor[state]))
			cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
		end
	end)

	-- Events
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
	frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")

	frame:SetScript("OnEvent", function(self, event, ...)
		local now = GetTime()

		if event == "STOP_AUTOREPEAT_SPELL" then
			retryEnd = 0
			SetState(State.IDLE, 0)
			return
		end

		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
			if sourceGUID ~= playerGUID or subevent ~= "SPELL_CAST_START" then return end
			print(string.format("[cfSwing] SPELL_CAST_START spellId=%d state=%d elapsed=%.3f", cleuSpellId, state, now - stateStart))
			if cfSwingTimer_RangedAttack[cleuSpellId] then
				if state == State.SHOOT then
					print(string.format("[cfSwing] WARNING: double SHOOT start (already in SHOOT, %.3fs in of %.3fs)", now - stateStart, stateDuration))
				end
				lastShotDuration = GetShotTime(cleuSpellId)
				SetState(State.SHOOT, lastShotDuration)
			elseif cfSwingTimer_HunterCast[cleuSpellId] then
				local _, _, _, castTimeMs = GetSpellInfo(cleuSpellId)
				local dur = (castTimeMs and castTimeMs > 0) and (castTimeMs / 1000) or GetShotTime(cleuSpellId)
				if not dur or dur == 0 then return end
				SetState(State.CAST, dur)
			end
			return
		end

		local unit, _, spellId = ...
		if unit ~= "player" then return end

		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if cfSwingTimer_RangedAttack[spellId] then
				local rangedSpeed = UnitRangedDamage("player")
				local reloadTime = cfSwingTimer_RangedAutoAttack[spellId] and (rangedSpeed - lastShotDuration) or rangedSpeed
				SetState(State.RELOAD, reloadTime)
			elseif cfSwingTimer_HunterCast[spellId] then
				StopCast(now)
			end
		elseif event == "UNIT_SPELLCAST_FAILED" then
			print(string.format("[cfSwing] SPELLCAST_FAILED spellId=%d state=%d elapsed=%.3f", spellId, state, now - stateStart))
			if cfSwingTimer_RangedAttack[spellId] then
				SetState(State.IDLE, 0)
			elseif cfSwingTimer_HunterCast[spellId] then
				StopCast(now)
			end
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			print(string.format("[cfSwing] SPELLCAST_INTERRUPTED spellId=%d state=%d elapsed=%.3f", spellId, state, now - stateStart))
			if cfSwingTimer_HunterCast[spellId] then
				StopCast(now)
			end
		elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
			print(string.format("[cfSwing] SPELLCAST_FAILED_QUIET spellId=%d state=%d elapsed=%.3f", spellId, state, now - stateStart))
			if cfSwingTimer_RangedAttack[spellId] then
				retryEnd = now + RETRY_DURATION
			end
		end
	end)
end
