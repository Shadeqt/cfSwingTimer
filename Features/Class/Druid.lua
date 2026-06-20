local _, addon = ...

-- Code-isolated plugin: all Druid code is here. Cat Form auto-attacks swing so fast
-- (~1s, faster with haste) that the bar is just spammy noise, so we suppress it while
-- in Cat Form. Other forms (Bear at 2.5s, caster) are left alone. Toggle by its toc line.
if select(2, UnitClass("player")) ~= "DRUID" then return end

local bar = addon.mainHandBar
if not bar then return end

local CAT_FORM_SPELL = 768  -- match the active form by spell, so stance-bar order doesn't matter

-- True only when the *active* shapeshift form is Cat Form. GetShapeshiftFormInfo returns
-- icon, active, castable, spellID (confirmed Era signature); index alone isn't reliable
-- because the stance-bar order depends on which forms are learned.
local function InCatForm()
    for i = 1, GetNumShapeshiftForms() do
        local _, active, _, spellID = GetShapeshiftFormInfo(i)
        if active then return spellID == CAT_FORM_SPELL end
    end
    return false
end

-- Suppress by wrapping the bar's own Show: Melee's StartSwing calls mainHandBar:Show()
-- on every swing, so reactively Hide()ing would just flip back a frame later. Making Show
-- a no-op while in Cat Form keeps the bar down with no flicker and no change to Melee.lua;
-- Hide() is untouched, so Melee's out-of-combat auto-hide still works. Leaving the form
-- restores Show, and the bar reappears on the next swing as usual.
local suppressed = false
local Show = bar.Show
bar.Show = function(self)
    if suppressed then return end
    return Show(self)
end

local events = CreateFrame("Frame")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    suppressed = InCatForm()
    if suppressed then bar:Hide() end  -- drop any bar still in flight from before the shift
end)

-- Queue highlight for Maul, mirroring Warrior's Heroic Strike: Maul is the Bear-Form
-- on-next-swing ability, so the same UNIT_SPELLCAST_SENT + IsCurrentSpell pattern works.
-- Recolor the MH bar Rogue yellow while Maul is queued; idle is the bar's default
-- "SHAMAN" colorToken. Only Bear queues Maul, so this never collides with Cat suppression.
local queuedSpellId

local function ApplyColor()
    if queuedSpellId and addon.spells.maul[queuedSpellId] then
        bar.colorToken = "ROGUE"
    else
        bar.colorToken = "SHAMAN"
    end
    addon.ApplyBarColor(bar)
end

local castEvents = CreateFrame("Frame")
castEvents:RegisterEvent("UNIT_SPELLCAST_SENT")
castEvents:SetScript("OnEvent", function(_, _, unit, _, _, spellId)
    if unit == "player" and addon.spells.maul[spellId] then
        queuedSpellId = spellId
        ApplyColor()
    end
end)

-- Clear the highlight once the queued Maul is no longer current. Cheap: the body only
-- runs work while something is queued.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    if queuedSpellId and not C_Spell.IsCurrentSpell(queuedSpellId) then
        queuedSpellId = nil
        ApplyColor()
    end
end)
