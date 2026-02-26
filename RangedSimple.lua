-- RangedSimple.lua — Minimal ranged swing timer
-- SHOOT (blue, L→R) + CAST (orange, L→R) + RELOAD (white, R→L)

local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID

local RANGED_INVENTORY_SLOT = 18

local Color = {
    SHOOT  = { 0, 0.5, 1 },
    CAST   = { 1, 0.7, 0 },
    RELOAD = { 1, 1, 1 },
}

local State = {
    IDLE = 0,
    SHOOT = 1,
    RELOAD = 2,
    CAST = 3,
}

local state = State.IDLE
local stateStart = 0
local stateDuration = 0
local lastShootStateDuration = 0

-- Frame + bar
local frame = CreateFrame("Frame", "cfSwingTimerRangedSimple", UIParent)
frame:SetPoint("CENTER", 0, -200)
frame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local bar = cfSwingTimer.CreateSwingBar(frame)
bar:SetPoint("TOP")

local function ResetSwingBar(reason)
    state = State.IDLE
    cfSwingTimer.UpdateSwingBar(bar, 0, 0)
    cfSwingTimer.dbg("[cfST-S] reset: " .. reason)
end

-- OnUpdate
frame:SetScript("OnUpdate", function()
    if state == State.IDLE then return end

    local elapsed = GetTime() - stateStart
    local remaining = math.max(0, stateDuration - elapsed)

    if state == State.SHOOT or state == State.CAST then
        if GetUnitSpeed("player") > 0 then
            ResetSwingBar("movement during " .. (state == State.SHOOT and "SHOOT" or "CAST"))
            return
        end
        local progress = math.min(1, elapsed / stateDuration)
        cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    elseif state == State.RELOAD then
        local progress = remaining / stateDuration
        cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    end

    if remaining <= 0 then state = State.IDLE end
end)

local function GetShootDuration(spellId)
    local speed = UnitRangedDamage("player")
    local _, _, _, baseShootMs = GetSpellInfo(spellId)
    local baseShoot = (baseShootMs or 500) / 1000
    local baseSpeed = cfSwingTimer.GetBaseWeaponSpeed(RANGED_INVENTORY_SLOT)
    if not baseSpeed then return baseShoot end
    return baseShoot * speed / baseSpeed
end

local function GetReloadDuration(spellId)
    local speed = UnitRangedDamage("player")
    if not cfSwingTimer_AutoRepeat[spellId] then return speed end
    return speed - lastShootStateDuration
end

local function StartShoot(spellId)
    stateStart = GetTime()
    stateDuration = GetShootDuration(spellId)
    lastShootStateDuration = stateDuration
    state = State.SHOOT
    bar:SetStatusBarColor(unpack(Color.SHOOT))
    cfSwingTimer.dbg(string.format("[cfST-S] shoot | T=%.2f spellId=%d duration=%.2f",
        GetTime(), spellId, stateDuration))
end

local function StartCast(spellId)
    local _, _, _, castTimeMs = GetSpellInfo(spellId)
    if not castTimeMs or castTimeMs == 0 then return end
    stateStart = GetTime()
    stateDuration = castTimeMs / 1000
    state = State.CAST
    bar:SetStatusBarColor(unpack(Color.CAST))
    cfSwingTimer.dbg(string.format("[cfST-S] cast | T=%.2f spellId=%d duration=%.2f",
        GetTime(), spellId, stateDuration))
end

local function StartReload(spellId)
    stateStart = GetTime()
    stateDuration = GetReloadDuration(spellId)
    state = State.RELOAD
    bar:SetStatusBarColor(unpack(Color.RELOAD))
    cfSwingTimer.dbg(string.format("[cfST-S] reload | T=%.2f duration=%.2f",
        GetTime(), stateDuration))
end

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")

frame:SetScript("OnEvent", function(self, event, unit, _, spellId)
    if event == "UNIT_SPELLCAST_FAILED" and unit == "player" then
        if cfSwingTimer_RangedShot[spellId] then
            ResetSwingBar(string.format("FAILED spellId=%d state=%d", spellId, state))
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED_QUIET" and unit == "player" then
        if cfSwingTimer_RangedShot[spellId] then
            cfSwingTimer.dbg(string.format("[cfST-S] FAILED_QUIET | T=%.2f spellId=%d state=%d",
                GetTime(), spellId, state))
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        if cfSwingTimer_RangedShot[spellId] then
            StartReload(spellId)
        end
        return
    end

    local _, sub, _, src, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
    if src ~= playerGUID then return end

    if sub == "SPELL_CAST_START" then
        if cfSwingTimer_RangedShot[cleuSpellId] then
            StartShoot(cleuSpellId)
        elseif cfSwingTimer_HunterCast[cleuSpellId] then
            StartCast(cleuSpellId)
        end
    elseif cfSwingTimer_HunterCast[cleuSpellId] then
        if sub == "SPELL_CAST_SUCCESS"
            or sub == "SPELL_CAST_FAILED"
            or sub == "SPELL_CAST_INTERRUPTED" then
            ResetSwingBar("cast end: " .. sub)
        end
    end
end)
