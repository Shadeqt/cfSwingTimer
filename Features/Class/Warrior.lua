local _, addon = ...

-- Code-isolated plugin: all Warrior code is here. It recolors the shared MH bar by
-- queued ability and resets the MH swing on Slam — both reaching into melee's bar /
-- state, but entirely from this file. Toggle by its toc line.
if select(2, UnitClass("player")) ~= "WARRIOR" then return end

local bar = addon.mainHandBar
if not bar then return end

local function classColor(token)
    local c = RAID_CLASS_COLORS[token]
    return c.r, c.g, c.b
end

local queuedSpellId

-- Write bar.color too, so Core's OnShow texture re-apply keeps the queue color
-- across a live retexture (and restores the idle color on dequeue).
local function ApplyColor()
    if queuedSpellId and addon.spells.heroicStrike[queuedSpellId] then
        bar.color = { classColor("ROGUE") }      -- Heroic Strike
    elseif queuedSpellId and addon.spells.cleave[queuedSpellId] then
        bar.color = { 0.00, 1.00, 0.60 }          -- Cleave (Monk green — no Era class entry)
    else
        bar.color = { classColor("SHAMAN") }      -- idle / MH default
    end
    bar:SetStatusBarColor(bar.color[1], bar.color[2], bar.color[3])
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

ApplyColor()
