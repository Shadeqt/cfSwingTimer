function cfSwingTimer.initRanged()
	local M = cfSwingTimer.MODULE
	local playerGUID = cfSwingTimer.playerGUID

	local RANGED_INVENTORY_SLOT = 18

	local Color = {
		SHOOT  = cfSwingTimer.CLASS_COLORS.DEMONHUNTER,
		CAST   = cfSwingTimer.CASTBAR_COLORS.CASTING,
		RELOAD = cfSwingTimer.CLASS_COLORS.PRIEST,
		RETRY  = cfSwingTimer.CASTBAR_COLORS.FAILED,
	}

	local State = {
		IDLE = 0,
		SHOOT = 1,
		RELOAD = 2,
	}

	local state = State.IDLE
	local stateStart = 0
	local stateDuration = 0
	local lastShootDuration = 0

	-- Cast overlay (independent of state machine)
	local castStart = 0
	local castDuration = 0

	-- Retry underlay (independent of state machine, like cast overlay)
	local retryStart = 0
	local retryDuration = 0.5

	-- Frame + bar
	local frame = CreateFrame("Frame", "cfSwingTimerRangedSimple", UIParent)
	frame:SetPoint("CENTER", 0, -200)
	frame:SetSize(cfSwingTimer.BAR_WIDTH, cfSwingTimer.BAR_HEIGHT)

	local swingBar = cfSwingTimer.CreateCenterSwingBar(frame)
	swingBar:SetPoint("TOP")
	cfSwingTimer.bars[M.RANGED] = swingBar

	local function GetShootDuration(spellId)
		local rangedSpeed = UnitRangedDamage("player")
		local _, _, _, baseShootMs = GetSpellInfo(spellId)
		local baseShootTime = ((baseShootMs or 0) > 0 and baseShootMs or 500) / 1000
		local baseSpeed = cfSwingTimer.GetBaseWeaponSpeed(RANGED_INVENTORY_SLOT)
		if not baseSpeed then return baseShootTime end
		return baseShootTime * rangedSpeed / baseSpeed
	end

	-- Clip zone overlay: shows when casting would delay the next auto shot
	local clipZones = {}
	local barWidth = cfSwingTimer.BAR_WIDTH
	local barHeight = cfSwingTimer.BAR_HEIGHT

	if swingBar.isCenter then
		local left = swingBar.overlayMid:CreateTexture(nil, "OVERLAY")
		left:SetColorTexture(1, 0, 0, 0.3)
		left:SetPoint("LEFT", swingBar, "CENTER", 0, 0)
		left:Hide()
		local right = swingBar.overlayMid:CreateTexture(nil, "OVERLAY")
		right:SetColorTexture(1, 0, 0, 0.3)
		right:SetPoint("RIGHT", swingBar, "CENTER", 0, 0)
		right:Hide()
		clipZones = { left, right }
	else
		local clip = swingBar:CreateTexture(nil, "OVERLAY")
		clip:SetColorTexture(1, 0, 0, 0.3)
		clip:SetPoint("RIGHT", swingBar, "RIGHT", 0, 0)
		clip:Hide()
		clipZones = { clip }
	end

	local function HideClipZone()
		for _, tex in ipairs(clipZones) do tex:Hide() end
	end

	local function ShowClipZone(reloadDuration)
		local castDur = GetShootDuration(75)
		if not castDur or reloadDuration == 0 then
			HideClipZone()
			return
		end
		local fraction = castDur / reloadDuration
		local maxWidth = swingBar.isCenter and (barWidth / 2) or barWidth
		local clipWidth = math.min(fraction * maxWidth, maxWidth)
		for _, tex in ipairs(clipZones) do
			tex:SetSize(clipWidth, barHeight)
			tex:Show()
		end
	end

	local function ApplyStateColor()
		if state == State.SHOOT then
			swingBar:SetStatusBarColor(unpack(Color.SHOOT))
			HideClipZone()
		elseif state == State.RELOAD then
			swingBar:SetStatusBarColor(unpack(Color.RELOAD))
			ShowClipZone(stateDuration)
		else
			HideClipZone()
		end
	end

	local function ResetSwingBar()
		state = State.IDLE
		cfSwingTimer.UpdateSwingBar(swingBar, 0, 0)
		ApplyStateColor()
	end

	local function RenderRetry(now)
		if retryStart == 0 then return end
		local elapsed = now - retryStart
		if elapsed < retryDuration then
			swingBar:SetStatusBarColor(unpack(Color.RETRY))
			cfSwingTimer.UpdateSwingBar(swingBar, 1 - elapsed / retryDuration, retryDuration - elapsed)
		else
			retryStart = 0
			cfSwingTimer.UpdateSwingBar(swingBar, 0, 0)
		end
	end

	local function StopCast()
		castStart = 0
		ApplyStateColor()
	end

	-- OnUpdate
	frame:SetScript("OnUpdate", function()
		local now = GetTime()
		local isMoving = GetUnitSpeed("player") > 0
		local isCasting = UnitCastingInfo("player") ~= nil

		-- Movement resets SHOOT and casting, but not RELOAD
		if isMoving and state ~= State.RELOAD then
			if castStart > 0 then StopCast() end
			if state == State.SHOOT then ResetSwingBar() end
			RenderRetry(now)
			return
		end

		-- Cast overlay (independent of state machine)
		if castStart > 0 then
			local elapsed = now - castStart
			local remaining = castDuration - elapsed
			cfSwingTimer.UpdateSwingBar(swingBar, elapsed / castDuration, remaining)
			return
		end

		-- Nothing to render (retry shows in idle gaps)
		if state == State.IDLE then RenderRetry(now) return end

		-- Auto shot state (shoot / reload)
		local elapsed = now - stateStart
		local remaining = math.max(0, stateDuration - elapsed)
		local progress

		if state == State.SHOOT then
			progress = elapsed / stateDuration
		elseif state == State.RELOAD then
			progress = 1 - elapsed / stateDuration
		end

		if progress then
			cfSwingTimer.UpdateSwingBar(swingBar, progress, remaining)
		end
		if elapsed >= stateDuration then
			if state == State.SHOOT and isCasting then
				ResetSwingBar()
			else
				state = State.IDLE
				ApplyStateColor()
			end
		end
	end)

	local function StartShoot(spellId)
		stateDuration = GetShootDuration(spellId)
		stateStart = GetTime()
		lastShootDuration = stateDuration
		state = State.SHOOT
		ApplyStateColor()
	end

	local function StartCast(spellId)
		local _, _, _, castTimeMs = GetSpellInfo(spellId)
		castDuration = (castTimeMs and castTimeMs > 0) and (castTimeMs / 1000) or GetShootDuration(spellId)
		if not castDuration or castDuration == 0 then return end
		if state == State.SHOOT then ResetSwingBar() end
		castStart = GetTime()
		swingBar:SetStatusBarColor(unpack(Color.CAST))
		HideClipZone()
	end

	local function GetReloadDuration(spellId)
		local rangedSpeed = UnitRangedDamage("player")
		if not cfSwingTimer_RangedAutoAttack[spellId] then return rangedSpeed end
		return rangedSpeed - lastShootDuration
	end

	local function StartReload(spellId)
		stateDuration = GetReloadDuration(spellId)
		stateStart = GetTime()
		state = State.RELOAD
		ApplyStateColor()
	end

	-- Events
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
	frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")

	frame:SetScript("OnEvent", function(self, event, ...)
		-- Auto Shot toggled off
		if event == "STOP_AUTOREPEAT_SPELL" then
			retryStart = 0
			cfSwingTimer.UpdateSwingBar(swingBar, 0, 0)
			if state == State.SHOOT then ResetSwingBar() end
			return
		end

		-- CLEU (only for SPELL_CAST_START)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
			if sourceGUID ~= playerGUID or subevent ~= "SPELL_CAST_START" then return end
			if cfSwingTimer_RangedAttack[cleuSpellId] then
				StartShoot(cleuSpellId)
			elseif cfSwingTimer_HunterCast[cleuSpellId] then
				StartCast(cleuSpellId)
			end
			return
		end

		-- Unit events
		local unit, _, spellId = ...
		if unit ~= "player" then return end

		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if cfSwingTimer_RangedAttack[spellId] then
				StartReload(spellId)
			elseif cfSwingTimer_HunterCast[spellId] then
				StopCast()
			end
		elseif event == "UNIT_SPELLCAST_FAILED" then
			if cfSwingTimer_RangedAttack[spellId] then
				ResetSwingBar()
			elseif cfSwingTimer_HunterCast[spellId] then
				StopCast()
			end
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			if cfSwingTimer_HunterCast[spellId] then
				StopCast()
			end
		elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
			if cfSwingTimer_RangedAttack[spellId] then
				retryStart = GetTime()
			end
		end
	end)
end
