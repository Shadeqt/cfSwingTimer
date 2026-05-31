local _, addon = ...

-- Code-isolated plugin: all Paladin code is here. Toggle by its toc line; melee
-- never references it. Self-initializes off the shared MH bar handle.
if select(2, UnitClass("player")) ~= "PALADIN" then return end

local bar = addon.mainHandBar
if not bar then return end

-- Inlined marker helper (not shared, so this file is independently removable).
local function CreateMarker(r, g, b)
    local marker = bar:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(r, g, b)
    marker:SetSize(2, bar:GetHeight())
    return marker
end

local twistMarker = CreateMarker(addon.CastbarColor("nonInterruptibleColor")) -- seal twist window (gray)
local gcdMarker = CreateMarker(addon.CastbarColor("failedCastColor"))         -- twist + GCD (red)

local function UpdateMarkers()
    local speed = UnitAttackSpeed("player") or 0
    if speed == 0 then
        twistMarker:Hide()
        gcdMarker:Hide()
        return
    end
    local width = bar:GetWidth()
    twistMarker:ClearAllPoints()
    twistMarker:SetPoint("CENTER", bar, "LEFT", (1 - 0.4 / speed) * width, 0)
    twistMarker:Show()
    gcdMarker:ClearAllPoints()
    gcdMarker:SetPoint("CENTER", bar, "LEFT", (1 - (0.4 + 1.5) / speed) * width, 0)
    gcdMarker:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_ATTACK_SPEED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
        UpdateMarkers()
    end
end)

UpdateMarkers()
