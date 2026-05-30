local _, addon = ...

-- CLEU select() indices (confirmed against the canonical suffix schema):
-- 11 base params, then the per-subevent suffix.
local SWING_DAMAGE_OFFHAND_INDEX = 21
local SWING_MISSED_OFFHAND_INDEX = 13
local EXTRA_ATTACKS_AMOUNT_INDEX = 15

-- Fixed palette picks as literals. NOT RAID_CLASS_COLORS: in Classic Era the
-- default Shaman color is pink (only cfClassColors makes it blue), so reading it
-- live mis-colors the MH bar and breaks standalone use.
local MH_COLOR = { 0.00, 0.44, 0.87 } -- blue
local OH_COLOR = { 0.25, 0.78, 0.92 } -- cyan

-- Shared swing state on the namespace (class plugins read mhSwingStart / mhSpeed).
addon.mhSwingStart = 0
addon.offHandSwingStart = 0
addon.mhSpeed = 0
addon.offHandSpeed = 0
addon.extraAttacks = 0

-- The MH bar is the driver: it carries the OnUpdate animation and is shown/hidden
-- as a unit. The OH bar is parented to it, so it hides with MH and is only visible
-- while dual-wielding. Both are hidden until the first swing of a combat.
local mainHandBar = addon.CreateSwingBar(UIParent)
mainHandBar:SetPoint("CENTER", 0, -150)
mainHandBar.color = MH_COLOR
mainHandBar:SetStatusBarColor(mainHandBar.color[1], mainHandBar.color[2], mainHandBar.color[3])
mainHandBar:Hide()
addon.mainHandBar = mainHandBar

local offHandBar = addon.CreateSwingBar(mainHandBar)
offHandBar:SetPoint("TOP", mainHandBar, "BOTTOM", 0, -addon.BAR_SPACING)
offHandBar.color = OH_COLOR
offHandBar:SetStatusBarColor(offHandBar.color[1], offHandBar.color[2], offHandBar.color[3])
offHandBar:Hide()
addon.offHandBar = offHandBar

local function UpdateBar(bar, swingStart, speed, now)
    if speed == 0 or swingStart == 0 then return end
    local elapsed = now - swingStart
    if elapsed >= speed then
        addon.UpdateSwingBar(bar, 0, 0)
        return true
    end
    addon.UpdateSwingBar(bar, elapsed / speed, speed - elapsed)
end

mainHandBar:SetScript("OnUpdate", function()
    local now = GetTime()
    if UpdateBar(mainHandBar, addon.mhSwingStart, addon.mhSpeed, now) then
        addon.mhSwingStart = 0
    end
    if UpdateBar(offHandBar, addon.offHandSwingStart, addon.offHandSpeed, now) then
        addon.offHandSwingStart = 0
    end
end)

local function RefreshSpeeds()
    local mh, oh = UnitAttackSpeed("player")
    addon.mhSpeed = mh or 0
    addon.offHandSpeed = oh or 0
    offHandBar:SetShown(addon.offHandSpeed > 0) -- only visible while MH (parent) is shown
end

local function StartSwing(isOffHand, now)
    if isOffHand then
        addon.offHandSwingStart = now
    elseif addon.extraAttacks > 0 then
        addon.extraAttacks = addon.extraAttacks - 1
    else
        addon.mhSwingStart = now
    end
    mainHandBar:Show() -- show on first swing of the combat (idempotent thereafter)
end

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_ATTACK_SPEED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_ENTER_COMBAT")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1)
    local now = GetTime()

    if event == "PLAYER_ENTERING_WORLD" then
        addon.playerGUID = UnitGUID("player")
        RefreshSpeeds()
        return
    elseif event == "UNIT_ATTACK_SPEED" then
        if arg1 ~= "player" then return end
        -- Rescale the in-flight swing so progress doesn't jump on a haste change.
        local oldMH, oldOH = addon.mhSpeed, addon.offHandSpeed
        RefreshSpeeds()
        if oldMH > 0 and addon.mhSwingStart > 0 then
            addon.mhSwingStart = now - (now - addon.mhSwingStart) * addon.mhSpeed / oldMH
        end
        if oldOH > 0 and addon.offHandSwingStart > 0 then
            addon.offHandSwingStart = now - (now - addon.offHandSwingStart) * addon.offHandSpeed / oldOH
        end
        return
    elseif event == "PLAYER_ENTER_COMBAT" then
        -- Off-hand forced half-speed delay on engaging.
        if addon.offHandSwingStart > 0 and addon.offHandSpeed > 0 then
            local halfSpeed = addon.offHandSpeed / 2
            local remaining = addon.offHandSpeed - (now - addon.offHandSwingStart)
            if remaining < halfSpeed then
                addon.offHandSwingStart = now - halfSpeed
            end
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon.mhSwingStart = 0
        addon.offHandSwingStart = 0
        addon.extraAttacks = 0
        mainHandBar:Hide()
        return
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == 16 then
            RefreshSpeeds()
            addon.mhSwingStart = now
        elseif arg1 == 17 then
            RefreshSpeeds()
            addon.offHandSwingStart = now
        end
        return
    end

    -- COMBAT_LOG_EVENT_UNFILTERED
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellIdOrMissType = CombatLogGetCurrentEventInfo()

    if sourceGUID == addon.playerGUID then
        if subevent == "SWING_DAMAGE" then
            StartSwing(select(SWING_DAMAGE_OFFHAND_INDEX, CombatLogGetCurrentEventInfo()), now)
        elseif subevent == "SWING_MISSED" then
            StartSwing(select(SWING_MISSED_OFFHAND_INDEX, CombatLogGetCurrentEventInfo()), now)
        elseif subevent == "SPELL_EXTRA_ATTACKS" then
            addon.extraAttacks = addon.extraAttacks + select(EXTRA_ATTACKS_AMOUNT_INDEX, CombatLogGetCurrentEventInfo())
        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
            if addon.spells.meleeReplacer[spellIdOrMissType] then
                StartSwing(false, now)
            end
        end
    end

    -- Parry haste: when the player parries an incoming attack, the player's swing speeds up.
    if destGUID == addon.playerGUID and subevent == "SWING_MISSED" and spellIdOrMissType == "PARRY" and addon.mhSwingStart > 0 then
        local parryReduction = addon.mhSpeed * 0.4
        local parryFloor = addon.mhSpeed * 0.2
        local elapsed = now - addon.mhSwingStart
        addon.mhSwingStart = now - math.min(elapsed + parryReduction, addon.mhSpeed - parryFloor)
    end
end)

RefreshSpeeds()
