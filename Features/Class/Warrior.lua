local _, addon = ...

-- Code-isolated plugin: all Warrior code is here. It recolors the shared MH bar by
-- queued ability (via Core's shared queue-highlight helper) and resets the MH swing on
-- Slam -- both reaching into melee's bar / state, but entirely from this file. Toggle by
-- its toc line.
if select(2, UnitClass("player")) ~= "WARRIOR" then return end

local bar = addon.mainHandBar
if not bar then return end

-- Ordered rules: Heroic Strike (Rogue yellow) takes precedence over Cleave (Monk green).
-- Idle is Melee's "SHAMAN" default, applied live in Core's OnShow.
local OnSent = addon.MakeQueueHighlight(bar, {
    { set = addon.spells.heroicStrike, token = "ROGUE" },
    { set = addon.spells.cleave,       token = "MONK" },
}, "SHAMAN")

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local unit, _, _, spellId = ...
        if unit == "player" then OnSent(spellId) end
        return
    end

    -- Slam resets the MH swing on cast success when the swing was still active.
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, cleuSpellId = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= addon.playerGUID then return end
    if subevent ~= "SPELL_CAST_SUCCESS" then return end
    if not addon.spells.slam[cleuSpellId] then return end
    local now = GetTime()
    if addon.mhSwingStart > 0 and (now - addon.mhSwingStart) < addon.mhSpeed then
        addon.mhSwingStart = now
    end
end)
