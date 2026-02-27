local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID
local extraAttacks = 0

-- Frame + bars
local frame = CreateFrame("Frame", "cfSwingTimerFrame", UIParent)
frame:SetPoint("CENTER", 0, -150)
frame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local mainHandBar = cfSwingTimer.CreateSwingBar(frame, 2)
mainHandBar:SetPoint("TOP")

local offHandBar = cfSwingTimer.CreateSwingBar(frame)
offHandBar:SetPoint("CENTER", UIParent, "CENTER", 0, -175)
offHandBar:Hide()

-- Expose for class files
cfSwingTimer.mainHandBar = mainHandBar
cfSwingTimer.offHandBar = offHandBar

local function ResetSwingTimer(bar)
    if extraAttacks > 0 then
        extraAttacks = extraAttacks - 1
        cfSwingTimer.dbg(("[cfST-M] extra | left=%d"):format(extraAttacks))
    else
        bar.timer = bar.speed
        cfSwingTimer.dbg(("[cfST-M] reset | speed=%.2f"):format(bar.speed))
    end
end

local function RescaleTimer(bar, newSpeed)
    if newSpeed ~= bar.speed and bar.timer > 0 then
        local oldTimer = bar.timer
        bar.timer = bar.timer * (newSpeed / bar.speed)
        cfSwingTimer.dbg(("[cfST-M] scale | %.2f>%.2f timer=%.2f>%.2f"):format(bar.speed, newSpeed, oldTimer, bar.timer))
    end
    bar.speed = newSpeed
end

-- OnUpdate
frame:SetScript("OnUpdate", function(self, elapsed)
    cfSwingTimer.UpdateBar(mainHandBar, mainHandBar.paused and 0 or elapsed)
    cfSwingTimer.UpdateBar(offHandBar, elapsed)
end)

local function InitWeaponSpeeds()
    local mhSpeed, ohSpeed = UnitAttackSpeed("player")
    cfSwingTimer.dbg(("[cfST-M] InitWeaponSpeeds | mh=%.2f oh=%s"):format(
        mhSpeed or 0, ohSpeed and ("%.2f"):format(ohSpeed) or "none"))
    RescaleTimer(mainHandBar, mhSpeed or 2)
    RescaleTimer(offHandBar, ohSpeed or 0)
    if ohSpeed then offHandBar:Show() else offHandBar:Hide() end
end

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_ATTACK_SPEED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        InitWeaponSpeeds()
        return
    end

    if event == "UNIT_ATTACK_SPEED" then
        if unit == "player" then InitWeaponSpeeds() end
        return
    end

    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGUID == playerGUID then
        if subevent == "SPELL_EXTRA_ATTACKS" then
            local extraAttacksAmount = 15
            local extraAmount = select(extraAttacksAmount, CombatLogGetCurrentEventInfo())
            extraAttacks = extraAttacks + extraAmount
        elseif subevent == "SWING_DAMAGE" then
            local swingDamageIsOffHand = 21
            local isOffHand = select(swingDamageIsOffHand, CombatLogGetCurrentEventInfo())
            ResetSwingTimer(isOffHand and offHandBar or mainHandBar)
        elseif subevent == "SWING_MISSED" then
            local swingMissedIsOffHand = 13
            local isOffHand = select(swingMissedIsOffHand, CombatLogGetCurrentEventInfo())
            ResetSwingTimer(isOffHand and offHandBar or mainHandBar)
        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
            if cfSwingTimer_MeleeReplacer[spellId] then ResetSwingTimer(mainHandBar) end
        end
    end

    -- spellId is missType for SWING_MISSED
    if destGUID == playerGUID and subevent == "SWING_MISSED" and spellId == "PARRY" and mainHandBar.timer > 0 then
        local parryReduction = mainHandBar.speed * 0.4
        local parryFloor = mainHandBar.speed * 0.2
        local oldTimer = mainHandBar.timer
        mainHandBar.timer = math.max(parryFloor, mainHandBar.timer - parryReduction)
        cfSwingTimer.dbg(("[cfST-M] parry | timer=%.2f>%.2f"):format(oldTimer, mainHandBar.timer))
    end
end)
