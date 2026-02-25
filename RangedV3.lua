-- RangedV3.lua — Event-driven ranged swing timer
-- Priority display: CAST > RELOAD > failure (background timer)
-- State machine: IDLE → CAST → RELOAD. Failure is independent.

local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID

local CAST_COLOR = { 0, 0.5, 1 }
local RELOAD_COLOR = { 1, 0.7, 0 }
local FAIL_COLOR = { 1, 0, 0 }
local FAIL_INTERVAL = 0.5

-- State: IDLE, CAST, RELOAD
local state = "IDLE"
local phaseStart = 0
local phaseDuration = 0
local lastCastTime = 0

-- Background failure timer (independent of state)
local failStart = 0
local failDuration = 0

-- Debug log colors
local BLUE   = "|cff4488ff"
local GREEN  = "|cff44ff44"
local RED    = "|cffff4444"
local YELLOW = "|cffffff44"
local GRAY   = "|cff888888"
local function log(color, msg)
    local late = GetTime() - phaseStart - phaseDuration
    print(color .. msg .. string.format(" | late=%.3f", late) .. "|r")
end

local isActive = false
local pendingStop = false
local hunterCasting = false
local failCastLogged = false
local targetSwapped = false
local stoppedDuringReload = false

-- Tooltip scanner for base (unhasted) weapon speed
local scanner = CreateFrame("GameTooltip", "cfScanTipV3", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
local baseSpeedCache = {}

local function GetBaseRangedSpeed()
    local id = GetInventoryItemID("player", 18)
    if not id then return nil end
    if baseSpeedCache[id] then return baseSpeedCache[id] end
    scanner:ClearLines()
    scanner:SetInventoryItem("player", 18)
    for i = 2, scanner:NumLines() do
        local text = _G["cfScanTipV3TextRight" .. i]:GetText()
        if text then
            local speed = text:match("Speed (%d+%.%d+)")
            if speed then
                baseSpeedCache[id] = tonumber(speed)
                return baseSpeedCache[id]
            end
        end
    end
end

local function GetHastedCastTime(hastedSpeed)
    local _, _, _, baseCastMs = GetSpellInfo(75) -- Auto Shot
    local baseCast = baseCastMs / 1000
    local baseSpeed = GetBaseRangedSpeed()
    if not baseSpeed then return baseCast end
    return baseCast * (hastedSpeed / baseSpeed)
end

-- Frame + bar
local frame = CreateFrame("Frame", "cfSwingTimerRangedV3", UIParent)
frame:SetPoint("CENTER", 0, -200)
frame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local bar = cfSwingTimer.CreateSwingBar(frame)
bar:SetPoint("TOP")

-- State helpers
local function SetState(newState, duration, color)
    state = newState
    phaseStart = GetTime()
    phaseDuration = duration
    bar:SetStatusBarColor(unpack(color))
end

local function GoIdle()
    state = "IDLE"
    phaseDuration = 0
    bar:SetValue(0)
    bar.spark:Hide()
    bar.text:SetText("")
end

-- OnUpdate: priority display (CAST > RELOAD > failure)
frame:SetScript("OnUpdate", function(self, dt)
    -- Safety: moving during cast interrupts it
    if state == "CAST" and GetUnitSpeed("player") > 0 then
        log(RED, string.format("[V3] moving during CAST | T=%.2f", GetTime()))
        state = "IDLE"
        failStart = GetTime()
        failDuration = FAIL_INTERVAL
    end

    local now = GetTime()

    -- Priority 1: CAST (blue, fills left to right)
    if state == "CAST" then
        local elapsed = now - phaseStart
        local remaining = math.max(0, phaseDuration - elapsed)
        if remaining > 0 then
            local progress = math.min(1, elapsed / phaseDuration)
            bar:SetStatusBarColor(unpack(CAST_COLOR))
            bar:SetValue(progress)
            bar.spark:Show()
            bar.spark:ClearAllPoints()
            bar.spark:SetPoint("CENTER", bar, "LEFT", progress * BAR_WIDTH, 0)
            bar.text:SetText(string.format("%.1f", remaining))
        else
            bar:SetStatusBarColor(unpack(CAST_COLOR))
            bar:SetValue(1)
            bar.spark:Hide()
            bar.text:SetText("")
        end
        return
    end

    -- Priority 2: RELOAD (orange, empties right to left)
    if state == "RELOAD" then
        local remaining = phaseDuration - (now - phaseStart)
        if remaining > 0 then
            local progress = remaining / phaseDuration
            bar:SetStatusBarColor(unpack(RELOAD_COLOR))
            bar:SetValue(progress)
            bar.spark:Show()
            bar.spark:ClearAllPoints()
            bar.spark:SetPoint("CENTER", bar, "LEFT", progress * BAR_WIDTH, 0)
            bar.text:SetText(string.format("%.1f", remaining))
            return
        end
        -- RELOAD expired
        if pendingStop then
            log(GRAY, string.format("[V3] STOP commit | T=%.2f state=%s -> IDLE", now, state))
            pendingStop = false
            isActive = false
            GoIdle()
            return
        end
    end

    -- Priority 3: Failure timer (red, empties right to left)
    local failRemaining = failDuration - (now - failStart)
    if failRemaining > 0 then
        -- Hide during player casts (looting, skinning, etc.)
        if not hunterCasting then
            local castName = UnitCastingInfo("player")
            if castName then
                if not failCastLogged then
                    log(GRAY, string.format("[V3] fail hidden (casting: %s) | T=%.2f", castName, now))
                    failCastLogged = true
                end
                bar:SetValue(0)
                bar.spark:Hide()
                bar.text:SetText("")
                return
            end
        end
        failCastLogged = false
        local progress = failRemaining / failDuration
        bar:SetStatusBarColor(unpack(FAIL_COLOR))
        bar:SetValue(progress)
        bar.spark:Show()
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", progress * BAR_WIDTH, 0)
        bar.text:SetText(string.format("%.1f", failRemaining))
        return
    end
    failCastLogged = false

    -- Nothing active
    bar:SetValue(0)
    bar.spark:Hide()
    bar.text:SetText("")
    if pendingStop then
        log(GRAY, string.format("[V3] STOP commit | T=%.2f state=%s -> IDLE", now, state))
        pendingStop = false
        isActive = false
        GoIdle()
    end
end)

-- Events
frame:RegisterEvent("START_AUTOREPEAT_SPELL")
frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("MIRROR_TIMER_STOP")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

frame:SetScript("OnEvent", function(self, event, unit, _, spellId)
    if event == "PLAYER_TARGET_CHANGED" then
        if state == "RELOAD" then targetSwapped = true end
        return
    end

    if event == "MIRROR_TIMER_STOP" and unit == "FEIGNDEATH" then
        local speed = UnitRangedDamage("player")
        log(GRAY, string.format("[V3] FD_END | T=%.2f state=%s -> RELOAD %.2f", GetTime(), state, speed))
        SetState("RELOAD", speed, RELOAD_COLOR)
        stoppedDuringReload = false
        return
    end

    if event == "START_AUTOREPEAT_SPELL" then
        log(GRAY, string.format("[V3] START_AUTOREPEAT | T=%.2f state=%s", GetTime(), state))
        isActive = true
        pendingStop = false
        return
    end

    if event == "STOP_AUTOREPEAT_SPELL" then
        log(GRAY, string.format("[V3] STOP_AUTOREPEAT | T=%.2f state=%s", GetTime(), state))
        if state == "IDLE" then
            isActive = false
        else
            pendingStop = true
            if state == "RELOAD" then
                stoppedDuringReload = true
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        if cfSwingTimer_RangedShot[spellId] then
            local speed = UnitRangedDamage("player")
            local castTime = GetHastedCastTime(speed)
            lastCastTime = castTime
            local reload = speed - castTime
            log(GREEN, string.format("[V3] SUCCEEDED | T=%.2f spell=%d state=%s -> RELOAD %.2f (speed=%.2f cast=%.2f)",
                GetTime(), spellId, state, reload, speed, castTime))
            SetState("RELOAD", reload, RELOAD_COLOR)
        elseif spellId == 5384 then
            stoppedDuringReload = false
            local speed = UnitRangedDamage("player")
            local reloadElapsed = state == "RELOAD" and (GetTime() - phaseStart) or 0
            local fdReload = reloadElapsed + speed + FAIL_INTERVAL
            log(GREEN, string.format("[V3] SUCCEEDED (FD) | T=%.2f state=%s -> RELOAD %.2f (elapsed=%.2f speed=%.2f)", GetTime(), state, fdReload, reloadElapsed, speed))
            if state == "RELOAD" then
                SetState("RELOAD", fdReload, RELOAD_COLOR)
            end
        end
        return
    end

    if (event == "UNIT_SPELLCAST_FAILED_QUIET" or event == "UNIT_SPELLCAST_FAILED") and unit == "player" then
        local tag = event == "UNIT_SPELLCAST_FAILED_QUIET" and "FAILED_QUIET" or "FAILED"
        if cfSwingTimer_RangedShot[spellId] and isActive and not hunterCasting then
            if event == "UNIT_SPELLCAST_FAILED" and state == "CAST" then
                state = "IDLE"
            end
            local failRunning = (GetTime() - failStart) < failDuration
            if not failRunning then
                failStart = GetTime()
                failDuration = FAIL_INTERVAL
            end
            local remaining = phaseDuration - (GetTime() - phaseStart)
            local moving = GetUnitSpeed("player") > 0
            log(YELLOW, string.format("[V3] %s | T=%.2f spell=%d state=%s remain=%.2f move=%s swap=%s stop=%s",
                tag, GetTime(), spellId, state, remaining, tostring(moving), tostring(targetSwapped), tostring(stoppedDuringReload)))
        end
        if cfSwingTimer_HunterCast[spellId] then
            log(GRAY, string.format("[V3] %s (hunter cast) | T=%.2f spell=%d", tag, GetTime(), spellId))
            hunterCasting = false
        end
        return
    end

    -- CLEU
    local _, sub, _, src, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()

    -- Feign Death CLEU events (debug: log all, before src filter)
    if cleuSpellId == 5384 then
        log(GRAY, string.format("[V3] FD_CLEU | T=%.2f sub=%s src_is_player=%s state=%s", GetTime(), sub, tostring(src == playerGUID), state))
    end

    if src ~= playerGUID then return end

    -- Auto shot cast started (server confirmed)
    if cfSwingTimer_RangedShot[cleuSpellId] and sub == "SPELL_CAST_START" then
        if state == "CAST" then
            local remaining = phaseDuration - (GetTime() - phaseStart)
            local moving = GetUnitSpeed("player") > 0
            log(YELLOW, string.format("[V3] CLEU CAST_START (dup) | T=%.2f spell=%d remain=%.2f move=%s (ignored)",
                GetTime(), cleuSpellId, remaining, tostring(moving)))
            return
        end
        local speed = UnitRangedDamage("player")
        local castTime = GetHastedCastTime(speed)
        lastCastTime = castTime
        log(BLUE, string.format("[V3] CLEU CAST_START | T=%.2f spell=%d state=%s -> CAST %.2f",
            GetTime(), cleuSpellId, state, castTime))
        log(GRAY, string.format("[V3] DEBUG cast: base=0.50 hastedSpeed=%.2f baseSpeed=%.1f", speed, GetBaseRangedSpeed() or 0))
        targetSwapped = false
        stoppedDuringReload = false
        SetState("CAST", castTime, CAST_COLOR)
        return
    end

    -- Hunter casts block auto shot (Aimed, Multi, Steady)
    if cfSwingTimer_HunterCast[cleuSpellId] then
        if sub == "SPELL_CAST_START" then
            log(GRAY, string.format("[V3] HUNTER_CAST | T=%.2f spell=%d (%s)",
                GetTime(), cleuSpellId, cfSwingTimer_HunterCast[cleuSpellId]))
            hunterCasting = true
        elseif sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_FAILED" then
            log(GRAY, string.format("[V3] HUNTER_END | T=%.2f spell=%d sub=%s",
                GetTime(), cleuSpellId, sub))
            hunterCasting = false
        end
    end
end)
