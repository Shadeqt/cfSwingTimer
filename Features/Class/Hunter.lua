local _, addon = ...

-- Code-isolated plugin: recolors the shared MH bar Rogue yellow while Raptor Strike
-- (the Hunter on-next-swing ability) is queued, via Core's shared queue-highlight helper.
-- Idle is the bar's default "SHAMAN" colorToken. Toggle by its toc line.
if select(2, UnitClass("player")) ~= "HUNTER" then return end

local bar = addon.mainHandBar
if not bar then return end

local OnSent = addon.MakeQueueHighlight(bar, {
    { set = addon.spells.raptorStrike, token = "ROGUE" },
}, "SHAMAN")

local events = CreateFrame("Frame")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:SetScript("OnEvent", function(_, _, unit, _, _, spellId)
    if unit == "player" then OnSent(spellId) end
end)
