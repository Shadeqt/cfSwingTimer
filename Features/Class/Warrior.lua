local _, addon = ...

-- Code-isolated plugin: all Warrior code is here. It recolors the shared MH bar by
-- queued ability and resets the MH swing on Slam — both reaching into melee's bar /
-- state, but entirely from this file. Toggle by its toc line.
if select(2, UnitClass("player")) ~= "WARRIOR" then return end

local bar = addon.mainHandBar
if not bar then return end

-- Queue highlight via class tokens, resolved live from RAID_CLASS_COLORS in Core's
-- ApplyBarColor: Heroic Strike = Rogue yellow, Cleave = Monk green, idle = Shaman
-- blue (matching the MH bar's default). Setting bar.colorToken also lets Core's
-- OnShow re-apply the right color across a live retexture.
local queuedSpellId

local function ApplyColor()
    if queuedSpellId and addon.spells.heroicStrike[queuedSpellId] then
        bar.colorToken = "ROGUE"
    elseif queuedSpellId and addon.spells.cleave[queuedSpellId] then
        bar.colorToken = "MONK"
    else
        bar.colorToken = "SHAMAN"
    end
    addon.ApplyBarColor(bar)
end

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local unit, _, _, spellId = ...
        if unit == "player" and addon.spells.meleeReplacer[spellId] then
            queuedSpellId = spellId
            ApplyColor()
        end
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

-- Clear the highlight once the queued ability is no longer current. Cheap: the
-- body only runs work while something is queued.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    if queuedSpellId and not C_Spell.IsCurrentSpell(queuedSpellId) then
        queuedSpellId = nil
        ApplyColor()
    end
end)

-- No initial ApplyColor() here on purpose: the idle color is Melee's "SHAMAN"
-- colorToken, applied live in OnShow. Reading the color at file scope would be the
-- one load-time RAID_CLASS_COLORS read, which breaks if cfClassColors loads later.
