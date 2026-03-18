-- Blizzard CastingBarFrame dimensions
-- Source: Interface/AddOns/Blizzard_CastingBar/Vanilla/CastingBarFrame.xml (Gethe/wow-ui-source, classic_era)
local BAR_WIDTH = 195
local BAR_HEIGHT = 13
local BORDER_WIDTH = 256
local BORDER_HEIGHT = 64
local SPARK_SIZE = 32

-- Blizzard class colors (RAID_CLASS_COLORS)
-- Source: warcraft.wiki.gg/wiki/RAID_CLASS_COLORS
local CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    MAGE        = { 0.25, 0.78, 0.92 },
    WARLOCK     = { 0.53, 0.53, 0.93 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
}

-- Blizzard casting bar colors
-- Source: Interface/AddOns/Blizzard_CastingBar/Vanilla/CastingBarFrame.lua (Gethe/wow-ui-source, classic_era)
local CASTBAR_COLORS = {
    CASTING          = { 1.00, 0.70, 0.00 },
    CHANNELING       = { 0.00, 1.00, 0.00 },
    FINISHED         = { 0.00, 1.00, 0.00 },
    FAILED           = { 1.00, 0.00, 0.00 },
    NONINTERRUPTIBLE = { 0.70, 0.70, 0.70 },
}

cfSwingTimer = {
    BAR_WIDTH = BAR_WIDTH,
    BAR_HEIGHT = BAR_HEIGHT,
    playerGUID = UnitGUID("player"),
    bars = {},
    CLASS_COLORS = CLASS_COLORS,
    CASTBAR_COLORS = CASTBAR_COLORS,
}

-- Tooltip scanner: only way to get base (unhasted) weapon speed in Classic
local tooltipScanner = CreateFrame("GameTooltip", "cfScanTip", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
local baseSpeedCache = {}

function cfSwingTimer.GetBaseWeaponSpeed(inventorySlot)
    local itemId = GetInventoryItemID("player", inventorySlot)
    if not itemId then return nil end
    if baseSpeedCache[itemId] then return baseSpeedCache[itemId] end
    tooltipScanner:ClearLines()
    tooltipScanner:SetInventoryItem("player", inventorySlot)
    for i = 2, tooltipScanner:NumLines() do
        local text = _G["cfScanTipTextRight" .. i]:GetText()
        if text then
            local speed = text:match("Speed (%d+%.%d+)")
            if speed then
                baseSpeedCache[itemId] = tonumber(speed)
                return baseSpeedCache[itemId]
            end
        end
    end
end


local function AddBackground(frame)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.5)
end

local function AddBorder(frame, overlayParent)
    overlayParent = overlayParent or frame
    frame.border = overlayParent:CreateTexture(nil, "OVERLAY")
    frame.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
    frame.border:SetSize(BORDER_WIDTH, BORDER_HEIGHT)
    frame.border:SetPoint("TOP", frame, "TOP", 0, 26)
end

local function AddText(frame, overlayParent, flags)
    overlayParent = overlayParent or frame
    frame.text = overlayParent:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont("Fonts\\FRIZQT__.ttf", 11, flags)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
end

local function CreateStatusBar(parent, texture, color)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(unpack(color))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local DEFAULT_COLOR = CASTBAR_COLORS.CASTING

function cfSwingTimer.CreateSwingBar(parent, speed)
    local texture = cfSwingTimer.GetBarTexture()
    local bar = CreateStatusBar(parent, texture, DEFAULT_COLOR)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar.timer = 0
    bar.speed = speed or 0

    AddBackground(bar)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetSize(SPARK_SIZE, SPARK_SIZE)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    bar.spark:Hide()

    AddBorder(bar)
    AddText(bar)

    return bar
end

function cfSwingTimer.CreateCenterSwingBar(parent, speed)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(BAR_WIDTH, BAR_HEIGHT)
    frame.timer = 0
    frame.speed = speed or 0

    AddBackground(frame)

    local halfWidth = BAR_WIDTH / 2
    local texture = cfSwingTimer.GetBarTexture()

    frame.leftBar = CreateStatusBar(frame, texture, DEFAULT_COLOR)
    frame.leftBar:SetSize(halfWidth, BAR_HEIGHT)
    frame.leftBar:SetPoint("RIGHT", frame, "CENTER", 0, 0)
    frame.leftBar:SetReverseFill(true)

    frame.rightBar = CreateStatusBar(frame, texture, DEFAULT_COLOR)
    frame.rightBar:SetSize(halfWidth, BAR_HEIGHT)
    frame.rightBar:SetPoint("LEFT", frame, "CENTER", 0, 0)

    -- Mid-level frame for overlays (above bars, below border)
    frame.overlayMid = CreateFrame("Frame", nil, frame)
    frame.overlayMid:SetAllPoints()
    frame.overlayMid:SetFrameLevel(frame:GetFrameLevel() + 5)

    -- Raised frame so border/text draw above everything
    local overlayFrame = CreateFrame("Frame", nil, frame)
    overlayFrame:SetAllPoints()
    overlayFrame:SetFrameLevel(frame:GetFrameLevel() + 10)

    AddBorder(frame, overlayFrame)
    AddText(frame, overlayFrame, "OUTLINE")

    frame.SetStatusBarColor = function(self, r, g, b, a)
        self.leftBar:SetStatusBarColor(r, g, b, a)
        self.rightBar:SetStatusBarColor(r, g, b, a)
    end

    frame.isCenter = true
    return frame
end

function cfSwingTimer.CreateBarFrame(moduleKey, y)
    local frame = CreateFrame("Frame", "cfSwingTimer_" .. moduleKey, UIParent)
    frame:SetPoint("CENTER", 0, y)
    frame:SetSize(cfSwingTimer.BAR_WIDTH, cfSwingTimer.BAR_HEIGHT)
    local bar = cfSwingTimer.CreateSwingBar(frame)
    bar:SetPoint("TOP")
    cfSwingTimer.bars[moduleKey] = bar
    return frame, bar
end

function cfSwingTimer.CreateCenterBarFrame(moduleKey, y)
    local frame = CreateFrame("Frame", "cfSwingTimer_" .. moduleKey, UIParent)
    frame:SetPoint("CENTER", 0, y)
    frame:SetSize(cfSwingTimer.BAR_WIDTH, cfSwingTimer.BAR_HEIGHT)
    local bar = cfSwingTimer.CreateCenterSwingBar(frame)
    bar:SetPoint("TOP")
    cfSwingTimer.bars[moduleKey] = bar
    return frame, bar
end

function cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    if bar.isCenter then
        bar.leftBar:SetValue(progress)
        bar.rightBar:SetValue(progress)
    else
        bar:SetValue(progress)
        if remaining > 0 then
            bar.spark:Show()
            bar.spark:ClearAllPoints()
            bar.spark:SetPoint("CENTER", bar, "LEFT", progress * bar:GetWidth(), 0)
        else
            bar.spark:Hide()
        end
    end

    bar.text:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
end


