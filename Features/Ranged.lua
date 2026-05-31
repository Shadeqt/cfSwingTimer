local _, addon = ...

-- Ranged is Hunter-only: a hunter always has the ranged engine, so we gate the
-- whole file by class rather than dynamically registering on UnitRangedDamage.
if select(2, UnitClass("player")) ~= "HUNTER" then return end

local RANGED_SLOT = 18
local AUTO_SHOT = 75
local RETRY_DURATION = 0.5
local PUSHBACK = { 1.0, 1.8, 2.4, 2.8, 3.0 }

-- SHOOT/RELOAD are class colors from RAID_CLASS_COLORS (Demon Hunter purple, Priest
-- white). RETRY/CAST are casting-bar colors sourced live from CastingBarFrame
-- (failed red, casting orange). All snapshotted at load -- none of these tracks
-- cfClassColors, so no need to re-resolve.
local function classRGB(token)
    local c = RAID_CLASS_COLORS[token]
    return { c.r, c.g, c.b }
end
local Color = {
    SHOOT  = classRGB("DEMONHUNTER"),
    RELOAD = classRGB("PRIEST"),
    RETRY  = { addon.CastbarColor("failedCastColor") },
    CAST   = { addon.CastbarColor("startCastColor") },
}

-- State
local shootStart, shootEnd = 0, 0
local reloadStart, reloadEnd = 0, 0
local retryEnd = 0
local lastShotDuration = 0
local castStart, castEnd, castSpellId = 0, 0, 0
local pushbackCount = 0

