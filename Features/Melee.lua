local _, addon = ...

-- CLEU select() indices (confirmed against the canonical suffix schema):
-- 11 base params, then the per-subevent suffix.
local SWING_DAMAGE_OFFHAND_INDEX = 21
local SWING_MISSED_OFFHAND_INDEX = 13
local EXTRA_ATTACKS_AMOUNT_INDEX = 15

-- Bar colors are class tokens, resolved live from RAID_CLASS_COLORS in OnShow:
-- MH = Shaman blue, OH = Mage cyan. NOTE: the Era default Shaman color is pink;
-- cfFrames patches RAID_CLASS_COLORS.SHAMAN to blue (Fixes/ShamanColorFix.lua), so the MH bar relies on
-- cfFrames being loaded (it patches at file scope, before us alphabetically).

-- Swing state. mhSwingStart / mhSpeed live on the namespace because the Warrior plugin
-- reads them (Slam reset / MH color). The off-hand and extra-attack state is used only
-- in this file, so it stays local.
addon.mhSwingStart = 0
addon.mhSpeed = 0
local offHandSwingStart = 0
local offHandSpeed = 0
local extraAttacks = 0
-- Auto-attack toggle state (PLAYER_ENTER_COMBAT / PLAYER_LEAVE_COMBAT). Visibility is
-- keyed on this, not the combat flag: shown on a swing start, hidden once auto-attack
-- is off AND no swing is still in flight. Local (not on addon) -- no class plugin reads
-- it, unlike the swing state above, so it stays private to this file.
local autoAttackOn = false

-- The MH bar is the driver: it carries the OnUpdate animation and is shown/hidden
-- as a unit. The OH bar is parented to it, so it hides with MH and is only visible
-- while dual-wielding. Both are hidden until the first swing starts, and hide again
-- once auto-attack is off and no swing is in flight.
local mainHandBar = addon.CreateSwingBar(UIParent)
mainHandBar:SetPoint("CENTER", 0, -150)
mainHandBar.colorToken = "SHAMAN"
mainHandBar:Hide()
addon.mainHandBar = mainHandBar

local offHandBar = addon.CreateSwingBar(mainHandBar)
offHandBar:SetPoint("TOP", mainHandBar, "BOTTOM", 0, -addon.BAR_HEIGHT)
offHandBar.colorToken = "MAGE"
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
    if UpdateBar(offHandBar, offHandSwingStart, offHandSpeed, now) then
        offHandSwingStart = 0
    end
    -- Hide once auto-attack is off AND both hands are ready (no swing in flight), so a
    -- swing that's still running when auto-attack stops isn't cut off mid-flight.
    if not autoAttackOn and addon.mhSwingStart == 0 and offHandSwingStart == 0 then
        extraAttacks = 0
        mainHandBar:Hide()
    end
end)

local function RefreshSpeeds()
    local mh, oh = UnitAttackSpeed("player")
    addon.mhSpeed = mh or 0
    offHandSpeed = oh or 0
    offHandBar:SetShown(offHandSpeed > 0) -- only visible while MH (parent) is shown
end

local function StartSwing(isOffHand, now)
    if isOffHand then
        offHandSwingStart = now
    elseif extraAttacks > 0 then
        extraAttacks = extraAttacks - 1
    else
        addon.mhSwingStart = now
    end
    -- A swing means auto-attack is on. Setting this here (not only from PLAYER_ENTER_COMBAT)
    -- makes visibility self-healing after a /reload mid-combat, where the enter-combat edge
    -- doesn't re-fire; PLAYER_LEAVE_COMBAT still clears it.
    autoAttackOn = true
    mainHandBar:Show() -- show on a swing start (idempotent thereafter)
end

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_ATTACK_SPEED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_ENTER_COMBAT")
events:RegisterEvent("PLAYER_LEAVE_COMBAT")
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
        local oldMH, oldOH = addon.mhSpeed, offHandSpeed
        RefreshSpeeds()
        if oldMH > 0 and addon.mhSwingStart > 0 then
            addon.mhSwingStart = now - (now - addon.mhSwingStart) * addon.mhSpeed / oldMH
        end
        if oldOH > 0 and offHandSwingStart > 0 then
            offHandSwingStart = now - (now - offHandSwingStart) * offHandSpeed / oldOH
        end
        return
    elseif event == "PLAYER_ENTER_COMBAT" then
        -- Auto-attack toggled on. Visibility is driven by swing starts, so we don't
        -- show here -- just track state for the hide condition.
        autoAttackOn = true
        -- Off-hand forced half-speed delay on engaging.
        if offHandSwingStart > 0 and offHandSpeed > 0 then
            local halfSpeed = offHandSpeed / 2
            local remaining = offHandSpeed - (now - offHandSwingStart)
            if remaining < halfSpeed then
                offHandSwingStart = now - halfSpeed
            end
        end
        return
    elseif event == "PLAYER_LEAVE_COMBAT" then
        -- Auto-attack toggled off. Don't hide now -- OnUpdate hides once the in-flight
        -- swing finishes, so it isn't cut off mid-flight.
        autoAttackOn = false
        return
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Start a fresh swing on a weapon swap, but only if a weapon is actually equipped:
        -- on an unequip RefreshSpeeds sets speed 0, and starting a swing then would leave a
        -- non-zero swingStart that UpdateBar never clears (speed==0 guard), pinning the bar
        -- shown. Zeroing the start instead lets the idle-hide fire.
        if arg1 == 16 then
            RefreshSpeeds()
            addon.mhSwingStart = addon.mhSpeed > 0 and now or 0
        elseif arg1 == 17 then
            RefreshSpeeds()
            offHandSwingStart = offHandSpeed > 0 and now or 0
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
            extraAttacks = extraAttacks + select(EXTRA_ATTACKS_AMOUNT_INDEX, CombatLogGetCurrentEventInfo())
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
