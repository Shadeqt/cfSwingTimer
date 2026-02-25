local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID
local TWIST_WINDOW = 0.4
local GCD = 1.5
local extraAttacks = 0
local slamCasting = false

local function CreateTwistMarkers(bar)
    if select(2, UnitClass("player")) ~= "PALADIN" then return end

    bar.twistMarker = bar:CreateTexture(nil, "OVERLAY")
    bar.twistMarker:SetColorTexture(1, 0.996, 0.722, 1)
    bar.twistMarker:SetSize(2, BAR_HEIGHT)

    bar.gcdMarker = bar:CreateTexture(nil, "OVERLAY")
    bar.gcdMarker:SetColorTexture(1, 0, 0, 0.8)
    bar.gcdMarker:SetSize(2, BAR_HEIGHT)
end

-- Anchor
local frame = CreateFrame("Frame", "cfSwingTimerFrame", UIParent)
frame:SetPoint("CENTER", 0, -150)
frame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local mhBar = cfSwingTimer.CreateSwingBar(frame, 2)
mhBar:SetPoint("TOP")
CreateTwistMarkers(mhBar)

local ohBar = cfSwingTimer.CreateSwingBar(frame)
ohBar:SetPoint("CENTER", UIParent, "CENTER", 0, -175)
ohBar:Hide()

local function UpdateTwistMarkers(bar)
    local twistPos = (1 - TWIST_WINDOW / bar.speed) * BAR_WIDTH
    bar.twistMarker:ClearAllPoints()
    bar.twistMarker:SetPoint("CENTER", bar, "LEFT", twistPos, 0)

    local gcdPos = (1 - (TWIST_WINDOW + GCD) / bar.speed) * BAR_WIDTH
    if gcdPos > 0 then
        bar.gcdMarker:ClearAllPoints()
        bar.gcdMarker:SetPoint("CENTER", bar, "LEFT", gcdPos, 0)
        bar.gcdMarker:Show()
    else
        bar.gcdMarker:Hide()
    end
end

local function ResetSwingTimer(bar)
    if extraAttacks > 0 then
        extraAttacks = extraAttacks - 1
    else
        bar.timer = bar.speed
    end
end

local function ScaleBar(bar, newSpeed)
    if newSpeed ~= bar.speed and bar.timer > 0 then
        bar.timer = bar.timer * (newSpeed / bar.speed)
    end
    bar.speed = newSpeed
end

-- OnUpdate
local function updateMelee(bar, dt)
    if bar.speed == 0 then return end
    bar.timer = math.max(0, bar.timer - dt)
    local progress = bar.timer > 0 
        and (1 - bar.timer / bar.speed) 
        or 0
    cfSwingTimer.UpdateSwingBar(bar, progress, bar.timer)
end

frame:SetScript("OnUpdate", function(self, elapsed)
    updateMelee(mhBar, slamCasting and 0 or elapsed)
    updateMelee(ohBar, elapsed)
end)

local function InitSpeeds()
    local s1, s2 = UnitAttackSpeed("player")
    ScaleBar(mhBar, s1 or 2)
    ScaleBar(ohBar, s2 or 0)
    if mhBar.twistMarker then UpdateTwistMarkers(mhBar) end
    if s2 then ohBar:Show() else ohBar:Hide() end
end

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_ATTACK_SPEED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        InitSpeeds()
        return
    end

    if event == "UNIT_ATTACK_SPEED" then
        if unit == "player" then InitSpeeds() end
        return
    end

    local _, sub, _, srcGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    if srcGUID == playerGUID then
        if sub == "SPELL_EXTRA_ATTACKS" then
            extraAttacks = extraAttacks + select(15, CombatLogGetCurrentEventInfo())
        elseif sub == "SWING_DAMAGE" then
            local isOff = select(21, CombatLogGetCurrentEventInfo())
            ResetSwingTimer(isOff and ohBar or mhBar)
        elseif sub == "SWING_MISSED" then
            local isOff = select(13, CombatLogGetCurrentEventInfo())
            ResetSwingTimer(isOff and ohBar or mhBar)
        elseif sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED" then
            if cfSwingTimer_SwingReset[spellId] then ResetSwingTimer(mhBar) end
        elseif sub == "SPELL_CAST_START" then
            if cfSwingTimer_SlamPause[spellId] then slamCasting = true end
        elseif sub == "SPELL_CAST_SUCCESS"
            or sub == "SPELL_CAST_FAILED"
            or sub == "SPELL_CAST_INTERRUPTED" then
            if cfSwingTimer_SlamPause[spellId] then slamCasting = false end
        end
    end

    -- pos 12 is missType for SWING_MISSED (spellId for SPELL_* events)
    if destGUID == playerGUID and sub == "SWING_MISSED" and spellId == "PARRY" then
        local reduction = mhBar.speed * 0.4
        local floor = mhBar.speed * 0.2
        mhBar.timer = math.max(floor, mhBar.timer - reduction)
    end
end)
