local addon = cfSwingTimer

local SWING_DAMAGE_OFFHAND_INDEX = 21
local SWING_MISSED_OFFHAND_INDEX = 13
local EXTRA_ATTACKS_AMOUNT_INDEX = 15

local function UpdateBar(bar, swingStart, speed, now)
	if speed == 0 or swingStart == 0 then return end
	local elapsed = now - swingStart
	if elapsed >= speed then
		addon.UpdateSwingBar(bar, 0, 0)
		return true
	end
	local progress = elapsed / speed
	local remaining = speed - elapsed
	addon.UpdateSwingBar(bar, progress, remaining)
end

local function StartSwing(isOffHand, now)
	if isOffHand then
		addon.offHandSwingStart = now
	elseif addon.extraAttacks > 0 then
		addon.extraAttacks = addon.extraAttacks - 1
	else
		addon.mhSwingStart = now
	end
end

function addon.InitMeleeWeaponSpeeds()
	local mh, oh = UnitAttackSpeed("player")
	addon.mhSpeed = mh or 0
	addon.offHandSpeed = oh or 0
	addon.UpdateMeleeVisibility()
end

function addon.UpdateMeleeVisibility()
	if not addon.meleeInitialized then return end

	if addon.db[addon.KEYS.MAINHAND] then
		addon.mainHandBar:Show()
	else
		addon.mainHandBar:Hide()
	end

	if addon.db[addon.KEYS.OFFHAND] and addon.offHandSpeed > 0 then
		addon.offHandBar:Show()
	else
		addon.offHandBar:Hide()
	end
end

function addon.EnableMelee()
	if addon.meleeInitialized then
		addon.UpdateMeleeVisibility()
		return
	end

	local mhFrame, mhBar = addon.CreateBarFrame(addon.KEYS.MAINHAND, -150)
	mhBar:SetStatusBarColor(unpack(addon.CLASS_COLORS.SHAMAN))

	local ohFrame, ohBar = addon.CreateBarFrame(addon.KEYS.OFFHAND)
	ohFrame:SetPoint("TOP", mhFrame, "BOTTOM", 0, -addon.BAR_SPACING)
	ohBar:SetStatusBarColor(unpack(addon.CLASS_COLORS.MAGE))
	ohBar:Hide()

	addon.mainHandFrame = mhFrame
	addon.mainHandBar = mhBar
	addon.offHandFrame = ohFrame
	addon.offHandBar = ohBar
	addon.mhSwingStart = 0
	addon.offHandSwingStart = 0
	addon.mhSpeed = 0
	addon.offHandSpeed = 0
	addon.extraAttacks = 0

	mhFrame:SetScript("OnUpdate", function()
		local now = GetTime()
		if UpdateBar(addon.mainHandBar, addon.mhSwingStart, addon.mhSpeed, now) then
			addon.mhSwingStart = 0
		end
		if UpdateBar(addon.offHandBar, addon.offHandSwingStart, addon.offHandSpeed, now) then
			addon.offHandSwingStart = 0
		end
	end)

	mhFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	mhFrame:RegisterEvent("UNIT_ATTACK_SPEED")
	mhFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	mhFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
	mhFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
	mhFrame:SetScript("OnEvent", function(_, event, unit)
		local now = GetTime()

		if event == "PLAYER_ENTERING_WORLD" then
			addon.InitMeleeWeaponSpeeds()
			return
		elseif event == "UNIT_ATTACK_SPEED" then
			if unit == "player" then addon.InitMeleeWeaponSpeeds() end
			return
		elseif event == "PLAYER_ENTER_COMBAT" then
			if addon.offHandSwingStart > 0 and addon.offHandSpeed > 0 then
				local halfSpeed = addon.offHandSpeed / 2
				local remaining = addon.offHandSpeed - (now - addon.offHandSwingStart)
				if remaining < halfSpeed then
					addon.offHandSwingStart = now - halfSpeed
				end
			end
			return
		elseif event == "PLAYER_LEAVE_COMBAT" then
			return
		end

		local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellIdOrMissType = CombatLogGetCurrentEventInfo()
		if sourceGUID ~= addon.playerGUID then return end

		if subevent == "SWING_DAMAGE" then
			StartSwing(select(SWING_DAMAGE_OFFHAND_INDEX, CombatLogGetCurrentEventInfo()), now)
		elseif subevent == "SWING_MISSED" then
			StartSwing(select(SWING_MISSED_OFFHAND_INDEX, CombatLogGetCurrentEventInfo()), now)
		elseif subevent == "SPELL_EXTRA_ATTACKS" then
			addon.extraAttacks = addon.extraAttacks + select(EXTRA_ATTACKS_AMOUNT_INDEX, CombatLogGetCurrentEventInfo())
		elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
			if cfSwingTimer_MeleeReplacer[spellIdOrMissType] then
				StartSwing(false, now)
			end
		end

		if destGUID == addon.playerGUID and subevent == "SWING_MISSED" and spellIdOrMissType == "PARRY" and addon.mhSwingStart > 0 then
			local parryReduction = addon.mhSpeed * 0.4
			local parryFloor = addon.mhSpeed * 0.2
			local elapsed = now - addon.mhSwingStart
			local elapsedAfterParry = elapsed + parryReduction
			local elapsedCap = addon.mhSpeed - parryFloor
			addon.mhSwingStart = now - math.min(elapsedAfterParry, elapsedCap)
		end
	end)

	addon.meleeInitialized = true

	if addon.db[addon.KEYS.PALADIN_TWIST] then
		addon.InitPaladinTwist()
	end
	if addon.db[addon.KEYS.WARRIOR_QUEUE] then
		addon.InitWarriorQueue()
	end
	if addon.db[addon.KEYS.SHAMAN_HALF] then
		addon.InitShamanHalf()
	end

	addon.UpdateMeleeVisibility()
end

function addon.initMelee()
	addon.EnableMelee()
end
