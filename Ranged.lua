local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local playerGUID = cfSwingTimer.playerGUID
local CAST_PHASE_COLOR = { 0, 0.5, 1 }
local COOLDOWN_PHASE_COLOR = { 1, 0.7, 0 }
local RETRY_INTERVAL = 0.5
local isCastPhase = false
local isAutoShotActive = false
local lastCastTime = 0
local phaseStartTime = 0
local phaseDuration = 0
local debugResetTime = nil
local debugPredicted = nil
local debugReason = nil
local lastTargetSwapTime = 0
local cleuConfirmed = false
local autoShotStopTime = 0
local lastAutoFailedTime = 0
local waitForCleu = false
local hunterCastSpellId = nil
-- Tooltip scanner: only way to get base (unhasted) weapon speed in Classic
local tooltipScanner = CreateFrame("GameTooltip", "cfScanTip", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local baseWeaponSpeedCache = {}

local function GetBaseRangedSpeed()
    local weaponId = GetInventoryItemID("player", 18)
    if baseWeaponSpeedCache[weaponId] then return baseWeaponSpeedCache[weaponId] end
    tooltipScanner:ClearLines()
    tooltipScanner:SetInventoryItem("player", 18)
    for i = 2, tooltipScanner:NumLines() do
        local text = _G["cfScanTipTextRight" .. i]:GetText()
        if text then
            local speedText = text:match("Speed (%d+%.%d+)")
            if speedText then
                baseWeaponSpeedCache[weaponId] = tonumber(speedText)
                return baseWeaponSpeedCache[weaponId]
            end
        end
    end
end

-- Anchor
local rangedFrame = CreateFrame("Frame", "cfSwingTimerRangedFrame", UIParent)
rangedFrame:SetPoint("CENTER", 0, -200)
rangedFrame:SetSize(BAR_WIDTH, BAR_HEIGHT)

local rangedBar = cfSwingTimer.CreateSwingBar(rangedFrame)
rangedBar:SetPoint("TOP")

-- GetSpellInfo gives base cast, scale by haste ratio (hastedSpeed / baseSpeed)
local function GetHastedCastTime(spellId, speed)
    local _, _, _, baseCastMs = GetSpellInfo(spellId)
    local baseCast = baseCastMs / 1000
    local baseSpeed = GetBaseRangedSpeed()
    return baseSpeed and (baseCast * speed / baseSpeed) or baseCast
end

local function StartCastPhase(spellId)
    local speed = UnitRangedDamage("player")
    local castTime = GetHastedCastTime(spellId, speed)
    lastCastTime = castTime
    phaseStartTime = GetTime()
    phaseDuration = castTime
    isCastPhase = true
    cleuConfirmed = false
    rangedBar:SetStatusBarColor(unpack(CAST_PHASE_COLOR))
    print(string.format("[cfST] cast phase | T=%.2f castTime=%.2f cooldown=%.2f",
        GetTime(), castTime, speed - castTime))
end

local function StartCooldownPhase()
    local speed = UnitRangedDamage("player")
    local cooldown = speed - lastCastTime
    phaseStartTime = GetTime()
    phaseDuration = cooldown
    isCastPhase = false
    cleuConfirmed = false
    rangedBar:SetStatusBarColor(unpack(COOLDOWN_PHASE_COLOR))
    print(string.format("[cfST] cooldown phase | T=%.2f duration=%.2f",
        GetTime(), cooldown))
end

-- Auto Shot retries every 0.5s when it can't fire (moving, out of range)
local function StartRetryPhase(reason)
    print(string.format("[cfST] retry(%s) | T=%.2f", reason or "?", GetTime()))
    phaseStartTime = GetTime()
    phaseDuration = RETRY_INTERVAL
    isCastPhase = false
    cleuConfirmed = false
    rangedBar:SetStatusBarColor(unpack(COOLDOWN_PHASE_COLOR))
end

local function ResetBarToIdle()
    print(string.format("[cfST] reset idle | T=%.2f", GetTime()))
    phaseDuration = 0
    rangedBar:SetValue(0)
    rangedBar.spark:Hide()
    rangedBar.text:SetText("")
    isCastPhase = false
    cleuConfirmed = false
end

-- FD and target swap reset the server's auto-shot cycle.
-- Hypothesis: server discards elapsed reload progress and starts a fresh full cycle.
-- duration = elapsed + speed  (where elapsed = speed - remaining)
local function StartResetCooldown(reason)
    local speed = UnitRangedDamage("player")
    local remaining = math.max(0, phaseDuration - (GetTime() - phaseStartTime))
    local elapsed = speed - remaining
    local duration = elapsed + speed + RETRY_INTERVAL
    local phase = isCastPhase and "cast" or "reload"
    phaseStartTime = GetTime()
    phaseDuration = duration
    isCastPhase = false
    rangedBar:SetStatusBarColor(unpack(COOLDOWN_PHASE_COLOR))
    print(string.format("[cfST] %s | T=%.2f phase=%s speed=%.2f remaining=%.2f elapsed=%.2f -> bar=%.2f",
        reason, GetTime(), phase, speed, remaining, elapsed, duration))
    debugResetTime = GetTime()
    debugPredicted = duration
    debugReason = reason
end

-- OnUpdate
rangedFrame:SetScript("OnUpdate", function(self, dt)
    -- Commit a pending auto-shot stop if START_AUTOREPEAT didn't follow within 0.5s
    if autoShotStopTime > 0 and GetTime() - autoShotStopTime > 0.5 then
        local stopTime = autoShotStopTime
        autoShotStopTime = 0
        isAutoShotActive = false
        -- Only reset if cast started before the STOP event (not from reload expiry during debounce)
        if isCastPhase and not cleuConfirmed and phaseStartTime <= stopTime then
            ResetBarToIdle()
        end
    end

    if phaseDuration <= 0 then return end

    -- Get casting state once, reuse below
    local isHunterCasting = hunterCastSpellId ~= nil
    local isPlayerBusy = false
    do
        local _, _, _, _, _, _, _, _, castSpellId = UnitCastingInfo("player")
        if castSpellId and not cfSwingTimer_RangedShot[castSpellId] and not cfSwingTimer_HunterCast[castSpellId] then
            isPlayerBusy = true
        elseif UnitChannelInfo("player") then
            isPlayerBusy = true
        end
    end

    if isCastPhase then
        if isPlayerBusy then
            ResetBarToIdle()
            return
        end
        if GetUnitSpeed("player") > 0 then
            if isAutoShotActive then
                StartRetryPhase("moving-cast")
            else
                ResetBarToIdle()
                return
            end
        end
    end

    local elapsed = GetTime() - phaseStartTime
    local remaining = math.max(0, phaseDuration - elapsed)
    local progress = isCastPhase and math.min(1, elapsed / phaseDuration) or remaining / phaseDuration
    rangedBar:SetValue(progress)

    if remaining > 0 then
        rangedBar.spark:Show()
        rangedBar.spark:ClearAllPoints()
        rangedBar.spark:SetPoint("CENTER", rangedBar, "LEFT", progress * BAR_WIDTH, 0)
        rangedBar.text:SetText(string.format("%.1f", remaining))
    else
        rangedBar.spark:Hide()
        if isCastPhase then
            rangedBar:SetStatusBarColor(unpack(COOLDOWN_PHASE_COLOR))
            rangedBar:SetValue(1)  -- wait for SUCCEEDED; orange signals cast done, projectile in flight
            rangedBar.text:SetText("")
        elseif isAutoShotActive or (GetTime() - lastAutoFailedTime < 1.0) then
            if isHunterCasting then
                rangedBar:SetValue(0)       -- blocked by hunter cast, hold at "ready"
                rangedBar.text:SetText("")
            elseif isPlayerBusy then
                phaseDuration = 0           -- non-combat cast (bandage, etc.), go idle
                rangedBar:SetValue(0)
                rangedBar.text:SetText("")
            elseif GetUnitSpeed("player") == 0 then
                if not waitForCleu and UnitExists("target") and not UnitIsDeadOrGhost("target") then
                    print(string.format("[cfST] cast start (OnUpdate) | T=%.2f", GetTime()))
                    StartCastPhase(75)
                else
                    phaseDuration = 0
                    rangedBar:SetValue(0)
                    rangedBar.text:SetText("")
                end
            else
                StartRetryPhase("moving-reload")
            end
        else
            -- isAutoShotActive=false and no recent FAILEDs; CLEU will start cast or FAILED will reset
            phaseDuration = 0
            rangedBar:SetValue(0)
            rangedBar.text:SetText("")
        end
    end
end)

local function GetFailedReason()
    if GetUnitSpeed("player") > 0 then return "moving" end
    if not UnitExists("target") then return "no-target" end
    if UnitIsDeadOrGhost("target") then return "dead-target" end
    if GetTime() - lastTargetSwapTime < 2.0 then return "target-swap" end
    return "other"
end

-- Events
rangedFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
rangedFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
rangedFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
rangedFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
rangedFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
rangedFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
rangedFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
rangedFrame:SetScript("OnEvent", function(self, event, unit, _, eventSpellId)
    if event == "START_AUTOREPEAT_SPELL" then
        isAutoShotActive = true
        autoShotStopTime = 0  -- cancel any pending stop
        if debugReason == "FD" and debugResetTime then
            -- Player stood up; measure from here, not from FD cast
            print(string.format("[cfST] FD stand-up | T=%.2f time in FD=%.2f", GetTime(), GetTime() - debugResetTime))
            debugResetTime = GetTime()
        end
        if phaseDuration <= 0 and GetUnitSpeed("player") == 0 then
            StartCastPhase(75)
        end
        return
    end

    -- Debounce: tab-targeting fires STOP then START within ~0.4s; don't react immediately
    if event == "STOP_AUTOREPEAT_SPELL" then
        autoShotStopTime = GetTime()
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        local hasTarget = UnitExists("target")
        lastTargetSwapTime = GetTime()
        local remaining = math.max(0, phaseDuration - (GetTime() - phaseStartTime))
        local phase = isCastPhase and "cast" or (phaseDuration > 0 and "reload" or "idle")
        local guid = UnitGUID("target") or "none"
        print(string.format("[cfST] TARGET_CHANGED | T=%.2f guid=%s phase=%s remaining=%.2f/%.2f",
            GetTime(), guid, phase, remaining, phaseDuration))
        if phaseDuration > 0 then
            if hasTarget then
                -- Start timing session to measure actual delay to next shot
                debugResetTime = GetTime()
                debugPredicted = remaining
                debugReason = "TARGET_SWAP"
            else
                -- Lost target: clear debug tracking so stale measurements don't leak into the next fight
                debugResetTime = nil
                debugPredicted = nil
                debugReason = nil
                if isCastPhase and not cleuConfirmed then
                    -- De-targeted mid-cast: cancel only if server hasn't confirmed the cast yet
                    -- If cleuConfirmed, shot is already in flight; SUCCEEDED will start the reload
                    ResetBarToIdle()
                end
                -- De-targeted during reload: server cycle keeps running, bar stays
            end
        end
        return
    end

    -- Frame event: faster than CLEU for cooldown transition
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then
            if cfSwingTimer_RangedShot[eventSpellId] then
                print(string.format("[cfST] SUCCEEDED | T=%.2f spellId=%s",
                    GetTime(), tostring(eventSpellId)))
                StartCooldownPhase()
            elseif eventSpellId == 5384 then -- Feign Death
                StartResetCooldown("FD")
            end
        end
        return
    end

    if event == "UNIT_SPELLCAST_FAILED_QUIET" or event == "UNIT_SPELLCAST_FAILED" then
        if unit == "player" then
            local tag = event == "UNIT_SPELLCAST_FAILED_QUIET" and "quiet" or "loud"
            local reason = GetFailedReason()
            print(string.format("[cfST] FAILED(%s) | T=%.2f spellId=%s isCast=%s matched=%s reason=%s",
                tag, GetTime(),
                tostring(eventSpellId), tostring(isCastPhase),
                tostring(cfSwingTimer_RangedShot[eventSpellId] ~= nil),
                reason))
            if cfSwingTimer_HunterCast[eventSpellId] then
                hunterCastSpellId = nil
            end
            if cfSwingTimer_RangedShot[eventSpellId] then
                -- Server rejected shot during our predicted cast — abort and let CLEU restart
                if isCastPhase and not cleuConfirmed then
                    StartRetryPhase("failed-cast")
                    waitForCleu = true
                end
                if event == "UNIT_SPELLCAST_FAILED_QUIET" then
                    local now = GetTime()
                    lastAutoFailedTime = now
                    -- Server retries auto-shot every ~0.5s after a failure.
                    -- If cooldown bar has < 0.5s left, snap to 0.5s so cast phase
                    -- doesn't start before the server's next retry arrives.
                    if not isCastPhase and phaseDuration > 0 and hunterCastSpellId == nil then
                        local remaining = math.max(0, phaseDuration - (now - phaseStartTime))
                        if remaining < RETRY_INTERVAL then
                            phaseStartTime = now - (phaseDuration - RETRY_INTERVAL)
                        end
                    end
                end
                if phaseDuration <= 0 then
                    if isAutoShotActive and UnitExists("target") and not UnitIsDeadOrGhost("target") then
                        StartRetryPhase("idle-retry")
                    elseif rangedBar:GetValue() > 0 then
                        ResetBarToIdle()
                    end
                end
            end
        end
        return
    end

    local _, subEvent, _, srcGUID, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    if srcGUID ~= playerGUID then return end

    -- Hunter cast spells (Aimed Shot, Steady Shot, Multi-Shot)
    if cfSwingTimer_HunterCast[spellId] then
        if subEvent == "SPELL_CAST_START" then
            hunterCastSpellId = spellId
            print(string.format("[cfST] HUNTER_CAST | T=%.2f spell=%s",
                GetTime(), cfSwingTimer_HunterCast[spellId]))
            -- TBC: Aimed Shot resets auto shot timer on cast start
            if cfSwingTimer_AimedShot[spellId] then
                local speed = UnitRangedDamage("player")
                phaseStartTime = GetTime()
                phaseDuration = speed
                isCastPhase = false
                rangedBar:SetStatusBarColor(unpack(COOLDOWN_PHASE_COLOR))
                print(string.format("[cfST] aimed reset | T=%.2f speed=%.2f", GetTime(), speed))
            end
        elseif subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_CAST_FAILED" then
            hunterCastSpellId = nil
            print(string.format("[cfST] HUNTER_END | T=%.2f spell=%s event=%s",
                GetTime(), cfSwingTimer_HunterCast[spellId], subEvent))
        end
    end

    if not cfSwingTimer_RangedShot[spellId] then return end

    if subEvent == "SPELL_CAST_START" then
        waitForCleu = false
        print(string.format("[cfST] CLEU CAST_START | T=%.2f isCast=%s",
            GetTime(), tostring(isCastPhase)))
        if isCastPhase then
            cleuConfirmed = true
            -- Log and clear debug comparison (was only clearing in the fallback path before)
            if debugResetTime then
                local actual = GetTime() - debugResetTime
                local _, _, _, latencyWorld = GetNetStats()
                print(string.format("[cfST] shot start (CLEU confirm) | T=%.2f actual=%.2f predicted=%.2f latency=%dms",
                    GetTime(), actual, debugPredicted or 0, latencyWorld))
                debugResetTime = nil
                debugPredicted = nil
                debugReason = nil
            end
        end
        -- CLEU fallback: catches first shot and cases prediction misses
        if not isCastPhase then
            if debugResetTime then
                local actual = GetTime() - debugResetTime
                local _, _, _, latencyWorld = GetNetStats()
                print(string.format("[cfST] shot start (CLEU) | T=%.2f actual=%.2f predicted=%.2f latency=%dms",
                    GetTime(), actual, debugPredicted or 0, latencyWorld))
                debugResetTime = nil
                debugPredicted = nil
                debugReason = nil
            end
            StartCastPhase(spellId)
        end
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED" then
        print(string.format("[cfST] CLEU %s | T=%.2f", subEvent, GetTime()))
    end
end)