-- Tooltip scanner: the only way to read base (unhasted) weapon speed in Era (no
-- data API; C_TooltipInfo item getters are Retail-only). Locale-safe: find the
-- WEAPON_SPEED label, then parse a number allowing ',' or '.' decimals.
local scanner = CreateFrame("GameTooltip", "cfSwingTimerScanTip", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
local baseSpeedCache = {}
local speedLabel = WEAPON_SPEED or "Speed"

local function GetBaseWeaponSpeed(slot)
    local itemId = GetInventoryItemID("player", slot)
    if not itemId then return end
    if baseSpeedCache[itemId] then return baseSpeedCache[itemId] end
    scanner:ClearLines()
    scanner:SetInventoryItem("player", slot)
    for i = 2, scanner:NumLines() do
        local text = _G["cfSwingTimerScanTipTextRight" .. i]:GetText()
        if text and text:find(speedLabel, 1, true) then
            local number = text:match("(%d+[%.,]%d+)")
            if number then
                baseSpeedCache[itemId] = tonumber((number:gsub(",", ".")))
                return baseSpeedCache[itemId]
            end
        end
    end
end

local function GetShotTime(spellId)
    local rangedSpeed = UnitRangedDamage("player")
    local info = C_Spell.GetSpellInfo(spellId)
    local baseShotMs = info and info.castTime or 0
    local baseShotTime = (baseShotMs > 0 and baseShotMs or 500) / 1000
    local baseSpeed = GetBaseWeaponSpeed(RANGED_SLOT)
    if not baseSpeed then return baseShotTime end
    return baseShotTime * rangedSpeed / baseSpeed
end

-- The base ranged bar is the driver (OnUpdate). The cast bar is parented above it
-- and shown only during a cast. Both hidden until the first ranged action.
local rangedBar = addon.CreateSwingBar(UIParent)
rangedBar:SetPoint("CENTER", 0, -120)
rangedBar:Hide()

-- Clip zone: a band sized to a shot's cast time, on the reload bar. Firing a shot
-- inside it delays the next auto-shot — the "don't clip" warning. Ranged-only.
local clipZone = rangedBar:CreateTexture(nil, "OVERLAY")
clipZone:SetColorTexture(Color.RETRY[1], Color.RETRY[2], Color.RETRY[3], 0.25) -- failed red + our alpha
-- Anchored to the LEFT: the reload bar depletes right-to-left, so the clip
-- window (the final shotTime before the auto-shot fires) sits at the left edge.
clipZone:SetPoint("TOPLEFT", rangedBar, "TOPLEFT", 0, 0)
clipZone:SetPoint("BOTTOMLEFT", rangedBar, "BOTTOMLEFT", 0, 0)
clipZone:Hide()

local function SetClip(fraction)
    clipZone:SetWidth(math.min(fraction * addon.BAR_WIDTH, addon.BAR_WIDTH))
    clipZone:Show()
end

local castBar = addon.CreateSwingBar(rangedBar)
castBar:SetPoint("BOTTOM", rangedBar, "TOP", 0, addon.BAR_HEIGHT)
castBar.color = Color.CAST
castBar:Hide()

-- Exposed for the /cfst test harness (melee bars are already on addon).
addon.rangedBar = rangedBar
addon.castBar = castBar
addon.SetClip = SetClip

local function ShowRanged()
    if UnitRangedDamage("player") > 0 then
        rangedBar:Show()
    end
end

local function StopCast()
    castStart, castEnd, castSpellId, pushbackCount = 0, 0, 0, 0
    castBar:Hide()
end

local function ClearShots()
    shootEnd, reloadEnd, retryEnd = 0, 0, 0
end

rangedBar:SetScript("OnUpdate", function()
    local now = GetTime()

    if GetUnitSpeed("player") > 0 then
        shootEnd = 0
    end

    if shootEnd > now then
        clipZone:Hide()
        rangedBar:SetStatusBarColor(Color.SHOOT[1], Color.SHOOT[2], Color.SHOOT[3])
        addon.UpdateSwingBar(rangedBar, (now - shootStart) / (shootEnd - shootStart), shootEnd - now)
    elseif reloadEnd > now then
        rangedBar:SetStatusBarColor(Color.RELOAD[1], Color.RELOAD[2], Color.RELOAD[3])
        addon.UpdateSwingBar(rangedBar, 1 - (now - reloadStart) / (reloadEnd - reloadStart), reloadEnd - now)
    elseif retryEnd > now then
        clipZone:Hide()
        rangedBar:SetStatusBarColor(Color.RETRY[1], Color.RETRY[2], Color.RETRY[3])
        addon.UpdateSwingBar(rangedBar, (retryEnd - now) / RETRY_DURATION, retryEnd - now)
    else
        clipZone:Hide()
        addon.UpdateSwingBar(rangedBar, 0, 0)
    end

    if castEnd > 0 then
        local castDuration = castEnd - castStart
        local pushback = pushbackCount > 0 and PUSHBACK[pushbackCount] or 0
        local elapsed = now - castStart - math.min(pushback, now - castStart)
        addon.UpdateSwingBar(castBar, elapsed / castDuration, math.max(0, castDuration - elapsed))
        castBar:Show()
    else
        castBar:Hide()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:RegisterEvent("UNIT_SPELLCAST_FAILED")
events:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
events:RegisterEvent("STOP_AUTOREPEAT_SPELL")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function(_, event, ...)
    local now = GetTime()

    if event == "PLAYER_ENTERING_WORLD" then
        addon.playerGUID = UnitGUID("player")
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        ClearShots()
        StopCast()
        rangedBar:Hide()
        return
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        if slot == RANGED_SLOT and UnitRangedDamage("player") == 0 then
            ClearShots()
            StopCast()
            rangedBar:Hide()
        end
        return
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        retryEnd = 0
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()

        if castEnd > 0 and destGUID == addon.playerGUID and pushbackCount < #PUSHBACK then
            if subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "ENVIRONMENTAL_DAMAGE" then
                pushbackCount = pushbackCount + 1
            end
        end

        if sourceGUID ~= addon.playerGUID or subevent ~= "SPELL_CAST_START" then return end
        if addon.spells.rangedAttack[cleuSpellId] then
            lastShotDuration = GetShotTime(cleuSpellId)
            if shootEnd <= now then
                shootStart = now
                shootEnd = now + lastShotDuration
            end
            ShowRanged()
        elseif addon.spells.hunterCast[cleuSpellId] then
            local info = C_Spell.GetSpellInfo(cleuSpellId)
            local castTimeMs = info and info.castTime or 0
            local duration = (castTimeMs > 0) and (castTimeMs / 1000) or GetShotTime(cleuSpellId)
            if not duration or duration == 0 then return end
            shootEnd = 0
            retryEnd = 0
            castStart = now
            castSpellId = cleuSpellId
            pushbackCount = (castTimeMs > 0) and 0 or (#PUSHBACK + 1)
            castEnd = now + duration
            castBar:SetStatusBarColor(Color.CAST[1], Color.CAST[2], Color.CAST[3])
            ShowRanged()
        end
        return
    end

    -- UNIT_SPELLCAST_* events
    local unit, _, spellId = ...
    if unit ~= "player" then return end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if addon.spells.rangedAttack[spellId] then
            local rangedSpeed = UnitRangedDamage("player")
            local reloadTime = addon.spells.rangedAutoAttack[spellId] and (rangedSpeed - lastShotDuration) or rangedSpeed
            reloadStart = now
            reloadEnd = now + reloadTime
            shootEnd = 0
            SetClip(GetShotTime(AUTO_SHOT) / reloadTime)
            ShowRanged()
        elseif spellId == castSpellId then
            StopCast()
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if addon.spells.rangedAttack[spellId] then
            shootEnd = 0
        end
        if spellId == castSpellId then
            StopCast()
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if spellId == castSpellId then
            StopCast()
        end
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        if addon.spells.rangedAttack[spellId] and castEnd == 0 then
            retryEnd = now + RETRY_DURATION
            ShowRanged()
        end
    end
end)
