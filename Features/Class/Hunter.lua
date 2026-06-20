local _, addon = ...

-- Code-isolated plugin: all Hunter code is here. It recolors the shared MH bar while
-- Raptor Strike is queued, mirroring Warrior's Heroic Strike and Druid's Maul — Raptor
-- Strike is the Hunter on-next-swing ability, so the same UNIT_SPELLCAST_SENT +
-- IsCurrentSpell pattern works. Toggle by its toc line.
if select(2, UnitClass("player")) ~= "HUNTER" then return end

local bar = addon.mainHandBar
if not bar then return end

-- Recolor the MH bar Rogue yellow while Raptor Strike is queued; idle is the bar's
-- default "SHAMAN" colorToken. Setting bar.colorToken also lets Core's OnShow re-apply
-- the right color across a live retexture.
local queuedSpellId

local function ApplyColor()
    if queuedSpellId and addon.spells.raptorStrike[queuedSpellId] then
        bar.colorToken = "ROGUE"
    else
        bar.colorToken = "SHAMAN"
    end
    addon.ApplyBarColor(bar)
end

local castEvents = CreateFrame("Frame")
castEvents:RegisterEvent("UNIT_SPELLCAST_SENT")
castEvents:SetScript("OnEvent", function(_, _, unit, _, _, spellId)
    if unit == "player" and addon.spells.raptorStrike[spellId] then
        queuedSpellId = spellId
        ApplyColor()
    end
end)

-- Clear the highlight once the queued Raptor Strike is no longer current. Cheap: the
-- body only runs work while something is queued.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    if queuedSpellId and not C_Spell.IsCurrentSpell(queuedSpellId) then
        queuedSpellId = nil
        ApplyColor()
    end
end)
