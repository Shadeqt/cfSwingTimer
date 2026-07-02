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
-- Hide() is untouched, so Melee's auto-attack-off auto-hide still works. Leaving the form
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

-- Queue highlight for Maul (the Bear-Form on-next-swing ability), via Core's shared
-- queue-highlight helper: recolor the MH bar Rogue yellow while Maul is queued; idle is
-- the bar's default "SHAMAN" colorToken. Only Bear queues Maul, so this never collides
-- with Cat suppression above.
local OnSent = addon.MakeQueueHighlight(bar, {
    { set = addon.spells.maul, token = "ROGUE" },
}, "SHAMAN")

local castEvents = CreateFrame("Frame")
castEvents:RegisterEvent("UNIT_SPELLCAST_SENT")
castEvents:SetScript("OnEvent", function(_, _, unit, _, _, spellId)
    if unit == "player" then OnSent(spellId) end
end)
