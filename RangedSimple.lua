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
}

local state = State.IDLE
local stateStart = 0
local stateDuration = 0
local lastShootDuration = 0

-- Cast overlay (independent of state machine)
local castStart = 0
local castDuration = 0

-- Frame + bar
local frame = CreateFrame("Frame", "cfSwingTimerRangedSimple", UIParent)
frame:SetPoint("CENTER", 0, -200)
frame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local swingBar = cfSwingTimer.CreateSwingBar(frame)
swingBar:SetPoint("TOP")

local function ResetSwingBar(reason)
    state = State.IDLE
    cfSwingTimer.UpdateSwingBar(swingBar, 0, 0)
    cfSwingTimer.dbg("[cfST-S] reset: " .. reason)
end

local function ApplyStateColor()
    if state == State.SHOOT then
        swingBar:SetStatusBarColor(unpack(Color.SHOOT))
    elseif state == State.RELOAD then
        swingBar:SetStatusBarColor(unpack(Color.RELOAD))
    end
end

local function StopCast(reason)
    castStart = 0
    ApplyStateColor()
    cfSwingTimer.dbg("[cfST-S] cast end: " .. reason)
end

-- OnUpdate
frame:SetScript("OnUpdate", function()
    local now = GetTime()
    local isMoving = GetUnitSpeed("player") > 0

    -- Movement resets SHOOT and casting, but not RELOAD
    if isMoving and state ~= State.RELOAD then
        if castStart > 0 then StopCast("movement") end
        if state == State.SHOOT then ResetSwingBar("movement during SHOOT") end
        return
    end
    -- Nothing to render
    if state == State.IDLE then return end

    -- Cast overlay (independent of state machine)
    if castStart > 0 then
        local elapsed = now - castStart
        local remaining = castDuration - elapsed
        cfSwingTimer.UpdateSwingBar(swingBar, elapsed / castDuration, remaining)
        return
    end

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
    if elapsed >= stateDuration then state = State.IDLE end
end)

local function StartCast(spellId)
    local _, _, _, castTimeMs = GetSpellInfo(spellId)
    if not castTimeMs or castTimeMs == 0 then return end
    if state == State.SHOOT then ResetSwingBar("cast interrupts shoot") end
    castDuration = castTimeMs / 1000
    castStart = GetTime()
    swingBar:SetStatusBarColor(unpack(Color.CAST))
    cfSwingTimer.dbg(("[cfST-S] cast | T=%.2f id=%d dur=%.2f"):format(GetTime(), spellId, castDuration))
end

local function GetShootDuration(spellId)
    local rangedSpeed = UnitRangedDamage("player")
    local _, _, _, baseShootMs = GetSpellInfo(spellId)
    local baseShootTime = (baseShootMs or 500) / 1000
    local baseSpeed = cfSwingTimer.GetBaseWeaponSpeed(RANGED_INVENTORY_SLOT)
    if not baseSpeed then return baseShootTime end
    return baseShootTime * rangedSpeed / baseSpeed
end

local function StartShoot(spellId)
    stateDuration = GetShootDuration(spellId)
    stateStart = GetTime()
    lastShootDuration = stateDuration
    state = State.SHOOT
    ApplyStateColor()
    cfSwingTimer.dbg(("[cfST-S] shoot | T=%.2f id=%d dur=%.2f"):format(GetTime(), spellId, stateDuration))
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
    cfSwingTimer.dbg(("[cfST-S] reload | T=%.2f dur=%.2f"):format(GetTime(), stateDuration))
end

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

frame:SetScript("OnEvent", function(self, event, unit, _, spellId)
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
    if unit ~= "player" then return end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if cfSwingTimer_RangedAttack[spellId] then
            StartReload(spellId)
        elseif cfSwingTimer_HunterCast[spellId] then
            StopCast(event)
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if cfSwingTimer_RangedAttack[spellId] then
            ResetSwingBar(("FAILED spellId=%d state=%d"):format(spellId, state))
        elseif cfSwingTimer_HunterCast[spellId] then
            StopCast(event)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if cfSwingTimer_HunterCast[spellId] then
            StopCast(event)
        end
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        if cfSwingTimer_RangedAttack[spellId] then
            cfSwingTimer.dbg(("[cfST-S] FAILED_QUIET | T=%.2f id=%d state=%d"):format(GetTime(), spellId, state))
        end
    end
end)
