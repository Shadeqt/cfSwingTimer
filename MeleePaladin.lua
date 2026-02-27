-- MeleePaladin.lua — Seal twist markers on main hand bar
if select(2, UnitClass("player")) ~= "PALADIN" then return end

local BAR_WIDTH = cfSwingTimer.BAR_WIDTH
local BAR_HEIGHT = cfSwingTimer.BAR_HEIGHT
local mainHandBar = cfSwingTimer.mainHandBar
local TWIST_WINDOW = 0.4
local GCD = 1.5

local Color = {
    TWIST = { 1, 0.996, 0.722, 1 },
    GCD   = { 1, 0, 0, 0.8 },
}

local function CreateMarker(color)
    local marker = mainHandBar:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(unpack(color))
    marker:SetSize(2, BAR_HEIGHT)
    return marker
end

local twistMarker = CreateMarker(Color.TWIST)
local gcdMarker = CreateMarker(Color.GCD)

local function PlaceMarker(marker, timeBeforeSwing)
    local pos = (1 - timeBeforeSwing / mainHandBar.speed) * BAR_WIDTH
    if pos > 0 then
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", mainHandBar, "LEFT", pos, 0)
        marker:Show()
    else
        marker:Hide()
    end
end

local function UpdateTwistMarkers()
    PlaceMarker(twistMarker, TWIST_WINDOW)
    PlaceMarker(gcdMarker, TWIST_WINDOW + GCD)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_ATTACK_SPEED")
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
        UpdateTwistMarkers()
    end
end)
