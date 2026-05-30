local _, addon = ...

-- Code-isolated plugin: all Shaman code is here. Static half-speed markers at the
-- center of the MH (and OH, when present) bar; they are children of those bars, so
-- they hide/show with them automatically. Toggle by its toc line.
if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local mainHandBar = addon.mainHandBar
if not mainHandBar then return end

-- Inlined marker helper (not shared, so this file is independently removable).
local function CreateHalfMarker(bar)
    local marker = bar:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(0.70, 0.70, 0.70)
    marker:SetSize(2, bar:GetHeight())
    marker:SetPoint("CENTER", bar, "LEFT", 0.5 * bar:GetWidth(), 0)
    return marker
end

CreateHalfMarker(mainHandBar)

if addon.offHandBar then
    CreateHalfMarker(addon.offHandBar)
end
