local addon = cfSwingTimer

local RANGED_SLOT = 18
local AUTO_SHOT = 75
local RETRY_DURATION = 0.5
local PUSHBACK = { 1.0, 1.8, 2.4, 2.8, 3.0 }

local Color = {
	SHOOT = addon.CLASS_COLORS.DEMONHUNTER,
	RELOAD = addon.CLASS_COLORS.PRIEST,
	RETRY = addon.CASTBAR_COLORS.FAILED,
	CAST = addon.CASTBAR_COLORS.CASTING,
}

local function GetShotTime(spellId)
	local rangedSpeed = UnitRangedDamage("player")
	local _, _, _, baseShotMs = GetSpellInfo(spellId)
	local baseShotTime = ((baseShotMs or 0) > 0 and baseShotMs or 500) / 1000
	local baseSpeed = addon.GetBaseWeaponSpeed(RANGED_SLOT)
	if not baseSpeed then return baseShotTime end
	return baseShotTime * rangedSpeed / baseSpeed
end

local function StopCast()
	addon.rangedCastStart = 0
	addon.rangedCastEnd = 0
	addon.rangedCastSpellId = 0
	addon.rangedPushbackCount = 0
	if addon.rangedCastFrame then
		addon.rangedCastFrame:Hide()
	end
end

function addon.UpdateRangedVisibility()
	if not addon.rangedInitialized then return end

	local showBase = addon.showRangedBar and addon.db[addon.KEYS.RANGED]
	local showCast = addon.showRangedBar and addon.db[addon.KEYS.RANGED] and addon.db[addon.KEYS.RANGED_CAST] and addon.rangedCastEnd > 0

	if showBase then
		addon.rangedFrame:Show()
	else
		addon.rangedFrame:Hide()
	end

	if showCast then
		addon.rangedCastFrame:Show()
	else
		addon.rangedCastFrame:Hide()
	end
end

