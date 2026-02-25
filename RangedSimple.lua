-- RangedSimple.lua — Minimal ranged swing timer
-- SHOOT (blue, fills L→R) + RELOAD (orange, empties R→L)

local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID

local SHOOT_COLOR = { 0, 0.5, 1 }
local RELOAD_COLOR = { 1, 0.7, 0 }
local SHOOT_TIME = 0.5
local WEAPON_SPEED = 2.6

local State = {
    IDLE = 0,
    SHOOT = 1,
    RELOAD = 2,
}

local state = State.IDLE
local stateStart = 0
local stateDuration = 0

-- Frame + bar
local frame = CreateFrame("Frame", "cfSwingTimerRangedSimple", UIParent)
frame:SetPoint("CENTER", 0, -200)
frame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local bar = cfSwingTimer.CreateSwingBar(frame)
bar:SetPoint("TOP")

-- OnUpdate
frame:SetScript("OnUpdate", function()
    if state == State.IDLE then return end

    local elapsed = GetTime() - stateStart
    local remaining = math.max(0, stateDuration - elapsed)

    local progress
    if state == State.SHOOT then
        progress = math.min(1, elapsed / stateDuration)
    else
        progress = remaining / stateDuration
    end

    cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    if remaining <= 0 then state = State.IDLE end
end)

local function StartReload()
    stateStart = GetTime()
    stateDuration = WEAPON_SPEED - SHOOT_TIME
    state = State.RELOAD
    bar:SetStatusBarColor(unpack(RELOAD_COLOR))
end

local function StartShoot()
    stateStart = GetTime()
    stateDuration = SHOOT_TIME
    state = State.SHOOT
    bar:SetStatusBarColor(unpack(SHOOT_COLOR))
end

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", function(self, event, unit, _, spellId)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        if cfSwingTimer_RangedShot[spellId] then
            StartReload()
        end
        return
    end

    local _, sub, _, src, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
    if src ~= playerGUID then return end

    if cfSwingTimer_RangedShot[cleuSpellId] and sub == "SPELL_CAST_START" then
        StartShoot()
    end
end)
