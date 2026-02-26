-- RangedSimple.lua — Minimal ranged swing timer
-- SHOOT (blue, L→R) + RELOAD (white, R→L)

local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID

local RANGED_INVENTORY_SLOT = 18

local Color = {
    SHOOT  = { 0, 0.5, 1 },
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

local function ApplyStateColor()
    if state == State.SHOOT then
        bar:SetStatusBarColor(unpack(Color.SHOOT))
    elseif state == State.RELOAD then
        bar:SetStatusBarColor(unpack(Color.RELOAD))
    end
end

-- OnUpdate
frame:SetScript("OnUpdate", function()
    local now = GetTime()
    local moving = GetUnitSpeed("player") > 0

    -- Movement resets SHOOT but not RELOAD
    if moving and state == State.SHOOT then
        ResetSwingBar("movement during SHOOT")
        return
    end
    -- Nothing to render
    if state == State.IDLE then return end

    local elapsed = now - stateStart
    local remaining = math.max(0, stateDuration - elapsed)
    if state == State.SHOOT then
        local progress = elapsed / stateDuration
        cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    elseif state == State.RELOAD then
        local progress = 1 - elapsed / stateDuration
        cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    end
    if elapsed >= stateDuration then state = State.IDLE end
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
    stateDuration = GetShootDuration(spellId)
    stateStart = GetTime()
    lastShootStateDuration = stateDuration
    state = State.SHOOT
    ApplyStateColor()
    cfSwingTimer.dbg(string.format("[cfST-S] shoot | T=%.2f spellId=%d duration=%.2f",
        GetTime(), spellId, stateDuration))
end

local function StartReload(spellId)
    stateDuration = GetReloadDuration(spellId)
    stateStart = GetTime()
    state = State.RELOAD
    ApplyStateColor()
    cfSwingTimer.dbg(string.format("[cfST-S] reload | T=%.2f duration=%.2f",
        GetTime(), stateDuration))
end

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")

frame:SetScript("OnEvent", function(self, event, unit, _, spellId)
    -- Unit events
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        if unit ~= "player" then return end
        if not cfSwingTimer_RangedShot[spellId] then return end

        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            StartReload(spellId)
        elseif event == "UNIT_SPELLCAST_FAILED" then
            ResetSwingBar(string.format("FAILED spellId=%d state=%d", spellId, state))
        elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
            cfSwingTimer.dbg(string.format("[cfST-S] FAILED_QUIET | T=%.2f spellId=%d state=%d",
                GetTime(), spellId, state))
        end
        return
    end

    -- CLEU (only for SPELL_CAST_START)
    local _, sub, _, src, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
    if src ~= playerGUID or sub ~= "SPELL_CAST_START" then return end

    if cfSwingTimer_RangedShot[cleuSpellId] then
        StartShoot(cleuSpellId)
    end
end)