function addon.SetupRanged()
	if addon.rangedInitialized then
		addon.UpdateRangedVisibility()
		return
	end

	local frame, bar = addon.CreateCenterBarFrame(addon.KEYS.RANGED, -120, true)
	frame:Hide()

	local castFrame, castBar = addon.CreateBarFrame(addon.KEYS.RANGED_CAST)
	castFrame:SetPoint("BOTTOM", frame, "TOP", 0, addon.BAR_SPACING)
	castFrame:Hide()

	addon.rangedFrame = frame
	addon.rangedBar = bar
	addon.rangedCastFrame = castFrame
	addon.rangedCastBar = castBar
	addon.rangedShootStart = 0
	addon.rangedShootEnd = 0
	addon.rangedReloadStart = 0
	addon.rangedReloadEnd = 0
	addon.rangedRetryEnd = 0
	addon.rangedLastShotDuration = 0
	addon.rangedCastStart = 0
	addon.rangedCastEnd = 0
	addon.rangedCastSpellId = 0
	addon.rangedPushbackCount = 0
	addon.showRangedBar = false

	frame:SetScript("OnUpdate", function()
		local now = GetTime()

		if GetUnitSpeed("player") > 0 then
			addon.rangedShootEnd = 0
		end

		if addon.rangedShootEnd > now then
			addon.HideClipZone(addon.rangedBar)
			local duration = addon.rangedShootEnd - addon.rangedShootStart
			local elapsed = now - addon.rangedShootStart
			addon.rangedBar:SetStatusBarColor(unpack(Color.SHOOT))
			addon.UpdateSwingBar(addon.rangedBar, elapsed / duration, addon.rangedShootEnd - now)
		elseif addon.rangedReloadEnd > now then
			local duration = addon.rangedReloadEnd - addon.rangedReloadStart
			local elapsed = now - addon.rangedReloadStart
			addon.rangedBar:SetStatusBarColor(unpack(Color.RELOAD))
			addon.UpdateSwingBar(addon.rangedBar, 1 - elapsed / duration, addon.rangedReloadEnd - now)
		elseif addon.rangedRetryEnd > now then
			addon.HideClipZone(addon.rangedBar)
			local progress = 1 - (addon.rangedRetryEnd - now) / RETRY_DURATION
			addon.rangedBar:SetStatusBarColor(unpack(Color.RETRY))
			addon.UpdateSwingBar(addon.rangedBar, progress, addon.rangedRetryEnd - now)
		else
			addon.HideClipZone(addon.rangedBar)
			addon.UpdateSwingBar(addon.rangedBar, 0, 0)
		end

		if addon.rangedCastEnd > 0 and addon.db[addon.KEYS.RANGED] and addon.db[addon.KEYS.RANGED_CAST] then
			local castDuration = addon.rangedCastEnd - addon.rangedCastStart
			local pb = addon.rangedPushbackCount > 0 and PUSHBACK[addon.rangedPushbackCount] or 0
			local elapsed = now - addon.rangedCastStart - math.min(pb, now - addon.rangedCastStart)
			local progress = elapsed / castDuration
			local remaining = math.max(0, castDuration - elapsed)
			addon.UpdateSwingBar(addon.rangedCastBar, progress, remaining)
			addon.rangedCastFrame:Show()
		else
			addon.rangedCastFrame:Hide()
		end
	end)

	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
	frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	frame:SetScript("OnEvent", function(_, event, ...)
		local now = GetTime()

		if event == "PLAYER_ENTERING_WORLD" then
			addon.showRangedBar = UnitRangedDamage("player") > 0
			addon.UpdateRangedVisibility()
			return
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			if (...) ~= RANGED_SLOT then return end
			addon.showRangedBar = UnitRangedDamage("player") > 0
			addon.UpdateRangedVisibility()
			return
		end

		if not addon.showRangedBar then
			addon.UpdateRangedVisibility()
			return
		end

		if event == "STOP_AUTOREPEAT_SPELL" then
			addon.rangedRetryEnd = 0
			addon.UpdateRangedVisibility()
			return
		end

		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()

			if addon.rangedCastEnd > 0 and destGUID == addon.playerGUID and addon.rangedPushbackCount < #PUSHBACK then
				if subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "ENVIRONMENTAL_DAMAGE" then
					addon.rangedPushbackCount = addon.rangedPushbackCount + 1
				end
			end

			if sourceGUID ~= addon.playerGUID or subevent ~= "SPELL_CAST_START" then return end
			if cfSwingTimer_RangedAttack[cleuSpellId] then
				addon.rangedLastShotDuration = GetShotTime(cleuSpellId)
				if addon.rangedShootEnd <= now then
					addon.rangedShootStart = now
					addon.rangedShootEnd = now + addon.rangedLastShotDuration
				end
			elseif cfSwingTimer_HunterCast[cleuSpellId] then
				local _, _, _, castTimeMs = GetSpellInfo(cleuSpellId)
				local dur = (castTimeMs and castTimeMs > 0) and (castTimeMs / 1000) or GetShotTime(cleuSpellId)
				if not dur or dur == 0 then return end
				addon.rangedShootEnd = 0
				addon.rangedRetryEnd = 0
				addon.rangedCastStart = now
				addon.rangedCastSpellId = cleuSpellId
				addon.rangedPushbackCount = (castTimeMs and castTimeMs > 0) and 0 or (#PUSHBACK + 1)
				addon.rangedCastEnd = now + dur
				addon.rangedCastBar:SetStatusBarColor(unpack(Color.CAST))
				addon.UpdateRangedVisibility()
			end
			return
		end

		local unit, _, spellId = ...
		if unit ~= "player" then return end

		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if cfSwingTimer_RangedAttack[spellId] then
				local rangedSpeed = UnitRangedDamage("player")
				local reloadTime = cfSwingTimer_RangedAutoAttack[spellId] and (rangedSpeed - addon.rangedLastShotDuration) or rangedSpeed
				addon.rangedReloadStart = now
				addon.rangedReloadEnd = now + reloadTime
				addon.rangedShootEnd = 0
				addon.SetClipFraction(addon.rangedBar, GetShotTime(AUTO_SHOT) / reloadTime)
			elseif spellId == addon.rangedCastSpellId then
				StopCast()
				addon.UpdateRangedVisibility()
			end
		elseif event == "UNIT_SPELLCAST_FAILED" then
			if cfSwingTimer_RangedAttack[spellId] then
				addon.rangedShootEnd = 0
			end
			if spellId == addon.rangedCastSpellId then
				StopCast()
				addon.UpdateRangedVisibility()
			end
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			if spellId == addon.rangedCastSpellId then
				StopCast()
				addon.UpdateRangedVisibility()
			end
		elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
			if cfSwingTimer_RangedAttack[spellId] and addon.rangedCastEnd == 0 then
				addon.rangedRetryEnd = now + RETRY_DURATION
			end
		end
	end)

	addon.rangedInitialized = true
	addon.UpdateRangedVisibility()
end

function addon.initRanged()
	addon.SetupRanged()
end
