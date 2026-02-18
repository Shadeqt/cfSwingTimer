local BAR_W, BAR_H = 195, 13
local TWIST_WINDOW = 0.4
local GCD = 1.5
local extraAttacks = 0
local slamCasting = false

local function CreateSwingBar(parent, speed)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.7, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.timer = 0
    bar.speed = speed

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetSize(32, 32)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)

    bar.border = bar:CreateTexture(nil, "OVERLAY")
    bar.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
    bar.border:SetSize(256, 64)
    bar.border:SetPoint("TOP", bar, "TOP", 0, 26)

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont("Fonts\\FRIZQT__.ttf", 11)
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    return bar
end

local function CreateTwistMarkers(bar)
    if select(2, UnitClass("player")) ~= "PALADIN" then return end

    bar.twistMarker = bar:CreateTexture(nil, "OVERLAY")
    bar.twistMarker:SetColorTexture(1, 0.996, 0.722, 1)
    bar.twistMarker:SetSize(2, BAR_H)

    bar.gcdMarker = bar:CreateTexture(nil, "OVERLAY")
    bar.gcdMarker:SetColorTexture(1, 0, 0, 0.8)
    bar.gcdMarker:SetSize(2, BAR_H)
end

-- Anchor
local frame = CreateFrame("Frame", "cfSwingTimerFrame", UIParent)
frame:SetPoint("CENTER", 0, -200)
frame:SetSize(BAR_W, BAR_H)

local mhBar = CreateSwingBar(frame, 2)
mhBar:SetPoint("TOP")
CreateTwistMarkers(mhBar)

local ohBar = CreateSwingBar(frame, 0)
ohBar:SetPoint("TOP", mhBar, "BOTTOM", 0, -20)
ohBar:Hide()

local function UpdateTwistMarkers(bar)
    local twistPos = (1 - TWIST_WINDOW / bar.speed) * BAR_W
    bar.twistMarker:ClearAllPoints()
    bar.twistMarker:SetPoint("CENTER", bar, "LEFT", twistPos, 0)

    local gcdPos = (1 - (TWIST_WINDOW + GCD) / bar.speed) * BAR_W
    if gcdPos > 0 then
        bar.gcdMarker:ClearAllPoints()
        bar.gcdMarker:SetPoint("CENTER", bar, "LEFT", gcdPos, 0)
        bar.gcdMarker:Show()
    else
        bar.gcdMarker:Hide()
    end
end

local function UpdateBar(bar, elapsed)
    if bar.timer > 0 then bar.timer = math.max(0, bar.timer - elapsed) end
    local pct = 1 - bar.timer / bar.speed
    bar:SetValue(pct)
    if bar.timer > 0 then
        bar.spark:Show()
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", pct * BAR_W, 0)
    else
        bar.spark:Hide()
    end
    bar.text:SetText(string.format("%.1f", bar.timer))
    if bar.twistMarker then UpdateTwistMarkers(bar) end
end

local function ResetSwingTimer(bar)
    if extraAttacks > 0 then
        extraAttacks = extraAttacks - 1
    else
        bar.timer = bar.speed
    end
end

local function HandleSwing(ohPos)
    local isOff = select(ohPos, CombatLogGetCurrentEventInfo())
    ResetSwingTimer(isOff and ohBar or mhBar)
end

local function HandleAbilitySwing()
    local spellId = select(12, CombatLogGetCurrentEventInfo())
    if cfSwingTimer_SwingReset[spellId] then
        ResetSwingTimer(mhBar)
    end
end

local function HandleWeaponSwap()
    local s1, s2 = UnitAttackSpeed("player")
    local newMH = s1 or 2
    local newOH = s2 or 0
    if newMH ~= mhBar.speed and mhBar.timer > 0 then mhBar.timer = newMH end
    if newOH ~= ohBar.speed and ohBar.timer > 0 then ohBar.timer = newOH end
end

local function HandleExtraAttacks()
    local amount = select(15, CombatLogGetCurrentEventInfo())
    extraAttacks = extraAttacks + amount
end

local function ScaleBar(bar, newSpeed)
    if newSpeed ~= bar.speed and bar.timer > 0 then
        bar.timer = bar.timer * (newSpeed / bar.speed)
    end
    bar.speed = newSpeed
end

local function HandleHaste()
    local s1, s2 = UnitAttackSpeed("player")
    ScaleBar(mhBar, s1 or 2)
    ScaleBar(ohBar, s2 or 0)
end

local function HandleSlamCast(casting)
    local spellId = select(12, CombatLogGetCurrentEventInfo())
    if cfSwingTimer_SlamPause[spellId] then
        slamCasting = casting
    end
end

local function HandleParryHaste()
    local missType = select(12, CombatLogGetCurrentEventInfo())
    if missType == "PARRY" then
        local reduction = mhBar.speed * 0.4
        local floor = mhBar.speed * 0.2
        mhBar.timer = math.max(floor, mhBar.timer - reduction)
    end
end

-- OnUpdate
frame:SetScript("OnUpdate", function(self, elapsed)
    HandleHaste()

    UpdateBar(mhBar, slamCasting and 0 or elapsed)
    if ohBar.speed > 0 then
        ohBar:Show()
        UpdateBar(ohBar, elapsed)
    else
        ohBar:Hide()
    end
end)

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "UNIT_INVENTORY_CHANGED" then
        HandleWeaponSwap()
        return
    end

    local _, sub, _, srcGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")

    if srcGUID == playerGUID then
        if sub == "SPELL_EXTRA_ATTACKS" then
            HandleExtraAttacks()
        -- isOffHand is at position 21 in SWING_DAMAGE
        elseif sub == "SWING_DAMAGE" then
            HandleSwing(21)
        -- isOffHand is at position 13 in SWING_MISSED
        elseif sub == "SWING_MISSED" then
            HandleSwing(13)
        elseif sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED" then
            HandleAbilitySwing()
        elseif sub == "SPELL_CAST_START" then
            HandleSlamCast(true)
        elseif sub == "SPELL_CAST_SUCCESS"
            or sub == "SPELL_CAST_FAILED"
            or sub == "SPELL_CAST_INTERRUPTED" then
            HandleSlamCast(false)
        end
    end

    if destGUID == playerGUID and (sub == "SWING_MISSED" or sub == "SPELL_MISSED") then
        HandleParryHaste()
    end
end)
